local ARMCore = require("core")
local MMU = require("mmu").MMU
-- 假设你的中断模块叫 IRQHandler，如果叫其他名字请修改
local IRQ = require("irq") 
local IO = require("gbaio")
local VIDEO = require("video")
local Keypad = require("keypad")
local SIO = require("sio")

-- ==========================================
-- 1. 虚拟设备 (Stub/Mock Devices)
-- 用于欺骗 MMU，防止读写 IO/Video 时报错
-- ==========================================
local DummyDevice = {}
DummyDevice.__index = DummyDevice

function DummyDevice:new(name)
    return setmetatable({name = name}, self)
end

-- 所有读操作返回 0
function DummyDevice:load8(offset) return 0 end
function DummyDevice:load16(offset) return 0 end
function DummyDevice:load32(offset) return 0 end
function DummyDevice:loadU8(offset) return 0 end
function DummyDevice:loadU16(offset) return 0 end

-- 所有写操作只打印日志（可选），不实际存储
function DummyDevice:store8(offset, value) 
    -- print(string.format("[%s] Write8 off:0x%x val:0x%x", self.name, offset, value)) 
end
function DummyDevice:store16(offset, value) 
    -- print(string.format("[%s] Write16 off:0x%x val:0x%x", self.name, offset, value)) 
end
function DummyDevice:store32(offset, value) 
    -- print(string.format("[%s] Write32 off:0x%x val:0x%x", self.name, offset, value)) 
end

-- 清除状态接口
function DummyDevice:clear() end 

-- ==========================================
-- 2. GBA 主类
-- ==========================================
local ClassUtils = require("ClassUtils")
local GBA = ClassUtils.class("GBA")

function GBA:ctor()
    local gba = self
    gba.LOG_ERROR = 1;
    gba.LOG_WARN = 2;
    gba.LOG_STUB = 4;
    gba.LOG_INFO = 8;
    gba.LOG_DEBUG = 16;
    gba.logLevel = gba.LOG_ERROR | gba.LOG_WARN;
    gba.SYS_ID = "com.lua.gba"

    -- 调试钩子：设为 true 可输出 SWI/DMA 等调试信息，用于排查塞尔达白屏等
    -- 用法: gba.debugHooks.swiCpuSet = true   -- 打印 SWI 0x0B/0x0C 调用
    --       gba.debugHooks.dma = true         -- 打印 DMA 调度与执行
    gba.debugHooks = {
        swiCpuSet = false,
        dma = false,
    }

    -- 实例化核心组件
    gba.cpu = ARMCore.new()
    gba.mmu = MMU.new()
    gba.irq = IRQ.new()

    -- 实例化虚拟外设
    gba.io = IO.new()
    gba.audio = DummyDevice:new("Audio")
    gba.sio = SIO.new()
    gba.keypad = Keypad.new()

    gba.video = VIDEO.new()

    -- ==============================
    -- 依赖注入 (Wiring) - 核心部分
    -- ==============================
    -- CPU 连接
    gba.cpu.mmu = gba.mmu
    gba.cpu.irq = gba.irq

    -- MMU 连接
    gba.mmu.cpu = gba.cpu
    gba.mmu.core = gba

    -- IRQ 连接
    gba.irq.cpu = gba.cpu
    gba.irq.io = gba.io
    gba.irq.audio = gba.audio
    gba.irq.video = gba.video
    gba.irq.core = gba

    -- IO 连接
    gba.io.cpu = gba.cpu
    gba.io.audio = gba.audio
    gba.io.video = gba.video
    gba.io.sio = gba.sio
    gba.io.keypad = gba.keypad
    gba.io.core = gba
    gba.io:initHandlers()

    gba.sio.core = gba

    gba.video.cpu = gba.cpu;
    gba.video.core = gba;

    -- 与 gbajs 一致的 vblankCallback + waitFrame 机制：每帧 VBlank 时置位 seenFrame，step() 跑到一帧结束
    gba.seenFrame = false
    gba.seenSave = false
    gba.saveDir = "."  -- 存档目录，可配置
    gba.doStep = function() return gba:waitFrame() end
    gba.video.vblankCallback = function()
        gba.seenFrame = true
    end
end

function GBA:reset()
    self.seenFrame = false
    -- 清空 MMU 映射
    self.mmu:clear()
    self.io:clear()
    self.audio:clear()
    self.video:clear()
    self.sio:clear()
    self.keypad:clear()


    -- 如果你的 MMU.mmap 还没实现，这里会报错，需要先去 MMU 实现它
    self.mmu:mmap(self.mmu.REGION_IO, self.io)
    self.mmu:mmap(self.mmu.REGION_PALETTE_RAM, self.video.renderPath.palette)
    self.mmu:mmap(self.mmu.REGION_VRAM, self.video.renderPath.vram)
    self.mmu:mmap(self.mmu.REGION_OAM, self.video.renderPath.oam)

    -- 重置 CPU (ARM模式，PC=0)
    self.cpu:resetCPU(0)
end

-- ==========================================
-- 3. ROM 加载器 (核心需求)
-- ==========================================
local ArrayBuffer = require("hal.ArrayBuffer")

local function stringToArrayBuffer(content)
    local romTable = ArrayBuffer.new(#content)
    local index = 0
    for i = 1, #content, 4 do
        local b1 = string.byte(content, i) or 0
        local b2 = string.byte(content, i+1) or 0
        local b3 = string.byte(content, i+2) or 0
        local b4 = string.byte(content, i+3) or 0
        local word = b1 + (b2 << 8) + (b3 << 16) + (b4 << 24)
        romTable[index] = word
        index = index + 1
    end
    return romTable
end

local function readFileAsArrayBuffer(filename)
    local f = io.open(filename, "rb")
    if not f then 
        print("Error: Could not open file " .. filename)
        return false 
    end
    local content = f:read("*all")
    f:close()
    return stringToArrayBuffer(content)
end

function GBA:loadBiosFromFile(filename)
    local biosTable = readFileAsArrayBuffer(filename)
    if not biosTable then
        return false
    end
    self.mmu:loadBios(biosTable)
    return true
end

function GBA:loadRomFromFileSimple(filename)
    local romTable = readFileAsArrayBuffer(filename)
    if not romTable then
        return false
    end
    self.mmu:loadRomSimple(romTable)
    
    return true
end


function GBA:loadRomFromFile(filename)
    local romTable = readFileAsArrayBuffer(filename)
    if not romTable then
        return false
    end
    self:reset()
    local ok = self.mmu:loadRom(romTable, true)
    if not ok then
        return false
    end
    self:retrieveSavedata()
    return true
end






-- ==========================================
-- 4. 调试辅助函数
-- ==========================================

-- 跳过 BIOS 引导，直接准备运行 ROM
function GBA:skipBios()
    -- 设置模式为 System (0x1F) 或 User (0x10)，通常 System 权限更高方便调试
    -- 还要禁用 IRQ/FIQ (设置 I/F 位)
    self.cpu.cpsr = 0x1F 
    
    -- 设置栈指针 (R13/SP)
    -- 真实 BIOS 会将 SP 初始化到 IWRAM (0x03007F00)
    self.cpu.gprs[13] = 0x03007F00 
    
    -- 设置 PC (R15) 指向 ROM 入口 (0x08000000)
    -- JS 原始代码中 resetCPU 设为 0 是因为有 BIOS。我们跳过 BIOS。
    self.cpu.gprs[15] = 0x08000004
    
    -- 如果是 Thumb 模式入口 (极少见)，需要调整。通常 GBA 游戏是 ARM 入口。
    
    -- 刷新流水线 (模拟器中通常只需要设定 PC)
    print("Skipped BIOS. PC set to 0x08000000, SP set to 0x03007F00")
end

function GBA:setCanvas(canvas, drawCallback)
    self.video:setBacking(canvas)
    self.video.drawCallback = drawCallback
end

-- 与 gbajs 一致：未见到本帧 VBlank 时返回 true（继续跑），见到后返回 false（本帧结束）
function GBA:waitFrame()
    local seen = self.seenFrame
    self.seenFrame = false
    return not seen
end

-- 跑 CPU 直到完成一帧（即直到发生一次 VBlank，vblankCallback 被调用）
function GBA:step()
    while self:doStep() do
        self.cpu:step()
    end
end

-- 与 gbajs 一致：一帧结束后处理存档（延迟写入磁盘，避免频繁 I/O）
function GBA:advanceFrame()
    self:step()
    if self.seenSave then
        if not self.mmu:saveNeedsFlush() then
            self:storeSavedata()
            self.seenSave = false
        else
            self.mmu:flushSave()
        end
    elseif self.mmu:saveNeedsFlush() then
        self.seenSave = true
        self.mmu:flushSave()
    end
end

-- ==========================================
-- 存档持久化 (Lua 本地文件)
-- ==========================================
local savedata_mod = require("savedata")

function GBA:setSavedata(data)
    if self.mmu.save then
        self.mmu:loadSavedata(data)
    end
end

function GBA:loadSavedataFromFile(path)
    local data = savedata_mod.loadSavedataFromFile(path)
    if data then
        self:setSavedata(data)
        return true
    end
    return false
end

function GBA:storeSavedata()
    local save = self.mmu.save
    if not save then
        self:WARN("No save data available")
        return false
    end
    local cart = self.mmu.cart
    if not cart or not cart.code then
        self:WARN("No cart code for save path")
        return false
    end
    local path = savedata_mod.getSavePath(cart.code, self.saveDir)
    local ok = savedata_mod.storeSavedataToFile(path, save.buffer)
    if not ok then
        self:WARN("Could not store savedata to " .. path)
        return false
    end
    return true
end

function GBA:retrieveSavedata()
    local cart = self.mmu.cart
    if not cart or not cart.code then
        return false
    end
    local path = savedata_mod.getSavePath(cart.code, self.saveDir)
    local data = savedata_mod.loadSavedataFromFile(path)
    if data then
        self:setSavedata(data)
        return true
    end
    return false
end

function GBA:log(level, message)
    print(string.format("LOG: %s %s", level, message))
end
function GBA:setLogger(logger)
    self.log = logger;
end
function GBA:logStackTrace(stack)
    local overflow = #stack - 32;
    self:ERROR("Stack trace follows:");
    if overflow > 0 then
        self:log(-1, "> (Too many frames)");
    end
    for i = math.max(overflow, 0), #stack do
        self:log(-1, "> " .. stack[i]);
    end
end
function GBA:ERROR(error)
    if self.logLevel & self.LOG_ERROR ~=0 then
        self:log(self.LOG_ERROR, error);
    end
end

function GBA:WARN(warn)
    if self.logLevel & self.LOG_WARN ~=0 then
        self:log(self.LOG_WARN, warn);
    end
end
function GBA:STUB(func)
    if self.logLevel & self.LOG_STUB ~=0 then
        self:log(self.LOG_STUB, func);
    end
end
function GBA:INFO(info)
    if self.logLevel & self.LOG_INFO ~=0 then
        self:log(self.LOG_INFO, info);
    end
end


function GBA:DEBUG(info)
    if self.logLevel & self.LOG_DEBUG ~=0 then
        self:log(self.LOG_DEBUG, info);
    end
end
function GBA:ASSERT_UNREACHED(err)
    error("Should be unreached: " .. err);
end
function GBA:ASSERT(test, err)
    if not test then
        error("Assertion failed: " .. err);
    end
end
return GBA