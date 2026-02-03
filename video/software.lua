local ClassUtils = require("ClassUtils")
local MemoryAligned16 = ClassUtils.class("MemoryAligned16")
local GameBoyAdvanceVRAM = ClassUtils.class("GameBoyAdvanceVRAM", MemoryAligned16)
local GameBoyAdvanceOAM = ClassUtils.class("GameBoyAdvanceOAM", MemoryAligned16)
local GameBoyAdvancePalette = ClassUtils.class("GameBoyAdvancePalette")
local GameBoyAdvanceOBJ = ClassUtils.class("GameBoyAdvanceOBJ")
local GameBoyAdvanceOBJLayer = ClassUtils.class("GameBoyAdvanceOBJLayer")
local GameBoyAdvanceSoftwareRenderer = ClassUtils.class("GameBoyAdvanceSoftwareRenderer")

local makeUint16Array = function(size)
    local array = {}
    array.byteLength = size << 1
    for i = 0, size - 1 do
        array[i] = 0
    end
    return array
end
local makeUint8Array = function(size)
    local array = {}
    array.byteLength = size
    for i = 0, size - 1 do
        array[i] = 0
    end
    return array
end

local makeArray = function(size)
    local array = {}
    for i = 0, size - 1 do
        array[i] = 0
    end
    return array
end


-- Helper to simulate JS "value | 0" or 32-bit truncation if needed, 
-- though Lua 5.3+ integers are usually 64-bit.
local function toInt32(v)
    return v & 0xFFFFFFFF
end

-- Helper for sign extension from n-bits to Lua integer
local function signExtend(val, bits)
    local m = 1 << (bits - 1)
    return (val ~ m) - m
end

-- Forward declaration for pushPixel (static in JS)
local pushPixel

--------------------------------------------------------------------------------
-- MemoryAligned16
--------------------------------------------------------------------------------
function MemoryAligned16:ctor(size)
    self.buffer = makeUint16Array(size >> 1) -- Simulating Uint16Array
end

function MemoryAligned16:load8(offset)
    -- JS: (this.loadU8(offset) << 24) >> 24
    return signExtend(self:loadU8(offset), 8)
end

function MemoryAligned16:load16(offset)
    -- JS: (this.loadU16(offset) << 16) >> 16
    return signExtend(self:loadU16(offset), 16)
end

function MemoryAligned16:loadU8(offset)
    local index = offset >> 1
    local val = self.buffer[index]
    if (offset & 1) ~= 0 then
        return (val & 0xFF00) >> 8
    else
        return val & 0x00FF
    end
end

function MemoryAligned16:loadU16(offset)
    return self.buffer[offset >> 1]
end

function MemoryAligned16:load32(offset)
    local index = offset >> 1
    local lower = self.buffer[index & ~1]
    local upper = self.buffer[index | 1]
    return lower | (upper << 16)
end

function MemoryAligned16:store8(offset, value)
    -- var index = offset >> 1; (Unused in JS logic directly, implemented via store16)
    self:store16(offset, (value << 8) | (value & 0xFF))
end

function MemoryAligned16:store16(offset, value)
    self.buffer[offset >> 1] = value & 0xFFFF
end

function MemoryAligned16:store32(offset, value)
    local index = offset >> 1
    local valLo = value & 0xFFFF
    local valHi = value >> 16
    self:store16(offset, valLo)
    self.buffer[index] = valLo -- Redundant call in JS structure, but keeping logic
    self:store16(offset + 2, valHi)
    self.buffer[index + 1] = valHi
end

function MemoryAligned16:insert(start, data)
    -- data is assumed to be a table of 16-bit values
    for i = 0, #data do
        self.buffer[start + i] = data[i]
    end
end

function MemoryAligned16:invalidatePage(address) 
end

--------------------------------------------------------------------------------
-- GameBoyAdvanceVRAM
--------------------------------------------------------------------------------
function GameBoyAdvanceVRAM:ctor(size)
    -- MemoryAligned16.ctor(self, size) -- Inherited ctor called automatically by ClassUtils if not overridden or explicitly called
    self.super.ctor(self, size)
    self.vram = self.buffer
end

--------------------------------------------------------------------------------
-- GameBoyAdvanceOAM
--------------------------------------------------------------------------------
function GameBoyAdvanceOAM:ctor(size)
    self.super.ctor(self, size)
    self.oam = self.buffer
    self.objs = {}
    for i = 0, 127 do
        self.objs[i] = GameBoyAdvanceOBJ.new(self, i)
    end
    self.scalerot = {}
    for i = 0, 31 do
        self.scalerot[i] = { a = 1, b = 0, c = 0, d = 1 }
    end
    
    -- Function table for store16 logic
    self.storeHandlers = {
        [0] = function(obj, scalerot, value) -- Attribute 0
            obj.y = value & 0x00FF
            local wasScalerot = obj.scalerot
            obj.scalerot = (value & 0x0100) ~= 0
            if obj.scalerot then
                obj.scalerotOam = self.scalerot[obj.scalerotParam]
                obj.doublesize = (value & 0x0200) ~= 0
                obj.disable = 0
                obj.hflip = 0
                obj.vflip = 0
            else
                obj.doublesize = false
                obj.disable = (value & 0x0200) ~= 0 and 1 or 0
                if wasScalerot then
                    obj.hflip = (obj.scalerotParam & 0x0008)
                    obj.vflip = (obj.scalerotParam & 0x0010)
                end
            end
            obj.mode = (value & 0x0C00) >> 6
            obj.mosaic = (value & 0x1000) ~= 0
            obj.multipalette = (value & 0x2000) ~= 0
            obj.shape = (value & 0xC000) >> 14
            obj:recalcSize()
        end,
        [2] = function(obj, scalerot, value) -- Attribute 1
            obj.x = value & 0x01FF
            if obj.scalerot then
                obj.scalerotParam = (value & 0x3E00) >> 9
                obj.scalerotOam = self.scalerot[obj.scalerotParam]
                obj.hflip = 0
                obj.vflip = 0
                obj.drawScanline = obj.drawScanlineAffine
            else
                obj.hflip = value & 0x1000
                obj.vflip = value & 0x2000
                obj.drawScanline = obj.drawScanlineNormal
            end
            obj.size = (value & 0xC000) >> 14
            obj:recalcSize()
        end,
        [4] = function(obj, scalerot, value) -- Attribute 2
            obj.tileBase = value & 0x03FF
            obj.priority = (value & 0x0C00) >> 10
            obj.palette = (value & 0xF000) >> 8
        end,
        [6] = function(obj, scalerot, value, index) -- Scaling/rotation parameter
            local subIndex = index & 3
            -- Using a small inner table or if/else for the 4 params
            if subIndex == 0 then
                scalerot.a = (value << 16) / 0x1000000 -- JS divides to get float, Lua / is float div
            elseif subIndex == 1 then
                scalerot.b = (value << 16) / 0x1000000
            elseif subIndex == 2 then
                scalerot.c = (value << 16) / 0x1000000
            elseif subIndex == 3 then
                scalerot.d = (value << 16) / 0x1000000
            end
        end
    }
end

function GameBoyAdvanceOAM:overwrite(memory)
    for i = 0, (self.buffer.byteLength>>1) - 1 do
         -- JS logic loop based on buffer size, but memory access is linear
        self:store16(i << 1, memory[i])
    end
end

function GameBoyAdvanceOAM:store16(offset, value)
    local index = (offset & 0x3F8) >> 3
    local obj = self.objs[index]
    local scalerot = self.scalerot[index >> 2]
    
    local handler = self.storeHandlers[offset & 0x00000006]
    if handler then
        handler(obj, scalerot, value, index)
    end

    MemoryAligned16.store16(self, offset, value)
end

--------------------------------------------------------------------------------
-- GameBoyAdvancePalette
--------------------------------------------------------------------------------
function GameBoyAdvancePalette:ctor()
    self.colors = { [0]=makeArray(256), makeArray(256) } -- [0] and [1]
    self.adjustedColors = { [0]=makeArray(256), makeArray(256) }
    self.passthroughColors = {
        [0]=self.colors[0], -- BG0
        self.colors[0], -- BG1
        self.colors[0], -- BG2
        self.colors[0], -- BG3
        self.colors[1], -- OBJ
        self.colors[0]  -- Backdrop
    }
    self.blendY = 1
    self.adjustColor = self.adjustColorBright -- Default
end

function GameBoyAdvancePalette:overwrite(memory)
    for i = 0, 511 do
        self:store16(i << 1, memory[i])
    end
end

function GameBoyAdvancePalette:loadU8(offset)
    return (self:loadU16(offset) >> (8 * (offset & 1))) & 0xFF
end

function GameBoyAdvancePalette:loadU16(offset)
    local typeIdx = (offset & 0x200) >> 9
    local index = (offset & 0x1FF) >> 1
    return self.colors[typeIdx][index] or 0
end

function GameBoyAdvancePalette:load16(offset)
    return signExtend(self:loadU16(offset), 16)
end

function GameBoyAdvancePalette:load32(offset)
    return self:loadU16(offset) | (self:loadU16(offset + 2) << 16)
end

function GameBoyAdvancePalette:store16(offset, value)
    local typeIdx = (offset & 0x200) >> 9
    local index = (offset & 0x1FF) >> 1
    self.colors[typeIdx][index] = value
    self.adjustedColors[typeIdx][index] = self:adjustColor(value)
end

function GameBoyAdvancePalette:store32(offset, value)
    self:store16(offset, value & 0xFFFF)
    self:store16(offset + 2, value >> 16)
end

function GameBoyAdvancePalette:invalidatePage(address) end

function GameBoyAdvancePalette:convert16To32(value, input)
    local r = (value & 0x001F) << 3
    local g = (value & 0x03E0) >> 2
    local b = (value & 0x7C00) >> 7
    input[0] = r
    input[1] = g
    input[2] = b
end

function GameBoyAdvancePalette:mix(aWeight, aColor, bWeight, bColor)
    local ar = (aColor & 0x001F)
    local ag = (aColor & 0x03E0) >> 5
    local ab = (aColor & 0x7C00) >> 10

    local br = (bColor & 0x001F)
    local bg = (bColor & 0x03E0) >> 5
    local bb = (bColor & 0x7C00) >> 10

    local r =(aWeight * ar + bWeight * br) >> 4
    local g = (aWeight * ag + bWeight * bg) >> 4
    local b = (aWeight * ab + bWeight * bb) >> 4
    if r > 0x1F then r = 0x1F end
    if g > 0x1F then g = 0x1F end
    if b > 0x1F then b = 0x1F end
    return r | (g << 5) | (b << 10)
end

function GameBoyAdvancePalette:makeDarkPalettes(layers)
    if self.adjustColor ~= self.adjustColorDark then
        self.adjustColor = self.adjustColorDark
        self:resetPalettes()
    end
    self:resetPaletteLayers(layers)
end

function GameBoyAdvancePalette:makeBrightPalettes(layers)
    if self.adjustColor ~= self.adjustColorBright then
        self.adjustColor = self.adjustColorBright
        self:resetPalettes()
    end
    self:resetPaletteLayers(layers)
end

function GameBoyAdvancePalette:makeNormalPalettes()
    self.passthroughColors[0] = self.colors[0]
    self.passthroughColors[1] = self.colors[0]
    self.passthroughColors[2] = self.colors[0]
    self.passthroughColors[3] = self.colors[0]
    self.passthroughColors[4] = self.colors[1]
    self.passthroughColors[5] = self.colors[0]
end

function GameBoyAdvancePalette:makeSpecialPalette(layer)
    -- layer is 0-5. JS: layer == 4 ? 1 : 0
    local typeIdx = (layer == 4) and 1 or 0
    self.passthroughColors[layer] = self.adjustedColors[typeIdx]
end

function GameBoyAdvancePalette:makeNormalPalette(layer)
    local typeIdx = (layer == 4) and 1 or 0
    self.passthroughColors[layer] = self.colors[typeIdx]
end

function GameBoyAdvancePalette:resetPaletteLayers(layers)
    if (layers & 0x01) ~= 0 then self.passthroughColors[0] = self.adjustedColors[0] else self.passthroughColors[0] = self.colors[0] end
    if (layers & 0x02) ~= 0 then self.passthroughColors[1] = self.adjustedColors[0] else self.passthroughColors[1] = self.colors[0] end
    if (layers & 0x04) ~= 0 then self.passthroughColors[2] = self.adjustedColors[0] else self.passthroughColors[2] = self.colors[0] end
    if (layers & 0x08) ~= 0 then self.passthroughColors[3] = self.adjustedColors[0] else self.passthroughColors[3] = self.colors[0] end
    if (layers & 0x10) ~= 0 then self.passthroughColors[4] = self.adjustedColors[1] else self.passthroughColors[4] = self.colors[1] end
    if (layers & 0x20) ~= 0 then self.passthroughColors[5] = self.adjustedColors[0] else self.passthroughColors[5] = self.colors[0] end
end

function GameBoyAdvancePalette:resetPalettes()
    local outPalette = self.adjustedColors[0]
    local inPalette = self.colors[0]
    for i = 0, 255 do
        outPalette[i] = self:adjustColor(inPalette[i] or 0)
    end

    outPalette = self.adjustedColors[1]
    inPalette = self.colors[1]
    for i = 0, 255 do
        outPalette[i] = self:adjustColor(inPalette[i] or 0)
    end
end

function GameBoyAdvancePalette:accessColor(layer, index)
    return self.passthroughColors[layer][index]
end

function GameBoyAdvancePalette:adjustColorDark(color)
    local r = (color & 0x001F)
    local g = (color & 0x03E0) >> 5
    local b = (color & 0x7C00) >> 10

    r = r - (r * self.blendY)
    g = g - (g * self.blendY)
    b = b - (b * self.blendY)

    return math.floor(r) | (math.floor(g) << 5) | (math.floor(b) << 10)
end

function GameBoyAdvancePalette:adjustColorBright(color)
    local r = (color & 0x001F)
    local g = (color & 0x03E0) >> 5
    local b = (color & 0x7C00) >> 10

    r = r + ((31 - r) * self.blendY)
    g = g + ((31 - g) * self.blendY)
    b = b + ((31 - b) * self.blendY)

    return math.floor(r) | (math.floor(g) << 5) | (math.floor(b) << 10)
end

function GameBoyAdvancePalette:setBlendY(y)
    if self.blendY ~= y then
        self.blendY = y
        self:resetPalettes()
    end
end

--------------------------------------------------------------------------------
-- GameBoyAdvanceOBJ
--------------------------------------------------------------------------------
function GameBoyAdvanceOBJ:ctor(oam, index)
    self.TILE_OFFSET = 0x10000
    self.oam = oam
    self.index = index
    self.x = 0
    self.y = 0
    self.scalerot = false -- JS int/bool mix, using bool in Lua logic where possible
    self.doublesize = false
    self.disable = 1
    self.mode = 0
    self.mosaic = false
    self.multipalette = false
    self.shape = 0
    self.scalerotParam = 0
    self.hflip = 0
    self.vflip = 0
    self.tileBase = 0
    self.priority = 0
    self.palette = 0
    self.drawScanline = self.drawScanlineNormal
    self.pushPixel = pushPixel -- Assigned local reference
    self.cachedWidth = 8
    self.cachedHeight = 8
end


function GameBoyAdvanceOBJ:drawScanlineNormal(backing, y, yOff, start, endPoint)
    local video = self.oam.video
    local x
    local underflow
    local offset
    local mask = self.mode | video.target2[video.LAYER_OBJ] | (self.priority << 1)
    
    if self.mode == 0x10 then
        mask = mask | video.TARGET1_MASK
    end
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[video.LAYER_OBJ]
    end

    local totalWidth = self.cachedWidth
    if self.x < video.HORIZONTAL_PIXELS then
        if self.x < start then
            underflow = start - self.x
            offset = start
        else
            underflow = 0
            offset = self.x
        end
        if endPoint < self.cachedWidth + self.x then
            totalWidth = endPoint - self.x
        end
    else
        underflow = start + 512 - self.x
        offset = start
        if endPoint < self.cachedWidth - underflow then
            totalWidth = endPoint
        end
    end

    local localX
    local localY
    if self.vflip == 0 then
        localY = y - yOff
    else
        localY = self.cachedHeight - y + yOff - 1
    end
    local localYLo = localY & 0x7
    local mosaicX
    local tileOffset

    local paletteShift = self.multipalette and 1 or 0

    if video.objCharacterMapping ~= 0 then
        tileOffset = ((localY & 0x01F8) * self.cachedWidth) >> 6
    else
        tileOffset = (localY & 0x01F8) << (2 - paletteShift)
    end

    if self.mosaic then
        mosaicX = video.objMosaicX - 1 - (video.objMosaicX + offset - 1) % video.objMosaicX
        offset = offset + mosaicX
        underflow = underflow + mosaicX
    end

    if self.hflip == 0 then
        localX = underflow
    else
        localX = self.cachedWidth - underflow - 1
    end

    local tileRow = video:accessTile(self.TILE_OFFSET + (localX & 0x4) * paletteShift, 
                                     self.tileBase + (tileOffset << paletteShift) + ((localX & 0x01F8) >> (3 - paletteShift)), 
                                     localYLo << paletteShift)

    for x = underflow, totalWidth - 1 do
        mosaicX = self.mosaic and (offset % video.objMosaicX) or 0
        if self.hflip == 0 then
            localX = x - mosaicX
        else
            localX = self.cachedWidth - (x - mosaicX) - 1
        end

        if paletteShift == 0 then
            if (x & 0x7) == 0 or (self.mosaic and mosaicX == 0) then
                tileRow = video:accessTile(self.TILE_OFFSET, self.tileBase + tileOffset + (localX >> 3), localYLo)
            end
        else
            if (x & 0x3) == 0 or (self.mosaic and mosaicX == 0) then
                tileRow = video:accessTile(self.TILE_OFFSET + (localX & 0x4), self.tileBase + (tileOffset << 1) + ((localX & 0x01F8) >> 2), localYLo << 1)
            end
        end
        self.pushPixel(video.LAYER_OBJ, self, video, tileRow, localX & 0x7, offset, backing, mask, false)
        offset = offset + 1
    end
end

function GameBoyAdvanceOBJ:drawScanlineAffine(backing, y, yOff, start, endPoint)
    local video = self.oam.video
    local x
    local underflow
    local offset
    local mask = self.mode | video.target2[video.LAYER_OBJ] | (self.priority << 1)
    if self.mode == 0x10 then
        mask = mask | video.TARGET1_MASK
    end
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[video.LAYER_OBJ]
    end

    local localX
    local localY
    local yDiff = y - yOff
    local tileOffset

    local paletteShift = self.multipalette and 1 or 0
    local doublesizeShift = self.doublesize and 1 or 0
    local totalWidth = self.cachedWidth << doublesizeShift
    local totalHeight = self.cachedHeight << doublesizeShift
    local drawWidth = totalWidth
    if drawWidth > video.HORIZONTAL_PIXELS then
        totalWidth = video.HORIZONTAL_PIXELS
    end

    if self.x < video.HORIZONTAL_PIXELS then
        if self.x < start then
            underflow = start - self.x
            offset = start
        else
            underflow = 0
            offset = self.x
        end
        if endPoint < drawWidth + self.x then
            drawWidth = endPoint - self.x
        end
    else
        underflow = start + 512 - self.x
        offset = start
        if endPoint < drawWidth - underflow then
            drawWidth = endPoint
        end
    end

    for x = underflow, drawWidth - 1 do
        -- Affine transformation
        -- Lua math is doubles by default, ensure int logic
        localX = self.scalerotOam.a * (x - (totalWidth >> 1)) + self.scalerotOam.b * (yDiff - (totalHeight >> 1)) + (self.cachedWidth >> 1)
        localY = self.scalerotOam.c * (x - (totalWidth >> 1)) + self.scalerotOam.d * (yDiff - (totalHeight >> 1)) + (self.cachedHeight >> 1)
        
        -- Truncate to int for usage
        localX = math.floor(localX)
        localY = math.floor(localY)

        if self.mosaic then
            localX = localX - (x % video.objMosaicX) * self.scalerotOam.a - (y % video.objMosaicY) * self.scalerotOam.b
            localY = localY - (x % video.objMosaicX) * self.scalerotOam.c - (y % video.objMosaicY) * self.scalerotOam.d
            localX = math.floor(localX)
            localY = math.floor(localY)
        end

        if localX < 0 or localX >= self.cachedWidth or localY < 0 or localY >= self.cachedHeight then
            offset = offset + 1
            -- continue simulation in Lua loop
            goto continue_affine_loop
        end

        if video.objCharacterMapping ~= 0 then
            tileOffset = ((localY & 0x01F8) * self.cachedWidth) >> 6
        else
            tileOffset = (localY & 0x01F8) << (2 - paletteShift)
        end
        
        local tileRow = video:accessTile(self.TILE_OFFSET + (localX & 0x4) * paletteShift, 
                                         self.tileBase + (tileOffset << paletteShift) + ((localX & 0x01F8) >> (3 - paletteShift)), 
                                         (localY & 0x7) << paletteShift)
        self.pushPixel(video.LAYER_OBJ, self, video, tileRow, localX & 0x7, offset, backing, mask, false)
        offset = offset + 1
        
        ::continue_affine_loop::
    end
end

function GameBoyAdvanceOBJ:recalcSize()
    -- Converted switch to simple logic or could be table
    if not self.size then
        self.size = 0
    end
    if self.shape == 0 then
        -- Square
        self.cachedWidth = 8 << self.size
        self.cachedHeight = 8 << self.size
    elseif self.shape == 1 then
        -- Horizontal
        if self.size == 0 then self.cachedWidth = 16; self.cachedHeight = 8
        elseif self.size == 1 then self.cachedWidth = 32; self.cachedHeight = 8
        elseif self.size == 2 then self.cachedWidth = 32; self.cachedHeight = 16
        elseif self.size == 3 then self.cachedWidth = 64; self.cachedHeight = 32
        end
    elseif self.shape == 2 then
        -- Vertical
        if self.size == 0 then self.cachedWidth = 8; self.cachedHeight = 16
        elseif self.size == 1 then self.cachedWidth = 8; self.cachedHeight = 32
        elseif self.size == 2 then self.cachedWidth = 16; self.cachedHeight = 32
        elseif self.size == 3 then self.cachedWidth = 32; self.cachedHeight = 64
        end
    end
end

--------------------------------------------------------------------------------
-- GameBoyAdvanceOBJLayer
--------------------------------------------------------------------------------
function GameBoyAdvanceOBJLayer:ctor(video, index)
    self.video = video
    self.bg = false
    self.index = video.LAYER_OBJ
    self.priority = index
    self.enabled = false
    self.objwin = 0
    self.drawScanline = function(backing, layer, start, endPoint)
        local y = self.video.vcount
    local wrappedY
    local mosaicY
    local obj
    if start >= endPoint then
        return
    end
    local objs = self.video.oam.objs
    -- JS loop: var i = 0; i < objs.length; ++i
    for i = 0, #objs do 
        obj = objs[i]
        if obj.disable == 0 then
            -- Logic block for continue
            local match = false
            if (obj.mode & self.video.OBJWIN_MASK) == self.objwin then
                if (obj.mode & self.video.OBJWIN_MASK) ~= 0 or self.priority == obj.priority then
                    match = true
                end
            end

            if match then
                if obj.y < self.video.VERTICAL_PIXELS then
                    wrappedY = obj.y
                else
                    wrappedY = obj.y - 256
                end
                
                local totalHeight
                if not obj.scalerot then
                    totalHeight = obj.cachedHeight
                else
                    totalHeight = obj.cachedHeight << (obj.doublesize and 1 or 0)
                end

                if not obj.mosaic then
                    mosaicY = y
                else
                    mosaicY = y - y % self.video.objMosaicY
                end

                if wrappedY <= y and (wrappedY + totalHeight) > y then
                    obj:drawScanline(backing, mosaicY, wrappedY, start, endPoint)
                end
            end
        end
    end
    end
end


--------------------------------------------------------------------------------
-- pushPixel (Local function, logic moved from static class method)
--------------------------------------------------------------------------------
pushPixel = function(layer, map, video, row, x, offset, backing, mask, raw)
    local index
    
    -- 1. 提取索引 & 透明度快速检查 (最频繁的退出路径)
    if raw then
        index = 0 -- raw 模式下 index 不参与透明判断，由调用者保证非空或不用
    else
        -- 优化：合并 multipalette 判断逻辑
        -- 注意：x & 3 是为了防止 8bpp 下 x>=4 导致移位溢出
        if map.multipalette or (video.bg[layer] and video.bg[layer].multipalette) then
             index = (row >> ((x & 0x3) << 3)) & 0xFF
        else
            index = (row >> (x << 2)) & 0xF
        end

        -- 透明像素直接退出，无需读取 Stencil 或 Palette
        if index == 0 then return end
        
        if not map.multipalette then
            index = index | map.palette
        end
    end

    -- 2. 准备上下文环境 (局部变量化以减少 Table Lookup)
    local backStencil = backing.stencil
    local oldStencil = backStencil[offset] or 0 -- 防护 nil
    
    local stencilVal = 0x80 -- WRITTEN_MASK
    local enableBlend = false
    local forceBlend = false
    local blendMode = video.blendMode
    local passthroughColors = video.palette.passthroughColors
    
    -- 3. 窗口处理 (Windowing Logic)
    -- 这是开销最大的逻辑部分，尽量简化
    if video.objwinActive then
        -- OBJWIN_MASK (0x20)
        if (oldStencil & 0x20) ~= 0 then
            local win3 = video.windows[3]
            if win3.enabled[layer] then
                if win3.special and video.target1[layer] then
                    enableBlend = true
                    if video.alphaEnabled then mask = mask | video.target1[layer] end
                end
                stencilVal = stencilVal | 0x20
            else
                return -- 被 OBJ Window 裁剪
            end
        elseif video.windows[2].enabled[layer] then
            local win2 = video.windows[2]
            if win2.special and video.target1[layer] then
                enableBlend = true
                if video.alphaEnabled then mask = mask | video.target1[layer] end
            end
        else
            return -- 被 Outside Window 裁剪
        end
    end

    -- 检查是否满足普通混合条件 (Target 1 & Target 2)
    -- TARGET1_MASK=0x10, TARGET2_MASK=0x08
    if (mask & 0x10) ~= 0 and (oldStencil & 0x08) ~= 0 then
        forceBlend = true -- 强制混合 (1st Target over 2nd Target)
    end

    -- 4. 获取像素颜色 (延迟到确定可见后)
    local pixel
    if raw then
        pixel = row
    else
        pixel = passthroughColors[layer][index]
    end

    -- 设置混合状态
    -- 只有在需要改变状态时才调用，或者根据逻辑精简调用
    if enableBlend or forceBlend or (mask & 0x10) ~= 0 then
        -- 这里逻辑稍微有些冗余，为了保持与原代码行为一致
        -- 原代码逻辑：
        -- 1. Window 可能会 setBlendEnabled
        -- 2. (mask & 0x10) 和 (oldStencil & 0x08) 可能会 setBlendEnabled(..., 1)
        -- 3. (mask & 0x10) 可能会 setBlendEnabled(..., blendMode)
        -- 我们合并一下：最后一次 setBlendEnabled 生效
        
        local finalBlendMode = blendMode
        local finalEnable = (mask & 0x10) ~= 0
        
        if forceBlend then 
            finalEnable = true
            finalBlendMode = 1 
        elseif enableBlend then
            finalEnable = true -- Window special enabled
        end

        video:setBlendEnabled(layer, finalEnable, finalBlendMode)
    end

    -- 5. 深度/优先级测试与写入
    local backColor = backing.color
    local oldPriority = oldStencil & 0x07
    local newPriority = mask & 0x07
    
    -- PRIORITY_MASK=0x07, BACKGROUND_MASK=0x01
    local highPriority = newPriority < oldPriority
    if newPriority == oldPriority then
        highPriority = (mask & 0x01) ~= 0 -- 同级下，BG mask 决定覆盖
    end

    if (oldStencil & 0x80) == 0 then
        -- 1. 空白处写入 (最常见情况)
        backStencil[offset] = stencilVal | mask
        backColor[offset] = pixel
    elseif highPriority then
        -- 2. 高优先级覆盖
        if (mask & 0x10) ~= 0 and (oldStencil & 0x08) ~= 0 then
            -- 如果我是 Target1 且底下是 Target2，进行 Alpha 混合
            pixel = video.palette:mix(video.blendA, pixel, video.blendB, backColor[offset])
        end
        -- 写入，清除 Target1 标记 (防止双重混合)
        backStencil[offset] = stencilVal | (mask & ~0x10)
        backColor[offset] = pixel
    elseif newPriority > oldPriority then
        -- 3. 低优先级，但在底下 (Background behind Sprite etc)
        -- 检查是否构成混合：我是 Target2 (0x08)，上面是 Target1 (0x10)
        if (mask & 0x08) ~= 0 and (oldStencil & 0x10) ~= 0 then
            -- 混合：上面(dst) mix 下面(src)
            -- 注意：mix 参数通常是 mix(weightA, colorA, weightB, colorB)
            -- 这里逻辑是：oldPixel (Target1) * A + newPixel (Target2) * B
            -- 原代码写的是 mix(blendB, pixel, blendA, backingColor)
            pixel = video.palette:mix(video.blendB, pixel, video.blendA, backColor[offset])
            
            -- 更新 stencil: 移除 Target 标记，表示已混合完成
            backStencil[offset] = oldStencil & ~(0x10 | 0x08)
            backColor[offset] = pixel
        else
            return -- 被遮挡且不发生混合
        end
    else
        return -- 优先级相同或被遮挡
    end

    -- OBJWIN 标记处理 (如果当前像素是 OBJ Window 及其一部分)
    if (mask & 0x20) ~= 0 then
        backStencil[offset] = backStencil[offset] | 0x20
    end
end

--------------------------------------------------------------------------------
-- GameBoyAdvanceSoftwareRenderer
--------------------------------------------------------------------------------
function GameBoyAdvanceSoftwareRenderer:ctor()
    self.LAYER_BG0 = 0
    self.LAYER_BG1 = 1
    self.LAYER_BG2 = 2
    self.LAYER_BG3 = 3
    self.LAYER_OBJ = 4
    self.LAYER_BACKDROP = 5

    self.HORIZONTAL_PIXELS = 240
    self.VERTICAL_PIXELS = 160

    self.LAYER_MASK = 0x06
    self.BACKGROUND_MASK = 0x01
    self.TARGET2_MASK = 0x08
    self.TARGET1_MASK = 0x10
    self.OBJWIN_MASK = 0x20
    self.WRITTEN_MASK = 0x80

    self.PRIORITY_MASK = self.LAYER_MASK | self.BACKGROUND_MASK

    self.drawBackdrop = {
        bg = true,
        priority = -1,
        index = self.LAYER_BACKDROP,
        enabled = true,
        sx=0,
        sy=0,
        dmx=0,
        dmy=0,
        drawScanline = function(backing, layer, start, endPoint)
            -- Inner function needs reference to video (self)
            -- In JS it was a closure. Here we assume caller passes correct self context if needed
            -- But standard pattern in this file is explicit arguments.
            -- The JS logic accessed 'video' from closure.
            local video = self 
            for x = start, endPoint - 1 do
                if (backing.stencil[x] & video.WRITTEN_MASK) == 0 then
                    backing.color[x] = video.palette:accessColor(layer.index, 0)
                    backing.stencil[x] = video.WRITTEN_MASK
                elseif (backing.stencil[x] & video.TARGET1_MASK) ~= 0 then
                    backing.color[x] = video.palette:mix(video.blendB, video.palette:accessColor(layer.index, 0), video.blendA, backing.color[x])
                    backing.stencil[x] = video.WRITTEN_MASK
                end
            end
        end
    }
end

function GameBoyAdvanceSoftwareRenderer:clear(mmu)
    self.palette = GameBoyAdvancePalette.new()
    self.vram = GameBoyAdvanceVRAM.new(mmu.SIZE_VRAM)
    self.oam = GameBoyAdvanceOAM.new(mmu.SIZE_OAM)
    self.oam.video = self

    self.objLayers = {
        [0]=GameBoyAdvanceOBJLayer.new(self, 0),
        GameBoyAdvanceOBJLayer.new(self, 1),
        GameBoyAdvanceOBJLayer.new(self, 2),
        GameBoyAdvanceOBJLayer.new(self, 3)
    }
    self.objwinLayer = GameBoyAdvanceOBJLayer.new(self, 4)
    self.objwinLayer.objwin = self.OBJWIN_MASK

    -- DISPCNT
    self.backgroundMode = 0
    self.displayFrameSelect = 0
    self.hblankIntervalFree = 0
    self.objCharacterMapping = 0
    self.forcedBlank = 1
    self.win0 = 0
    self.win1 = 0
    self.objwin = 0

    -- VCOUNT
    self.vcount = -1

    -- WIN0H
    self.win0Left = 0
    self.win0Right = 240

    -- WIN1H
    self.win1Left = 0
    self.win1Right = 240

    -- WIN0V
    self.win0Top = 0
    self.win0Bottom = 160

    -- WIN1V
    self.win1Top = 0
    self.win1Bottom = 160

    -- WININ/WINOUT
    self.windows = {}
    for i = 0, 3 do
        self.windows[i] = {
            enabled = {[0]=false, false, false, false, false, true},
            special = 0
        }
    end

    -- BLDCNT
    self.target1 = {}
    self.target2 = {}
    for i = 0, 5 do self.target1[i] = 0; self.target2[i] = 0 end
    self.blendMode = 0

    -- BLDALPHA
    self.blendA = 0
    self.blendB = 0

    -- BLDY
    self.blendY = 0

    -- MOSAIC
    self.bgMosaicX = 1
    self.bgMosaicY = 1
    self.objMosaicX = 1
    self.objMosaicY = 1

    self.lastHblank = 0
    self.HDRAW_LENGTH = 1006 -- Not defined in JS snippet but referenced
    self.nextHblank = self.HDRAW_LENGTH
    self.nextEvent = self.nextHblank

    self.nextHblankIRQ = 0
    self.nextVblankIRQ = 0
    self.nextVcounterIRQ = 0

    -- BG layer drawScanline 必须用包装函数：JS 中 layer.drawScanline(backing,layer,...) 时
    -- this=layer；Lua 中若直接存 self.drawScanlineBGMode0，调用时不会传入 renderer 作为 self，导致参数错位。
    -- 包装后以 renderer 为 self 调用对应方法。
    local renderer = self
    self.bg = {}
    for i = 0, 3 do
        self.bg[i] = {
            bg = true,
            index = i,
            enabled = false,
            video = self,
            vram = self.vram,
            priority = 0,
            charBase = 0,
            mosaic = false,
            multipalette = false,
            screenBase = 0,
            overflow = 0,
            size = 0,
            x = 0,
            y = 0,
            refx = 0,
            refy = 0,
            dx = 1,
            dmx = 0,
            dy = 0,
            dmy = 1,
            sx = 0,
            sy = 0,
            pushPixel = pushPixel,
            drawScanline = function(backing, layer, start, endPoint)
                renderer:drawScanlineBGMode0(backing, layer, start, endPoint)
            end
        }
    end

    -- Mode function table
    self.bgModes = {
        [0] = self.drawScanlineBGMode0,
        [1] = self.drawScanlineBGMode2, -- Modes 1 and 2 are identical for layers 2 and 3
        [2] = self.drawScanlineBGMode2,
        [3] = self.drawScanlineBGMode3,
        [4] = self.drawScanlineBGMode4,
        [5] = self.drawScanlineBGMode5
    }

    -- 1-based 表，与 for i=1,#drawLayers 和 table.sort 一致；JS 为 0-based 数组
    self.drawLayers = {
        self.bg[0],
        self.bg[1],
        self.bg[2],
        self.bg[3],
        self.objLayers[0],
        self.objLayers[1],
        self.objLayers[2],
        self.objLayers[3],
        self.objwinLayer,
        self.drawBackdrop
    }

    self.objwinActive = false
    self.alphaEnabled = false

    self.scanline = {
        color = makeUint16Array(self.HORIZONTAL_PIXELS), -- Uint16Array
        stencil = makeUint8Array(self.HORIZONTAL_PIXELS) -- Uint8Array
    }

    self.sharedColor = {[0]=0, [1]=0, [2]=0}
    self.sharedMap = {
        tile = 0,
        hflip = false,
        vflip = false,
        palette = 0,
        multipalette = false -- Needed for Lua dynamic typing in pushPixel
    }
end


function GameBoyAdvanceSoftwareRenderer:clearSubsets(mmu, regions)
    if (regions & 0x04) ~= 0 then
        self.palette:overwrite(makeArray(mmu.SIZE_PALETTE_RAM >> 1)) -- Assuming MMU helper
    end
    if (regions & 0x08) ~= 0 then
        self.vram:insert(0, makeArray(mmu.SIZE_VRAM >> 1))
    end
    if (regions & 0x10) ~= 0 then
        self.oam:overwrite(makeArray(mmu.SIZE_OAM >> 1))
        self.oam.video = self
    end
end

function GameBoyAdvanceSoftwareRenderer:freeze() end
function GameBoyAdvanceSoftwareRenderer:defrost(frost) end

function GameBoyAdvanceSoftwareRenderer:setBacking(backing)
    self.pixelData = backing
    -- Clear backing
    for offset = 1, self.HORIZONTAL_PIXELS * self.VERTICAL_PIXELS * 4 do
        self.pixelData.data[offset] = 0xFF
    end

end

function GameBoyAdvanceSoftwareRenderer:writeDisplayControl(value)
    self.backgroundMode = value & 0x0007
    self.displayFrameSelect = value & 0x0010
    self.hblankIntervalFree = value & 0x0020
    self.objCharacterMapping = value & 0x0040
    self.forcedBlank = value & 0x0080
    self.bg[0].enabled = (value & 0x0100) ~= 0
    self.bg[1].enabled = (value & 0x0200) ~= 0
    self.bg[2].enabled = (value & 0x0400) ~= 0
    self.bg[3].enabled = (value & 0x0800) ~= 0
    self.objLayers[0].enabled = (value & 0x1000) ~= 0
    self.objLayers[1].enabled = (value & 0x1000) ~= 0
    self.objLayers[2].enabled = (value & 0x1000) ~= 0
    self.objLayers[3].enabled = (value & 0x1000) ~= 0
    self.win0 = value & 0x2000
    self.win1 = value & 0x4000
    self.objwin = value & 0x8000
    self.objwinLayer.enabled = ((value & 0x1000) ~= 0) and ((value & 0x8000) ~= 0)

    -- Hack
    self.bg[2].multipalette = false
    self.bg[3].multipalette = false
    if self.backgroundMode > 0 then
        self.bg[2].multipalette = true
    end
    if self.backgroundMode == 2 then
        self.bg[3].multipalette = true
    end

    self:resetLayers()
end

function GameBoyAdvanceSoftwareRenderer:writeBackgroundControl(bg, value)
    local bgData = self.bg[bg]
    bgData.priority = value & 0x0003
    bgData.charBase = (value & 0x000C) << 12
    bgData.mosaic = (value & 0x0040) ~= 0
    
    bgData.multipalette = false
    if bg < 2 or self.backgroundMode == 0 then
        bgData.multipalette = (value & 0x0080) ~= 0
    end
    bgData.screenBase = (value & 0x1F00) << 3
    bgData.overflow = value & 0x2000
    bgData.size = (value & 0xC000) >> 14

    self:sortLayers()
end

function GameBoyAdvanceSoftwareRenderer:writeBackgroundHOffset(bg, value)
    self.bg[bg].x = value & 0x1FF
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundVOffset(bg, value)
    self.bg[bg].y = value & 0x1FF
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundRefX(bg, value)
    self.bg[bg].refx = (value << 4) / 0x1000;
    self.bg[bg].sx = self.bg[bg].refx
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundRefY(bg, value)
    self.bg[bg].refy = (value << 4) / 0x1000;
    self.bg[bg].sy = self.bg[bg].refy
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundParamA(bg, value)
    self.bg[bg].dx = (value << 16) / 0x1000000;
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundParamB(bg, value)
    self.bg[bg].dmx = (value << 16) / 0x1000000;
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundParamC(bg, value)
    self.bg[bg].dy = (value << 16) / 0x1000000;
end
function GameBoyAdvanceSoftwareRenderer:writeBackgroundParamD(bg, value)
    self.bg[bg].dmy = (value << 16) / 0x1000000;
end

function GameBoyAdvanceSoftwareRenderer:writeWin0H(value)
    self.win0Left = (value & 0xFF00) >> 8
    self.win0Right = math.min(self.HORIZONTAL_PIXELS, value & 0x00FF)
    if self.win0Left > self.win0Right then
        self.win0Right = self.HORIZONTAL_PIXELS
    end
end
function GameBoyAdvanceSoftwareRenderer:writeWin1H(value)
    self.win1Left = (value & 0xFF00) >> 8
    self.win1Right = math.min(self.HORIZONTAL_PIXELS, value & 0x00FF)
    if self.win1Left > self.win1Right then
        self.win1Right = self.HORIZONTAL_PIXELS
    end
end
function GameBoyAdvanceSoftwareRenderer:writeWin0V(value)
    self.win0Top = (value & 0xFF00) >> 8
    self.win0Bottom = math.min(self.VERTICAL_PIXELS, value & 0x00FF)
    if self.win0Top > self.win0Bottom then
        self.win0Bottom = self.VERTICAL_PIXELS
    end
end
function GameBoyAdvanceSoftwareRenderer:writeWin1V(value)
    self.win1Top = (value & 0xFF00) >> 8
    self.win1Bottom = math.min(self.VERTICAL_PIXELS, value & 0x00FF)
    if self.win1Top > self.win1Bottom then
        self.win1Bottom = self.VERTICAL_PIXELS
    end
end

function GameBoyAdvanceSoftwareRenderer:writeWindow(index, value)
    local window = self.windows[index]
    window.enabled[0] = (value & 0x01) ~= 0
    window.enabled[1] = (value & 0x02) ~= 0
    window.enabled[2] = (value & 0x04) ~= 0
    window.enabled[3] = (value & 0x08) ~= 0
    window.enabled[4] = (value & 0x10) ~= 0
    window.special = (value & 0x20) ~= 0
end

function GameBoyAdvanceSoftwareRenderer:writeWinIn(value)
    self:writeWindow(0, value)
    self:writeWindow(1, value >> 8)
end
function GameBoyAdvanceSoftwareRenderer:writeWinOut(value)
    self:writeWindow(2, value)
    self:writeWindow(3, value >> 8)
end

function GameBoyAdvanceSoftwareRenderer:writeBlendControl(value)
    self.target1[0] = ((value & 0x0001) ~= 0) and self.TARGET1_MASK or 0
    self.target1[1] = ((value & 0x0002) ~= 0) and self.TARGET1_MASK or 0
    self.target1[2] = ((value & 0x0004) ~= 0) and self.TARGET1_MASK or 0
    self.target1[3] = ((value & 0x0008) ~= 0) and self.TARGET1_MASK or 0
    self.target1[4] = ((value & 0x0010) ~= 0) and self.TARGET1_MASK or 0
    self.target1[5] = ((value & 0x0020) ~= 0) and self.TARGET1_MASK or 0
    self.target2[0] = ((value & 0x0100) ~= 0) and self.TARGET2_MASK or 0
    self.target2[1] = ((value & 0x0200) ~= 0) and self.TARGET2_MASK or 0
    self.target2[2] = ((value & 0x0400) ~= 0) and self.TARGET2_MASK or 0
    self.target2[3] = ((value & 0x0800) ~= 0) and self.TARGET2_MASK or 0
    self.target2[4] = ((value & 0x1000) ~= 0) and self.TARGET2_MASK or 0
    self.target2[5] = ((value & 0x2000) ~= 0) and self.TARGET2_MASK or 0
    self.blendMode = (value & 0x00C0) >> 6

    -- Using if/elseif instead of switch for Mode
    if self.blendMode == 1 or self.blendMode == 0 then
        self.palette:makeNormalPalettes()
    elseif self.blendMode == 2 then
        self.palette:makeBrightPalettes(value & 0x3F)
    elseif self.blendMode == 3 then
        self.palette:makeDarkPalettes(value & 0x3F)
    end
end

function GameBoyAdvanceSoftwareRenderer:setBlendEnabled(layer, enabled, override)
    self.alphaEnabled = enabled and (override == 1)
    if enabled then
        if override == 1 or override == 0 then
            self.palette:makeNormalPalette(layer)
        elseif override == 2 or override == 3 then
            self.palette:makeSpecialPalette(layer)
        end
    else
        self.palette:makeNormalPalette(layer)
    end
end

function GameBoyAdvanceSoftwareRenderer:writeBlendAlpha(value)
    self.blendA = value & 0x001F
    -- if self.blendA > 1 then self.blendA = 1 end
    self.blendB = (value & 0x1F00) >> 8
    --if self.blendB > 1 then self.blendB = 1 end
end

function GameBoyAdvanceSoftwareRenderer:writeBlendY(value)
    self.blendY = value
    self.palette:setBlendY(value >= 16 and 1 or (value / 16))
end

function GameBoyAdvanceSoftwareRenderer:writeMosaic(value)
    self.bgMosaicX = (value & 0xF) + 1
    self.bgMosaicY = ((value >> 4) & 0xF) + 1
    self.objMosaicX = ((value >> 8) & 0xF) + 1
    self.objMosaicY = ((value >> 12) & 0xF) + 1
end

function GameBoyAdvanceSoftwareRenderer:resetLayers()
    if self.backgroundMode > 1 then
        self.bg[0].enabled = false
        self.bg[1].enabled = false
    end
    -- 用包装保证调用 layer.drawScanline(backing, layer, start, end) 时以 renderer 为 self
    local renderer = self
    if self.bg[2].enabled then
        local method = self.bgModes[self.backgroundMode]
        self.bg[2].drawScanline = function(backing, layer, start, endPoint)
            method(renderer, backing, layer, start, endPoint)
        end
    end
    if self.backgroundMode == 0 or self.backgroundMode == 2 then
        if self.bg[3].enabled then
            local method = self.bgModes[self.backgroundMode]
            self.bg[3].drawScanline = function(backing, layer, start, endPoint)
                method(renderer, backing, layer, start, endPoint)
            end
        end
    else
        self.bg[3].enabled = false
    end
    self:sortLayers()
end

function GameBoyAdvanceSoftwareRenderer:sortLayers()
    table.sort(self.drawLayers, function(a, b)
        local diff = b.priority - a.priority
        if diff ~= 0 then return diff < 0 end -- sort expects boolean 'less than' in strict definition, but JS comparator returned diff.
        -- JS: return b.priority - a.priority. If > 0 (b > a), b comes first?
        -- JS Sort: < 0 a first, > 0 b first.
        -- We want higher priority (lower number) drawn later? No, drawScanline draws lower priority first (higher number).
        -- JS code: "Draw lower priority first". Lower priority value = Higher Priority visually?
        -- GBA: Priority 0 is top, 3 is bottom.
        -- JS comparator: b.priority - a.priority.
        -- If b=3, a=0 -> 3. b comes after a. a(0) drawn first. b(3) drawn last.
        -- WAIT. "Draw lower priority first". GBA "Higher priority" = 0. "Lower priority" = 3.
        -- If we draw 3 first, then 0, 0 is on top. Correct.
        -- So we want desc order of priority value (3, 2, 1, 0).
        -- Lua sort (a,b): true if a comes before b.
        -- We want 3 before 0. So a > b.
        
        if diff ~= 0 then return a.priority > b.priority end

        if a.bg and not b.bg then return true end -- a(bg) comes before b(obj)?
        -- JS: if a.bg && !b.bg return -1 (a first).
        if not a.bg and b.bg then return false end

        return a.index > b.index -- JS: b.index - a.index. if b > a, b after a? No, return >0 means b first.
        -- JS: return b.index - a.index.
        -- If b=3, a=0. Result 3. b comes after a. a first.
        -- We want high index drawn last? 
        -- If a.index > b.index.
    end)
end

function GameBoyAdvanceSoftwareRenderer:accessMapMode0(base, size, x, yBase, out)
    local offset = base + ((x >> 2) & 0x3E) + yBase
    if (size & 1) ~= 0 then
        offset = offset + ((x & 0x100) << 3)
    end 
    local mem = self.vram.buffer[offset >> 1]
    out.tile = mem & 0x03FF
    out.hflip = (mem & 0x0400) ~= 0
    out.vflip = (mem & 0x0800) ~= 0
    out.palette = (mem & 0xF000) >> 8
    out.multipalette = false -- helper for pushPixel dynamic
end

function GameBoyAdvanceSoftwareRenderer:accessMapMode1(base, size, x, yBase, out)
    local offset = base + (x >> 3) + yBase
    out.tile = self.vram:loadU8(offset)
    out.multipalette = false
end

function GameBoyAdvanceSoftwareRenderer:accessTile(base, tile, y)
    local offset = base + (tile << 5)
    offset = offset | (y << 2)
    return self.vram:load32(offset)
end

function GameBoyAdvanceSoftwareRenderer:drawScanlineBlank(backing)
    for x = 0, self.HORIZONTAL_PIXELS - 1 do
        backing.color[x] = 0xFFFF
        backing.stencil[x] = 0
    end
end

function GameBoyAdvanceSoftwareRenderer:prepareScanline(backing)
    local target = self.target2[self.LAYER_BACKDROP]
    for x = 0, self.HORIZONTAL_PIXELS - 1 do
        backing.stencil[x] = target
    end
end
-- 批量处理像素的函数
-- 参数:
-- count: 需要处理的像素数量 (通常是 8 或 4，边缘处可能更少)
-- shiftStart: 初始位移量 (处理水平翻转)
-- shiftStep: 位移步进 (4 或 -4 等)
-- mask, backing, offset: 渲染上下文
function GameBoyAdvanceSoftwareRenderer:pushPixelBatch(layer, map, video, row, count, shiftStart, shiftStep, offset, backing, mask, is8bpp, paletteBase)
    local index
    local stencilVal
    local oldStencil
    local pixel
    local highPriority
    local blend = video.blendMode
    local blendA = video.blendA
    local blendB = video.blendB
    local palette = video.palette
    local backStencil = backing.stencil
    local backColor = backing.color
    
    -- 本地化窗口逻辑需要的变量，减少查找
    local objwinActive = video.objwinActive
    local winTarget1 = video.target1
    local winWindows = video.windows
    local alphaEnabled = video.alphaEnabled

    local passthroughColors = palette.passthroughColors

    -- 循环展开：为了极致性能，这里使用 while 而不是 for，或者直接根据 count 展开
    -- 但考虑到 count 是动态的 (边缘裁剪)，使用数值循环。
    -- LuaJIT对这种简单数值循环优化很好。
    
    local currentShift = shiftStart
    
    local i = 0
    while i < count do
        -- 1. 提取颜色索引
        if is8bpp then
            index = (row >> currentShift) & 0xFF
        else
            index = (row >> currentShift) & 0xF
        end

        -- 2. 透明度检查 (Index 0 is transparent)
        if index ~= 0 then
            if not is8bpp then
                index = index | paletteBase -- 4bpp加上调色板偏移
            end

            -- 3. 模板与窗口逻辑 (这是最耗时的部分，内联化)
            local currentOffset = offset + i
            oldStencil = backStencil[currentOffset] or 0 -- 防护 nil
            stencilVal = 0x80 -- WRITTEN_MASK

            local drawPixel = true
            local currentMask = mask

            -- OBJWIN_MASK check
            if objwinActive then
                if (oldStencil & 0x20) ~= 0 then
                    if winWindows[3].enabled[layer] then
                        if winWindows[3].special and winTarget1[layer] then
                            video:setBlendEnabled(layer, true, blend)
                            if alphaEnabled then currentMask = currentMask | winTarget1[layer] end
                        else
                            video:setBlendEnabled(layer, false, blend)
                        end
                        stencilVal = stencilVal | 0x20
                    else
                        drawPixel = false
                    end
                elseif winWindows[2].enabled[layer] then -- WIN0/WIN1 shared logic usually handled by stencil bits, simplified here
                     -- 这里假设 backing.stencil 已经包含了窗口逻辑位
                     -- 标准GBA逻辑比较复杂，这里尽量保持原 pushPixel 逻辑的内联
                     if winWindows[2].special and winTarget1[layer] then
                        video:setBlendEnabled(layer, true, blend)
                        if alphaEnabled then currentMask = currentMask | winTarget1[layer] end
                     else
                        video:setBlendEnabled(layer, false, blend)
                     end
                else
                    drawPixel = false
                end
            end

            -- TARGET1_MASK (0x10) check against oldStencil TARGET2 (0x08)
            if drawPixel and (currentMask & 0x10) ~= 0 and (oldStencil & 0x08) ~= 0 then
                video:setBlendEnabled(layer, true, 1)
            end

            if drawPixel then
                -- 获取像素颜色
                pixel = passthroughColors[layer][index]

                if (currentMask & 0x10) ~= 0 then
                    video:setBlendEnabled(layer, blend ~= 0, blend)
                end

                -- 优先级判断
                -- PRIORITY_MASK is 0x07, BACKGROUND_MASK is 0x01
                highPriority = (currentMask & 0x07) < (oldStencil & 0x07)
                if (currentMask & 0x07) == (oldStencil & 0x07) then
                    highPriority = (currentMask & 0x01) ~= 0
                end

                if (oldStencil & 0x80) == 0 then
                    -- 之前没有像素
                    backStencil[currentOffset] = stencilVal | currentMask
                    backColor[currentOffset] = pixel
                elseif highPriority then
                    -- 优先级更高，覆盖并可能混合
                    if (currentMask & 0x10) ~= 0 and (oldStencil & 0x08) ~= 0 then
                        pixel = palette:mix(blendA, pixel, blendB, backColor[currentOffset])
                    end
                    backStencil[currentOffset] = stencilVal | (currentMask & ~0x10)
                    backColor[currentOffset] = pixel
                elseif (currentMask & 0x07) > (oldStencil & 0x07) then
                    -- 优先级低，但在下方，可能是混合目标
                    if (currentMask & 0x08) ~= 0 and (oldStencil & 0x10) ~= 0 then
                         -- 它是 Target2，上方是 Target1，混合写入
                        pixel = palette:mix(blendB, pixel, blendA, backColor[currentOffset])
                        -- 更新 Stencil 移除 blend 标记防止重复混合? 通常保持原样或清除
                        backStencil[currentOffset] = oldStencil & ~(0x10 | 0x08)
                        backColor[currentOffset] = pixel
                    end
                end
                
                -- OBJWIN Special Logic (if mask has 0x20)
                if (currentMask & 0x20) ~= 0 then
                    backStencil[currentOffset] = backStencil[currentOffset] | 0x20
                end
            end
        end
        
        currentShift = currentShift + shiftStep
        i = i + 1
    end
end
function GameBoyAdvanceSoftwareRenderer:drawScanlineBGMode0(backing, bg, start, endPoint)
    local video = self
    local y = video.vcount
    local offset = start
    local xOff = bg.x
    local yOff = bg.y
    
    -- 提取频繁访问的对象到局部变量
    local screenBase = bg.screenBase
    local charBase = bg.charBase
    local size = bg.size
    local index = bg.index
    local map = video.sharedMap
    local bgPriority = bg.priority
    
    -- 计算 Mask
    local baseMask = video.target2[index] | (bgPriority << 1) | video.BACKGROUND_MASK
    if video.blendMode == 1 and video.alphaEnabled then
        baseMask = baseMask | video.target1[index]
    end

    -- 确定 Y 坐标 (Mosaic Y 处理)
    local localY = y + yOff
    local bgMosaic = bg.mosaic
    -- 如果马赛克参数为 1x1，等同于关闭
    if bgMosaic and video.bgMosaicX == 1 and video.bgMosaicY == 1 then
        bgMosaic = false
    end

    if bgMosaic then
        localY = localY - (y % video.bgMosaicY)
    end
    local localYLo = localY & 0x7

    -- 计算 Map 的 yBase
    local yBase = (localY << 3) & 0x7C0
    if size == 2 then
        yBase = yBase + ((localY << 3) & 0x800)
    elseif size == 3 then
        yBase = yBase + ((localY << 4) & 0x1000)
    end

    local xMask = ((size & 1) ~= 0) and 0x1FF or 0xFF
    local x = start

    -- =============================================================
    -- 路径 1: Mosaic 开启 (慢速/兼容路径)
    -- 直接保留原有的逐像素逻辑，因为坐标跳跃，批量优化收益低且复杂
    -- =============================================================
    if bgMosaic then
        local mosaicX
        local localX, localXLo, tileY, tileRow, shiftX
        local paletteShift = bg.multipalette and 1 or 0
        
        while x < endPoint do
            localX = (x + xOff) & xMask
            mosaicX = (offset % video.bgMosaicX) -- Mosaic offset calculation
            localX = localX - mosaicX
            localXLo = localX & 0x7
            
            if paletteShift == 0 then -- 4bpp
                if localXLo == 0 or mosaicX == 0 then
                    video:accessMapMode0(screenBase, size, localX, yBase, map)
                    tileY = map.vflip and (7 - localYLo) or localYLo
                    tileRow = video:accessTile(charBase, map.tile, tileY)
                end
            else -- 8bpp
                if localXLo == 0 or mosaicX == 0 then
                    video:accessMapMode0(screenBase, size, localX, yBase, map)
                end
                if (localXLo & 0x3) == 0 or mosaicX == 0 then
                    local hFlipCheck = (localX & 0x4) ~= 0
                    if map.hflip then hFlipCheck = not hFlipCheck end
                    tileY = map.vflip and (7 - localYLo) or localYLo
                    tileRow = video:accessTile(charBase + (hFlipCheck and 4 or 0), map.tile << 1, tileY << 1)
                end
            end
            
            shiftX = localXLo
            if map.hflip then shiftX = 7 - shiftX end
            
            -- 使用旧的单像素 pushPixel (前提是该函数存在于你的代码库中)
            bg.pushPixel(index, map, video, tileRow, shiftX, offset, backing, baseMask, false)
            
            offset = offset + 1
            x = x + 1
        end
        return
    end

    -- =============================================================
    -- 路径 2: Mosaic 关闭 (高性能/批量路径)
    -- =============================================================
    
    if not bg.multipalette then
        -- >>>>>>>>>>>>>>> 4bpp Loop (16 Colors) >>>>>>>>>>>>>>>
        while x < endPoint do
            local localX = (x + xOff) & xMask
            local localXLo = localX & 0x7
            
            -- 获取 Map 信息
            -- accessMapMode0 在同一瓦片内调用是幂等的，开销相对较小，
            -- 但为了对齐，我们在切瓦片时调用
            video:accessMapMode0(screenBase, size, localX, yBase, map)
            
            local tileY = map.vflip and (7 - localYLo) or localYLo
            local tileRow = video:accessTile(charBase, map.tile, tileY)

            -- [优化] 快速跳过全透明瓦片
            if tileRow == 0 then
                local skip = 8 - localXLo
                if x + skip > endPoint then skip = endPoint - x end
                x = x + skip
                offset = offset + skip
            else
                -- 准备批量处理
                local count = 8 - localXLo
                if x + count > endPoint then count = endPoint - x end

                -- 计算位移 (Shift)
                -- 4bpp: 每个像素占 4位
                -- 无翻转: 0->0, 1->4, 2->8 ...
                -- 翻转: 0->28, 1->24 ... (Tile像素顺序反转)
                local shiftStart
                local shiftStep = 4
                
                if map.hflip then
                    shiftStart = 28 - (localXLo << 2)
                    shiftStep = -4
                else
                    shiftStart = localXLo << 2
                end

                -- 调用批量处理
                self:pushPixelBatch(index, map, video, tileRow, count, shiftStart, shiftStep, offset, backing, baseMask, false, map.palette)
                
                x = x + count
                offset = offset + count
            end
        end
    else
        -- >>>>>>>>>>>>>>> 8bpp Loop (256 Colors) >>>>>>>>>>>>>>>
        -- 8bpp 下 Tile 宽度仍为 8，但 accessTile 一次只返回 4 个像素 (32bit)
        -- 需要处理左半 (0-3) 和 右半 (4-7)
        while x < endPoint do
            local localX = (x + xOff) & xMask
            local localXLo = localX & 0x7
            
            video:accessMapMode0(screenBase, size, localX, yBase, map)
            
            -- 判断是在 Tile 的前半段还是后半段
            local subTileX = localXLo & 0x3 -- 0-3
            local isSecondHalf = (localX & 0x4) ~= 0
            
            -- 处理 HFlip 对半区选择的影响
            local hFlipCheck = isSecondHalf
            if map.hflip then hFlipCheck = not hFlipCheck end
            
            local tileY = map.vflip and (7 - localYLo) or localYLo
            
            -- 8bpp: charBase 偏移 (+4) 和索引 (*2) 
            local tileRow = video:accessTile(charBase + (hFlipCheck and 4 or 0), map.tile << 1, tileY << 1)

            -- [优化] 跳过全透明
            if tileRow == 0 then
                local skip = 4 - subTileX
                if x + skip > endPoint then skip = endPoint - x end
                x = x + skip
                offset = offset + skip
            else
                local count = 4 - subTileX
                if x + count > endPoint then count = endPoint - x end
                
                local shiftStart
                local shiftStep = 8 -- 8 bits per pixel
                
                if map.hflip then
                    -- HFlip 8bpp: 块内像素倒序 3->2->1->0
                    shiftStart = (3 - subTileX) << 3
                    shiftStep = -8
                else
                    shiftStart = subTileX << 3
                end
                
                -- 8bpp 不需要 paletteBase (传0)，flag 为 true
                self:pushPixelBatch(index, map, video, tileRow, count, shiftStart, shiftStep, offset, backing, baseMask, true, 0)
                
                x = x + count
                offset = offset + count
            end
        end
    end
end

function GameBoyAdvanceSoftwareRenderer:drawScanlineBGMode2(backing, bg, start, endPoint)
    local video = self
    local offset = start
    local localX, localY
    local screenBase = bg.screenBase
    local charBase = bg.charBase
    local size = bg.size
    local sizeAdjusted = 128 << size
    local index = bg.index
    local map = video.sharedMap
    local mask = video.target2[index] | (bg.priority << 1) | video.BACKGROUND_MASK
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[index]
    end

    for x = start, endPoint - 1 do
        localX = bg.dx * x + bg.sx
        localY = bg.dy * x + bg.sy
        if bg.mosaic then
            localX = localX - (x % video.bgMosaicX) * bg.dx - (video.vcount % video.bgMosaicY) * bg.dmx
            localY = localY - (x % video.bgMosaicX) * bg.dy - (video.vcount % video.bgMosaicY) * bg.dmy
        end
        
        localX = math.floor(localX)
        localY = math.floor(localY)

        if bg.overflow ~= 0 then
            localX = localX & (sizeAdjusted - 1)
            -- if localX < 0 is implicit handled by mask usually, but Lua % is different. 
            -- Using & bitmask on negative works in Lua 5.3+
            localY = localY & (sizeAdjusted - 1)
        else
            if localX < 0 or localY < 0 or localX >= sizeAdjusted or localY >= sizeAdjusted then
                offset = offset + 1
                goto continue_bg2
            end
        end
        
        local yBase = ((localY << 1) & 0x7F0) << size
        video:accessMapMode1(screenBase, size, localX, yBase, map)
        local color = self.vram:loadU8(charBase + (map.tile << 6) + ((localY & 0x7) << 3) + (localX & 0x7))
        bg.pushPixel(index, map, video, color, 0, offset, backing, mask, false)
        offset = offset + 1
        ::continue_bg2::
    end
end

function GameBoyAdvanceSoftwareRenderer:drawScanlineBGMode3(backing, bg, start, endPoint)
    local video = self
    local offset = start
    local localX, localY
    local index = bg.index
    local map = video.sharedMap
    local mask = video.target2[index] | (bg.priority << 1) | video.BACKGROUND_MASK
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[index]
    end

    for x = start, endPoint - 1 do
        localX = bg.dx * x + bg.sx
        localY = bg.dy * x + bg.sy
        if bg.mosaic then
             localX = localX - (x % video.bgMosaicX) * bg.dx - (video.vcount % video.bgMosaicY) * bg.dmx
             localY = localY - (x % video.bgMosaicX) * bg.dy - (video.vcount % video.bgMosaicY) * bg.dmy
        end
        
        localX = math.floor(localX)
        localY = math.floor(localY)

        if localX < 0 or localY < 0 or localX >= video.HORIZONTAL_PIXELS or localY >= video.VERTICAL_PIXELS then
            offset = offset + 1
            goto continue_bg3
        end
        
        local color = self.vram:loadU16(((localY * video.HORIZONTAL_PIXELS) + localX) << 1)
        bg.pushPixel(index, map, video, color, 0, offset, backing, mask, true)
        offset = offset + 1
        ::continue_bg3::
    end
end

function GameBoyAdvanceSoftwareRenderer:drawScanlineBGMode4(backing, bg, start, endPoint)
    local video = self
    local offset = start
    local localX, localY
    local charBase = 0
    if video.displayFrameSelect ~= 0 then
        charBase = charBase + 0xA000
    end
    local index = bg.index
    local map = video.sharedMap
    local mask = video.target2[index] | (bg.priority << 1) | video.BACKGROUND_MASK
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[index]
    end

    for x = start, endPoint - 1 do
        localX = bg.dx * x + bg.sx
        localY = bg.dy * x + bg.sy
        if bg.mosaic then
             localX = localX - (x % video.bgMosaicX) * bg.dx - (video.vcount % video.bgMosaicY) * bg.dmx
             localY = localY - (x % video.bgMosaicX) * bg.dy - (video.vcount % video.bgMosaicY) * bg.dmy
        end
        
        localX = math.floor(localX)
        localY = math.floor(localY)

        if localX < 0 or localY < 0 or localX >= video.HORIZONTAL_PIXELS or localY >= video.VERTICAL_PIXELS then
            offset = offset + 1
            goto continue_bg4
        end
        
        local color = self.vram:loadU8(charBase + (localY * video.HORIZONTAL_PIXELS) + localX)
        bg.pushPixel(index, map, video, color, 0, offset, backing, mask, false)
        offset = offset + 1
        ::continue_bg4::
    end
end

function GameBoyAdvanceSoftwareRenderer:drawScanlineBGMode5(backing, bg, start, endPoint)
    local video = self
    local offset = start
    local localX, localY
    local charBase = 0
    if video.displayFrameSelect ~= 0 then
        charBase = charBase + 0xA000
    end
    local index = bg.index
    local map = video.sharedMap
    local mask = video.target2[index] | (bg.priority << 1) | video.BACKGROUND_MASK
    if video.blendMode == 1 and video.alphaEnabled then
        mask = mask | video.target1[index]
    end

    for x = start, endPoint - 1 do
        localX = bg.dx * x + bg.sx
        localY = bg.dy * x + bg.sy
        if bg.mosaic then
             localX = localX - (x % video.bgMosaicX) * bg.dx - (video.vcount % video.bgMosaicY) * bg.dmx
             localY = localY - (x % video.bgMosaicX) * bg.dy - (video.vcount % video.bgMosaicY) * bg.dmy
        end
        
        localX = math.floor(localX)
        localY = math.floor(localY)

        if localX < 0 or localY < 0 or localX >= 160 or localY >= 128 then
            offset = offset + 1
            goto continue_bg5
        end
        
        local color = self.vram:loadU16((charBase + (localY * 160) + localX) << 1)
        bg.pushPixel(index, map, video, color, 0, offset, backing, mask, true)
        offset = offset + 1
        ::continue_bg5::
    end
end

function GameBoyAdvanceSoftwareRenderer:drawScanline(y)
    local backing = self.scanline
    if self.forcedBlank ~= 0 then
        self:drawScanlineBlank(backing)
        return
    end
    self:prepareScanline(backing)
    local layer
    local firstStart, firstEnd, lastStart, lastEnd
    self.vcount = y
    for i = 1, #self.drawLayers do
        layer = self.drawLayers[i]
        if layer.enabled then
            self.objwinActive = false
            if (self.win0 == 0) and (self.win1 == 0) and (self.objwin == 0) then
                self:setBlendEnabled(layer.index, (self.target1[layer.index] ~= 0), self.blendMode)
                layer.drawScanline(backing, layer, 0, self.HORIZONTAL_PIXELS)
            else
                firstStart = 0; firstEnd = self.HORIZONTAL_PIXELS
                lastStart = 0; lastEnd = self.HORIZONTAL_PIXELS

                if self.win0 ~= 0 and y >= self.win0Top and y < self.win0Bottom then
                    if self.windows[0].enabled[layer.index] then
                        self:setBlendEnabled(layer.index, self.windows[0].special and (self.target1[layer.index] ~= 0), self.blendMode)
                        layer.drawScanline(backing, layer, self.win0Left, self.win0Right)
                    end
                    firstStart = math.max(firstStart, self.win0Left)
                    firstEnd = math.min(firstEnd, self.win0Left)
                    lastStart = math.max(lastStart, self.win0Right)
                    lastEnd = math.min(lastEnd, self.win0Right)
                end

                if self.win1 ~= 0 and y >= self.win1Top and y < self.win1Bottom then
                    if self.windows[1].enabled[layer.index] then
                        self:setBlendEnabled(layer.index, self.windows[1].special and (self.target1[layer.index] ~= 0), self.blendMode)
                        if not self.windows[0].enabled[layer.index] and (self.win1Left < firstStart or self.win1Right < lastStart) then
                            layer.drawScanline(backing, layer, self.win1Left, firstStart)
                            layer.drawScanline(backing, layer, lastEnd, self.win1Right)
                        else
                            layer.drawScanline(backing, layer, self.win1Left, self.win1Right)
                        end
                    end
                    firstStart = math.max(firstStart, self.win1Left)
                    firstEnd = math.min(firstEnd, self.win1Left)
                    lastStart = math.max(lastStart, self.win1Right)
                    lastEnd = math.min(lastEnd, self.win1Right)
                end

                if self.windows[2].enabled[layer.index] or (self.objwin ~= 0 and self.windows[3].enabled[layer.index]) then
                    self.objwinActive = (self.objwin ~= 0)
                    self:setBlendEnabled(layer.index, self.windows[2].special and (self.target1[layer.index] ~= 0), self.blendMode)
                    if firstEnd > lastStart then
                        layer.drawScanline(backing, layer, 0, self.HORIZONTAL_PIXELS)
                    else
                        if firstEnd > 0 then
                            layer.drawScanline(backing, layer, 0, firstEnd)
                        end
                        if lastStart < self.HORIZONTAL_PIXELS then
                            layer.drawScanline(backing, layer, lastStart, self.HORIZONTAL_PIXELS)
                        end
                        if lastEnd < firstStart then
                            layer.drawScanline(backing, layer, lastEnd, firstStart)
                        end
                    end
                end

                self:setBlendEnabled(self.LAYER_BACKDROP, (self.target1[self.LAYER_BACKDROP] ~= 0) and self.windows[2].special, self.blendMode)
            end

            if layer.bg then
                layer.sx = layer.sx + layer.dmx
                layer.sy = layer.sy + layer.dmy
    end
    end
    end

    self:finishScanline(backing)
end

function GameBoyAdvanceSoftwareRenderer:finishScanline(backing)
    local color
    local bd = self.palette:accessColor(self.LAYER_BACKDROP, 0)
    local xx = self.vcount * self.HORIZONTAL_PIXELS * 4 -- index 0 based
    local isTarget2 = (self.target2[self.LAYER_BACKDROP] ~= 0)

    local backingcolor = backing.color;
    local backingstencil = backing.stencil;
    local r,g,b
    local pdata = self.pixelData.data;
    for x = 0, self.HORIZONTAL_PIXELS - 1 do
        --0x80 is written mask
        if (backingstencil[x] & 0x80) ~= 0 then
            color = backingcolor[x]
            -- 0x10 is target1 mask
            if isTarget2 and (backingstencil[x] & 0x10) ~= 0 then
                color = self.palette:mix(self.blendA, color, self.blendB, bd)
            end
            pdata[1+xx] = (color & 0x001F) << 3
            pdata[2+xx] = (color & 0x03E0) >> 2
            pdata[3+xx] = (color & 0x7C00) >> 7
            --pdata[4+xx] = 255 -- Alpha Always 255
        else
            pdata[1+xx] = (bd & 0x001F) << 3
            pdata[2+xx] = (bd & 0x03E0) >> 2
            pdata[3+xx] = (bd & 0x7C00) >> 7
            --pdata[4+xx] = 255 -- Alpha Always 255
        end
        xx = xx + 4
    end
end

function GameBoyAdvanceSoftwareRenderer:startDraw()
end

function GameBoyAdvanceSoftwareRenderer:finishDraw(caller)
    self.bg[2].sx = self.bg[2].refx
    self.bg[2].sy = self.bg[2].refy
    self.bg[3].sx = self.bg[3].refx
    self.bg[3].sy = self.bg[3].refy
    caller:finishDraw(self.pixelData)
end

return GameBoyAdvanceSoftwareRenderer