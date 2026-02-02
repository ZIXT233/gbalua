--[[
  keypad.lua - GBA 按键输入模块
  参考 gbajs keypad.js，适配 moonglfw 键盘接口
  GBA KEYINPUT: 10 位，低电平有效（按下=0，释放=1）
]]

local ClassUtils = require("ClassUtils")
local GameBoyAdvanceKeypad = ClassUtils.class("GameBoyAdvanceKeypad")

-- GBA 按键位索引（与 keypad.js 一致）
GameBoyAdvanceKeypad.A = 0
GameBoyAdvanceKeypad.B = 1
GameBoyAdvanceKeypad.SELECT = 2
GameBoyAdvanceKeypad.START = 3
GameBoyAdvanceKeypad.RIGHT = 4
GameBoyAdvanceKeypad.LEFT = 5
GameBoyAdvanceKeypad.UP = 6
GameBoyAdvanceKeypad.DOWN = 7
GameBoyAdvanceKeypad.R = 8
GameBoyAdvanceKeypad.L = 9

function GameBoyAdvanceKeypad:ctor()
    self.window = nil  -- 用于 pollGamepads 轮询
    -- moonglfw 的键盘按键名 -> GBA 按键位
    -- 与 gbajs 默认映射一致：Z=A, X=B, Enter=Start, Backslash=Select, A=L, S=R, 方向键
    self.keyMap = {
        ["left"] = self.LEFT,
        ["right"] = self.RIGHT,
        ["up"] = self.UP,
        ["down"] = self.DOWN,
        ["enter"] = self.START,
        ["backslash"] = self.SELECT,
        ["right shift"] = self.SELECT,
        ["left shift"] = self.SELECT,
        ["z"] = self.A,
        ["x"] = self.B,
        ["a"] = self.L,
        ["s"] = self.R,
    }

    -- currentDown: 0x03ff = 全释放（GBA 低电平有效，1=未按下）
    self.currentDown = 0x03ff
    self.eatInput = false
end

function GameBoyAdvanceKeypad:clear()
    self.currentDown = 0x03ff
end

function GameBoyAdvanceKeypad:freeze()
    return { currentDown = self.currentDown }
end

function GameBoyAdvanceKeypad:defrost(frost)
    self.currentDown = frost.currentDown or 0x03ff
end

-- 键盘回调：key 为 moonglfw 的按键名（字符串），action 为 'press'|'release'|'repeat'
function GameBoyAdvanceKeypad:keyboardHandler(key, action)
    local gbaBit = self.keyMap[key]
    if not gbaBit then
        return
    end

    local toggle = 1 << gbaBit
    if action == "press" or action == "repeat" then
        self.currentDown = self.currentDown & ~toggle
    else
        self.currentDown = self.currentDown | toggle
    end
end

-- 供 gbaio KEYINPUT 读取时调用（与 keypad.js 接口一致）
-- 若有 window 则轮询键盘状态，否则依赖 callback 已更新的 currentDown
function GameBoyAdvanceKeypad:pollGamepads()
    if self.window then
        self:pollKeys(self.window)
    end
end

-- 轮询模式：用 glfw.get_key 更新按键状态
-- 多个物理键映射同一 GBA 键时，任一按下即视为按下
function GameBoyAdvanceKeypad:pollKeys(window)
    if not window then
        return
    end
    local glfw = require("moonglfw")
    local pressed = 0
    for glfwKey, gbaBit in pairs(self.keyMap) do
        local ok, state = pcall(function() return glfw.get_key(window, glfwKey) end)
        if ok and (state == "press" or state == "repeat") then
            pressed = pressed | (1 << gbaBit)
        end
    end
    self.currentDown = (0x03ff & ~pressed)
end

-- 注册 moonglfw 键盘回调到指定窗口
-- 同时保存 window 供 pollGamepads 轮询
function GameBoyAdvanceKeypad:registerHandlers(window, existingCallback)
    if not window then
        return
    end
    self.window = window
    local glfw = require("moonglfw")
    local keypad = self
    local prev = existingCallback
    glfw.set_key_callback(window, function(win, key, scancode, action, mods)
        keypad:keyboardHandler(key, action)
        if prev then
            prev(win, key, scancode, action, mods)
        end
    end)
end

return {
    new = function()
        return GameBoyAdvanceKeypad.new()
    end,
    GameBoyAdvanceKeypad = GameBoyAdvanceKeypad,
}
