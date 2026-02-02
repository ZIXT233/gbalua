-- GameBoyAdvanceVideo: Lua 移植自 gbajs 的 video 模块
-- 成员方法调用使用 : ，长 switch 用函数表查找

local ClassUtils = require("ClassUtils")
local GameBoyAdvanceSoftwareRenderer = require("video.software")

-- 关键节点调试：设为 true 时在 updateTimers / finishDraw 等处打印
local VIDEO_DEBUG = true
local VIDEO_DEBUG_FRAME_MAX = 2  -- 仅对前 N 帧做扫描线级输出
local function videoLog(tag, fmt, ...)
	if not VIDEO_DEBUG then return end
	if fmt then
		-- print(string.format("[VIDEO:%s] " .. fmt, tag, ...))
	else
		-- print("[VIDEO:" .. tag .. "]")
	end
end

local GameBoyAdvanceVideo = ClassUtils.class("GameBoyAdvanceVideo")

function GameBoyAdvanceVideo:ctor()
	-- 尝试使用 RenderProxy（如 Service Worker 渲染器），失败则回退到软件渲染
	local renderPath
	local ok, RenderProxy = pcall(require, "video.renderproxy")
	if ok and RenderProxy then
		renderPath = RenderProxy.new(self)
	else
		if not ok then
			-- print("Service worker renderer couldn't load. Save states (not save files) may be glitchy")
		end
		renderPath = GameBoyAdvanceSoftwareRenderer.new()
	end
	self.renderPath = renderPath

	self.CYCLES_PER_PIXEL = 4
	self.HORIZONTAL_PIXELS = 240
	self.HBLANK_PIXELS = 68
	self.HDRAW_LENGTH = 1006
	self.HBLANK_LENGTH = 226
	self.HORIZONTAL_LENGTH = 1232
	self.VERTICAL_PIXELS = 160
	self.VBLANK_PIXELS = 68
	self.VERTICAL_TOTAL_PIXELS = 228
	self.TOTAL_LENGTH = 280896

	self.drawCallback = function() end
	self.vblankCallback = function() end

	-- vcount 分支表（在 ctor 中构建一次，避免每次 updateTimers 重建）
	self.vcountHandlers = self:buildVcountHandlers()
end

function GameBoyAdvanceVideo:clear()
	self.renderPath:clear(self.cpu.mmu)

	-- DISPSTAT
	self.DISPSTAT_MASK = 0xFF38
	self.inHblank = false
	self.inVblank = false
	self.vcounter = 0
	self.vblankIRQ = 0
	self.hblankIRQ = 0
	self.vcounterIRQ = 0
	self.vcountSetting = 0
	-- VCOUNT
	self.vcount = -1

	self.lastHblank = 0
	self.nextHblank = self.HDRAW_LENGTH
	self.nextEvent = self.nextHblank

	self.nextHblankIRQ = 0
	self.nextVblankIRQ = 0
	self.nextVcounterIRQ = 0
end

function GameBoyAdvanceVideo:freeze()
	return {
		inHblank = self.inHblank,
		inVblank = self.inVblank,
		vcounter = self.vcounter,
		vblankIRQ = self.vblankIRQ,
		hblankIRQ = self.hblankIRQ,
		vcounterIRQ = self.vcounterIRQ,
		vcountSetting = self.vcountSetting,
		vcount = self.vcount,
		lastHblank = self.lastHblank,
		nextHblank = self.nextHblank,
		nextEvent = self.nextEvent,
		nextHblankIRQ = self.nextHblankIRQ,
		nextVblankIRQ = self.nextVblankIRQ,
		nextVcounterIRQ = self.nextVcounterIRQ,
		renderPath = self.core and self.core.encodeBase64 and self.renderPath:freeze(self.core.encodeBase64) or self.renderPath:freeze()
	}
end

function GameBoyAdvanceVideo:defrost(frost)
	self.inHblank = frost.inHblank
	self.inVblank = frost.inVblank
	self.vcounter = frost.vcounter
	self.vblankIRQ = frost.vblankIRQ
	self.hblankIRQ = frost.hblankIRQ
	self.vcounterIRQ = frost.vcounterIRQ
	self.vcountSetting = frost.vcountSetting
	self.vcount = frost.vcount
	self.lastHblank = frost.lastHblank
	self.nextHblank = frost.nextHblank
	self.nextEvent = frost.nextEvent
	self.nextHblankIRQ = frost.nextHblankIRQ
	self.nextVblankIRQ = frost.nextVblankIRQ
	self.nextVcounterIRQ = frost.nextVcounterIRQ
	if self.core and self.core.decodeBase64 then
		self.renderPath:defrost(frost.renderPath, self.core.decodeBase64)
	else
		self.renderPath:defrost(frost.renderPath)
	end
end

function GameBoyAdvanceVideo:setBacking(backing)
	--local pixelData = backing.createImageData(
	--	self.HORIZONTAL_PIXELS,
	--	self.VERTICAL_PIXELS
	--)
	--self.context = backing
	local pixelData = backing

	self.renderPath:setBacking(pixelData)
end

-- vcount 分支：用函数表替代长 switch
function GameBoyAdvanceVideo:buildVcountHandlers()
	local video = self
	return {
		[video.VERTICAL_PIXELS] = function()
			-- 进入 VBlank
			video.inVblank = true
			video.renderPath:finishDraw(video)
			video.nextVblankIRQ = video.nextEvent + video.TOTAL_LENGTH
			video.cpu.mmu:runVblankDmas()
			if video.vblankIRQ ~= 0 then
				video.cpu.irq:raiseIRQ(video.cpu.irq.IRQ_VBLANK)
			end
			video.vblankCallback()
		end,
		[video.VERTICAL_TOTAL_PIXELS - 1] = function()
			video.inVblank = false
		end,
		[video.VERTICAL_TOTAL_PIXELS] = function()
			video.vcount = 0
			video.renderPath:startDraw()
		end
	}
end

function GameBoyAdvanceVideo:updateTimers(cpu)
	local cycles = cpu.cycles

	if self.nextEvent <= cycles then
		if self.inHblank then
			-- 结束 HBlank
			self.inHblank = false
			self.nextEvent = self.nextHblank

			self.vcount = self.vcount + 1

			-- [关键节点] vcount 变化：0=新帧首行, 160=VBlank, 228=startDraw
			if VIDEO_DEBUG and (self.vcount == 0 or self.vcount == 160 or self.vcount == 228) then
				videoLog("TIMER", "endHBlank vcount=%d cycles=%d", self.vcount, cpu.cycles)
			end
			local handler = self.vcountHandlers[self.vcount]
			if handler then
				handler()
			end

			self.vcounter = (self.vcount == self.vcountSetting)
			if self.vcounter and self.vcounterIRQ ~= 0 then
				self.cpu.irq:raiseIRQ(self.cpu.irq.IRQ_VCOUNTER)
				self.nextVcounterIRQ = self.nextVcounterIRQ + self.TOTAL_LENGTH
			end

			if self.vcount < self.VERTICAL_PIXELS then
				if VIDEO_DEBUG and self.renderPath._ppuDebugFrame and self.renderPath._ppuDebugFrame <= VIDEO_DEBUG_FRAME_MAX and (self.vcount == 0 or self.vcount == 79 or self.vcount == 159) then
					videoLog("SCAN", "drawScanline y=%d", self.vcount)
				end
				self.renderPath:drawScanline(self.vcount)
			end
		else
			-- 开始 HBlank
			self.inHblank = true
			self.lastHblank = self.nextHblank
			self.nextEvent = self.lastHblank + self.HBLANK_LENGTH
			self.nextHblank = self.nextEvent + self.HDRAW_LENGTH
			self.nextHblankIRQ = self.nextHblank

			if self.vcount < self.VERTICAL_PIXELS then
				self.cpu.mmu:runHblankDmas()
			end
			if self.hblankIRQ ~= 0 then
				self.cpu.irq:raiseIRQ(self.cpu.irq.IRQ_HBLANK)
			end
		end
	end
end

function GameBoyAdvanceVideo:writeDisplayStat(value)
	self.vblankIRQ = value & 0x0008
	self.hblankIRQ = value & 0x0010
	self.vcounterIRQ = value & 0x0020
	-- Lua >> 为逻辑右移；此处为无符号 8 位，无需符号扩展
	self.vcountSetting = (value & 0xFF00) >> 8

	if self.vcounterIRQ ~= 0 then
		-- FIXME: 若正处于 HBlank 中间可能偏晚
		self.nextVcounterIRQ = self.nextHblank
			+ self.HBLANK_LENGTH
			+ (self.vcountSetting - self.vcount) * self.HORIZONTAL_LENGTH
		if self.nextVcounterIRQ < self.nextEvent then
			self.nextVcounterIRQ = self.nextVcounterIRQ + self.TOTAL_LENGTH
		end
	end
end

function GameBoyAdvanceVideo:readDisplayStat()
	local v = (self.inVblank and 1 or 0)
		| ((self.inHblank and 1 or 0) << 1)
		| ((self.vcounter and 1 or 0) << 2)
	return v
end

function GameBoyAdvanceVideo:finishDraw(pixelData)
	-- [关键节点] 一帧渲染完毕，即将交给显示
	if VIDEO_DEBUG then
		local sample = pixelData and pixelData.data
		local r = sample and sample[0] or 0
		local g = sample and sample[1] or 0
		local b = sample and sample[2] or 0
		videoLog("OUT", "finishDraw pixel(0,0)=%d,%d,%d context=%s", r, g, b, (self.context and "yes" or "no"))
	end
	self.drawCallback()
end

return GameBoyAdvanceVideo
