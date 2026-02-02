local ClassUtils = require("ClassUtils")
local ARMCoreArm = ClassUtils.class("ARMCoreArm")

local NOMAP = -1
local WB_32_MASK= 0xffffffff
function ARMCoreArm:ctor(cpu)
    self.cpu = cpu;
    self.addressingMode23Immediate = {
    [0] = function(rn, offset, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        gprs[rn] = (gprs[rn] - offset)&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, offset, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        gprs[rn] = (gprs[rn] + offset)&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, offset, condOp)
            local gprs = cpu.gprs
            local addr
            local address = setmetatable(
                {},
                {__call = function()
                    addr = gprs[rn] - offset
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, offset, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = (gprs[rn] - offset)&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        function(rn, offset, condOp)
            local gprs = cpu.gprs
            local addr
            local address = setmetatable(
                {},
                {__call = function()
                    addr = gprs[rn] + offset
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, offset, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = (gprs[rn] + offset)&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP
    }
    self.addressingMode23Register = {
    [0] =function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        gprs[rn] = (gprs[rn] - gprs[rm])&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        gprs[rn] = (gprs[rn] + gprs[rm])&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    return (gprs[rn] - gprs[rm])&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = (gprs[rn] - gprs[rm])&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn] + gprs[rm]
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, rm, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = (gprs[rn] + gprs[rm])&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP
    }
    self.addressingMode2RegisterShifted = {
    [0] = function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        shiftOp()
                        gprs[rn] = (gprs[rn] - cpu.shifterOperand)&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    local addr = gprs[rn]
                    if not condOp or condOp() then
                        shiftOp()
                        gprs[rn] = (gprs[rn] + cpu.shifterOperand)&WB_32_MASK
                    end
                    return addr&WB_32_MASK
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        NOMAP,
        function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    shiftOp()
                    return (gprs[rn] - cpu.shifterOperand)&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    shiftOp()
                    local addr = (gprs[rn] - cpu.shifterOperand)&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writesPC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP,
        function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    shiftOp()
                    return (gprs[rn] + cpu.shifterOperand)&WB_32_MASK
                end}
            )
            address.writesPC = false
            return address
        end,
        function(rn, shiftOp, condOp)
            local gprs = cpu.gprs
            local address = setmetatable(
                {},
                {__call = function()
                    shiftOp()
                    local addr = (gprs[rn] + cpu.shifterOperand)&WB_32_MASK
                    if not condOp or condOp() then
                        gprs[rn] = addr
                    end
                    return addr
                end}
            )
            address.writePC = rn == cpu.PC
            return address
        end,
        NOMAP,
        NOMAP
    }
end

function ARMCoreArm:constructAddressingMode1ASR(rs, rm)
    local cpu = self.cpu
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1
        local shift = gprs[rs]
        if rs == cpu.PC then
            shift = shift + 4
        end
        shift = shift & 255
        local shiftVal = gprs[rm]
        if rm == cpu.PC then
            shiftVal = shiftVal + 4
        end
        if shift == 0 then
            cpu.shifterOperand = shiftVal
            cpu.shifterCarryOut = cpu.cpsrC;
        elseif shift < 32 then
            local sign = shiftVal >> 31;
            local prefill = 0
            if sign ~= 0 then
                prefill = 0xffffffff << (32 - shift);
            end 
            cpu.shifterOperand = (shiftVal >> shift | prefill)&WB_32_MASK
            cpu.shifterCarryOut = (shiftVal & (1 << (shift - 1))) ~= 0;
        elseif gprs[rm] >> 31 ~= 0 then
            cpu.shifterOperand = 0xffffffff;
            cpu.shifterCarryOut = true;
        else
            cpu.shifterOperand = 0
            cpu.shifterCarryOut = false;
        end
    end
end


function ARMCoreArm:constructAddressingMode1Immediate(immediate)
    local cpu = self.cpu
    return function()
        cpu.shifterOperand = immediate
        cpu.shifterCarryOut = cpu.cpsrC
    end
end

function ARMCoreArm:constructAddressingMode1ImmediateRotate(immediate, rotate)
    local cpu = self.cpu
    return function()
        cpu.shifterOperand =
            ((immediate >> rotate) | (immediate << (32 - rotate)))&WB_32_MASK
        cpu.shifterCarryOut = cpu.shifterOperand >> 31 ~= 0;
    end
end


function ARMCoreArm:constructAddressingMode1LSL(rs, rm)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.cycles = cpu.cycles + 1;
        local shift = gprs[rs];
        if rs == cpu.PC then
            shift = shift + 4
        end
        shift = shift & 255
        local shiftVal = gprs[rm];
        if rm == cpu.PC then
            shiftVal = shiftVal + 4
        end
        if shift == 0 then
            cpu.shifterOperand = shiftVal;
            cpu.shifterCarryOut = cpu.cpsrC;
        elseif shift < 32 then
            cpu.shifterOperand = (shiftVal << shift)&WB_32_MASK;
            cpu.shifterCarryOut = (shiftVal & (1 << (32 - shift)))~=0;
        elseif shift == 32 then
            cpu.shifterOperand = 0;
            cpu.shifterCarryOut = (shiftVal & 1) ~= 0;
        else 
            cpu.shifterOperand = 0;
            cpu.shifterCarryOut = false;
        end
    end
end

function ARMCoreArm:constructAddressingMode1LSR(rs, rm)
    local cpu = self.cpu
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1
        local shift = gprs[rs]
        if rs == cpu.PC then
            shift = shift + 4
        end
        shift = shift & 255
        local shiftVal = gprs[rm]
        if rm == cpu.PC then
            shiftVal = shiftVal + 4
        end
        if shift == 0 then
            cpu.shifterOperand = shiftVal
            cpu.shifterCarryOut = cpu.cpsrC
        elseif shift < 32 then
            cpu.shifterOperand = (shiftVal >> shift)&WB_32_MASK
            cpu.shifterCarryOut = (shiftVal & (1 << (shift - 1))) ~= 0;
        elseif shift == 32 then
            cpu.shifterOperand = 0
            cpu.shifterCarryOut = (shiftVal >> 31) ~= 0;
        else
            cpu.shifterOperand = 0
            cpu.shifterCarryOut = false;
        end
    end
end

function ARMCoreArm:constructAddressingMode1ROR(rs, rm)
    local cpu = self.cpu
    local gprs = cpu.gprs
    return function()
        cpu.cycles = cpu.cycles + 1
        local shift = gprs[rs]
        if rs == cpu.PC then
            shift = shift + 4
        end
        shift = shift & 255
        local shiftVal = gprs[rm]
        if rm == cpu.PC then
            shiftVal = shiftVal + 4
        end
        local rotate = shift & 31
        if shift == 0 then
            cpu.shifterOperand = shiftVal
            cpu.shifterCarryOut = cpu.cpsrC
        elseif rotate~=0 then
            cpu.shifterOperand = (gprs[rm] >> rotate | gprs[rm] << 32 - rotate)&WB_32_MASK
            cpu.shifterCarryOut = (shiftVal & (1 << (rotate - 1))) ~= 0;
        else
            cpu.shifterOperand = shiftVal
            cpu.shifterCarryOut = (shiftVal >> 31) ~= 0;
        end
    end
end

function ARMCoreArm:constructAddressingMode23Immediate(instruction, immediate, condOp)
    local rn = (instruction & 0x000f0000) >> 16;
    return self.addressingMode23Immediate[(instruction & 0x01a00000) >> 21](
        rn,
        immediate,
        condOp
    );
end
function ARMCoreArm:constructAddressingMode23Register(instruction, rm, condOp)
    local rn = (instruction & 0x000f0000) >> 16;
    return self.addressingMode23Register[(instruction & 0x01a00000) >> 21](
        rn,
        rm,
        condOp
    );
end
function ARMCoreArm:constructAddressingMode2RegisterShifted(instruction, shiftOp, condOp)
    local rn = (instruction & 0x000f0000) >> 16;
    return self.addressingMode2RegisterShifted[
        (instruction & 0x01a00000) >> 21
    ](rn, shiftOp, condOp);
end
function ARMCoreArm:constructAddressingMode4(immediate, rn) 
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        local addr = (gprs[rn] + immediate)&WB_32_MASK;
        return addr;
    end
end

function ARMCoreArm:constructAddressingMode4Writeback(immediate, offset, rn, overlap)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function (writeInitial)
        local addr = (gprs[rn] + immediate)&WB_32_MASK;
        if writeInitial and overlap then
            cpu.mmu:store32(gprs[rn] + immediate - 4, gprs[rn]);
        end
        gprs[rn] = (gprs[rn] + offset)&WB_32_MASK;
        return addr;
    end
end
function ARMCoreArm:constructADC(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local shifterOperand = cpu.shifterOperand + (cpu.cpsrC and 1 or 0);
        gprs[rd] = (gprs[rn] + shifterOperand) & WB_32_MASK;
    end
end

function ARMCoreArm:constructADCS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local shifterOperand = cpu.shifterOperand + (cpu.cpsrC and 1 or 0);
        local d = gprs[rn] + shifterOperand;
        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0;
            cpu.cpsrC = d > 0xffffffff;
            cpu.cpsrV =
                gprs[rn] >> 31 == shifterOperand >> 31 and
                gprs[rn] >> 31 ~= d32 >> 31 and
                shifterOperand >> 31 ~= d32 >> 31;
        end
        gprs[rd] = d32;
    end
end

function ARMCoreArm:constructADD(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (gprs[rn] + cpu.shifterOperand) & WB_32_MASK;
    end
end

function ARMCoreArm:constructADDS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local d = gprs[rn]  + cpu.shifterOperand;
        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0;
            cpu.cpsrC = d > 0xffffffff;
            cpu.cpsrV =
                gprs[rn] >> 31 == cpu.shifterOperand >> 31 and
                gprs[rn] >> 31 ~= d32 >> 31 and
                cpu.shifterOperand >> 31 ~= d32 >> 31;
        end
        gprs[rd] = d32;
    end
end
function ARMCoreArm:constructAND(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] & cpu.shifterOperand;
    end
end
function ARMCoreArm:constructANDS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] & cpu.shifterOperand;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0;
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end

function ARMCoreArm:constructB(immediate, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        gprs[cpu.PC] = gprs[cpu.PC] + immediate;
    end
end

function ARMCoreArm:constructBIC(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] & ~cpu.shifterOperand;
    end
end


function ARMCoreArm:constructBICS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] & ~cpu.shifterOperand;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end

function ARMCoreArm:constructBL(immediate, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        gprs[cpu.LR] = gprs[cpu.PC] - 4;
        gprs[cpu.PC] = gprs[cpu.PC] + immediate;
    end
end
function ARMCoreArm:constructBX(rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        cpu:switchExecMode(gprs[rm] & 0x00000001 ~= 0);
        gprs[cpu.PC] = gprs[rm] & 0xfffffffe;
    end
end
function ARMCoreArm:constructCMN(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local aluOut = (gprs[rn] & 0xffffffff) + (cpu.shifterOperand & 0xffffffff);
        local aluOut32 = aluOut & 0xffffffff;
        cpu.cpsrN = (aluOut32 >> 31)~=0;
        cpu.cpsrZ = aluOut32==0;
        cpu.cpsrC = aluOut > 0xffffffff;
        cpu.cpsrV =
            gprs[rn] >> 31 == cpu.shifterOperand >> 31 and 
            gprs[rn] >> 31 ~= aluOut32 >> 31 and
            cpu.shifterOperand >> 31 ~= aluOut32 >> 31;
    end
end
function ARMCoreArm:constructCMP(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local aluOut = gprs[rn] - cpu.shifterOperand;

        local aluOut32 = aluOut & 0xffffffff;

        cpu.cpsrN = (aluOut32 >> 31)~=0;
        cpu.cpsrZ = aluOut32==0;
        cpu.cpsrC = gprs[rn] >= cpu.shifterOperand&0xffffffff;
        cpu.cpsrV =
            gprs[rn] >> 31 ~= cpu.shifterOperand >> 31 and
            gprs[rn] >> 31 ~= aluOut32 >> 31;
    end
end
function ARMCoreArm:constructEOR(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (gprs[rn] ~ cpu.shifterOperand) & WB_32_MASK;
    end
end
function ARMCoreArm:constructEORS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (gprs[rn] ~ cpu.shifterOperand) & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end
function ARMCoreArm:constructLDM(rs, address, condOp)
    --据说没有PC处理
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    local mmu = cpu.mmu;
    return function ()
        mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address(false);
        local total = 0;
        local m=rs;
        local i=0;
        while m ~= 0 do
            if m & 1 ~= 0 then
                gprs[i] = mmu:load32(addr & 0xfffffffc);
                addr = addr + 4;
                total = total + 1;
            end
            m=m>>1;
            i= i+1;
        end
        mmu:waitMulti32(addr, total);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDMS(rs, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    local mmu = cpu.mmu;
    return function ()
        mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address(false);
        local total = 0;
        local mode = cpu.mode;
        cpu:switchMode(cpu.MODE_SYSTEM);
        local m=rs;
        local i=0;
        while m ~= 0 do
            if m & 1 ~= 0 then
                gprs[i] = mmu:load32(addr & 0xfffffffc);
                addr = addr + 4;
                total = total + 1;
            end
            m=m>>1;
            i=i+1;
        end
        cpu:switchMode(mode);
        mmu:waitMulti32(addr, total);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDR(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address();
        gprs[rd] = cpu.mmu:load32(addr);
        cpu.mmu:wait32(addr);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDRB(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address();
        gprs[rd] = cpu.mmu:loadU8(addr);
        cpu.mmu:wait(addr);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDRH(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address();
        gprs[rd] = cpu.mmu:loadU16(addr);
        cpu.mmu:wait(addr);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDRSB(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address();
        gprs[rd] = cpu.mmu:load8(addr);
        cpu.mmu:wait(addr);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructLDRSH(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        local addr = address();
        gprs[rd] = cpu.mmu:load16(addr);
        cpu.mmu:wait(addr);
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructMLA(rd, rn, rs, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        cpu.cycles=cpu.cycles+1;
        cpu.mmu:waitMul(rs);
        if gprs[rm] & 0xffff0000 ~= 0 and gprs[rs] & 0xffff0000 ~= 0 then
            --// Our data type is a double--we'll lose bits if we do it all at once!
            local hi = ((gprs[rm] & 0xffff0000) * gprs[rs]) & 0xffffffff;
            local lo = ((gprs[rm] & 0x0000ffff) * gprs[rs]) & 0xffffffff;
            gprs[rd] = (hi + lo + gprs[rn]) & 0xffffffff;
        else
            gprs[rd] = (gprs[rm] * gprs[rs] + gprs[rn])&WB_32_MASK;
        end
    end
end
function ARMCoreArm:constructMLAS(rd, rn, rs, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        cpu.cycles=cpu.cycles+1;
        cpu.mmu:waitMul(rs);
        if gprs[rm] & 0xffff0000 ~= 0 and gprs[rs] & 0xffff0000 ~= 0 then
            --// Our data type is a double--we'll lose bits if we do it all at once!
            local hi = ((gprs[rm] & 0xffff0000) * gprs[rs]) & 0xffffffff;
            local lo = ((gprs[rm] & 0x0000ffff) * gprs[rs]) & 0xffffffff;
            gprs[rd] = (hi + lo + gprs[rn]) & 0xffffffff;
        else
            gprs[rd] = (gprs[rm] * gprs[rs] + gprs[rn])&WB_32_MASK;
        end
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
    end
end
function ARMCoreArm:constructMOV(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = cpu.shifterOperand;
    end
end
function ARMCoreArm:constructMOVS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = cpu.shifterOperand;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end
function ARMCoreArm:constructMRS(rd, r, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        if r ~= 0 then
            gprs[rd] = cpu.spsr;
        else
            gprs[rd] = cpu:packCPSR();
        end 
    end
end
function ARMCoreArm:constructMSR(rm, r, instruction, immediate, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    local c = instruction & 0x00010000;
    --//local x = instruction & 0x00020000;
    --//local s = instruction & 0x00040000;
    local f = instruction & 0x00080000;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        --print(string.format("constructMSR: instruction=%X, rm=%X, r=%X, immediate=%X", instruction, rm, r, immediate))
        local operand;
        if (instruction & 0x02000000) ~= 0 then
            operand = immediate;
        else
            operand = gprs[rm];
        end

        local mask =
            (c~=0 and 0x000000ff or 0x00000000) |
            --(x and 0x0000FF00 or 0x00000000) | -- Irrelevant on ARMv4T
            --(s and 0x00FF0000 or 0x00000000) | -- Irrelevant on ARMv4T
            (f~=0 and 0xff000000 or 0x00000000);
      
        if r ~= 0 then
            mask = mask &( cpu.USER_MASK | cpu.PRIV_MASK | cpu.STATE_MASK);
            cpu.spsr = (cpu.spsr & ~mask) | (operand & mask) | 0x00000010; 
        else 
            if mask & cpu.USER_MASK ~= 0 then
                cpu.cpsrN = operand >> 31 ~= 0;
                cpu.cpsrZ = (operand & 0x40000000) ~= 0;
                cpu.cpsrC = (operand & 0x20000000) ~= 0;
                cpu.cpsrV = (operand & 0x10000000) ~= 0;
            end
            if cpu.mode ~= cpu.MODE_USER and (mask & cpu.PRIV_MASK) ~= 0 then 
                cpu:switchMode((operand & 0x0000000f) | 0x00000010);
                cpu.cpsrI = (operand & 0x00000080) ~= 0;
                cpu.cpsrF = (operand & 0x00000040) ~= 0; 
            end
        end
    end
end
function ARMCoreArm:constructMUL(rd, rs, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        --debugprint(string.format("rs:%d",gprs[rs]))
        cpu.mmu:waitMul(gprs[rs]);
        if gprs[rm] & 0xffff0000 ~= 0 and gprs[rs] & 0xffff0000 ~= 0 then
            --// Our data type is a double--we'll lose bits if we do it all at once!
            local hi = ((gprs[rm] & 0xffff0000) * gprs[rs]) & 0xffffffff;
            local lo = ((gprs[rm] & 0x0000ffff) * gprs[rs]) & 0xffffffff;
            gprs[rd] = (hi + lo) & WB_32_MASK;
        else
            gprs[rd] = (gprs[rm] * gprs[rs]) & WB_32_MASK;
        end
    end
end
function ARMCoreArm:constructMULS(rd, rs, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        cpu.mmu:waitMul(gprs[rs]);
        if gprs[rm] & 0xffff0000 ~= 0 and gprs[rs] & 0xffff0000 ~= 0 then
            --// Our data type is a double--we'll lose bits if we do it all at once!
            local hi = ((gprs[rm] & 0xffff0000) * gprs[rs]) & 0xffffffff;
            local lo = ((gprs[rm] & 0x0000ffff) * gprs[rs]) & 0xffffffff;
            gprs[rd] = (hi + lo) & WB_32_MASK;
        else
            gprs[rd] = (gprs[rm] * gprs[rs]) & WB_32_MASK;
        end
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
    end
end
function ARMCoreArm:constructMVN(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (~cpu.shifterOperand) & WB_32_MASK;
    end
end
function ARMCoreArm:constructMVNS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (~cpu.shifterOperand) & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end
function ARMCoreArm:constructORR(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] | cpu.shifterOperand;
    end
end
function ARMCoreArm:constructORRS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = gprs[rn] | cpu.shifterOperand;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = gprs[rd] >> 31 ~= 0
            cpu.cpsrZ = (gprs[rd] & 0xffffffff) == 0;
            cpu.cpsrC = cpu.shifterCarryOut;
        end
    end
end
function ARMCoreArm:constructRSB(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (cpu.shifterOperand - gprs[rn]) & WB_32_MASK;
    end
end
function ARMCoreArm:constructRSBS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local d = cpu.shifterOperand - gprs[rn];
        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0;
            cpu.cpsrC = cpu.shifterOperand >= gprs[rn];
            cpu.cpsrV =
                (cpu.shifterOperand >> 31 ~= gprs[rn] >> 31) and
                (cpu.shifterOperand >> 31 ~= d32 >> 31);
        end
        gprs[rd] = d32;
    end
end
function ARMCoreArm:constructRSC(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local n = gprs[rn] + (not cpu.cpsrC and 1 or 0);
        gprs[rd] = (cpu.shifterOperand - n) & WB_32_MASK;
    end
end
function ARMCoreArm:constructRSCS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local n = gprs[rn] + (not cpu.cpsrC and 1 or 0);
        local d = cpu.shifterOperand - n;
        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0;
            cpu.cpsrC = cpu.shifterOperand >= n;
            cpu.cpsrV =
                (cpu.shifterOperand >> 31 ~= n >> 31) and
                (cpu.shifterOperand >> 31 ~= d32 >> 31);
        end
        gprs[rd] = d32;
    end
end
function ARMCoreArm:constructSBC(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local shifterOperand = cpu.shifterOperand + (not cpu.cpsrC and 1 or 0);
        gprs[rd] = (gprs[rn] - shifterOperand) & WB_32_MASK;
    end
end
function ARMCoreArm:constructSBCS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();

        local shifterOperand = cpu.shifterOperand + ((not cpu.cpsrC) and 1 or 0);
        local d = gprs[rn] - shifterOperand;
        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0;
            cpu.cpsrC = gprs[rn] >= shifterOperand;
            cpu.cpsrV =
                (gprs[rn] >> 31 ~= shifterOperand >> 31) and
                (gprs[rn] >> 31 ~= d32 >> 31);
        end
        gprs[rd] = d32;
    end
end
function ARMCoreArm:constructSMLAL(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    -- Lua 5.4 不需要 SHIFT_32 这种浮点技巧，直接用位移即可
    
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        if condOp and not condOp() then
            return
        end
        
        cpu.cycles = cpu.cycles + 2
        -- 4. 模拟乘法等待周期
        cpu.mmu:waitMul(rs)
        
        -- 5. 获取操作数
        -- 假设 gprs 中存储的是无符号 32 位整数，我们需要将其视为有符号数进行乘法
        local val_m = gprs[rm]
        local val_s = gprs[rs]
        local val_n = gprs[rn] -- 低位累加数
        local val_d = gprs[rd] -- 高位累加数

        -- SMLAL 是有符号乘法，如果最高位(31位)是1，需手动转为 Lua 的 64 位负数
        if val_m >= 0x80000000 then val_m = val_m - 0x100000000 end
        if val_s >= 0x80000000 then val_s = val_s - 0x100000000 end

        -- 6. 计算乘积 (原生 64 位有符号乘法)
        local product = val_m * val_s

        local accum = (val_d << 32) | val_n
        -- 8. 执行累加
        local result = accum + product

        gprs[rn] = result & WB_32_MASK
        
        gprs[rd] = (result >> 32) & WB_32_MASK
    end
end
function ARMCoreArm:constructSMLALS(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    -- Lua 5.4 不需要 SHIFT_32 这种浮点技巧，直接用位移即可
    
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        if condOp and not condOp() then
            return
        end
        
        cpu.cycles = cpu.cycles + 2
        -- 4. 模拟乘法等待周期
        cpu.mmu:waitMul(rs)
        
        -- 5. 获取操作数
        -- 假设 gprs 中存储的是无符号 32 位整数，我们需要将其视为有符号数进行乘法
        local val_m = gprs[rm]
        local val_s = gprs[rs]
        local val_n = gprs[rn] -- 低位累加数
        local val_d = gprs[rd] -- 高位累加数

        -- SMLAL 是有符号乘法，如果最高位(31位)是1，需手动转为 Lua 的 64 位负数
        if val_m >= 0x80000000 then val_m = val_m - 0x100000000 end
        if val_s >= 0x80000000 then val_s = val_s - 0x100000000 end

        -- 6. 计算乘积 (原生 64 位有符号乘法)
        local product = val_m * val_s

        local accum = (val_d << 32) | val_n
        -- 8. 执行累加
        local result = accum + product

        gprs[rn] = result & WB_32_MASK
        
        gprs[rd] = (result >> 32) & WB_32_MASK
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff==0 and gprs[rn] & 0xffffffff==0);
    end
end

function ARMCoreArm:constructSMULL(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    return function ()
        -- 1. 等待预取
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end
        
        -- 3. 增加周期 (修复 ++ 语法)
        cpu.cycles = cpu.cycles + 1
        
        -- 4. 获取操作数 (保存为局部变量以优化访问)
        local val_m = gprs[rm]
        local val_s = gprs[rs]

        -- 5. 模拟乘法等待 (通常取决于 Rs 的值)
        cpu.mmu:waitMul(val_s)
        
        -- 6. 符号扩展 (Sign Extension) [关键步骤]
        -- 将 32位无符号数 转为 Lua 64位有符号数
        -- 如果 >= 0x80000000，说明是负数，减去 2^32 即可得到对应的负数值
        if val_m >= 0x80000000 then val_m = val_m - 0x100000000 end
        if val_s >= 0x80000000 then val_s = val_s - 0x100000000 end

        -- 7. 执行 64 位乘法
        local result = val_m * val_s

        -- 8. 拆分结果并写回寄存器
        -- 低 32 位 -> Rn (使用位与操作截断)
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd (右移 32 位后截断)
        -- 注意：Lua 的 >> 对有符号数是算术右移，但我们需要的是位数据，
        -- 所以 & 0xFFFFFFFF 能确保写入寄存器的是干净的 32 位无符号形式。
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
    end
end
function ARMCoreArm:constructSMULLS(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    return function ()
        -- 1. 等待预取
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end
        
        -- 3. 增加周期 (修复 ++ 语法)
        cpu.cycles = cpu.cycles + 1
        
        -- 4. 获取操作数 (保存为局部变量以优化访问)
        local val_m = gprs[rm]
        local val_s = gprs[rs]

        -- 5. 模拟乘法等待 (通常取决于 Rs 的值)
        cpu.mmu:waitMul(val_s)
        
        -- 6. 符号扩展 (Sign Extension) [关键步骤]
        -- 将 32位无符号数 转为 Lua 64位有符号数
        -- 如果 >= 0x80000000，说明是负数，减去 2^32 即可得到对应的负数值
        if val_m >= 0x80000000 then val_m = val_m - 0x100000000 end
        if val_s >= 0x80000000 then val_s = val_s - 0x100000000 end

        -- 7. 执行 64 位乘法
        local result = val_m * val_s

        -- 8. 拆分结果并写回寄存器
        -- 低 32 位 -> Rn (使用位与操作截断)
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd (右移 32 位后截断)
        -- 注意：Lua 的 >> 对有符号数是算术右移，但我们需要的是位数据，
        -- 所以 & 0xFFFFFFFF 能确保写入寄存器的是干净的 32 位无符号形式。
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff==0 and gprs[rn] & 0xffffffff==0);
    end
end

function ARMCoreArm:constructSTM(rs, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    local mmu = cpu.mmu;
    return function ()
        if condOp and not condOp() then
            mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        mmu:wait32(gprs[cpu.PC]);
        local addr = address(true);
       
        local total = 0;
        local m=rs;
        local i=0;
        while m~=0 do
            if m&1 ~= 0 then
                mmu:store32(addr, gprs[i]);
                addr = addr+4;
                total = total + 1;
            end
            m = m>>1;
            i=i+1;
        end
        addr = addr & WB_32_MASK
        mmu:waitMulti32(addr, total);
    end
end
function ARMCoreArm:constructSTMS(rs, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    local mmu = cpu.mmu;
    return function ()
        if condOp and not condOp() then
            mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        mmu:wait32(gprs[cpu.PC]);
        local mode = cpu.mode;
        local addr = address(true);
        local total = 0;
        local m=rs;
        local i=0;
        cpu:switchMode(cpu.MODE_SYSTEM);
        while m~=0 do
            if m&1 ~= 0 then
                mmu:store32(addr, gprs[i]);
                addr = addr+4;
                total = total + 1;
            end
            m=m>>1;
            i=i+1;
        end
        addr = addr & WB_32_MASK
        cpu:switchMode(mode);
        mmu:waitMulti32(addr, total);
    end
end
function ARMCoreArm:constructSTR(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        local addr = address();
        cpu.mmu:store32(addr, gprs[rd]);
        cpu.mmu:wait32(addr);
        cpu.mmu:wait32(gprs[cpu.PC]);
    end
end
function ARMCoreArm:constructSTRB(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        local addr = address();
        cpu.mmu:store8(addr, gprs[rd]);
        cpu.mmu:wait(addr);
        cpu.mmu:wait32(gprs[cpu.PC]);
    end
end
function ARMCoreArm:constructSTRH(rd, address, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        local addr = address();
        cpu.mmu:store16(addr, gprs[rd]);
        cpu.mmu:wait(addr);
        cpu.mmu:wait32(gprs[cpu.PC]);
    end
end
function ARMCoreArm:constructSUB(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        gprs[rd] = (gprs[rn] - cpu.shifterOperand)&WB_32_MASK;
    end
end
function ARMCoreArm:constructSUBS(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local d = gprs[rn] - cpu.shifterOperand;

        local d32 = d & WB_32_MASK;
        if rd == cpu.PC and cpu:hasSPSR() then
            cpu:unpackCPSR(cpu.spsr);
        else
            cpu.cpsrN = d32 >> 31 ~= 0;
            cpu.cpsrZ = d32 == 0 ;
            cpu.cpsrC = gprs[rn]  >= cpu.shifterOperand ;
            cpu.cpsrV = (gprs[rn] >> 31) ~= (cpu.shifterOperand >> 31) and
                    (gprs[rn] >> 31) ~= (d32 >> 31);
        end
        gprs[rd] = d32;
    end
end
function ARMCoreArm:constructSWI(immediate, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        if condOp and not condOp() then
            cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
            return;
        end
        cpu.irq:swi32(immediate);
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
    end
end
function ARMCoreArm:constructSWP(rd, rn, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        cpu.mmu:wait32(gprs[rn]);
        cpu.mmu:wait32(gprs[rn]);
        local d = cpu.mmu:load32(gprs[rn]);
        cpu.mmu:store32(gprs[rn], gprs[rm]);
        gprs[rd] = d;
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructSWPB(rd, rn, rm, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        cpu.mmu:wait(gprs[rn]);
        cpu.mmu:wait(gprs[rn]);
        local d = cpu.mmu:load8(gprs[rn]);
        cpu.mmu:store8(gprs[rn], gprs[rm]);
        gprs[rd] = d;
        cpu.cycles=cpu.cycles+1;
    end
end
function ARMCoreArm:constructTEQ(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local aluOut = gprs[rn] ~ cpu.shifterOperand;
        local aluOut32 = aluOut & WB_32_MASK;
        cpu.cpsrN = (aluOut32 >> 31)~=0;
        cpu.cpsrZ = aluOut32 == 0;
        cpu.cpsrC = cpu.shifterCarryOut;
    end
end
function ARMCoreArm:constructTST(rd, rn, shiftOp, condOp)
    local cpu = self.cpu;
    local gprs = cpu.gprs;
    return function ()
        cpu.mmu:waitPrefetch32(gprs[cpu.PC]);
        if condOp and not condOp() then
            return;
        end
        shiftOp();
        local aluOut = gprs[rn] & cpu.shifterOperand;
        local aluOut32 = aluOut & WB_32_MASK;
        cpu.cpsrN = (aluOut32 >> 31)~=0;
        cpu.cpsrZ = aluOut32 == 0;
        cpu.cpsrC = cpu.shifterCarryOut;
    end
end
function ARMCoreArm:constructUMLAL(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs

    return function ()
        -- 1. 等待预取指令
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])

        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end

        -- 3. 增加时钟周期 (修复 += 语法)
        cpu.cycles = cpu.cycles + 2

        -- 4. 获取操作数
        -- UMLAL 是无符号乘法，直接取值即可，无需处理符号位
        local val_m = gprs[rm]
        local val_s = gprs[rs]
        local val_n = gprs[rn] -- 低 32 位累加数
        local val_d = gprs[rd] -- 高 32 位累加数

        -- 5. 模拟乘法周期 (通常依赖于 Rs 的数值)
        cpu.mmu:waitMul(val_s)

        -- 6. 组合现有的 64 位累加器值 [Rd : Rn]
        -- 将高位 Rd 左移 32 位，与低位 Rn 结合
        local accum = (val_d << 32) | val_n

        -- 7. 计算乘积 (无符号 32 位 x 32 位 -> 64 位)
        -- 注意：虽然 Lua 内部是 signed int64，但对于位运算和加法溢出回绕机制来说，
        -- 直接相乘在二进制层面与无符号乘法是一致的。
        local product = val_m * val_s

        -- 8. 执行 64 位加法 (累加)
        local result = accum + product

        -- 9. 写回结果
        -- 低 32 位 -> Rn
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd (右移后截断)
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
    end
end
function ARMCoreArm:constructUMLALS(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs

    return function ()
        -- 1. 等待预取指令
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])

        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end

        -- 3. 增加时钟周期 (修复 += 语法)
        cpu.cycles = cpu.cycles + 2

        -- 4. 获取操作数
        -- UMLAL 是无符号乘法，直接取值即可，无需处理符号位
        local val_m = gprs[rm]
        local val_s = gprs[rs]
        local val_n = gprs[rn] -- 低 32 位累加数
        local val_d = gprs[rd] -- 高 32 位累加数

        -- 5. 模拟乘法周期 (通常依赖于 Rs 的数值)
        cpu.mmu:waitMul(val_s)

        -- 6. 组合现有的 64 位累加器值 [Rd : Rn]
        -- 将高位 Rd 左移 32 位，与低位 Rn 结合
        local accum = (val_d << 32) | val_n

        -- 7. 计算乘积 (无符号 32 位 x 32 位 -> 64 位)
        -- 注意：虽然 Lua 内部是 signed int64，但对于位运算和加法溢出回绕机制来说，
        -- 直接相乘在二进制层面与无符号乘法是一致的。
        local product = val_m * val_s

        -- 8. 执行 64 位加法 (累加)
        local result = accum + product

        -- 9. 写回结果
        -- 低 32 位 -> Rn
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd (右移后截断)
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff==0 and gprs[rn] & 0xffffffff==0);
    end
end

function ARMCoreArm:constructUMULL(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    return function ()
        -- 1. 等待预取
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end
        
        -- 3. 增加周期 (修复 ++ 语法)
        cpu.cycles = cpu.cycles + 1
        
        -- 4. 获取操作数
        -- UMULL 是无符号乘法，直接读取寄存器数值即可
        local val_m = gprs[rm]
        local val_s = gprs[rs]

        -- 5. 模拟乘法等待 (通常依赖于 Rs 的数值)
        cpu.mmu:waitMul(val_s)
        
        -- 6. 执行 64 位乘法
        -- 两个 32 位无符号数相乘，结果一定在 64 位整数范围内。
        -- 即使结果最高位是 1 (Lua 会视作负数)，其二进制位依然是正确的。
        local result = val_m * val_s

        -- 7. 拆分结果并写回
        -- 低 32 位 -> Rn
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd
        -- 右移 32 位并将高位清理干净 (防止算术右移带来的符号位干扰)
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
    end
end

function ARMCoreArm:constructUMULLS(rd, rn, rs, rm, condOp)
    local cpu = self.cpu
    local gprs = cpu.gprs
    
    return function ()
        -- 1. 等待预取
        cpu.mmu:waitPrefetch32(gprs[cpu.PC])
        
        -- 2. 条件执行判断
        if condOp and not condOp() then
            return
        end
        
        -- 3. 增加周期 (修复 ++ 语法)
        cpu.cycles = cpu.cycles + 1
        
        -- 4. 获取操作数
        -- UMULL 是无符号乘法，直接读取寄存器数值即可
        local val_m = gprs[rm]
        local val_s = gprs[rs]

        -- 5. 模拟乘法等待 (通常依赖于 Rs 的数值)
        cpu.mmu:waitMul(val_s)
        
        -- 6. 执行 64 位乘法
        -- 两个 32 位无符号数相乘，结果一定在 64 位整数范围内。
        -- 即使结果最高位是 1 (Lua 会视作负数)，其二进制位依然是正确的。
        local result = val_m * val_s

        -- 7. 拆分结果并写回
        -- 低 32 位 -> Rn
        gprs[rn] = result & 0xFFFFFFFF
        
        -- 高 32 位 -> Rd
        -- 右移 32 位并将高位清理干净 (防止算术右移带来的符号位干扰)
        gprs[rd] = (result >> 32) & 0xFFFFFFFF
        cpu.cpsrN = gprs[rd] >> 31 ~= 0
        cpu.cpsrZ = (gprs[rd] & 0xffffffff==0 and gprs[rn] & 0xffffffff==0);
    end
end


return ARMCoreArm