local ClassUtils = require("ClassUtils")
local DataView = ClassUtils.class("DataView")
local default_value = 0

function DataView:ctor(buffer, byteOffset)
    self.buffer = buffer
    self.byteOffset = byteOffset or 0
end

-- --- 读取接口 ---

function DataView:getUint8(offset)
    local addr = self.byteOffset + offset
    -- addr >> 2 相当于 math.floor(addr / 4)
    -- (addr & 3) << 3 相当于 (addr % 4) * 8
    local v =self.buffer[addr >> 2]
    if not v then
        return default_value
    end
    return (v >> ((addr & 3) << 3)) & 0xff
end

function DataView:getInt8(offset)
    local v = self:getUint8(offset)
    return v > 0x7f and v - 0x100 or v
end

function DataView:getUint16(offset, le)
    local addr = self.byteOffset + offset
    local idx = addr >> 2
    local shift = (addr & 3) << 3
    local v =self.buffer[idx]
    if not v then
        return default_value
    end
    if shift <= 16 then
        -- 数据在同一个 32 位词内
        return (self.buffer[idx] >> shift) & 0xffff
    else
        -- 跨词读取: 当前词的高 8 位 + 下一个词的低 8 位
        local low = (self.buffer[idx] >> 24) & 0xff
        local high = (self.buffer[idx + 1] or 0) & 0xff
        return low | (high << 8)
    end
end

function DataView:getInt16(offset, le)
    local v = self:getUint16(offset, le)
    return v > 0x7fff and v - 0x10000 or v
end


-- 返回 32 位整数(arm7tdmi is 32bit so not to do signext)
function DataView:getInt32(offset, le)
    local v =self.buffer[(self.byteOffset + offset) >> 2]
    return v and v & 0xffffffff or default_value
    --return self.buffer[(self.byteOffset + offset) >> 2] & 0xffffffff
    --return v > 0x7fffffff and v - 0x100000000 or v
end

-- --- 写入接口 ---

function DataView:setInt8(offset, value)
    local addr = self.byteOffset + offset
    local idx = addr >> 2
    local shift = (addr & 3) << 3
    local mask = ~(0xff << shift)
    local v = self.buffer[idx]
    if not v then
        v=default_value
        self.buffer[idx]=v
    end
    self.buffer[idx] = (v & mask) | ((value & 0xff) << shift)
end

function DataView:setUint16(offset, value, le)
    local addr = self.byteOffset + offset
    local idx = addr >> 2
    local shift = (addr & 3) << 3
    local v = self.buffer[idx]
    if not v then
        v = default_value
        self.buffer[idx] = v
    end
    if shift <= 16 then
        local mask = ~(0xffff << shift)
        self.buffer[idx] = (v & mask) | ((value & 0xffff) << shift)
    else
        local v1 = self.buffer[idx + 1]
        if not v1 then
            v1 = default_value
            self.buffer[idx + 1] = v1
        end
        -- 跨词写入
        self.buffer[idx] = (v & 0x00ffffff) | ((value & 0xff) << 24)
        self.buffer[idx + 1] = (v1 & 0xffffff00) | ((value >> 8) & 0xff)
    end
end

function DataView:setInt16(offset, value, le)
    local addr = self.byteOffset + offset
    local idx = addr >> 2
    local shift = (addr & 3) << 3
    local v = self.buffer[idx]
    if not v then
        v=default_value
        self.buffer[idx]=v
    end
    if shift <= 16 then
        local mask = ~(0xffff << shift)
        self.buffer[idx] = (v & mask) | ((value & 0xffff) << shift)
    else
        local v1 = self.buffer[idx + 1]
        if not v1 then
            v1=default_value
            self.buffer[idx+1]=v1
        end
        -- 跨词写入
        self.buffer[idx] = (v & 0x00ffffff) | ((value & 0xff) << 24)
        self.buffer[idx + 1] = (v1 & 0xffffff00) | ((value >> 8) & 0xff)
    end
end

function DataView:setInt32(offset, value, le)
    -- MMU 保证了 32 位对齐，直接覆盖索引即可
    -- 强制转为 32 位位模式存储
    self.buffer[(self.byteOffset + offset) >> 2] = value & 0xffffffff
end


return DataView