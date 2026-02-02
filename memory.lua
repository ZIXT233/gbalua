--[[
  memory.lua - MemoryView 与 MemoryBlock 基类
  独立模块避免 mmu <-> savedata 循环依赖
]]

local ClassUtils = require("ClassUtils")
local DataView = require("hal.DataView")
local ArrayBuffer = require("hal.ArrayBuffer")

local LIMIT32_MASK = 0xffffffff

local MemoryView = ClassUtils.class("MemoryView")

function MemoryView:ctor(memory, offset)
    self.buffer = memory
    self.view = DataView.new(self.buffer, offset or 0)
    self.mask = memory.byteLength - 1
    self:resetMask()
end

function MemoryView:resetMask()
    self.mask8 = self.mask & 0xffffffff
    self.mask16 = self.mask & 0xfffffffe
    self.mask32 = self.mask & 0xfffffffc
end

function MemoryView:load8(offset)
    return self.view:getInt8(offset & self.mask8)
end

function MemoryView:load16(offset)
    return self.view:getInt16(offset & self.mask, true)
end

function MemoryView:loadU8(offset)
    return self.view:getUint8(offset & self.mask8)
end

function MemoryView:loadU16(offset)
    return self.view:getUint16(offset & self.mask, true)
end

function MemoryView:load32(offset)
    local rotate = (offset & 3) << 3
    local mem = self.view:getInt32(offset & self.mask32, true)
    return ((mem >> rotate) | (mem << (32 - rotate))) & LIMIT32_MASK
end

function MemoryView:store8(offset, value)
    self.view:setInt8(offset & self.mask8, value)
end

function MemoryView:store16(offset, value)
    self.view:setInt16(offset & self.mask16, value, true)
end

function MemoryView:store32(offset, value)
    self.view:setInt32(offset & self.mask32, value, true)
end

function MemoryView:invalidatePage(address)
end

function MemoryView:replaceData(memory, offset)
    self.buffer = memory
    self.view = DataView.new(self.buffer, offset or 0)
    if self.icache then
        self.icache = {}
    end
end

-- MemoryBlock
local MemoryBlock = ClassUtils.class("MemoryBlock", MemoryView)

function MemoryBlock:ctor(size, cacheBits)
    self.super.ctor(self, ArrayBuffer.new(size))
    self.ICACHE_PAGE_BITS = cacheBits
    self.PAGE_MASK = (2 << self.ICACHE_PAGE_BITS) - 1
    self.icache = {}
end

function MemoryBlock:invalidatePage(address)
    local page = self.icache[(address & self.mask) >> self.ICACHE_PAGE_BITS]
    if page then
        page.invalid = true
    end
end

return {
    MemoryView = MemoryView,
    MemoryBlock = MemoryBlock,
}
