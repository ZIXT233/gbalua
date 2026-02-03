local GBA = require("GBA")
local glfw = require("moonglfw")
local gba_screen = require("gba_screen")

-- ==================== 配置区 ====================
local MEMORY_DUMP_START = 0x02000000  -- 内存打印起始地址
local MEMORY_DUMP_END   = 0x02000020  -- 内存打印结束地址（不包含）
local DUMP_STEP         = 4           -- 每次读取 4 字节（32位）
local SCALE             = 4            -- 显示窗口缩放倍数
-- =================================================

-- 1. 初始化
local emu = GBA.new()
 

local success = emu:loadBiosFromFile("bios.bin")
if not success then
    error("Failed to load BIOS file: bios.bin")
end

-- 创建 GBA 显示窗口（240x160，moongl/moonglfw）
local screen = gba_screen.new(SCALE, "GBA")
local window = screen:GetWindow()

-- canvas.data：240*160*4 扁平数组，RGBA；需要绘制时由视频模块填充，drawCallback 被调用
local canvas = { data = {} } 
local drawCallback = function() 
    screen:Update(canvas.data)
end
emu:setCanvas(canvas, drawCallback)
emu:reset()

-- 2. 加载 ROM
local success = emu:loadRomFromFile(arg[1])
if not success then
    print("Failed to load ROM file:", arg[1])
    screen:Quit()
    return
end

-- 按键：ESC 关闭窗口，F 切换跳帧，其余由 keypad 处理
local function onKey(win, key, scancode, action, mods)
    if key == 'escape' and action == 'press' then
        glfw.set_window_should_close(win, true)
    elseif key == 'f' and action == 'press' then
        local skip = (emu:getFrameSkip() + 1) % 10  -- 0,1,2,3 循环
        emu:setFrameSkip(skip)
        print(string.format("跳帧: %d (每%d帧渲染1帧)", skip, skip + 1))
    end
end
emu.keypad:registerHandlers(window, onKey)


-- 4. 辅助函数：打印所有寄存器
local function printRegisters(cpu)
    local gprs = cpu.gprs
    for i = 0, 15 do
        io.write(string.format("R%-2d: %08X  ", i, gprs[i]))
        if (i + 1) % 4 == 0 then io.write("\n") end
        io.flush()
    end
    if 16 % 4 ~= 0 then io.write("\n") end
end

-- 5. 辅助函数：打印 CPSR 标志位
local function printFlags(cpu)
    local cpsr = {
        N = cpu.cpsrN and "1" or "0",
        Z = cpu.cpsrZ and "1" or "0",
        C = cpu.cpsrC and "1" or "0",
        V = cpu.cpsrV and "1" or "0",
        -- 可选：其他标志如 Q、T（Thumb）等，如果模拟器支持
    }
    print(string.format("Flags: N=%s Z=%s C=%s V=%s", cpsr.N, cpsr.Z, cpsr.C, cpsr.V))
end

-- 6. 辅助函数：打印内存范围
local function printMemory(mmu, start, finish, step)
    print("Memory dump (" .. string.format("0x%08X", start) .. " - " .. string.format("0x%08X", finish) .. "):")
    for addr = start, finish - 1, step do
        if step == 4 then
            local val = mmu:load32(addr)
            print(string.format("  [0x%08X] = 0x%08X (%d)", addr, val, val))
        elseif step == 2 then
            local val = mmu:load16(addr)
            print(string.format("  [0x%08X] = 0x%04X (%d)", addr, val, val))
        else
            local val = mmu:load8(addr)
            print(string.format("  [0x%08X] = 0x%02X (%d)", addr, val, val))
        end
    end
end

-- 7. 主循环：参照 moongl_example，每帧 poll_events + 轮询按键 + 模拟一帧
--    避免长时间阻塞导致窗口无响应
-- 设置存档目录为当前工作目录（与 ROM 同目录）
emu.saveDir = "."

-- FPS 显示：每帧更新标题栏
local fpsFrames = 0
local fpsLastTime = os.clock()
local fpsUpdateInterval = 0.5  -- 每 0.5 秒更新一次 FPS 显示

print("Starting GBA (window open, ESC to exit)...")
while not glfw.window_should_close(window) do
    glfw.poll_events()
    emu:advanceFrame()

    fpsFrames = fpsFrames + 1
    local now = os.clock()
    if now - fpsLastTime >= fpsUpdateInterval then
        local fps = fpsFrames / (now - fpsLastTime)
        fpsFrames = 0
        fpsLastTime = now
        screen:SetTitle(string.format("GBA - %.1f FPS", fps))
    end
end
screen:Quit()