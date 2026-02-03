local ClassUtils = require("ClassUtils")
local ARMCoreThumb = ClassUtils.class("ARMCoreThumb")

local WB_32_MASK = 0xffffffff

function ARMCoreThumb:ctor(cpu)
    self.cpu = cpu
end

function ARMCoreThumb:constructADC(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[memory >> self.BASE_OFFSET];
        local m = (gprs[rm] & WB_32_MASK) + (cpu.cpsrC and 1 or 0)
        local oldD = gprs[rd]
        local d = (oldD & WB_32_MASK) + m
        
        local oldDn = (oldD & WB_32_MASK) >> 31
        local dn = (d & WB_32_MASK) >> 31
        local mn = (m & WB_32_MASK) >> 31
        
        cpu.cpsrN = dn ~= 0
        cpu.cpsrZ = (d & WB_32_MASK) == 0
        cpu.cpsrC = d > 0xffffffff
        cpu.cpsrV = (oldDn == mn) and (oldDn ~= dn) and (mn ~= dn)
        
        gprs[rd] = d & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = (gprs[rn] & WB_32_MASK) + immediate
        
        cpu.cpsrN = (d & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (d & WB_32_MASK) == 0
        cpu.cpsrC = d > 0xffffffff
        -- JS Logic: !(gprs[rn] >> 31) && ((gprs[rn] >> 31) ^ d) >> 31 && d >> 31
        -- Checks for Positive + Positive = Negative overflow
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local dSign = (d & WB_32_MASK) >> 31
        cpu.cpsrV = (rnSign == 0) and ((rnSign ~ dSign) ~= 0) and (dSign ~= 0)
        
        gprs[rd] = d & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD2(rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = (gprs[rn] & WB_32_MASK) + immediate
        
        cpu.cpsrN = (d & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (d & WB_32_MASK) == 0
        cpu.cpsrC = d > 0xffffffff
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local dSign = (d & WB_32_MASK) >> 31
        local immSign = (immediate & WB_32_MASK) >> 31
        
        cpu.cpsrV = (rnSign == 0) and ((rnSign ~ dSign) ~= 0) and ((immSign ~ dSign) ~= 0)
        
        gprs[rn] = d & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD3(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = (gprs[rn] & WB_32_MASK) + (gprs[rm] & WB_32_MASK)
        
        cpu.cpsrN = (d & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (d & WB_32_MASK) == 0
        cpu.cpsrC = d > 0xffffffff
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local rmSign = (gprs[rm] & WB_32_MASK) >> 31
        local dSign = (d & WB_32_MASK) >> 31
        
        cpu.cpsrV = ((rnSign ~ rmSign) == 0) and ((rnSign ~ dSign) ~= 0) and ((rmSign ~ dSign) ~= 0)
        
        gprs[rd] = d & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD4(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = (gprs[rd] + gprs[rm]) & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD5(rd, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = (gprs[15] & 0xfffffffc) + immediate
    end
end

function ARMCoreThumb:constructADD6(rd, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = (gprs[cpu.SP] + immediate) & WB_32_MASK
    end
end

function ARMCoreThumb:constructADD7(immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[cpu.SP] = (gprs[cpu.SP] + immediate) & WB_32_MASK
    end
end

function ARMCoreThumb:constructAND(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = gprs[rd] & gprs[rm]
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructASR1(rd, rm, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        if immediate == 0 then
            cpu.cpsrC = ((gprs[rm] & WB_32_MASK) >> 31) ~= 0
            if cpu.cpsrC then
                gprs[rd] = 0xffffffff
            else
                gprs[rd] = 0
            end
        else
            cpu.cpsrC = (gprs[rm] & (1 << (immediate - 1))) ~= 0
            -- Arithmetic shift
            local sign = gprs[rm] >> 31;
            local prefill = 0
            if sign ~= 0 then
                prefill = 0xffffffff << (32 - immediate);
            end 
            gprs[rd] = (gprs[rm] >> immediate | prefill) &WB_32_MASK
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructASR2(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local rs = gprs[rm] & 0xff
        if rs ~= 0 then
            if rs < 32 then
                cpu.cpsrC = (gprs[rd] & (1 << (rs - 1))) ~= 0
                local sign = gprs[rd] >> 31;
                local prefill = 0
                if sign ~= 0 then
                    prefill = 0xffffffff << (32 - rs);
                end  
                gprs[rd] = (gprs[rd] >> rs | prefill) & WB_32_MASK 
            else
                cpu.cpsrC = ((gprs[rd] & WB_32_MASK) >> 31) ~= 0
                if cpu.cpsrC then
                    gprs[rd] = 0xffffffff
                else
                    gprs[rd] = 0
                end
            end
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructB1(immediate, condOp)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        if condOp() then
            gprs[15] = gprs[15] + immediate
        end
    end
end

function ARMCoreThumb:constructB2(immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[15] = gprs[15] + immediate
    end
end

function ARMCoreThumb:constructBIC(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = gprs[rd] & (~gprs[rm])
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructBL1(immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[cpu.LR] = gprs[15] + immediate
    end
end

function ARMCoreThumb:constructBL2(immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local pc = gprs[15]
        gprs[15] = gprs[cpu.LR] + (immediate << 1)
        gprs[cpu.LR] = pc - 1 -- -1 effectively sets bit 0 to 1 for Thumb return
    end
end

function ARMCoreThumb:constructBX(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        cpu:switchExecMode(gprs[rm] & 0x00000001 ~= 0)
        local misalign = 0
        if rm == 15 then
            misalign = gprs[rm] & 0x00000002
        end
        gprs[15] = gprs[rm] & (0xfffffffe - misalign)
    end
end

function ARMCoreThumb:constructCMN(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local aluOut = (gprs[rd] & WB_32_MASK) + (gprs[rm] & WB_32_MASK)
        local aluOut32 = aluOut & WB_32_MASK
        
        cpu.cpsrN = (aluOut32 >> 31) ~= 0
        cpu.cpsrZ = aluOut32 == 0
        cpu.cpsrC = aluOut > 0xffffffff
        
        local rdSign = (gprs[rd] & WB_32_MASK) >> 31
        local rmSign = (gprs[rm] & WB_32_MASK) >> 31
        local outSign = aluOut32 >> 31
        
        cpu.cpsrV = (rdSign == rmSign) and (rdSign ~= outSign) and (rmSign ~= outSign)
    end
end

function ARMCoreThumb:constructCMP1(rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local aluOut = gprs[rn] - immediate
        local aluOut32 = aluOut & WB_32_MASK
        
        cpu.cpsrN = (aluOut32 >> 31) ~= 0
        cpu.cpsrZ = aluOut32 == 0
        cpu.cpsrC = (gprs[rn] & WB_32_MASK) >= immediate
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local outSign = aluOut32 >> 31
        cpu.cpsrV = (rnSign ~= 0) and ((rnSign ~ outSign) ~= 0)
    end
end

function ARMCoreThumb:constructCMP2(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = gprs[rd]
        local m = gprs[rm]
        local aluOut = d - m
        
        local an = (aluOut & WB_32_MASK) >> 31
        local dn = (d & WB_32_MASK) >> 31
        local mn = (m & WB_32_MASK) >> 31
        
        cpu.cpsrN = an ~= 0
        cpu.cpsrZ = (aluOut & WB_32_MASK) == 0
        cpu.cpsrC = (d & WB_32_MASK) >= (m & WB_32_MASK)
        cpu.cpsrV = (dn ~= mn) and (dn ~= an)
    end
end

function ARMCoreThumb:constructCMP3(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local aluOut = gprs[rd] - gprs[rm]
        local aluOut32 = aluOut & WB_32_MASK
        
        cpu.cpsrN = (aluOut32 >> 31) ~= 0
        cpu.cpsrZ = aluOut32 == 0
        cpu.cpsrC = (gprs[rd] & WB_32_MASK) >= (gprs[rm] & WB_32_MASK)
        
        local rdSign = (gprs[rd] & WB_32_MASK) >> 31
        local rmSign = (gprs[rm] & WB_32_MASK) >> 31
        local outSign = aluOut32 >> 31
        
        cpu.cpsrV = ((rdSign ~ rmSign) ~= 0) and ((rdSign ~ outSign) ~= 0)
    end
end

function ARMCoreThumb:constructEOR(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = gprs[rd] ~ gprs[rm]
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructLDMIA(rn, rs)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local address = gprs[rn]
        local total = 0
        local m = 1
        for i = 0, 7 do
            if (rs & m) ~= 0 then
                gprs[i] = cpu.mmu:load32(address)
                address = address + 4
                total = total + 1
            end
            m = m << 1
        end
        cpu.mmu:waitMulti32(address, total)
        if (rs & (1 << rn)) == 0 then
            gprs[rn] = address
        end
    end
end

function ARMCoreThumb:constructLDR1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local n = gprs[rn] + immediate
        gprs[rd] = cpu.mmu:load32(n)
        cpu.mmu:wait32(n)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDR2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[rn] + gprs[rm]
        gprs[rd] = cpu.mmu:load32(addr)
        cpu.mmu:wait32(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDR3(rd, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = (gprs[15] & 0xfffffffc) + immediate
        gprs[rd] = cpu.mmu:load32(addr)
        cpu.mmu:wait32(gprs[15])
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDR4(rd, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[cpu.SP] + immediate
        gprs[rd] = cpu.mmu:load32(addr)
        cpu.mmu:wait32(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRB1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local n = gprs[rn] + immediate
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = cpu.mmu:loadU8(n)
        cpu.mmu:wait(n)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRB2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[rn] + gprs[rm]
        gprs[rd] = cpu.mmu:loadU8(addr)
        cpu.mmu:wait(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRH1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local n = gprs[rn] + immediate
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = cpu.mmu:loadU16(n)
        cpu.mmu:wait(n)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRH2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[rn] + gprs[rm]
        gprs[rd] = cpu.mmu:loadU16(addr)
        cpu.mmu:wait(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRSB(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[rn] + gprs[rm]
        --print(string.format("addr %x",addr))
        gprs[rd] = cpu.mmu:load8(addr)
        cpu.mmu:wait(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLDRSH(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local addr = gprs[rn] + gprs[rm]
        gprs[rd] = cpu.mmu:load16(addr)
        cpu.mmu:wait(addr)
        cpu.cycles = cpu.cycles + 1
    end
end

function ARMCoreThumb:constructLSL1(rd, rm, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        if immediate == 0 then
            gprs[rd] = gprs[rm]
        else
            cpu.cpsrC = (gprs[rm] & (1 << (32 - immediate))) ~= 0
            gprs[rd] = gprs[rm] << immediate
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructLSL2(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local rs = gprs[rm] & 0xff
        if rs ~= 0 then
            if rs < 32 then
                cpu.cpsrC = (gprs[rd] & (1 << (32 - rs))) ~= 0
                gprs[rd] = gprs[rd] << rs
            else
                if rs > 32 then
                    cpu.cpsrC = false
                else
                    cpu.cpsrC = (gprs[rd] & 1) ~= 0
                end
                gprs[rd] = 0
            end
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructLSR1(rd, rm, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        if immediate == 0 then
            cpu.cpsrC = ((gprs[rm] & WB_32_MASK) >> 31) ~= 0
            gprs[rd] = 0
        else
            cpu.cpsrC = (gprs[rm] & (1 << (immediate - 1))) ~= 0
            -- Logical shift right (zero fill)
            gprs[rd] = (gprs[rm] & WB_32_MASK) >> immediate
        end
        cpu.cpsrN = false
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructLSR2(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local rs = gprs[rm] & 0xff
        if rs ~= 0 then
            if rs < 32 then
                cpu.cpsrC = (gprs[rd] & (1 << (rs - 1))) ~= 0
                gprs[rd] = (gprs[rd] & WB_32_MASK) >> rs
            else
                if rs > 32 then
                    cpu.cpsrC = false
                else
                    cpu.cpsrC = ((gprs[rd] & WB_32_MASK) >> 31) ~= 0
                end
                gprs[rd] = 0
            end
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructMOV1(rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rn] = immediate
        cpu.cpsrN = (immediate & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (immediate & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructMOV2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = gprs[rn]
        cpu.cpsrN = (d & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (d & WB_32_MASK) == 0
        cpu.cpsrC = false
        cpu.cpsrV = false
        gprs[rd] = d
    end
end

function ARMCoreThumb:constructMOV3(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = gprs[rm]
    end
end

function ARMCoreThumb:constructMUL(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        cpu.mmu:waitMul(gprs[rm])
        
        -- Lua handles 64-bit integers naturally.
        -- If upper bits are used logic similar to the C/JS impl is needed
        -- but simply gprs[rd] * gprs[rm] works for the low 32 bits.
        if (gprs[rm] & 0xffff0000) ~= 0 and (gprs[rd] & 0xffff0000) ~= 0 then
            -- Manual 32-bit multiplication to be safe regarding overflows/sign
            local hi = ((gprs[rd] & 0xffff0000) * gprs[rm]) & 0xffffffff
            local lo = ((gprs[rd] & 0x0000ffff) * gprs[rm]) & 0xffffffff
            gprs[rd] = (hi + lo) & WB_32_MASK
        else
            gprs[rd] = (gprs[rd] * gprs[rm]) & WB_32_MASK
        end
        
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructMVN(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = (~gprs[rm]) & WB_32_MASK
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructNEG(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = -gprs[rm]
        local d32 = d & WB_32_MASK
        
        cpu.cpsrN = (d32 >> 31) ~= 0
        cpu.cpsrZ = d32 == 0
        cpu.cpsrC = 0 >= (d32) -- Logic: 0 - Rm, borrow if 0 < Rm
        -- Borrow in Sub is NOT Carry. 
        -- Standard ARM for NEG (RSB Rd, Rm, #0) -> C is set if no borrow (0 >= Rm).
        cpu.cpsrC = 0 >= (gprs[rm] & WB_32_MASK)
        
        local rmSign = (gprs[rm] & WB_32_MASK) >> 31
        local dSign = d32 >> 31
        cpu.cpsrV = (rmSign ~= 0) and (dSign ~= 0) -- 0x80000000 check essentially
        
        gprs[rd] = d32
    end
end

function ARMCoreThumb:constructORR(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        gprs[rd] = gprs[rd] | gprs[rm]
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructPOP(rs, r)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        cpu.cycles = cpu.cycles + 1
        local address = gprs[cpu.SP]
        local total = 0
        local m = 1
        for i = 0, 7 do
            if (rs & m) ~= 0 then
                cpu.mmu:waitSeq32(address)
                gprs[i] = cpu.mmu:load32(address)
                address = address + 4
                total = total + 1
            end
            m = m << 1
        end
        if r ~= 0 then
            gprs[15] = cpu.mmu:load32(address) & 0xfffffffe
            address = address + 4
            total = total + 1
        end
        cpu.mmu:waitMulti32(address, total)
        gprs[cpu.SP] = address
    end
end

function ARMCoreThumb:constructPUSH(rs, r)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local address = gprs[cpu.SP] - 4
        local total = 0
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        if r ~= 0 then
            cpu.mmu:store32(address, gprs[cpu.LR])
            address = address - 4
            total = total + 1
        end
        
        -- High registers downwards
        local m = 0x80
        local i = 7
        while m ~= 0 do
            if (rs & m) ~= 0 then
                cpu.mmu:store32(address, gprs[i])
                address = address - 4
                total = total + 1
                break -- Optimization in JS source?
            end
            m = m >> 1
            i = i - 1
        end
        
        -- Continue loop
        m = m >> 1
        i = i - 1
        while m ~= 0 do
             if (rs & m) ~= 0 then
                cpu.mmu:store32(address, gprs[i])
                address = address - 4
                total = total + 1
            end
            m = m >> 1
            i = i - 1
        end
        
        cpu.mmu:waitMulti32(address, total)
        gprs[cpu.SP] = address + 4
    end
end

function ARMCoreThumb:constructROR(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local rs = gprs[rm] & 0xff
        if rs ~= 0 then
            local r4 = rs & 0x1f
            if r4 > 0 then
                cpu.cpsrC = (gprs[rd] & (1 << (r4 - 1))) ~= 0
                -- ROR
                gprs[rd] = (((gprs[rd] & WB_32_MASK) >> r4) | ((gprs[rd] & WB_32_MASK) << (32 - r4)))&WB_32_MASK
            else
                cpu.cpsrC = ((gprs[rd] & WB_32_MASK) >> 31) ~= 0
            end
        end
        cpu.cpsrN = (gprs[rd] & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & WB_32_MASK) == 0
    end
end

function ARMCoreThumb:constructSBC(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local m = (gprs[rm] & WB_32_MASK) + (not cpu.cpsrC and 1 or 0)
        local d = (gprs[rd] & WB_32_MASK) - m
        local d32 = d & WB_32_MASK
        
        cpu.cpsrN = (d32 >> 31) ~= 0
        cpu.cpsrZ = d32 == 0
        cpu.cpsrC = (gprs[rd] & WB_32_MASK) >= (m & WB_32_MASK) -- This check logic mimics JS behavior but standard ARM is >= m
        -- JS logic: gprs[rd] >>> 0 >= d >>> 0. If borrow occurred, d (u32) will be large.
        
        local rdSign = (gprs[rd] & WB_32_MASK) >> 31
        local mSign = (m & WB_32_MASK) >> 31
        local dSign = d32 >> 31
        
        cpu.cpsrV = ((rdSign ~ mSign) ~= 0) and ((rdSign ~ dSign) ~= 0)
        
        gprs[rd] = d32
    end
end

function ARMCoreThumb:constructSTMIA(rn, rs)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.mmu:wait(gprs[15])
        local address = gprs[rn]
        local total = 0
        local m = 1
        local i = 0
        
        -- Logic split to handle wait states optimization if needed, 
        -- but essentially loops 0-7
        while i < 8 do
            if (rs & m) ~= 0 then
                cpu.mmu:store32(address, gprs[i])
                address = address + 4
                total = total + 1
            end
            m = m << 1
            i = i + 1
        end
        
        cpu.mmu:waitMulti32(address, total)
        gprs[rn] = address
    end
end

function ARMCoreThumb:constructSTR1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local n = gprs[rn] + immediate
        cpu.mmu:store32(n, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait32(n)
    end
end

function ARMCoreThumb:constructSTR2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local addr = gprs[rn] + gprs[rm]
        cpu.mmu:store32(addr, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait32(addr)
    end
end

function ARMCoreThumb:constructSTR3(rd, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local addr = gprs[cpu.SP] + immediate
        cpu.mmu:store32(addr, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait32(addr)
    end
end

function ARMCoreThumb:constructSTRB1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local n = gprs[rn] + immediate
        cpu.mmu:store8(n, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait(n)
    end
end

function ARMCoreThumb:constructSTRB2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local addr = gprs[rn] + gprs[rm]
        cpu.mmu:store8(addr, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait(addr)
    end
end

function ARMCoreThumb:constructSTRH1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local n = gprs[rn] + immediate
        cpu.mmu:store16(n, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait(n)
    end
end

function ARMCoreThumb:constructSTRH2(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        local addr = gprs[rn] + gprs[rm]
        cpu.mmu:store16(addr, gprs[rd])
        cpu.mmu:wait(gprs[15])
        cpu.mmu:wait(addr)
    end
end

function ARMCoreThumb:constructSUB1(rd, rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = gprs[rn] - immediate
        local d32 = d & WB_32_MASK
        
        cpu.cpsrN = (d32 >> 31) ~= 0
        cpu.cpsrZ = d32 == 0
        cpu.cpsrC = (gprs[rn] & WB_32_MASK) >= immediate
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local dSign = d32 >> 31
        cpu.cpsrV = (rnSign ~= 0) and ((rnSign ~ dSign) ~= 0)
        
        gprs[rd] = d32
    end
end

function ARMCoreThumb:constructSUB2(rn, immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = gprs[rn] - immediate
        local d32 = d & WB_32_MASK
        
        cpu.cpsrN = (d32 >> 31) ~= 0
        cpu.cpsrZ = d32 == 0
        cpu.cpsrC = (gprs[rn] & WB_32_MASK) >= immediate
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local dSign = d32 >> 31
        cpu.cpsrV = (rnSign ~= 0) and ((rnSign ~ dSign) ~= 0)
        
        gprs[rn] = d32
    end
end

function ARMCoreThumb:constructSUB3(rd, rn, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local d = gprs[rn] - gprs[rm]
        local d32 = d & WB_32_MASK
        
        cpu.cpsrN = (d32 >> 31) ~= 0
        cpu.cpsrZ = d32 == 0
        cpu.cpsrC = (gprs[rn] & WB_32_MASK) >= (gprs[rm] & WB_32_MASK)
        
        local rnSign = (gprs[rn] & WB_32_MASK) >> 31
        local rmSign = (gprs[rm] & WB_32_MASK) >> 31
        local dSign = d32 >> 31
        
        cpu.cpsrV = (rnSign ~= rmSign) and (rnSign ~= dSign)
        
        gprs[rd] = d32
    end
end

function ARMCoreThumb:constructSWI(immediate)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.irq:swi(immediate)
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
    end
end

function ARMCoreThumb:constructTST(rd, rm)
    local cpu = self.cpu
    local mmu = cpu.mmu;
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32;
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1 + waitstatesPrefetch32[gprs[15] >> 24];
        local aluOut = gprs[rd] & gprs[rm]
        cpu.cpsrN = (aluOut & WB_32_MASK) >> 31 ~= 0
        cpu.cpsrZ = (aluOut & WB_32_MASK) == 0
    end
end

return ARMCoreThumb