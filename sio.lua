--[[
  sio.lua - GBA 串行 I/O (SIO) 模块
  参考 gbajs sio.js 移植，实现 SIO 寄存器级模拟
  支持 SIO_NORMAL_8/32、SIO_MULTI、SIO_UART、SIO_GPIO、SIO_JOYBUS 模式
  结合 Lua 本地文件读写，可选的多人联机状态持久化（用于调试/存档）
]]

local ClassUtils = require("ClassUtils")

local GameBoyAdvanceSIO = ClassUtils.class("GameBoyAdvanceSIO")

function GameBoyAdvanceSIO:ctor()
    -- SIO 模式常量 (与 sio.js 一致)
    self.SIO_NORMAL_8 = 0
    self.SIO_NORMAL_32 = 1
    self.SIO_MULTI = 2
    self.SIO_UART = 3
    self.SIO_GPIO = 8
    self.SIO_JOYBUS = 12

    -- 波特率表 [9600, 38400, 57600, 115200]
    self.BAUD = { 9600, 38400, 57600, 115200 }

    self.linkLayer = nil
    self.core = nil
    self:clear()
end

--- 清除 SIO 状态，重置为默认
function GameBoyAdvanceSIO:clear()
    self.mode = self.SIO_GPIO
    self.sd = false
    self.irq = false
    self.multiplayer = {
        baud = 0,
        si = 0,
        id = 0,
        error = 0,
        busy = 0,
        states = { 0xffff, 0xffff, 0xffff, 0xffff }
    }
    self.linkLayer = nil
end

--- 设置 SIO 模式 (由 RCNT/SIOCNT 写入触发)
function GameBoyAdvanceSIO:setMode(mode)
    if (mode & 0x8) ~= 0 then
        mode = mode & 0xc
    else
        mode = mode & 0x3
    end
    self.mode = mode

    if self.core then
        self.core:INFO("Setting SIO mode to " .. string.format("%x", mode))
    end
end

--- 写入 RCNT (仅 GPIO 模式下有效)
function GameBoyAdvanceSIO:writeRCNT(value)
    if self.mode ~= self.SIO_GPIO then
        return
    end
    if self.core then
        self.core:STUB("General purpose serial not supported")
    end
end

--- 写入 SIOCNT 控制寄存器
function GameBoyAdvanceSIO:writeSIOCNT(value)
    if self.mode == self.SIO_NORMAL_8 then
        if self.core then
            self.core:STUB("8-bit transfer unsupported")
        end
    elseif self.mode == self.SIO_NORMAL_32 then
        if self.core then
            self.core:STUB("32-bit transfer unsupported")
        end
    elseif self.mode == self.SIO_MULTI then
        self.multiplayer.baud = value & 0x0003
        if self.linkLayer and self.linkLayer.setBaud then
            self.linkLayer:setBaud(self.BAUD[self.multiplayer.baud + 1])
        end

        if self.multiplayer.si == 0 then
            self.multiplayer.busy = value & 0x0080
            if self.linkLayer and self.multiplayer.busy ~= 0 then
                if self.linkLayer.startMultiplayerTransfer then
                    self.linkLayer:startMultiplayerTransfer()
                end
            end
        end
        self.irq = (value & 0x4000) ~= 0
    elseif self.mode == self.SIO_UART then
        if self.core then
            self.core:STUB("UART unsupported")
        end
    elseif self.mode == self.SIO_GPIO then
        -- This register isn't used in general-purpose mode
    elseif self.mode == self.SIO_JOYBUS then
        if self.core then
            self.core:STUB("JOY BUS unsupported")
        end
    end
end

--- 读取 SIOCNT 控制寄存器
function GameBoyAdvanceSIO:readSIOCNT()
    local value = (self.mode << 12) & 0xffff
    if self.mode == self.SIO_NORMAL_8 then
        if self.core then
            self.core:STUB("8-bit transfer unsupported")
        end
    elseif self.mode == self.SIO_NORMAL_32 then
        if self.core then
            self.core:STUB("32-bit transfer unsupported")
        end
    elseif self.mode == self.SIO_MULTI then
        value = value | self.multiplayer.baud
        value = value | self.multiplayer.si
        value = value | ((self.sd and 1 or 0) << 3)
        value = value | (self.multiplayer.id << 4)
        value = value | self.multiplayer.error
        value = value | self.multiplayer.busy
        value = value | ((self.irq and 1 or 0) << 14)
    elseif self.mode == self.SIO_UART then
        if self.core then
            self.core:STUB("UART unsupported")
        end
    elseif self.mode == self.SIO_GPIO then
        -- This register isn't used in general-purpose mode
    elseif self.mode == self.SIO_JOYBUS then
        if self.core then
            self.core:STUB("JOY BUS unsupported")
        end
    end
    return value
end

--- 读取 SIOMULTI 传输寄存器 (slot 0-3)
function GameBoyAdvanceSIO:read(slot)
    if self.mode == self.SIO_NORMAL_32 then
        if self.core then
            self.core:STUB("32-bit transfer unsupported")
        end
        return 0
    elseif self.mode == self.SIO_MULTI then
        return self.multiplayer.states[slot + 1] or 0xffff
    elseif self.mode == self.SIO_UART then
        if self.core then
            self.core:STUB("UART unsupported")
        end
        return 0
    else
        if self.core then
            self.core:WARN("Reading from transfer register in unsupported mode")
        end
        return 0
    end
end

-- ============================================================
-- 可选：Lua 本地文件读写 - 多人联机状态持久化
-- 用于调试或将来实现本地多人模拟
-- ============================================================

--- 设置联机状态保存路径（nil 表示禁用）
function GameBoyAdvanceSIO:setStateSavePath(path)
    self.stateSavePath = path
end

--- 从文件加载联机状态（若启用）
function GameBoyAdvanceSIO:loadStateFromFile()
    if not self.stateSavePath then
        return false
    end
    local f = io.open(self.stateSavePath, "rb")
    if not f then
        return false
    end
    local content = f:read("*all")
    f:close()
    if not content or #content < 16 then
        return false
    end
    -- 简单格式：4 个 16 位小端 states
    for i = 1, 4 do
        local lo = string.byte(content, (i - 1) * 2 + 1) or 0
        local hi = string.byte(content, (i - 1) * 2 + 2) or 0
        self.multiplayer.states[i] = lo | (hi << 8)
    end
    return true
end

--- 将联机状态保存到文件（若启用）
function GameBoyAdvanceSIO:storeStateToFile()
    if not self.stateSavePath then
        return false
    end
    local f = io.open(self.stateSavePath, "wb")
    if not f then
        return false
    end
    for i = 1, 4 do
        local v = self.multiplayer.states[i] or 0xffff
        f:write(string.char(v & 0xff, (v >> 8) & 0xff))
    end
    f:close()
    return true
end

-- ============================================================
-- 导出 (与 gbaio.lua 一致，直接返回类)
-- ============================================================
return GameBoyAdvanceSIO
