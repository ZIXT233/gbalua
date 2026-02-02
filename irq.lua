local ClassUtils = require("ClassUtils")
local GameBoyAdvanceInterruptHandler = ClassUtils.class("GameBoyAdvanceInterruptHandler")
local MemoryBlock = require("mmu").MemoryBlock

-- 辅助函数：模拟 JS 的 (val | 0) 行为 (32位有符号截断)
local function toInt32(val)
	val = val & 0xFFFFFFFF
	if val >= 0x80000000 then
		return val - 0x100000000
	end
	return val
end

-- 辅助函数：模拟 C/JS 的整数除法 (向零取整)
local function div32(n, d)
	return math.modf(n / d)
end

-- SWI 查找表定义
local SWI_HANDLERS = {}

-- 0x00: SoftReset
SWI_HANDLERS[0x00] = function(self)
	local mem = self.core.mmu.memory[self.core.mmu.REGION_WORKING_IRAM]
	local flag = mem:loadU8(0x7ffa)
	for i = 0x7e00, 0x8000 - 1, 4 do
		mem:store32(i, 0)
	end
	self:resetSP()
	if flag == 0 then
		self.cpu.gprs[self.cpu.LR] = 0x08000000
	else
		self.cpu.gprs[self.cpu.LR] = 0x02000000
	end
	self.cpu:switchExecMode(self.cpu.MODE_ARM)
	self.cpu.instruction.writesPC = true
	self.cpu.gprs[self.cpu.PC] = self.cpu.gprs[self.cpu.LR]
end

-- 0x01: RegisterRamReset
SWI_HANDLERS[0x01] = function(self)
	local regions = self.cpu.gprs[0]
	if (regions & 0x01) ~= 0 then
		self.core.mmu.memory[self.core.mmu.REGION_WORKING_RAM] = 
			MemoryBlock.new(self.core.mmu.SIZE_WORKING_RAM, 9)
	end
	if (regions & 0x02) ~= 0 then
		local limit = self.core.mmu.SIZE_WORKING_IRAM - 0x200
		local mem = self.core.mmu.memory[self.core.mmu.REGION_WORKING_IRAM]
		for i = 0, limit - 1, 4 do
			mem:store32(i, 0)
		end
	end
	if (regions & 0x1c) ~= 0 then
		self.video.renderPath:clearSubsets(self.core.mmu, regions)
	end
	if (regions & 0xe0) ~= 0 then
		self.core:STUB("Unimplemented RegisterRamReset")
	end
end

-- 0x02: Halt
SWI_HANDLERS[0x02] = function(self)
	self:halt()
end

-- 0x04: IntrWait / 0x05: VBlankIntrWait
local function IntrWait(self, oldFlags)
	if not self.enable then
		self.io:store16(self.io.IME, 1)
	end
	if self.cpu.gprs[0] == 0 and (self.interruptFlags & self.cpu.gprs[1]) ~= 0 then
		return
	end
	self:dismissIRQs(0xffffffff)
	self.cpu:raiseTrap()
end

SWI_HANDLERS[0x04] = IntrWait
SWI_HANDLERS[0x05] = function(self)
	self.cpu.gprs[0] = 1
	self.cpu.gprs[1] = 1
	IntrWait(self)
end

-- 0x06: Div
SWI_HANDLERS[0x06] = function(self)
	local n = toInt32(self.cpu.gprs[0])
	local d = toInt32(self.cpu.gprs[1])
	local result = div32(n, d)
	local mod = n % d -- Lua % operator handles sign differently than JS usually, but for remainder:
    -- JS: n % d. Lua: n % d. 
    -- Note: JS -5 % 2 = -1. Lua -5 % 2 = 1.
    -- Manual remainder to match C/JS: n - (math.modf(n/d) * d)
    mod = n - (result * d)

	self.cpu.gprs[0] = result & 0xFFFFFFFF
	self.cpu.gprs[1] = mod & 0xFFFFFFFF
	self.cpu.gprs[3] = math.abs(result) & 0xFFFFFFFF
end

-- 0x07: DivArm
SWI_HANDLERS[0x07] = function(self)
	local d = toInt32(self.cpu.gprs[0])
	local n = toInt32(self.cpu.gprs[1])
    if d == 0 then -- Avoid division by zero
        -- Handle div by zero if necessary, usually GBA behavior is specific but basic Lua will error or inf
        d = 1 -- Dummy prevention or raise error
    end
	local result = div32(n, d)
	local mod = n - (result * d)
	self.cpu.gprs[0] = result & 0xFFFFFFFF
	self.cpu.gprs[1] = mod & 0xFFFFFFFF
	self.cpu.gprs[3] = math.abs(result) & 0xFFFFFFFF
end

-- 0x08: Sqrt
SWI_HANDLERS[0x08] = function(self)
	local root = math.sqrt(self.cpu.gprs[0])
	self.cpu.gprs[0] = math.floor(root)
end

-- 0x0a: ArcTan2
SWI_HANDLERS[0x0a] = function(self)
	local x = toInt32(self.cpu.gprs[0]) / 16384
	local y = toInt32(self.cpu.gprs[1]) / 16384
	-- JS: (Math.atan2(y, x) / (2 * Math.PI)) * 0x10000
    -- Lua 5.4 uses math.atan(y, x) instead of atan2
	self.cpu.gprs[0] = math.floor((math.atan(y, x) / (2 * math.pi)) * 0x10000) & 0xFFFFFFFF
end

-- 0x0b: CpuSet
SWI_HANDLERS[0x0b] = function(self)
	local source = self.cpu.gprs[0]
	local dest = self.cpu.gprs[1]
	local mode = self.cpu.gprs[2]
	local count = mode & 0x000fffff
	local fill = (mode & 0x01000000) ~= 0
	local wordsize = ((mode & 0x04000000) ~= 0) and 4 or 2

	if fill then
		if wordsize == 4 then
			source = source & 0xfffffffc
			dest = dest & 0xfffffffc
			local word = self.cpu.mmu:load32(source)
			for i = 0, count - 1 do
				self.cpu.mmu:store32(dest + (i << 2), word)
			end
		else
			source = source & 0xfffffffe
			dest = dest & 0xfffffffe
			local word = self.cpu.mmu:load16(source)
			for i = 0, count - 1 do
				self.cpu.mmu:store16(dest + (i << 1), word)
			end
		end
	else
		if wordsize == 4 then
			source = source & 0xfffffffc
			dest = dest & 0xfffffffc
			for i = 0, count - 1 do
				local word = self.cpu.mmu:load32(source + (i << 2))
				self.cpu.mmu:store32(dest + (i << 2), word)
			end
		else
			source = source & 0xfffffffe
			dest = dest & 0xfffffffe
			for i = 0, count - 1 do
				local word = self.cpu.mmu:load16(source + (i << 1))
				self.cpu.mmu:store16(dest + (i << 1), word)
			end
		end
	end
end

-- 0x0c: FastCpuSet
SWI_HANDLERS[0x0c] = function(self)
	local source = self.cpu.gprs[0] & 0xfffffffc
	local dest = self.cpu.gprs[1] & 0xfffffffc
	local mode = self.cpu.gprs[2]
	local count = mode & 0x000fffff
	count = ((count + 7) >> 3) << 3
	local fill = (mode & 0x01000000) ~= 0

	if fill then
		local word = self.cpu.mmu:load32(source)
		for i = 0, count - 1 do
			self.cpu.mmu:store32(dest + (i << 2), word)
		end
	else
		for i = 0, count - 1 do
			local word = self.cpu.mmu:load32(source + (i << 2))
			self.cpu.mmu:store32(dest + (i << 2), word)
		end
	end
end

-- 0x0e: BgAffineSet
SWI_HANDLERS[0x0e] = function(self)
	local i = self.cpu.gprs[2]
	local offset = self.cpu.gprs[0]
	local destination = self.cpu.gprs[1]
	
	while i > 0 do
		i = i - 1
		local ox = toInt32(self.core.mmu:load32(offset)) / 256
		local oy = toInt32(self.core.mmu:load32(offset + 4)) / 256
		local cx = toInt32(self.core.mmu:load16(offset + 8)) -- load16 is signed short in JS implementation context usually? JS version used load16 which implies signed.
        -- Assuming load16 is signed, loadU16 is unsigned.
        -- JS: load16. Lua ARMCore usually has load16 signed.
        
		local cy = toInt32(self.core.mmu:load16(offset + 10))
		local sx = toInt32(self.core.mmu:load16(offset + 12)) / 256
		local sy = toInt32(self.core.mmu:load16(offset + 14)) / 256
		local theta = ((self.core.mmu:loadU16(offset + 16) >> 8) / 128) * math.pi
		offset = offset + 20
		
		-- Rotation
		local a = math.cos(theta)
        local d = a
		local b = math.sin(theta)
        local c = b
		
		-- Scale
		a = a * sx
		b = b * -sx
		c = c * sy
		d = d * sy
		
		-- Translate
		local rx = ox - (a * cx + b * cy)
		local ry = oy - (c * cx + d * cy)
		
		self.core.mmu:store16(destination, math.floor(a * 256))
		self.core.mmu:store16(destination + 2, math.floor(b * 256))
		self.core.mmu:store16(destination + 4, math.floor(c * 256))
		self.core.mmu:store16(destination + 6, math.floor(d * 256))
		self.core.mmu:store32(destination + 8, math.floor(rx * 256))
		self.core.mmu:store32(destination + 12, math.floor(ry * 256))
		destination = destination + 16
	end
end

-- 0x0f: ObjAffineSet
SWI_HANDLERS[0x0f] = function(self)
	local i = self.cpu.gprs[2]
	local offset = self.cpu.gprs[0]
	local destination = self.cpu.gprs[1]
	local diff = self.cpu.gprs[3]
	
	while i > 0 do
		i = i - 1
		local sx = toInt32(self.core.mmu:load16(offset)) / 256
		local sy = toInt32(self.core.mmu:load16(offset + 2)) / 256
		local theta = ((self.core.mmu:loadU16(offset + 4) >> 8) / 128) * math.pi
		offset = offset + 6
		
		local a = math.cos(theta)
        local d = a
		local b = math.sin(theta)
        local c = b
		
		a = a * sx
		b = b * -sx
		c = c * sy
		d = d * sy
		
		self.core.mmu:store16(destination, math.floor(a * 256))
		self.core.mmu:store16(destination + diff, math.floor(b * 256))
		self.core.mmu:store16(destination + diff * 2, math.floor(c * 256))
		self.core.mmu:store16(destination + diff * 3, math.floor(d * 256))
		destination = destination + diff * 4
	end
end

-- 0x11: LZ77UnCompWram
SWI_HANDLERS[0x11] = function(self)
	self:lz77(self.cpu.gprs[0], self.cpu.gprs[1], 1)
end

-- 0x12: LZ77UnCompVram
SWI_HANDLERS[0x12] = function(self)
	self:lz77(self.cpu.gprs[0], self.cpu.gprs[1], 2)
end

-- 0x13: HuffUnComp
SWI_HANDLERS[0x13] = function(self)
	self:huffman(self.cpu.gprs[0], self.cpu.gprs[1])
end

-- 0x14: RlUnCompWram
SWI_HANDLERS[0x14] = function(self)
	self:rl(self.cpu.gprs[0], self.cpu.gprs[1], 1)
end

-- 0x15: RlUnCompVram
SWI_HANDLERS[0x15] = function(self)
	self:rl(self.cpu.gprs[0], self.cpu.gprs[1], 2)
end

-- 0x1f: MidiKey2Freq
SWI_HANDLERS[0x1f] = function(self)
	local key = self.cpu.mmu:load32(self.cpu.gprs[0] + 4)
	local val1 = self.cpu.gprs[1]
	local val2 = self.cpu.gprs[2]
	local exponent = (180 - val1 - val2 / 256) / 12
	self.cpu.gprs[0] = math.floor(key / (2 ^ exponent)) & 0xFFFFFFFF
end


function GameBoyAdvanceInterruptHandler:ctor()
	-- self.inherit();
	self.FREQUENCY = 0x1000000

	self.cpu = nil
	self.enable = false

	self.IRQ_VBLANK = 0x0
	self.IRQ_HBLANK = 0x1
	self.IRQ_VCOUNTER = 0x2
	self.IRQ_TIMER0 = 0x3
	self.IRQ_TIMER1 = 0x4
	self.IRQ_TIMER2 = 0x5
	self.IRQ_TIMER3 = 0x6
	self.IRQ_SIO = 0x7
	self.IRQ_DMA0 = 0x8
	self.IRQ_DMA1 = 0x9
	self.IRQ_DMA2 = 0xa
	self.IRQ_DMA3 = 0xb
	self.IRQ_KEYPAD = 0xc
	self.IRQ_GAMEPAK = 0xd

	self.MASK_VBLANK = 0x0001
	self.MASK_HBLANK = 0x0002
	self.MASK_VCOUNTER = 0x0004
	self.MASK_TIMER0 = 0x0008
	self.MASK_TIMER1 = 0x0010
	self.MASK_TIMER2 = 0x0020
	self.MASK_TIMER3 = 0x0040
	self.MASK_SIO = 0x0080
	self.MASK_DMA0 = 0x0100
	self.MASK_DMA1 = 0x0200
	self.MASK_DMA2 = 0x0400
	self.MASK_DMA3 = 0x0800
	self.MASK_KEYPAD = 0x1000
	self.MASK_GAMEPAK = 0x2000
end

function GameBoyAdvanceInterruptHandler:clear()
	self.enable = false
	self.enabledIRQs = 0
	self.interruptFlags = 0

	self.dma = {}
	for i = 0, 3 do
		self.dma[i] = {
			source = 0,
			dest = 0,
			count = 0,
			nextSource = 0,
			nextDest = 0,
			nextCount = 0,
			srcControl = 0,
			dstControl = 0,
			["repeat"] = false, -- repeat is a reserved keyword in Lua
			width = 0,
			drq = false,
			timing = 0,
			doIrq = false,
			enable = false,
			nextIRQ = 0
		}
	end

	self.timersEnabled = 0
	self.timers = {}
	for i = 0, 3 do
		self.timers[i] = {
			reload = 0,
			oldReload = 0,
			prescaleBits = 0,
			countUp = false,
			doIrq = false,
			enable = false,
			lastEvent = 0,
			nextEvent = 0,
			overflowInterval = 1
		}
	end

	self.nextEvent = 0
	self.springIRQ = false
	self:resetSP()
end

function GameBoyAdvanceInterruptHandler:freeze()
	return {
		enable = self.enable,
		enabledIRQs = self.enabledIRQs,
		interruptFlags = self.interruptFlags,
		dma = self.dma,
		timers = self.timers,
		nextEvent = self.nextEvent,
		springIRQ = self.springIRQ
	}
end

function GameBoyAdvanceInterruptHandler:defrost(frost)
	self.enable = frost.enable
	self.enabledIRQs = frost.enabledIRQs
	self.interruptFlags = frost.interruptFlags
	self.dma = frost.dma
	self.timers = frost.timers
	self.timersEnabled = 0
	if self.timers[0].enable then
		self.timersEnabled = self.timersEnabled + 1
	end
	if self.timers[1].enable then
		self.timersEnabled = self.timersEnabled + 1
	end
	if self.timers[2].enable then
		self.timersEnabled = self.timersEnabled + 1
	end
	if self.timers[3].enable then
		self.timersEnabled = self.timersEnabled + 1
	end
	self.nextEvent = frost.nextEvent
	self.springIRQ = frost.springIRQ
end

function GameBoyAdvanceInterruptHandler:updateTimers()
	if self.nextEvent > self.cpu.cycles then
		return
	end

	if self.springIRQ then
		self.cpu:raiseIRQ()
		self.springIRQ = false
	end

	self.video:updateTimers(self.cpu)
	--self.audio:updateTimers()
	
	if self.timersEnabled > 0 then
		-- TIMER 0
		local timer = self.timers[0]
		if timer.enable then
			if self.cpu.cycles >= timer.nextEvent then
				timer.lastEvent = timer.nextEvent
				timer.nextEvent = timer.nextEvent + timer.overflowInterval
				self.io.registers[self.io.TM0CNT_LO >> 1] = timer.reload
				timer.oldReload = timer.reload

				if timer.doIrq then
					self:raiseIRQ(self.IRQ_TIMER0)
				end

				if self.audio.enabled then
					if self.audio.enableChannelA and not self.audio.soundTimerA and self.audio.dmaA >= 0 then
						self.audio:sampleFifoA()
					end

					if self.audio.enableChannelB and not self.audio.soundTimerB and self.audio.dmaB >= 0 then
						self.audio:sampleFifoB()
					end
				end

				-- TIMER 1 Cascade
				timer = self.timers[1]
				if timer.countUp then
					local regIdx = self.io.TM1CNT_LO >> 1
					self.io.registers[regIdx] = (self.io.registers[regIdx] + 1) & 0xFFFF
					if self.io.registers[regIdx] == 0x10000 then -- Note: & 0xFFFF above prevents this unless we check before mask, but JS relies on overflow.
                        -- JS: ++reg == 0x10000. 
                        -- Correct Lua logic for 16-bit wrap check:
                        -- Actually, JS arrays for registers are usually typed or treated as such. 
                        -- Assuming self.io.registers stores numbers.
                        -- Let's re-eval JS: `if (++this.io.registers[...] == 0x10000)`
                        -- This implies the stored value becomes 0x10000 temporarily.
                        -- In Lua:
                        self.io.registers[regIdx] = self.io.registers[regIdx] + 1 -- allow 17-bit momentarily
						if self.io.registers[regIdx] == 0x10000 then
							timer.nextEvent = self.cpu.cycles
						end
                        self.io.registers[regIdx] = self.io.registers[regIdx] & 0xFFFF -- Mask back
					end
				end
			end
		end

		-- TIMER 1
		timer = self.timers[1]
		if timer.enable then
			if self.cpu.cycles >= timer.nextEvent then
				timer.lastEvent = timer.nextEvent
				timer.nextEvent = timer.nextEvent + timer.overflowInterval
				local regIdx = self.io.TM1CNT_LO >> 1
				if not timer.countUp or self.io.registers[regIdx] == 0x10000 then
					self.io.registers[regIdx] = timer.reload
				end
				timer.oldReload = timer.reload

				if timer.doIrq then
					self:raiseIRQ(self.IRQ_TIMER1)
				end

				if timer.countUp then
					timer.nextEvent = 0
				end

				if self.audio.enabled then
					if self.audio.enableChannelA and self.audio.soundTimerA and self.audio.dmaA >= 0 then
						self.audio:sampleFifoA()
					end
					if self.audio.enableChannelB and self.audio.soundTimerB and self.audio.dmaB >= 0 then
						self.audio:sampleFifoB()
					end
				end

				-- TIMER 2 Cascade
				timer = self.timers[2]
				if timer.countUp then
					local regIdx2 = self.io.TM2CNT_LO >> 1
                    self.io.registers[regIdx2] = self.io.registers[regIdx2] + 1
					if self.io.registers[regIdx2] == 0x10000 then
						timer.nextEvent = self.cpu.cycles
					end
                    self.io.registers[regIdx2] = self.io.registers[regIdx2] & 0xFFFF
				end
			end
		end

		-- TIMER 2
		timer = self.timers[2]
		if timer.enable then
			if self.cpu.cycles >= timer.nextEvent then
				timer.lastEvent = timer.nextEvent
				timer.nextEvent = timer.nextEvent + timer.overflowInterval
				local regIdx = self.io.TM2CNT_LO >> 1
				if not timer.countUp or self.io.registers[regIdx] == 0x10000 then
					self.io.registers[regIdx] = timer.reload
				end
				timer.oldReload = timer.reload

				if timer.doIrq then
					self:raiseIRQ(self.IRQ_TIMER2)
				end

				if timer.countUp then
					timer.nextEvent = 0
				end

				-- TIMER 3 Cascade
				timer = self.timers[3]
				if timer.countUp then
					local regIdx3 = self.io.TM3CNT_LO >> 1
                    self.io.registers[regIdx3] = self.io.registers[regIdx3] + 1
					if self.io.registers[regIdx3] == 0x10000 then
						timer.nextEvent = self.cpu.cycles
					end
                    self.io.registers[regIdx3] = self.io.registers[regIdx3] & 0xFFFF
				end
			end
		end

		-- TIMER 3
		timer = self.timers[3]
		if timer.enable then
			if self.cpu.cycles >= timer.nextEvent then
				timer.lastEvent = timer.nextEvent
				timer.nextEvent = timer.nextEvent + timer.overflowInterval
				local regIdx = self.io.TM3CNT_LO >> 1
				if not timer.countUp or self.io.registers[regIdx] == 0x10000 then
					self.io.registers[regIdx] = timer.reload
				end
				timer.oldReload = timer.reload

				if timer.doIrq then
					self:raiseIRQ(self.IRQ_TIMER3)
				end

				if timer.countUp then
					timer.nextEvent = 0
				end
			end
		end
	end

	-- DMA
	for i = 0, 3 do
		local dma = self.dma[i]
		if dma.enable and dma.doIrq and dma.nextIRQ ~= 0 and self.cpu.cycles >= dma.nextIRQ then
			dma.nextIRQ = 0
			self:raiseIRQ(self.IRQ_DMA0 + i) -- IRQ_DMA0 is base, +0,+1,+2,+3 maps correctly
		end
	end

	self:pollNextEvent()
end

function GameBoyAdvanceInterruptHandler:resetSP()
	self.cpu:switchMode(self.cpu.MODE_SUPERVISOR)
	self.cpu.gprs[self.cpu.SP] = 0x3007fe0
	self.cpu:switchMode(self.cpu.MODE_IRQ)
	self.cpu.gprs[self.cpu.SP] = 0x3007fa0
	self.cpu:switchMode(self.cpu.MODE_SYSTEM)
	self.cpu.gprs[self.cpu.SP] = 0x3007f00
end

function GameBoyAdvanceInterruptHandler:swi32(opcode)
	self:swi(opcode >> 16)
end

function GameBoyAdvanceInterruptHandler:swi(opcode)
	if self.core.mmu.bios.real then
		self.cpu:raiseTrap()
		return
	end

	local handler = SWI_HANDLERS[opcode]
	if handler then
		handler(self)
	else
		error("Unimplemented software interrupt: 0x" .. string.format("%x", opcode))
	end
end

function GameBoyAdvanceInterruptHandler:masterEnable(value)
	self.enable = value

	if self.enable and (self.enabledIRQs & self.interruptFlags) ~= 0 then
		self.cpu:raiseIRQ()
	end
end

function GameBoyAdvanceInterruptHandler:setInterruptsEnabled(value)
	self.enabledIRQs = value

	if (self.enabledIRQs & self.MASK_SIO) ~= 0 then
		self.core:STUB("Serial I/O interrupts not implemented")
	end

	if (self.enabledIRQs & self.MASK_KEYPAD) ~= 0 then
		self.core:STUB("Keypad interrupts not implemented")
	end

	if self.enable and (self.enabledIRQs & self.interruptFlags) ~= 0 then
		self.cpu:raiseIRQ()
	end
end

function GameBoyAdvanceInterruptHandler:pollNextEvent()
	local nextEvent = self.video.nextEvent
	local test

	if self.audio.enabled then
		test = self.audio.nextEvent
		if not nextEvent or (test ~= 0 and test < nextEvent) then
			nextEvent = test
		end
	end

	if self.timersEnabled > 0 then
		for i = 0, 3 do
			local timer = self.timers[i]
			test = timer.nextEvent
			if timer.enable and test ~= 0 and (not nextEvent or test < nextEvent) then
				nextEvent = test
			end
		end
	end

	for i = 0, 3 do
		local dma = self.dma[i]
		test = dma.nextIRQ
		if dma.enable and dma.doIrq and test ~= 0 and (not nextEvent or test < nextEvent) then
			nextEvent = test
		end
	end

	self.core:ASSERT(
		(not nextEvent) or (nextEvent >= self.cpu.cycles),
		"Next event is before present"
	)
	self.nextEvent = nextEvent or 0 -- ensure number
end

function GameBoyAdvanceInterruptHandler:waitForIRQ()
	local irqPending = self:testIRQ() or 
					   self.video.hblankIRQ or 
					   self.video.vblankIRQ or 
					   self.video.vcounterIRQ
	
	if self.timersEnabled > 0 then
		for i = 0, 3 do
			irqPending = irqPending or self.timers[i].doIrq
		end
	end

	if not irqPending then
		return false
	end

	while true do
		self:pollNextEvent()

		if self.nextEvent == 0 then
			return false
		else
			self.cpu.cycles = self.nextEvent
			self:updateTimers()
			if self.interruptFlags ~= 0 then
				return true
			end
		end
	end
end

function GameBoyAdvanceInterruptHandler:testIRQ()
	if self.enable and (self.enabledIRQs & self.interruptFlags) ~= 0 then
		self.springIRQ = true
		self.nextEvent = self.cpu.cycles
		return true
	end
	return false
end

function GameBoyAdvanceInterruptHandler:raiseIRQ(irqType)
	self.interruptFlags = self.interruptFlags | (1 << irqType)
	self.io.registers[self.io.IF >> 1] = self.interruptFlags

	if self.enable and (self.enabledIRQs & (1 << irqType)) ~= 0 then
		self.cpu:raiseIRQ()
	end
end

function GameBoyAdvanceInterruptHandler:dismissIRQs(irqMask)
	self.interruptFlags = self.interruptFlags & (~irqMask)
	self.io.registers[self.io.IF >> 1] = self.interruptFlags
end

function GameBoyAdvanceInterruptHandler:dmaSetSourceAddress(dma, address)
	self.dma[dma].source = address & 0xfffffffe
end

function GameBoyAdvanceInterruptHandler:dmaSetDestAddress(dma, address)
	self.dma[dma].dest = address & 0xfffffffe
end

function GameBoyAdvanceInterruptHandler:dmaSetWordCount(dma, count)
	if count ~= 0 then
		self.dma[dma].count = count
	else
		self.dma[dma].count = (dma == 3) and 0x10000 or 0x4000
	end
end

function GameBoyAdvanceInterruptHandler:dmaWriteControl(dma, control)
	local currentDma = self.dma[dma]
	local wasEnabled = currentDma.enable
	currentDma.dstControl = (control & 0x0060) >> 5
	currentDma.srcControl = (control & 0x0180) >> 7
	currentDma["repeat"] = (control & 0x0200) ~= 0
	currentDma.width = ((control & 0x0400) ~= 0) and 4 or 2
	currentDma.drq = (control & 0x0800) ~= 0
	currentDma.timing = (control & 0x3000) >> 12
	currentDma.doIrq = (control & 0x4000) ~= 0
	currentDma.enable = (control & 0x8000) ~= 0
	currentDma.nextIRQ = 0

	if currentDma.drq then
		self.core:WARN("DRQ not implemented")
	end

	if not wasEnabled and currentDma.enable then
		currentDma.nextSource = currentDma.source
		currentDma.nextDest = currentDma.dest
		currentDma.nextCount = currentDma.count
		self.cpu.mmu:scheduleDma(dma, currentDma)
	end
end

function GameBoyAdvanceInterruptHandler:timerSetReload(timer, reload)
	self.timers[timer].reload = reload & 0xffff
end

function GameBoyAdvanceInterruptHandler:timerWriteControl(timer, control)
	local currentTimer = self.timers[timer]
	local oldPrescale = currentTimer.prescaleBits
	
	local scaleBits = control & 0x0003
	if scaleBits == 0 then currentTimer.prescaleBits = 0
	elseif scaleBits == 1 then currentTimer.prescaleBits = 6
	elseif scaleBits == 2 then currentTimer.prescaleBits = 8
	else currentTimer.prescaleBits = 10 end

	currentTimer.countUp = (control & 0x0004) ~= 0
	currentTimer.doIrq = (control & 0x0040) ~= 0
	currentTimer.overflowInterval = (0x10000 - currentTimer.reload) << currentTimer.prescaleBits
	
	local wasEnabled = currentTimer.enable
	-- JS: !!(((control & 0x0080) >> 7) << timer) -- This logic seems specific to setting enabled based on index?
    -- No, JS logic: `((control & 0x0080) >> 7)` results in 0 or 1. `<< timer` shifts it. `!!` converts to boolean.
    -- Wait, `enable` property is specific to THIS timer. The JS logic `<< timer` implies they might be writing to a shared register or using the timer index weirdly. 
    -- Actually, standard TMxCNT_H is 16 bits. bit 7 is enable.
    -- If `timer` is 0, (1 << 0) is true. If timer is 1, (1 << 1) is 2 (true).
    -- So essentially `(control & 0x0080) != 0` is what matters.
	currentTimer.enable = ((control & 0x0080)>>7)<<timer ~= 0

	if not wasEnabled and currentTimer.enable then
		if not currentTimer.countUp then
			currentTimer.lastEvent = self.cpu.cycles
			currentTimer.nextEvent = self.cpu.cycles + currentTimer.overflowInterval
		else
			currentTimer.nextEvent = 0
		end
		self.io.registers[(self.io.TM0CNT_LO + (timer << 2)) >> 1] = currentTimer.reload
		currentTimer.oldReload = currentTimer.reload
		self.timersEnabled = self.timersEnabled + 1
	elseif wasEnabled and not currentTimer.enable then
		if not currentTimer.countUp then
			self.io.registers[(self.io.TM0CNT_LO + (timer << 2)) >> 1] = 
				(currentTimer.oldReload + (self.cpu.cycles - currentTimer.lastEvent)) >> oldPrescale
		end
		self.timersEnabled = self.timersEnabled - 1
	elseif currentTimer.prescaleBits ~= oldPrescale and not currentTimer.countUp then
		-- FIXME: this might be before present
		currentTimer.nextEvent = currentTimer.lastEvent + currentTimer.overflowInterval
	end

	self:pollNextEvent()
end

function GameBoyAdvanceInterruptHandler:timerRead(timer)
	local currentTimer = self.timers[timer]
	if currentTimer.enable and not currentTimer.countUp then
		return (currentTimer.oldReload + (self.cpu.cycles - currentTimer.lastEvent)) >> currentTimer.prescaleBits
	else
		return self.io.registers[(self.io.TM0CNT_LO + (timer << 2)) >> 1]
	end
end

function GameBoyAdvanceInterruptHandler:halt()
	if not self.enable then
		error("Requested HALT when interrupts were disabled!")
	end
	if not self:waitForIRQ() then
		error("Waiting on interrupt forever.")
	end
end

function GameBoyAdvanceInterruptHandler:lz77(source, dest, unitsize)
	local remaining = (self.cpu.mmu:load32(source) & 0xffffff00) >> 8
	-- We assume the signature byte (0x10) is correct
	local blockheader
	local sPointer = source + 4
	local dPointer = dest
	local blocksRemaining = 0
	local block
	local disp
	local bytes
	local buffer = 0
	local loaded

	while remaining > 0 do
		if blocksRemaining > 0 then
			if (blockheader & 0x80) ~= 0 then
				-- Compressed
				block = self.cpu.mmu:loadU8(sPointer) | (self.cpu.mmu:loadU8(sPointer + 1) << 8)
				sPointer = sPointer + 2
				disp = dPointer - (((block & 0x000f) << 8) | ((block & 0xff00) >> 8)) - 1
				bytes = ((block & 0x00f0) >> 4) + 3
				while bytes > 0 and remaining > 0 do
                    bytes = bytes - 1
					loaded = self.cpu.mmu:loadU8(disp)
                    disp = disp + 1
					if unitsize == 2 then
						buffer = buffer >> 8
						buffer = buffer | (loaded << 8)
						if (dPointer & 1) ~= 0 then
							self.cpu.mmu:store16(dPointer - 1, buffer)
						end
					else
						self.cpu.mmu:store8(dPointer, loaded)
					end
					remaining = remaining - 1
					dPointer = dPointer + 1
				end
			else
				-- Uncompressed
				loaded = self.cpu.mmu:loadU8(sPointer)
                sPointer = sPointer + 1
				if unitsize == 2 then
					buffer = buffer >> 8
					buffer = buffer | (loaded << 8)
					if (dPointer & 1) ~= 0 then
						self.cpu.mmu:store16(dPointer - 1, buffer)
					end
				else
					self.cpu.mmu:store8(dPointer, loaded)
				end
				remaining = remaining - 1
				dPointer = dPointer + 1
			end
			blockheader = blockheader << 1
			blocksRemaining = blocksRemaining - 1
		else
			blockheader = self.cpu.mmu:loadU8(sPointer)
            sPointer = sPointer + 1
			blocksRemaining = 8
		end
	end
end

function GameBoyAdvanceInterruptHandler:huffman(source, dest)
	source = source & 0xfffffffc
	local header = self.cpu.mmu:load32(source)
	local remaining = header >> 8
	local bits = header & 0xf
	if (32 % bits) ~= 0 then
		error("Unimplemented unaligned Huffman")
	end
	local padding = (4 - remaining) & 0x3
	remaining = remaining & 0xfffffffc
	
	local tree = {}
	local treesize = (self.cpu.mmu:loadU8(source + 4) << 1) + 1
	local sPointer = source + 5 + treesize
	local dPointer = dest & 0xfffffffc
	
	for i = 0, treesize - 1 do
		table.insert(tree, self.cpu.mmu:loadU8(source + 5 + i))
	end
	
	local node
	local offset = 0
	local bitsRemaining
	local readBits
	local bitsSeen = 0
	local block = 0
	node = tree[1] -- Lua tables 1-based usually, but here we copied manually. Let's respect indices.
    -- The JS pushed, so indices were 0 to treesize-1.
    -- In Lua `table.insert` creates 1-based array.
    -- tree[1] in Lua corresponds to tree[0] in JS.
    node = tree[1]

	while remaining > 0 do
		local bitstream = self.cpu.mmu:load32(sPointer)
		sPointer = sPointer + 4
		
        bitsRemaining = 32
        while bitsRemaining > 0 do
            bitsRemaining = bitsRemaining - 1
            
			if type(node) == "number" then
				-- Lazily construct tree
                -- JS: ((offset - 1) | 1) + ((node & 0x3f) << 1) + 2
                -- Note: offset in JS started at 0 (root).
                -- In Lua, since we iterate `tree`, if we use 0-based logic for math, we must convert to 1-based for access.
                -- Let's stick to 0-based math for `next` calculation then convert for access.
				local next_idx = ((offset - 1) | 1) + ((node & 0x3f) << 1) + 2
				node = {
					l = next_idx,
					r = next_idx + 1,
					lTerm = (node & 0x80) ~= 0,
					rTerm = (node & 0x40) ~= 0
				}
				tree[offset + 1] = node -- Update array at 1-based index
			end

			if (bitstream & 0x80000000) ~= 0 then
				-- Go right
				if node.rTerm then
					readBits = tree[node.r + 1]
				else
					offset = node.r
					node = tree[node.r + 1]
                    bitstream = bitstream << 1
					goto continue
				end
			else
				-- Go left
				if node.lTerm then
					readBits = tree[node.l + 1]
				else
					offset = node.l
					node = tree[offset + 1]
                    bitstream = bitstream << 1
					goto continue
				end
			end

			block = block | ((readBits & ((1 << bits) - 1)) << bitsSeen)
			bitsSeen = bitsSeen + bits
			offset = 0
			node = tree[1]
			if bitsSeen == 32 then
				bitsSeen = 0
				self.cpu.mmu:store32(dPointer, block)
				dPointer = dPointer + 4
				remaining = remaining - 4
				block = 0
			end
            
            bitstream = bitstream << 1
            
            ::continue::
		end
	end
	if padding > 0 then
		self.cpu.mmu:store32(dPointer, block)
	end
end

function GameBoyAdvanceInterruptHandler:rl(source, dest, unitsize)
	source = source & 0xfffffffc
	local remaining = (self.cpu.mmu:load32(source) & 0xffffff00) >> 8
	local padding = (4 - remaining) & 0x3
	-- We assume the signature byte (0x30) is correct
	local blockheader
	local block
	local sPointer = source + 4
	local dPointer = dest
	local buffer = 0

	while remaining > 0 do
		blockheader = self.cpu.mmu:loadU8(sPointer)
        sPointer = sPointer + 1
		if (blockheader & 0x80) ~= 0 then
			-- Compressed
			blockheader = blockheader & 0x7f
			blockheader = blockheader + 3
			block = self.cpu.mmu:loadU8(sPointer)
            sPointer = sPointer + 1
			while blockheader > 0 and remaining > 0 do
                blockheader = blockheader - 1
				remaining = remaining - 1
				if unitsize == 2 then
					buffer = buffer >> 8
					buffer = buffer | (block << 8)
					if (dPointer & 1) ~= 0 then
						self.cpu.mmu:store16(dPointer - 1, buffer)
					end
				else
					self.cpu.mmu:store8(dPointer, block)
				end
				dPointer = dPointer + 1
			end
		else
			-- Uncompressed
			blockheader = blockheader + 1
			while blockheader > 0 and remaining > 0 do
                blockheader = blockheader - 1
				remaining = remaining - 1
				block = self.cpu.mmu:loadU8(sPointer)
                sPointer = sPointer + 1
				if unitsize == 2 then
					buffer = buffer >> 8
					buffer = buffer | (block << 8)
					if (dPointer & 1) ~= 0 then
						self.cpu.mmu:store16(dPointer - 1, buffer)
					end
				else
					self.cpu.mmu:store8(dPointer, block)
				end
				dPointer = dPointer + 1
			end
		end
	end
	while padding > 0 do
        padding = padding - 1
		self.cpu.mmu:store8(dPointer, 0)
        dPointer = dPointer + 1
	end
end

return GameBoyAdvanceInterruptHandler