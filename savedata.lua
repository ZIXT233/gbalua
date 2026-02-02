--[[
  savedata.lua - GBA 存档模块
  参考 gbajs savedata.js 移植，支持 SRAM、Flash、EEPROM 三种存档类型
  结合 Lua 本地文件读写实现持久化
]]

local ClassUtils = require("ClassUtils")
local memory = require("memory")
local MemoryView = memory.MemoryView
local ArrayBuffer = require("hal.ArrayBuffer")
local DataView = require("hal.DataView")

-- ============================================================
-- SRAM 存档 (32KB)
-- ============================================================
local SRAMSaveData = ClassUtils.class("SRAMSaveData", MemoryView)

function SRAMSaveData:ctor(size)
    local buf = ArrayBuffer.new(size)
    self.super.ctor(self, buf, 0)
    self.writePending = false
end

function SRAMSaveData:store8(offset, value)
    self.view:setInt8(offset, value)
    self.writePending = true
end

function SRAMSaveData:store16(offset, value)
    self.view:setInt16(offset, value, true)
    self.writePending = true
end

function SRAMSaveData:store32(offset, value)
    self.view:setInt32(offset, value, true)
    self.writePending = true
end

-- ============================================================
-- Flash 存档 (64KB 或 128KB)
-- ============================================================
local FlashSaveData = ClassUtils.class("FlashSaveData", MemoryView)

function FlashSaveData:ctor(size)
    local buf = ArrayBuffer.new(size)
    self.super.ctor(self, buf, 0)

    self.COMMAND_WIPE = 0x10
    self.COMMAND_ERASE_SECTOR = 0x30
    self.COMMAND_ERASE = 0x80
    self.COMMAND_ID = 0x90
    self.COMMAND_WRITE = 0xa0
    self.COMMAND_SWITCH_BANK = 0xb0
    self.COMMAND_TERMINATE_ID = 0xf0

    self.ID_PANASONIC = 0x1b32
    self.ID_SANYO = 0x1362

    -- bank0: 前 64KB
    self.bank0 = DataView.new(self.buffer, 0)
    if size > 0x00010000 then
        self.id = self.ID_SANYO
        self.bank1 = DataView.new(self.buffer, 0x00010000)
    else
        self.id = self.ID_PANASONIC
        self.bank1 = nil
    end
    self.bank = self.bank0

    self.idMode = false
    self.writePending = false
    self.first = 0
    self.second = 0
    self.command = 0
    self.pendingCommand = 0
end

function FlashSaveData:load8(offset)
    if self.idMode and offset < 2 then
        return (self.id >> (offset << 3)) & 0xff
    elseif offset < 0x10000 then
        return self.bank:getInt8(offset)
    else
        return 0
    end
end

function FlashSaveData:load16(offset)
    return (self:load8(offset) & 0xff) | (self:load8(offset + 1) << 8)
end

function FlashSaveData:load32(offset)
    return (self:load8(offset) & 0xff)
        | (self:load8(offset + 1) << 8)
        | (self:load8(offset + 2) << 16)
        | (self:load8(offset + 3) << 24)
end

function FlashSaveData:loadU8(offset)
    return self:load8(offset) & 0xff
end

function FlashSaveData:loadU16(offset)
    return (self:loadU8(offset) & 0xff) | (self:loadU8(offset + 1) << 8)
end

function FlashSaveData:store8(offset, value)
    if self.command == 0 then
        if offset == 0x5555 then
            if self.second == 0x55 then
                if value == self.COMMAND_ERASE then
                    self.pendingCommand = value
                elseif value == self.COMMAND_ID then
                    self.idMode = true
                elseif value == self.COMMAND_TERMINATE_ID then
                    self.idMode = false
                else
                    self.command = value
                end
                self.second = 0
                self.first = 0
            else
                self.command = 0
                self.first = value
                self.idMode = false
            end
        elseif offset == 0x2aaa and self.first == 0xaa then
            self.first = 0
            if self.pendingCommand ~= 0 then
                self.command = self.pendingCommand
            else
                self.second = value
            end
        end
    elseif self.command == self.COMMAND_ERASE then
        if value == self.COMMAND_WIPE and offset == 0x5555 then
            for i = 0, self.view.buffer.byteLength - 1, 4 do
                self.view:setInt32(i, -1)
            end
        elseif value == self.COMMAND_ERASE_SECTOR and (offset & 0x0fff) == 0 then
            for i = offset, offset + 0x1000 - 1, 4 do
                self.bank:setInt32(i, -1)
            end
        end
        self.pendingCommand = 0
        self.command = 0
    elseif self.command == self.COMMAND_WRITE then
        self.bank:setInt8(offset, value)
        self.command = 0
        self.writePending = true
    elseif self.command == self.COMMAND_SWITCH_BANK then
        if self.bank1 and offset == 0 then
            if value == 1 then
                self.bank = self.bank1
            else
                self.bank = self.bank0
            end
        end
        self.command = 0
    end
end

function FlashSaveData:store16(offset, value)
    error("Unaligned save to flash!")
end

function FlashSaveData:store32(offset, value)
    error("Unaligned save to flash!")
end

function FlashSaveData:replaceData(memory, offset)
    local wasBank1 = (self.bank == self.bank1) and (self.bank1 ~= nil)
    self.super.replaceData(self, memory, offset or 0)

    self.bank0 = DataView.new(self.buffer, 0)
    if memory.byteLength > 0x00010000 then
        self.bank1 = DataView.new(self.buffer, 0x00010000)
    else
        self.bank1 = nil
    end
    self.bank = (wasBank1 and self.bank1) or self.bank0
end

-- ============================================================
-- EEPROM 存档 (8KB)
-- ============================================================
local EEPROMSaveData = ClassUtils.class("EEPROMSaveData", MemoryView)

function EEPROMSaveData:ctor(size, mmu)
    local buf = ArrayBuffer.new(size)
    self.super.ctor(self, buf, 0)

    self.writeAddress = 0
    self.readBitsRemaining = 0
    self.readAddress = 0
    self.command = 0
    self.commandBitsRemaining = 0
    self.realSize = 0
    self.addressBits = 0
    self.writePending = false

    self.dma = mmu.core.irq.dma[3]

    self.COMMAND_NULL = 0
    self.COMMAND_PENDING = 1
    self.COMMAND_WRITE = 2
    self.COMMAND_READ_PENDING = 3
    self.COMMAND_READ = 4
end

function EEPROMSaveData:load8(offset)
    error("Unsupported 8-bit access!")
end

function EEPROMSaveData:load16(offset)
    return self:loadU16(offset)
end

function EEPROMSaveData:loadU8(offset)
    error("Unsupported 8-bit access!")
end

function EEPROMSaveData:loadU16(offset)
    if self.command ~= self.COMMAND_READ or not self.dma.enable then
        return 1
    end
    self.readBitsRemaining = self.readBitsRemaining - 1
    if self.readBitsRemaining < 64 then
        local step = 63 - self.readBitsRemaining
        local data = (self.view:getUint8((self.readAddress + step) >> 3) >> (0x7 - (step & 0x7))) & 0x1
        if self.readBitsRemaining == 0 then
            self.command = self.COMMAND_NULL
        end
        return data
    end
    return 0
end

function EEPROMSaveData:load32(offset)
    error("Unsupported 32-bit access!")
end

function EEPROMSaveData:store8(offset, value)
    error("Unsupported 8-bit access!")
end

function EEPROMSaveData:store16(offset, value)
    if self.command == self.COMMAND_NULL or self.command == nil then
        self.command = value & 0x1
    elseif self.command == self.COMMAND_PENDING then
        self.command = (self.command << 1) | (value & 0x1)
        if self.command == self.COMMAND_WRITE then
            if self.realSize == 0 then
                local bits = self.dma.count - 67
                self.realSize = 8 << bits
                self.addressBits = bits
            end
            self.commandBitsRemaining = self.addressBits + 64 + 1
            self.writeAddress = 0
        else
            if self.realSize == 0 then
                local bits = self.dma.count - 3
                self.realSize = 8 << bits
                self.addressBits = bits
            end
            self.commandBitsRemaining = self.addressBits + 1
            self.readAddress = 0
        end
    elseif self.command == self.COMMAND_WRITE then
        self.commandBitsRemaining = self.commandBitsRemaining - 1
        if self.commandBitsRemaining > 64 then
            self.writeAddress = (self.writeAddress << 1) | ((value & 0x1) << 6)
        elseif self.commandBitsRemaining <= 0 then
            self.command = self.COMMAND_NULL
            self.writePending = true
        else
            local current = self.view:getUint8(self.writeAddress >> 3)
            local bitPos = 0x7 - (self.writeAddress & 0x7)
            current = (current & ~(1 << bitPos)) | ((value & 0x1) << bitPos)
            self.view:setInt8(self.writeAddress >> 3, current & 0xff)
            self.writeAddress = self.writeAddress + 1
        end
    elseif self.command == self.COMMAND_READ_PENDING then
        self.commandBitsRemaining = self.commandBitsRemaining - 1
        if self.commandBitsRemaining > 0 then
            self.readAddress = self.readAddress << 1
            if (value & 0x1) ~= 0 then
                self.readAddress = self.readAddress | 0x40
            end
        else
            self.readBitsRemaining = 68
            self.command = self.COMMAND_READ
        end
    end
end

function EEPROMSaveData:store32(offset, value)
    error("Unsupported 32-bit access!")
end

function EEPROMSaveData:replaceData(memory, offset)
    self.super.replaceData(self, memory, offset or 0)
end

-- ============================================================
-- 存档文件读写工具 (Lua 本地文件)
-- ============================================================

--- 将字节串转为 ArrayBuffer 格式 (小端)
local function bytesToArrayBuffer(content)
    local size = #content
    local buf = ArrayBuffer.new(size)
    for i = 1, size, 4 do
        local b1 = string.byte(content, i) or 0
        local b2 = string.byte(content, i + 1) or 0
        local b3 = string.byte(content, i + 2) or 0
        local b4 = string.byte(content, i + 3) or 0
        local word = b1 + (b2 << 8) + (b3 << 16) + (b4 << 24)
        buf[(i - 1) >> 2] = word & 0xffffffff
    end
    return buf
end

--- 将 ArrayBuffer 转为字节串 (小端)
local function bufferToBytes(buffer)
    local size = buffer.byteLength
    local parts = {}
    for i = 0, (size >> 2) - 1 do
        local word = (buffer[i] or 0) & 0xffffffff
        local b1 = word & 0xff
        local b2 = (word >> 8) & 0xff
        local b3 = (word >> 16) & 0xff
        local b4 = (word >> 24) & 0xff
        parts[#parts + 1] = string.char(b1, b2, b3, b4)
    end
    return table.concat(parts)
end

--- 根据 ROM 代码生成存档文件名
local function getSavePath(romCode, baseDir)
    baseDir = baseDir or "."
    return baseDir .. "/" .. romCode .. ".sav"
end

--- 从文件加载存档数据，返回 ArrayBuffer 或 nil
local function loadSavedataFromFile(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local content = f:read("*all")
    f:close()
    if not content or #content == 0 then
        return nil
    end
    return bytesToArrayBuffer(content)
end

--- 将存档数据写入文件
local function storeSavedataToFile(path, buffer)
    local f = io.open(path, "wb")
    if not f then
        return false
    end
    local ok, err = pcall(function()
        f:write(bufferToBytes(buffer))
    end)
    f:close()
    return ok
end

-- ============================================================
-- 导出
-- ============================================================
return {
    SRAMSaveData = SRAMSaveData,
    FlashSaveData = FlashSaveData,
    EEPROMSaveData = EEPROMSaveData,
    bytesToArrayBuffer = bytesToArrayBuffer,
    bufferToBytes = bufferToBytes,
    getSavePath = getSavePath,
    loadSavedataFromFile = loadSavedataFromFile,
    storeSavedataToFile = storeSavedataToFile,
}
