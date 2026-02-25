local ClassUtils = require("ClassUtils")
local GameBoyAdvanceIO = ClassUtils.class("GameBoyAdvanceIO")

function GameBoyAdvanceIO:ctor()
    -- Video
    self.DISPCNT = 0x000
    self.GREENSWP = 0x002
    self.DISPSTAT = 0x004
    self.VCOUNT = 0x006
    self.BG0CNT = 0x008
    self.BG1CNT = 0x00a
    self.BG2CNT = 0x00c
    self.BG3CNT = 0x00e
    self.BG0HOFS = 0x010
    self.BG0VOFS = 0x012
    self.BG1HOFS = 0x014
    self.BG1VOFS = 0x016
    self.BG2HOFS = 0x018
    self.BG2VOFS = 0x01a
    self.BG3HOFS = 0x01c
    self.BG3VOFS = 0x01e
    self.BG2PA = 0x020
    self.BG2PB = 0x022
    self.BG2PC = 0x024
    self.BG2PD = 0x026
    self.BG2X_LO = 0x028
    self.BG2X_HI = 0x02a
    self.BG2Y_LO = 0x02c
    self.BG2Y_HI = 0x02e
    self.BG3PA = 0x030
    self.BG3PB = 0x032
    self.BG3PC = 0x034
    self.BG3PD = 0x036
    self.BG3X_LO = 0x038
    self.BG3X_HI = 0x03a
    self.BG3Y_LO = 0x03c
    self.BG3Y_HI = 0x03e
    self.WIN0H = 0x040
    self.WIN1H = 0x042
    self.WIN0V = 0x044
    self.WIN1V = 0x046
    self.WININ = 0x048
    self.WINOUT = 0x04a
    self.MOSAIC = 0x04c
    self.BLDCNT = 0x050
    self.BLDALPHA = 0x052
    self.BLDY = 0x054

    -- Sound
    self.SOUND1CNT_LO = 0x060
    self.SOUND1CNT_HI = 0x062
    self.SOUND1CNT_X = 0x064
    self.SOUND2CNT_LO = 0x068
    self.SOUND2CNT_HI = 0x06c
    self.SOUND3CNT_LO = 0x070
    self.SOUND3CNT_HI = 0x072
    self.SOUND3CNT_X = 0x074
    self.SOUND4CNT_LO = 0x078
    self.SOUND4CNT_HI = 0x07c
    self.SOUNDCNT_LO = 0x080
    self.SOUNDCNT_HI = 0x082
    self.SOUNDCNT_X = 0x084
    self.SOUNDBIAS = 0x088
    self.WAVE_RAM0_LO = 0x090
    self.WAVE_RAM0_HI = 0x092
    self.WAVE_RAM1_LO = 0x094
    self.WAVE_RAM1_HI = 0x096
    self.WAVE_RAM2_LO = 0x098
    self.WAVE_RAM2_HI = 0x09a
    self.WAVE_RAM3_LO = 0x09c
    self.WAVE_RAM3_HI = 0x09e
    self.FIFO_A_LO = 0x0a0
    self.FIFO_A_HI = 0x0a2
    self.FIFO_B_LO = 0x0a4
    self.FIFO_B_HI = 0x0a6

    -- DMA
    self.DMA0SAD_LO = 0x0b0
    self.DMA0SAD_HI = 0x0b2
    self.DMA0DAD_LO = 0x0b4
    self.DMA0DAD_HI = 0x0b6
    self.DMA0CNT_LO = 0x0b8
    self.DMA0CNT_HI = 0x0ba
    self.DMA1SAD_LO = 0x0bc
    self.DMA1SAD_HI = 0x0be
    self.DMA1DAD_LO = 0x0c0
    self.DMA1DAD_HI = 0x0c2
    self.DMA1CNT_LO = 0x0c4
    self.DMA1CNT_HI = 0x0c6
    self.DMA2SAD_LO = 0x0c8
    self.DMA2SAD_HI = 0x0ca
    self.DMA2DAD_LO = 0x0cc
    self.DMA2DAD_HI = 0x0ce
    self.DMA2CNT_LO = 0x0d0
    self.DMA2CNT_HI = 0x0d2
    self.DMA3SAD_LO = 0x0d4
    self.DMA3SAD_HI = 0x0d6
    self.DMA3DAD_LO = 0x0d8
    self.DMA3DAD_HI = 0x0da
    self.DMA3CNT_LO = 0x0dc
    self.DMA3CNT_HI = 0x0de

    -- Timers
    self.TM0CNT_LO = 0x100
    self.TM0CNT_HI = 0x102
    self.TM1CNT_LO = 0x104
    self.TM1CNT_HI = 0x106
    self.TM2CNT_LO = 0x108
    self.TM2CNT_HI = 0x10a
    self.TM3CNT_LO = 0x10c
    self.TM3CNT_HI = 0x10e

    -- SIO
    self.SIODATA32_LO = 0x120
    self.SIOMULTI0 = 0x120
    self.SIODATA32_HI = 0x122
    self.SIOMULTI1 = 0x122
    self.SIOMULTI2 = 0x124
    self.SIOMULTI3 = 0x126
    self.SIOCNT = 0x128
    self.SIOMLT_SEND = 0x12a
    self.SIODATA8 = 0x12a
    self.RCNT = 0x134
    self.JOYCNT = 0x140
    self.JOY_RECV = 0x150
    self.JOY_TRANS = 0x154
    self.JOYSTAT = 0x158

    -- Keypad
    self.KEYINPUT = 0x130
    self.KEYCNT = 0x132

    -- Interrupts, etc
    self.IE = 0x200
    self.IF = 0x202
    self.WAITCNT = 0x204
    self.IME = 0x208

    self.POSTFLG = 0x300
    self.HALTCNT = 0x301

    self.DEFAULT_DISPCNT = 0x0080
    self.DEFAULT_SOUNDBIAS = 0x200
    self.DEFAULT_BGPA = 1
    self.DEFAULT_BGPD = 1
    self.DEFAULT_RCNT = 0x8000
    
    self.registers = nil -- will be table
end

function GameBoyAdvanceIO:initHandlers()
    local video = self.video
    local audio = self.audio
    local irq = self.cpu.irq
    local sio = self.sio
    local keypad = self.keypad

    -- Read Handlers
    self.readHandlers = {
        [self.DISPSTAT] = function() 
            return self.registers[self.DISPSTAT >> 1] | self.video:readDisplayStat() 
        end,
        [self.VCOUNT] = function() 
            return self.video.vcount
        end,
        
        -- Sound Reads
        [self.SOUND1CNT_HI] = function() return self.registers[self.SOUND1CNT_HI >> 1] & 0xffc0 end,
        [self.SOUND2CNT_LO] = function() return self.registers[self.SOUND2CNT_LO >> 1] & 0xffc0 end,
        [self.SOUND1CNT_X]  = function() return self.registers[self.SOUND1CNT_X >> 1] & 0x4000 end,
        [self.SOUND2CNT_HI] = function() return self.registers[self.SOUND2CNT_HI >> 1] & 0x4000 end,
        [self.SOUND3CNT_X]  = function() return self.registers[self.SOUND3CNT_X >> 1] & 0x4000 end,
        [self.SOUND3CNT_HI] = function() return self.registers[self.SOUND3CNT_HI >> 1] & 0xe000 end,
        [self.SOUND4CNT_LO] = function() return self.registers[self.SOUND4CNT_LO >> 1] & 0xff00 end,
        [self.SOUND4CNT_HI] = function() return self.registers[self.SOUND4CNT_HI >> 1] & 0x40ff end,
        [self.SOUNDCNT_X]   = function() 
            self.core:STUB("Unimplemented sound register read: SOUNDCNT_X")
            return self.registers[self.SOUNDCNT_X >> 1] | 0x0000 
        end,

        -- Timers Reads
        [self.TM0CNT_LO] = function() return self.cpu.irq:timerRead(0) end,
        [self.TM1CNT_LO] = function() return self.cpu.irq:timerRead(1) end,
        [self.TM2CNT_LO] = function() return self.cpu.irq:timerRead(2) end,
        [self.TM3CNT_LO] = function() return self.cpu.irq:timerRead(3) end,

        -- SIO/Input Reads
        [self.SIOCNT] = function() return self.sio:readSIOCNT() end,
        [self.KEYINPUT] = function() 
            return self.keypad.currentDown
        end,
        [self.KEYCNT] = function()
            self.core:STUB("Unimplemented I/O register read: KEYCNT")
            return 0
        end,
        [self.SIOMULTI0] = function() return self.sio:read(0) end,
        [self.SIOMULTI1] = function() return self.sio:read(1) end,
        [self.SIOMULTI2] = function() return self.sio:read(2) end,
        [self.SIOMULTI3] = function() return self.sio:read(3) end,
        [self.SIODATA8] = function() 
            self.core:STUB("Unimplemented SIO register read: 0x" .. string.format("%x", self.SIODATA8))
            return 0
        end,
        [self.JOYCNT] = function() 
            self.core:STUB("Unimplemented JOY register read: 0x" .. string.format("%x", self.JOYCNT))
            return 0
        end,
        [self.JOYSTAT] = function() 
            self.core:STUB("Unimplemented JOY register read: 0x" .. string.format("%x", self.JOYSTAT))
            return 0
        end
    }

    -- Write-only registers that warn on read
    local warnRead = function(offset)
        self.core:WARN("Read for write-only register: 0x" .. string.format("%x", offset))
        return self.core.mmu.badMemory:loadU16(0)
    end
    
    local writeOnlyRegs = {
        self.BG0HOFS, self.BG0VOFS, self.BG1HOFS, self.BG1VOFS, 
        self.BG2HOFS, self.BG2VOFS, self.BG3HOFS, self.BG3VOFS,
        self.BG2PA, self.BG2PB, self.BG2PC, self.BG2PD,
        self.BG3PA, self.BG3PB, self.BG3PC, self.BG3PD,
        self.BG2X_LO, self.BG2X_HI, self.BG2Y_LO, self.BG2Y_HI,
        self.BG3X_LO, self.BG3X_HI, self.BG3Y_LO, self.BG3Y_HI,
        self.WIN0H, self.WIN1H, self.WIN0V, self.WIN1V, self.BLDY,
        self.DMA0SAD_LO, self.DMA0SAD_HI, self.DMA0DAD_LO, self.DMA0DAD_HI, self.DMA0CNT_LO,
        self.DMA1SAD_LO, self.DMA1SAD_HI, self.DMA1DAD_LO, self.DMA1DAD_HI, self.DMA1CNT_LO,
        self.DMA2SAD_LO, self.DMA2SAD_HI, self.DMA2DAD_LO, self.DMA2DAD_HI, self.DMA2CNT_LO,
        self.DMA3SAD_LO, self.DMA3SAD_HI, self.DMA3DAD_LO, self.DMA3DAD_HI, self.DMA3CNT_LO,
        self.FIFO_A_LO, self.FIFO_A_HI, self.FIFO_B_LO, self.FIFO_B_HI
    }

    for _, reg in ipairs(writeOnlyRegs) do
        self.readHandlers[reg] = function() return warnRead(reg) end
    end
    self.readHandlers[self.MOSAIC] = function() 
        self.core:WARN("Read for write-only register: 0x" .. string.format("%x", self.MOSAIC))
        return 0 
    end


    -- Write Handlers
    -- Return true if the write is fully handled (register update manually done or skipped)
    -- Return modified value if the value needs masking before generic write
    -- Return nil to proceed with generic write of 'value'
    self.writeHandlers = {
        -- Video
        [self.DISPCNT] = function(v) self.video.renderPath:writeDisplayControl(v) end,
        [self.DISPSTAT] = function(v) 
            v = v & self.video.DISPSTAT_MASK
            self.video:writeDisplayStat(v) 
            return v -- proceed to write masked value
        end,
        [self.BG0CNT] = function(v) self.video.renderPath:writeBackgroundControl(0, v) end,
        [self.BG1CNT] = function(v) self.video.renderPath:writeBackgroundControl(1, v) end,
        [self.BG2CNT] = function(v) self.video.renderPath:writeBackgroundControl(2, v) end,
        [self.BG3CNT] = function(v) self.video.renderPath:writeBackgroundControl(3, v) end,
        [self.BG0HOFS] = function(v) self.video.renderPath:writeBackgroundHOffset(0, v) end,
        [self.BG0VOFS] = function(v) self.video.renderPath:writeBackgroundVOffset(0, v) end,
        [self.BG1HOFS] = function(v) self.video.renderPath:writeBackgroundHOffset(1, v) end,
        [self.BG1VOFS] = function(v) self.video.renderPath:writeBackgroundVOffset(1, v) end,
        [self.BG2HOFS] = function(v) self.video.renderPath:writeBackgroundHOffset(2, v) end,
        [self.BG2VOFS] = function(v) self.video.renderPath:writeBackgroundVOffset(2, v) end,
        [self.BG3HOFS] = function(v) self.video.renderPath:writeBackgroundHOffset(3, v) end,
        [self.BG3VOFS] = function(v) self.video.renderPath:writeBackgroundVOffset(3, v) end,
        
        [self.BG2X_LO] = function(v) 
            local upper = self.registers[(self.BG2X_LO >> 1) + 1]
            self.video.renderPath:writeBackgroundRefX(2, (upper << 16) | v)
        end,
        [self.BG2X_HI] = function(v) 
            local lower = self.registers[(self.BG2X_HI >> 1) - 1]
            self.video.renderPath:writeBackgroundRefX(2, lower | (v << 16))
        end,
        [self.BG2Y_LO] = function(v) 
            local upper = self.registers[(self.BG2Y_LO >> 1) + 1]
            self.video.renderPath:writeBackgroundRefY(2, (upper << 16) | v)
        end,
        [self.BG2Y_HI] = function(v) 
            local lower = self.registers[(self.BG2Y_HI >> 1) - 1]
            self.video.renderPath:writeBackgroundRefY(2, lower | (v << 16))
        end,
        [self.BG2PA] = function(v) self.video.renderPath:writeBackgroundParamA(2, v) end,
        [self.BG2PB] = function(v) self.video.renderPath:writeBackgroundParamB(2, v) end,
        [self.BG2PC] = function(v) self.video.renderPath:writeBackgroundParamC(2, v) end,
        [self.BG2PD] = function(v) self.video.renderPath:writeBackgroundParamD(2, v) end,
        
        [self.BG3X_LO] = function(v) 
            local upper = self.registers[(self.BG3X_LO >> 1) + 1]
            self.video.renderPath:writeBackgroundRefX(3, (upper << 16) | v)
        end,
        [self.BG3X_HI] = function(v) 
            local lower = self.registers[(self.BG3X_HI >> 1) - 1]
            self.video.renderPath:writeBackgroundRefX(3, lower | (v << 16))
        end,
        [self.BG3Y_LO] = function(v) 
            local upper = self.registers[(self.BG3Y_LO >> 1) + 1]
            self.video.renderPath:writeBackgroundRefY(3, (upper << 16) | v)
        end,
        [self.BG3Y_HI] = function(v) 
            local lower = self.registers[(self.BG3Y_HI >> 1) - 1]
            self.video.renderPath:writeBackgroundRefY(3, lower | (v << 16))
        end,
        [self.BG3PA] = function(v) self.video.renderPath:writeBackgroundParamA(3, v) end,
        [self.BG3PB] = function(v) self.video.renderPath:writeBackgroundParamB(3, v) end,
        [self.BG3PC] = function(v) self.video.renderPath:writeBackgroundParamC(3, v) end,
        [self.BG3PD] = function(v) self.video.renderPath:writeBackgroundParamD(3, v) end,
        [self.WIN0H] = function(v) self.video.renderPath:writeWin0H(v) end,
        [self.WIN1H] = function(v) self.video.renderPath:writeWin1H(v) end,
        [self.WIN0V] = function(v) self.video.renderPath:writeWin0V(v) end,
        [self.WIN1V] = function(v) self.video.renderPath:writeWin1V(v) end,
        [self.WININ] = function(v) 
            v = v & 0x3f3f 
            self.video.renderPath:writeWinIn(v)
            return v 
        end,
        [self.WINOUT] = function(v) 
            v = v & 0x3f3f 
            self.video.renderPath:writeWinOut(v)
            return v
        end,
        [self.BLDCNT] = function(v) 
            v = v & 0x7fff 
            self.video.renderPath:writeBlendControl(v)
            return v
        end,
        [self.BLDALPHA] = function(v) 
            v = v & 0x1f1f 
            self.video.renderPath:writeBlendAlpha(v)
            return v
        end,
        [self.BLDY] = function(v) 
            v = v & 0x001f 
            self.video.renderPath:writeBlendY(v)
            return v
        end,
        [self.MOSAIC] = function(v) self.video.renderPath:writeMosaic(v) end,

        -- Sound
        [self.SOUND1CNT_LO] = function(v)
            v = v & 0x007f
            --blockself.audio:writeSquareChannelSweep(0, v)
            return v
        end,
        [self.SOUND1CNT_HI] = function(v) 
            --blockself.audio:writeSquareChannelDLE(0, v) 

        end,
        [self.SOUND1CNT_X]  = function(v)
            v = v & 0xc7ff
            --blockself.audio:writeSquareChannelFC(0, v)
            return v & ~0x8000
        end,
        [self.SOUND2CNT_LO] = function(v) 
            --blockself.audio:writeSquareChannelDLE(1, v)    
        end,
        [self.SOUND2CNT_HI] = function(v)
            v = v & 0xc7ff
            --blockself.audio:writeSquareChannelFC(1, v)
            return v & ~0x8000
        end,
        [self.SOUND3CNT_LO] = function(v)
            v = v & 0x00e0
            --blockself.audio:writeChannel3Lo(v)
            return v
        end,
        [self.SOUND3CNT_HI] = function(v)
            v = v & 0xe0ff
            --blockself.audio:writeChannel3Hi(v)
            return v
        end,
        [self.SOUND3CNT_X]  = function(v)
            v = v & 0xc7ff
            --blockself.audio:writeChannel3X(v)
            return v & ~0x8000
        end,
        [self.SOUND4CNT_LO] = function(v)
            v = v & 0xff3f
            --blockself.audio:writeChannel4LE(v)
            return v
        end,
        [self.SOUND4CNT_HI] = function(v)
            v = v & 0xc0ff
            --blockself.audio:writeChannel4FC(v)
            return v & ~0x8000
        end,
        [self.SOUNDCNT_LO]  = function(v)
            v = v & 0xff77
            --blockself.audio:writeSoundControlLo(v)
            return v
        end,
        [self.SOUNDCNT_HI]  = function(v)
            v = v & 0xff0f
            --blockself.audio:writeSoundControlHi(v)
            return v
        end,
        [self.SOUNDCNT_X]   = function(v)
            v = v & 0x0080
            --blockself.audio:writeEnable(v)
            return v
        end,

        -- DMA
        [self.DMA0SAD_LO] = function(v) self:store32(self.DMA0SAD_LO, (self.registers[(self.DMA0SAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA0DAD_LO] = function(v) self:store32(self.DMA0DAD_LO, (self.registers[(self.DMA0DAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA1SAD_LO] = function(v) self:store32(self.DMA1SAD_LO, (self.registers[(self.DMA1SAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA1DAD_LO] = function(v) self:store32(self.DMA1DAD_LO, (self.registers[(self.DMA1DAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA2SAD_LO] = function(v) self:store32(self.DMA2SAD_LO, (self.registers[(self.DMA2SAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA2DAD_LO] = function(v) self:store32(self.DMA2DAD_LO, (self.registers[(self.DMA2DAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA3SAD_LO] = function(v) self:store32(self.DMA3SAD_LO, (self.registers[(self.DMA3SAD_LO >> 1) + 1] << 16) | v); return true end,
        [self.DMA3DAD_LO] = function(v) self:store32(self.DMA3DAD_LO, (self.registers[(self.DMA3DAD_LO >> 1) + 1] << 16) | v); return true end,
        
        [self.DMA0SAD_HI] = function(v) self:store32(self.DMA0SAD_LO, self.registers[(self.DMA0SAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA0DAD_HI] = function(v) self:store32(self.DMA0DAD_LO, self.registers[(self.DMA0DAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA1SAD_HI] = function(v) self:store32(self.DMA1SAD_LO, self.registers[(self.DMA1SAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA1DAD_HI] = function(v) self:store32(self.DMA1DAD_LO, self.registers[(self.DMA1DAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA2SAD_HI] = function(v) self:store32(self.DMA2SAD_LO, self.registers[(self.DMA2SAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA2DAD_HI] = function(v) self:store32(self.DMA2DAD_LO, self.registers[(self.DMA2DAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA3SAD_HI] = function(v) self:store32(self.DMA3SAD_LO, self.registers[(self.DMA3SAD_HI >> 1) - 1] | (v << 16)); return true end,
        [self.DMA3DAD_HI] = function(v) self:store32(self.DMA3DAD_LO, self.registers[(self.DMA3DAD_HI >> 1) - 1] | (v << 16)); return true end,

        [self.DMA0CNT_LO] = function(v) self.cpu.irq:dmaSetWordCount(0, v) end,
        [self.DMA1CNT_LO] = function(v) self.cpu.irq:dmaSetWordCount(1, v) end,
        [self.DMA2CNT_LO] = function(v) self.cpu.irq:dmaSetWordCount(2, v) end,
        [self.DMA3CNT_LO] = function(v) self.cpu.irq:dmaSetWordCount(3, v) end,
        
        [self.DMA0CNT_HI] = function(v)
            self.registers[self.DMA0CNT_HI >> 1] = v & 0xffe0
            self.cpu.irq:dmaWriteControl(0, v)
            return true -- Handled
        end,
        [self.DMA1CNT_HI] = function(v)
            self.registers[self.DMA1CNT_HI >> 1] = v & 0xffe0
            self.cpu.irq:dmaWriteControl(1, v)
            return true
        end,
        [self.DMA2CNT_HI] = function(v)
            self.registers[self.DMA2CNT_HI >> 1] = v & 0xffe0
            self.cpu.irq:dmaWriteControl(2, v)
            return true
        end,
        [self.DMA3CNT_HI] = function(v)
            self.registers[self.DMA3CNT_HI >> 1] = v & 0xffe0
            self.cpu.irq:dmaWriteControl(3, v)
            return true
        end,

        -- Timers
        [self.TM0CNT_LO] = function(v) self.cpu.irq:timerSetReload(0, v); return true end,
        [self.TM1CNT_LO] = function(v) self.cpu.irq:timerSetReload(1, v); return true end,
        [self.TM2CNT_LO] = function(v) self.cpu.irq:timerSetReload(2, v); return true end,
        [self.TM3CNT_LO] = function(v) self.cpu.irq:timerSetReload(3, v); return true end,
        
        [self.TM0CNT_HI] = function(v) v = v & 0x00c7; self.cpu.irq:timerWriteControl(0, v); return v end,
        [self.TM1CNT_HI] = function(v) v = v & 0x00c7; self.cpu.irq:timerWriteControl(1, v); return v end,
        [self.TM2CNT_HI] = function(v) v = v & 0x00c7; self.cpu.irq:timerWriteControl(2, v); return v end,
        [self.TM3CNT_HI] = function(v) v = v & 0x00c7; self.cpu.irq:timerWriteControl(3, v); return v end,

        -- SIO
        [self.SIOMULTI0] = function(v) self:STUB_REG("SIO", self.SIOMULTI0) end,
        [self.SIOMULTI1] = function(v) self:STUB_REG("SIO", self.SIOMULTI1) end,
        [self.SIOMULTI2] = function(v) self:STUB_REG("SIO", self.SIOMULTI2) end,
        [self.SIOMULTI3] = function(v) self:STUB_REG("SIO", self.SIOMULTI3) end,
        [self.SIODATA8]  = function(v) self:STUB_REG("SIO", self.SIODATA8) end,
        [self.JOYCNT]    = function(v) self:STUB_REG("JOY", self.JOYCNT) end,
        [self.JOYSTAT]   = function(v) self:STUB_REG("JOY", self.JOYSTAT) end,
        
        [self.RCNT] = function(v)
            local currentSIOCNT = self.registers[self.SIOCNT >> 1] or 0
            self.sio:setMode( ((v >> 12) & 0xc) | ((currentSIOCNT >> 12) & 0x3) )
            self.sio:writeRCNT(v)
        end,
        [self.SIOCNT] = function(v)
            local currentRCNT = self.registers[self.RCNT >> 1] or 0
            self.sio:setMode( ((v >> 12) & 0x3) | ((currentRCNT >> 12) & 0xc) )
            self.sio:writeSIOCNT(v)
            self.registers[self.SIOCNT >> 1] = v
            return true -- Handled
        end,

        -- Misc
        [self.IE] = function(v)
            v = v & 0x3fff
            self.cpu.irq:setInterruptsEnabled(v)
            return v
        end,
        [self.IF] = function(v)
            self.cpu.irq:dismissIRQs(v)
            return true -- registers not updated for IF write? (Check JS: YES, returns)
        end,
        [self.WAITCNT] = function(v)
            v = v & 0xdfff
            self.cpu.mmu:adjustTimings(v)
            return v
        end,
        [self.IME] = function(v)
            v = v & 0x0001
            self.cpu.irq:masterEnable(v)
            return v
        end
    }

    -- Wave RAM helper
    local waveRamRegs = {
        self.WAVE_RAM0_LO, self.WAVE_RAM0_HI, self.WAVE_RAM1_LO, self.WAVE_RAM1_HI,
        self.WAVE_RAM2_LO, self.WAVE_RAM2_HI, self.WAVE_RAM3_LO, self.WAVE_RAM3_HI
    }
    for _, reg in ipairs(waveRamRegs) do
        self.writeHandlers[reg] = function(v)
            --blockself.audio:writeWaveData(reg - self.WAVE_RAM0_LO, v, 2)
        end
    end
end

function GameBoyAdvanceIO:clear()
    -- Initialize registers table (sparse array or pre-filled)
    -- Using a lua table to simulate Uint16Array. 
    -- SIZE_IO is expected to be available in cpu.mmu.
    -- If not, we can default to 1024 (0x400 bytes, so 0x200 shorts)
    self.registers = {}
    local size = (self.cpu.mmu.SIZE_IO or 0x400) >> 1
    for i = 0, size - 1 do
        self.registers[i] = 0
    end

    self.registers[self.DISPCNT >> 1] = self.DEFAULT_DISPCNT
    self.registers[self.SOUNDBIAS >> 1] = self.DEFAULT_SOUNDBIAS
    self.registers[self.BG2PA >> 1] = self.DEFAULT_BGPA
    self.registers[self.BG2PD >> 1] = self.DEFAULT_BGPD
    self.registers[self.BG3PA >> 1] = self.DEFAULT_BGPA
    self.registers[self.BG3PD >> 1] = self.DEFAULT_BGPD
    self.registers[self.RCNT >> 1] = self.DEFAULT_RCNT
end

function GameBoyAdvanceIO:freeze()
    return {
        registers = self.registers
    }
end

function GameBoyAdvanceIO:defrost(frost)
    self.registers = frost.registers
    -- Video registers don't serialize themselves
    for i = 0, self.BLDY, 2 do
        self:store16(i, self.registers[i >> 1])
    end
end

function GameBoyAdvanceIO:load8(offset)
    error("Unimplemented unaligned I/O access")
end

local function signExtend16(val)
    if (val & 0x8000) ~= 0 then
        return val - 0x10000
    end
    return val
end

function GameBoyAdvanceIO:load16(offset)
    return signExtend16(self:loadU16(offset))
end

function GameBoyAdvanceIO:load32(offset)
    offset = offset & 0xfffffffc
    
    if offset == self.DMA0CNT_LO or 
       offset == self.DMA1CNT_LO or 
       offset == self.DMA2CNT_LO or 
       offset == self.DMA3CNT_LO then
        return (self:loadU16(offset | 2) << 16)
    elseif offset == self.IME then
        return self:loadU16(offset) & 0xffff
    elseif offset == self.JOY_RECV or offset == self.JOY_TRANS then
        self.core:STUB("Unimplemented JOY register read: 0x" .. string.format("%x", offset))
        return 0
    end

    return self:loadU16(offset) | (self:loadU16(offset | 2) << 16)
end

function GameBoyAdvanceIO:loadU8(offset)
    local odd = offset & 0x0001
    local value = self:loadU16(offset & 0xfffe)
    -- Lua 5.3+ logical right shift '>>'
    return (value >> (odd << 3)) & 0xff
end

function GameBoyAdvanceIO:loadU16(offset)
    local handler = self.readHandlers[offset]
    if handler then
        return handler()
    end

    local validAddress = self.registers[offset >> 1] ~= nil
    if not validAddress then
         self.core:WARN("Bad I/O register read: 0x" .. string.format("%x", offset))
         return self.core.mmu.badMemory:loadU16(0)
    end

    return self.registers[offset >> 1]
end

function GameBoyAdvanceIO:store8(offset, value)
    offset = offset & 0xffffffff
    -- Specific 8-bit writes
    if offset == self.WININ or offset == (self.WININ | 1) or
       offset == self.WINOUT or offset == (self.WINOUT | 1) then
           -- value & 0x3f (Seems to just be a no-op read in the original JS?)
           -- The original JS has `this.value & 0x3f;` which does nothing.
           -- Proceeding to break.
    elseif offset == self.HALTCNT then
        value = value & 0x80
        if value == 0 then
            self.core.irq:halt()
        else
            self.core:STUB("Stop")
        end
        return
    elseif (offset & 0xfffe) == self.SOUNDBIAS then -- SOUNDBIAS | 1
        -- Original JS does: case self.SOUNDBIAS | 1: self.STUB_REG(...)
        if (offset & 1) == 1 then
             self:STUB_REG("sound", offset)
             return -- Assuming stub implies we stop here? JS breaks, then writes to store16.
        end
    end
    -- Fallthrough behavior from JS switch for Sound/IF/IME
    
    -- Generic RMW (Read-Modify-Write)
    if (offset & 1) == 1 then
        value = (value << 8)
        value = value | (self.registers[offset >> 1] & 0x00ff)
    else
        value = value & 0x00ff
        value = value | (self.registers[offset >> 1] & 0xff00)
    end
    self:store16(offset & 0xfffffffe, value)
end

function GameBoyAdvanceIO:store16(offset, value)
    --print(string.format("store16 %x %x", offset, value))
    local handler = self.writeHandlers[offset]
    if handler then
        local result = handler(value)
        if result == true then
            return -- Handler signaled it finished everything
        elseif result ~= nil then
            value = result -- Handler updated/masked the value
        end
        -- If result is nil (or just updated value), continue to write to memory
    else
        -- Default stub for unknown registers not in map?
        -- The JS code uses default: STUB_REG("I/O", offset)
        -- But we only want to stub if it's truly not handled.
        -- We can assume if it's not in the map, it's either generic or unmapped.
        -- However, JS explicitly cases almost everything.
        -- Since we populated the map with supported registers, if we are here, it's unsupported.
        -- Check if it is a valid index first?
        if not self.registers[offset >> 1] then
             -- Not strict error, but might be useful to stub
             self:STUB_REG("I/O", offset)
             -- We still write to register in JS 'default' case usually? 
             -- Actually JS default case breaks, then writes at the end.
        end
    end

    self.registers[offset >> 1] = value
end

function GameBoyAdvanceIO:store32(offset, value)
    -- 32-bit specific overrides
    if offset == self.BG2X_LO then
        value = value & 0x0fffffff
        self.video.renderPath:writeBackgroundRefX(2, value)
    elseif offset == self.BG2Y_LO then
        value = value & 0x0fffffff
        self.video.renderPath:writeBackgroundRefY(2, value)
    elseif offset == self.BG3X_LO then
        value = value & 0x0fffffff
        self.video.renderPath:writeBackgroundRefX(3, value)
    elseif offset == self.BG3Y_LO then
        value = value & 0x0fffffff
        self.video.renderPath:writeBackgroundRefY(3, value)
    elseif offset == self.DMA0SAD_LO then
        self.cpu.irq:dmaSetSourceAddress(0, value)
    elseif offset == self.DMA0DAD_LO then
        self.cpu.irq:dmaSetDestAddress(0, value)
    elseif offset == self.DMA1SAD_LO then
        self.cpu.irq:dmaSetSourceAddress(1, value)
    elseif offset == self.DMA1DAD_LO then
        self.cpu.irq:dmaSetDestAddress(1, value)
    elseif offset == self.DMA2SAD_LO then
        self.cpu.irq:dmaSetSourceAddress(2, value)
    elseif offset == self.DMA2DAD_LO then
        self.cpu.irq:dmaSetDestAddress(2, value)
    elseif offset == self.DMA3SAD_LO then
        self.cpu.irq:dmaSetSourceAddress(3, value)
    elseif offset == self.DMA3DAD_LO then
        self.cpu.irq:dmaSetDestAddress(3, value)
    elseif offset == self.FIFO_A_LO then
        --blockself.audio:appendToFifoA(value)
        return
    elseif offset == self.FIFO_B_LO then
        --blockself.audio:appendToFifoB(value)
        return
    elseif offset == self.IME then
        self:store16(offset, value & 0xffff)
        return
    elseif offset == self.JOY_RECV or offset == self.JOY_TRANS then
        self:STUB_REG("JOY", offset)
        return
    else
        -- Default split 32-bit write
        self:store16(offset, value & 0xffff)
        self:store16(offset | 2, value >> 16)
        return
    end

    self.registers[offset >> 1] = value & 0xffff
    self.registers[(offset >> 1) + 1] = value >> 16
end

function GameBoyAdvanceIO:invalidatePage(address)
    -- Empty
end

function GameBoyAdvanceIO:STUB_REG(type, offset)
    self.core:STUB("Unimplemented " .. type .. " register write: " .. string.format("%x", offset))
end

return GameBoyAdvanceIO