local ClassUtils = require("ClassUtils")
local NOMAP = -1;
local WB_32_MASK = 0xffffffff;
local ARMCore = ClassUtils.class("ARMCore")
local ARMCoreArm = require("arm")
local ARMCoreThumb = require("thumb")

function ARMCore:ctor()
	-- self.inherit();
	self.SP = 13;
	self.LR = 14;
	self.PC = 15;
	self.MODE_ARM = false;
	self.MODE_THUMB = true;
	self.MODE_USER = 0x10;
	self.MODE_FIQ = 0x11;
	self.MODE_IRQ = 0x12;
	self.MODE_SUPERVISOR = 0x13;
	self.MODE_ABORT = 0x17;
	self.MODE_UNDEFINED = 0x1b;
	self.MODE_SYSTEM = 0x1f;
	self.BANK_NONE = 0;
	self.BANK_FIQ = 1;
	self.BANK_IRQ = 2;
	self.BANK_SUPERVISOR = 3;
	self.BANK_ABORT = 4;
	self.BANK_UNDEFINED = 5;
	self.UNALLOC_MASK = 0x0fffff00;
	self.USER_MASK = 0xf0000000;
	self.PRIV_MASK = 0x000000cf; -- This is out of spec, but it seems to be what's done in other implementations
	self.STATE_MASK = 0x00000020;
	self.WORD_SIZE_ARM = 4;
	self.WORD_SIZE_THUMB = 2;
	self.BASE_RESET = 0x00000000;
	self.BASE_UNDEF = 0x00000004;
	self.BASE_SWI = 0x00000008;
	self.BASE_PABT = 0x0000000c;
	self.BASE_DABT = 0x00000010;
	self.BASE_IRQ = 0x00000018;
	self.BASE_FIQ = 0x0000001c;
	self.armCompiler = ARMCoreArm.new(self);
	self.thumbCompiler = ARMCoreThumb.new(self);
	self:generateConds();
	self.gprs = {};
end
function ARMCore:resetCPU(startOffset)
	for i = 0, self.PC-1 do
		self.gprs[i] = 0;
    end
	self.gprs[self.PC] = startOffset + self.WORD_SIZE_ARM;
	self.loadInstruction = self.loadInstructionArm;
	self.execMode = self.MODE_ARM;
	self.instructionWidth = self.WORD_SIZE_ARM;
	self.mode = self.MODE_SYSTEM;
	self.cpsrI = false;
	self.cpsrF = false;
	self.cpsrV = false;
	self.cpsrC = false;
	self.cpsrZ = false;
	self.cpsrN = false;
	self.bankedRegisters = {
        [0]={[0]=0,[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0},
        [1]={[0]=0,[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[6]=0},
        [2]={[0]=0,[1]=0},
        [3]={[0]=0,[1]=0},
        [4]={[0]=0,[1]=0},
        [5]={[0]=0,[1]=0}
	};
	self.spsr = 0;
	self.bankedSPSRs = {[0]=0,[1]=0,[2]=0,[3]=0,[4]=0,[5]=0};
	self.cycles = 0;
	self.shifterOperand = 0;
	self.shifterCarryOut = 0;
	self.page = nil;
	self.pageId = 0;
	self.pageRegion = -1;
	self.instruction = nil;
	self.irq:clear();
	local gprs = self.gprs;
	local mmu = self.mmu;
	self.step = function ()
        local instruction = self.instruction;
        --debugprint(string.format("step: PC=%X", gprs[self.PC]-self.instructionWidth))
        if not instruction then
            instruction = self:loadInstruction(
                gprs[15] - self.instructionWidth
            );
            self.instruction = instruction;
        end
 
		gprs[15] = gprs[15] + self.instructionWidth;
		self.conditionPassed = true;
		instruction();

		if not instruction.writesPC then
            --debugprint("not write pc")
				if self.instruction ~= nil then
                    
					-- We might have gotten an interrupt from the instruction
					if instruction.next == nil or instruction.next.page.invalid then
						instruction.next = self:loadInstruction(
							gprs[15] - self.instructionWidth
						);
                    end
					self.instruction = instruction.next;
				end
        else
            --debugprint("writepc")

				if self.conditionPassed then
					local pc = (gprs[15] & 0xfffffffe);
                    gprs[self.PC] = pc;
					if self.execMode == self.MODE_ARM then
						mmu:wait32(pc);
						mmu:waitPrefetch32(pc);
					else
						mmu:wait(pc);
						mmu:waitPrefetch(pc);
					end
					gprs[15] = gprs[15] + self.instructionWidth;
					if not instruction.fixedJump then
						self.instruction = nil;
					elseif self.instruction ~= nil then
						if instruction.next == nil or instruction.next.page.invalid then
							instruction.next = self:loadInstruction(
								gprs[15] - self.instructionWidth
							);
						end
						self.instruction = instruction.next;
					end
				else
					self.instruction = nil;
				end
		end
		self.irq:updateTimers();
    end
    local gba = self.gba
    local gprs = self.gprs
    local irq = self.irq
    local mmu = self.mmu
    local waitstatesPrefetch32 = mmu.waitstatesPrefetch32
    local waitstatesPrefetch = mmu.waitstatesPrefetch
    local waitstates32 = mmu.waitstates32
    local waitstates = mmu.waitstates
    self.run_until_vblank = function()
        while not gba.seenFrame do
            local instruction = self.instruction;
            if not instruction then
                instruction = self:loadInstruction(
                gprs[15] - self.instructionWidth
            );
                self.instruction = instruction; 
            end 
            gprs[15] = gprs[15] + self.instructionWidth;
            self.conditionPassed = true;
            instruction();
            if not instruction.writesPC then
                if self.instruction ~= nil then 
                    if instruction.next == nil or instruction.next.page.invalid then
                        instruction.next = self:loadInstruction(
                            gprs[15] - self.instructionWidth
                        );
                    end
                    self.instruction = instruction.next;
                end
            else
                if self.conditionPassed then
                    local pc = (gprs[15] & 0xfffffffe);
                    gprs[15] = pc;
                    -- thumb = true , arm = false
                    if self.execMode then
                        self.cycles = self.cycles + 1 + waitstates[pc >> 24];
                        self.cycles = self.cycles + 1 + waitstatesPrefetch[pc >> 24];
                    else
                        self.cycles = self.cycles + 1 + waitstates32[pc >> 24];
                        self.cycles = self.cycles + 1 + waitstatesPrefetch32[pc >> 24];
                    end
                    gprs[15] = gprs[15] + self.instructionWidth;
                    if not instruction.fixedJump then
                        self.instruction = nil;
                    elseif self.instruction ~= nil then
                        if instruction.next == nil or instruction.next.page.invalid then
                            instruction.next = self:loadInstruction(
                                gprs[15] - self.instructionWidth
                            );
                        end
                        self.instruction = instruction.next;
                    end
                else
                    self.instruction = nil;
                end
            end
            if irq.nextEvent <= self.cycles then
                irq:updateTimers();
            end
        end  
        gba.seenFrame = false
    end
end

function ARMCore:freeze()
	return {
		gprs= {
			[0]=self.gprs[0],
			self.gprs[1],
			self.gprs[2],
			self.gprs[3],
			self.gprs[4],
			self.gprs[5],
			self.gprs[6],
			self.gprs[7],
			self.gprs[8],
			self.gprs[9],
			self.gprs[10],
			self.gprs[11],
			self.gprs[12],
			self.gprs[13],
			self.gprs[14],
			self.gprs[15]
        },
		mode= self.mode,
		cpsrI= self.cpsrI,
		cpsrF= self.cpsrF,
		cpsrV= self.cpsrV,
		cpsrC= self.cpsrC,
		cpsrZ= self.cpsrZ,
		cpsrN= self.cpsrN,
		bankedRegisters= {
			[0]={
				[0]= self.bankedRegisters[0][0],
				[1]= self.bankedRegisters[0][1],
				[2]= self.bankedRegisters[0][2],
				[3]= self.bankedRegisters[0][3],
				[4]= self.bankedRegisters[0][4],
				[5]= self.bankedRegisters[0][5],
				[6]= self.bankedRegisters[0][6]
			},
			[1]={
				[0]= self.bankedRegisters[1][0],
				[1]= self.bankedRegisters[1][1],
				[2]= self.bankedRegisters[1][2],
				[3]= self.bankedRegisters[1][3],
				[4]= self.bankedRegisters[1][4],
				[5]= self.bankedRegisters[1][5],
				[6]= self.bankedRegisters[1][6]
			},
			[2]={
				[0]= self.bankedRegisters[2][0],
				[1]= self.bankedRegisters[2][1]
			},
			[3]={
				[0]= self.bankedRegisters[3][0],
				[1]= self.bankedRegisters[3][1]
			},
			[4]={
				[0]= self.bankedRegisters[4][0],
				[1]= self.bankedRegisters[4][1]
			},
			[5]={
				[0]= self.bankedRegisters[5][0],
				[1]= self.bankedRegisters[5][1]
			}
		},
		spsr= self.spsr,
		bankedSPSRs= {
			[0]= self.bankedSPSRs[0],
			[1]= self.bankedSPSRs[1],
			[2]= self.bankedSPSRs[2],
			[3]= self.bankedSPSRs[3],
			[4]= self.bankedSPSRs[4],
			[5]= self.bankedSPSRs[5]
		},
		cycles= self.cycles
	};
end
function ARMCore:defrost(frost)
		self.instruction = nil;

		self.page = nil;
		self.pageId = 0;
		self.pageRegion = -1;

		self.gprs[0] = frost.gprs[0];
		self.gprs[1] = frost.gprs[1];
		self.gprs[2] = frost.gprs[2];
		self.gprs[3] = frost.gprs[3];
		self.gprs[4] = frost.gprs[4];
		self.gprs[5] = frost.gprs[5];
		self.gprs[6] = frost.gprs[6];
		self.gprs[7] = frost.gprs[7];
		self.gprs[8] = frost.gprs[8];
		self.gprs[9] = frost.gprs[9];
		self.gprs[10] = frost.gprs[10];
		self.gprs[11] = frost.gprs[11];
		self.gprs[12] = frost.gprs[12];
		self.gprs[13] = frost.gprs[13];
		self.gprs[14] = frost.gprs[14];
		self.gprs[15] = frost.gprs[15];

		self.mode = frost.mode;
		self.cpsrI = frost.cpsrI;
		self.cpsrF = frost.cpsrF;
		self.cpsrV = frost.cpsrV;
		self.cpsrC = frost.cpsrC;
		self.cpsrZ = frost.cpsrZ;
		self.cpsrN = frost.cpsrN;

		self.bankedRegisters[0][0] = frost.bankedRegisters[0][0];
		self.bankedRegisters[0][1] = frost.bankedRegisters[0][1];
		self.bankedRegisters[0][2] = frost.bankedRegisters[0][2];
		self.bankedRegisters[0][3] = frost.bankedRegisters[0][3];
		self.bankedRegisters[0][4] = frost.bankedRegisters[0][4];
		self.bankedRegisters[0][5] = frost.bankedRegisters[0][5];
		self.bankedRegisters[0][6] = frost.bankedRegisters[0][6];

		self.bankedRegisters[1][0] = frost.bankedRegisters[1][0];
		self.bankedRegisters[1][1] = frost.bankedRegisters[1][1];
		self.bankedRegisters[1][2] = frost.bankedRegisters[1][2];
		self.bankedRegisters[1][3] = frost.bankedRegisters[1][3];
		self.bankedRegisters[1][4] = frost.bankedRegisters[1][4];
		self.bankedRegisters[1][5] = frost.bankedRegisters[1][5];
		self.bankedRegisters[1][6] = frost.bankedRegisters[1][6];

		self.bankedRegisters[2][0] = frost.bankedRegisters[2][0];
		self.bankedRegisters[2][1] = frost.bankedRegisters[2][1];

		self.bankedRegisters[3][0] = frost.bankedRegisters[3][0];
		self.bankedRegisters[3][1] = frost.bankedRegisters[3][1];

		self.bankedRegisters[4][0] = frost.bankedRegisters[4][0];
		self.bankedRegisters[4][1] = frost.bankedRegisters[4][1];

		self.bankedRegisters[5][0] = frost.bankedRegisters[5][0];
		self.bankedRegisters[5][1] = frost.bankedRegisters[5][1];

		self.spsr = frost.spsr;
		self.bankedSPSRs[0] = frost.bankedSPSRs[0];
		self.bankedSPSRs[1] = frost.bankedSPSRs[1];
		self.bankedSPSRs[2] = frost.bankedSPSRs[2];
		self.bankedSPSRs[3] = frost.bankedSPSRs[3];
		self.bankedSPSRs[4] = frost.bankedSPSRs[4];
		self.bankedSPSRs[5] = frost.bankedSPSRs[5];

		self.cycles = frost.cycles;
end
function ARMCore:fetchPage(address)
		local region = address >> self.mmu.BASE_OFFSET;
		local pageId = self.mmu:addressToPage(
			region,
			address & self.mmu.OFFSET_MASK
		);
		if region == self.pageRegion then
			if pageId == self.pageId and not self.page.invalid then
				return;
			end
			self.pageId = pageId;
		else
			self.pageMask = self.mmu.memory[region].PAGE_MASK;
			self.pageRegion = region;
			self.pageId = pageId;
		end

		self.page = self.mmu:accessPage(region, pageId);
end
function ARMCore:loadInstructionArm(address)
		local next = nil;
		self:fetchPage(address);
		local offset = (address & self.pageMask) >> 2;
		next = self.page.arm[offset];
		if next then
			return next;
		end
		local instruction = self.mmu:load32(address);
        --debugprint(string.format("loadInstructionArm: address=%X, instruction=%X", address, instruction))
        next = self:compileArm(instruction)
		next.next = nil;
		next.page = self.page;
		next.address = address;
		next.opcode = instruction;
		self.page.arm[offset] = next;
		return next;
end
function ARMCore:loadInstructionThumb(address)
		local next = nil;
		self:fetchPage(address);
		local offset = (address & self.pageMask) >> 1;
		next = self.page.thumb[offset];
		if next then
			return next;
		end
		local instruction = self.mmu:loadU16(address);
        --debugprint(string.format("loadInstructionThumb: address=%X, instruction=%X", address, instruction))
        next = self:compileThumb(instruction)
		next.next = nil;
		next.page = self.page;
		next.address = address;
		next.opcode = instruction;
		self.page.thumb[offset] = next;
		return next;
end
function ARMCore:selectBank(mode)
        if mode == self.MODE_USER or mode == self.MODE_SYSTEM then
            return self.BANK_NONE;
        end
        if mode == self.MODE_FIQ or self.mode == self.MODE_FIQ then
            return self.BANK_FIQ;
        end
        if mode == self.MODE_IRQ then
            return self.BANK_IRQ;
        end
        if mode == self.MODE_SUPERVISOR then
            return self.BANK_SUPERVISOR;
        end
        if mode == self.MODE_ABORT then
            return self.BANK_ABORT;
        end
        if mode == self.MODE_UNDEFINED then
            return self.BANK_UNDEFINED;
        end
        error("Invalid user mode passed to selectBank");
end
function ARMCore:switchExecMode(newMode)
	if self.execMode ~= newMode then
		self.execMode = newMode;
		if newMode == self.MODE_ARM then
			self.instructionWidth = self.WORD_SIZE_ARM;
			self.loadInstruction = self.loadInstructionArm;
		else
			self.instructionWidth = self.WORD_SIZE_THUMB;
			self.loadInstruction = self.loadInstructionThumb;
		end
	end
end
function ARMCore:switchMode(newMode)
		if newMode == self.mode then
			-- Not switching modes after all
			return;
		end
		if newMode ~= self.MODE_USER or newMode ~= self.MODE_SYSTEM then
			-- Switch banked registers
			local newBank = self:selectBank(newMode);
			local oldBank = self:selectBank(self.mode);
			if newBank ~= oldBank then
				-- TODO: support FIQ
				if newMode == self.MODE_FIQ or self.mode == self.MODE_FIQ then
					local oldFiqBank = (oldBank == self.BANK_FIQ and 1 or 0) + 0;
					local newFiqBank = (newBank == self.BANK_FIQ and 1 or 0) + 0;
					self.bankedRegisters[oldFiqBank][2] = self.gprs[8];
					self.bankedRegisters[oldFiqBank][3] = self.gprs[9];
					self.bankedRegisters[oldFiqBank][4] = self.gprs[10];
					self.bankedRegisters[oldFiqBank][5] = self.gprs[11];
					self.bankedRegisters[oldFiqBank][6] = self.gprs[12];
					self.gprs[8] = self.bankedRegisters[newFiqBank][2];
					self.gprs[9] = self.bankedRegisters[newFiqBank][3];
					self.gprs[10] = self.bankedRegisters[newFiqBank][4];
					self.gprs[11] = self.bankedRegisters[newFiqBank][5];
					self.gprs[12] = self.bankedRegisters[newFiqBank][6];
                end
				self.bankedRegisters[oldBank][0] = self.gprs[self.SP];
				self.bankedRegisters[oldBank][1] = self.gprs[self.LR];
				self.gprs[self.SP] = self.bankedRegisters[newBank][0];
				self.gprs[self.LR] = self.bankedRegisters[newBank][1];

				self.bankedSPSRs[oldBank] = self.spsr;
				self.spsr = self.bankedSPSRs[newBank];
			end
		end
		self.mode = newMode;
	end
function ARMCore:packCPSR()
		return (
			self.mode |
			(self.execMode and 1 or 0) << 5 |
			(self.cpsrF and 1 or 0) << 6 |
			(self.cpsrI and 1 or 0) << 7 |
			(self.cpsrN and 1 or 0) << 31 |
			(self.cpsrZ and 1 or 0) << 30 |
			(self.cpsrC and 1 or 0) << 29 |
			(self.cpsrV and 1 or 0) << 28
		);
end
function ARMCore:unpackCPSR(spsr)
		self:switchMode(spsr & 0x0000001f);
		self:switchExecMode((spsr & 0x00000020)~=0);
		self.cpsrF = spsr & 0x00000040 ~= 0;
		self.cpsrI = spsr & 0x00000080 ~= 0;
		self.cpsrN = spsr & 0x80000000 ~= 0;
		self.cpsrZ = spsr & 0x40000000 ~= 0;
		self.cpsrC = spsr & 0x20000000 ~= 0;
		self.cpsrV = spsr & 0x10000000 ~= 0;

		self.irq:testIRQ();
end
function ARMCore:hasSPSR()
		return self.mode ~= self.MODE_SYSTEM and self.mode ~= self.MODE_USER;
end
function ARMCore:raiseIRQ()
		if self.cpsrI then
			return;
		end
		local cpsr = self:packCPSR();
		local instructionWidth = self.instructionWidth;
		self:switchMode(self.MODE_IRQ);
        
        
		self.spsr = cpsr;
		self.gprs[self.LR] = self.gprs[self.PC] - instructionWidth + 4;
		self.gprs[self.PC] = self.BASE_IRQ + self.WORD_SIZE_ARM;
		self.instruction = nil;
		self:switchExecMode(self.MODE_ARM);
		self.cpsrI = true;
end
function ARMCore:raiseTrap()
		local cpsr = self:packCPSR();
		local instructionWidth = self.instructionWidth;
		self:switchMode(self.MODE_SUPERVISOR);
        
		self.spsr = cpsr;
		self.gprs[self.LR] = self.gprs[self.PC] - instructionWidth;
		self.gprs[self.PC] = self.BASE_SWI + self.WORD_SIZE_ARM;
		self.instruction = nil;
		self:switchExecMode(self.MODE_ARM);
		self.cpsrI = true;
end
function ARMCore.badOp(instruction)
		local func = setmetatable({}, {
            __call = function ()
			error(string.format("Illegal instruction: 0x%X", instruction));
		end});
		func.writesPC = true;
		func.fixedJump = false;
		return func;
end
function ARMCore:generateConds()
		local cpu = self;
		self.conds = {
			-- EQ
			[0]=function ()
                cpu.conditionPassed = cpu.cpsrZ;
				return cpu.conditionPassed;
            end,
			-- NE
			[1]=function ()
                cpu.conditionPassed =  not cpu.cpsrZ;
				return cpu.conditionPassed;
            end,
			-- CS
			[2]=function ()
                cpu.conditionPassed = cpu.cpsrC;
				return cpu.conditionPassed;
            end,
			-- CC
			[3]=function ()
                cpu.conditionPassed = not cpu.cpsrC;
				return cpu.conditionPassed;
            end,
			-- MI
			[4]=function ()
                cpu.conditionPassed = cpu.cpsrN;
				return cpu.conditionPassed;
            end,
			-- PL
			[5]=function ()
                cpu.conditionPassed = not cpu.cpsrN;
				return cpu.conditionPassed;
            end,
			-- VS
			[6]=function ()
                cpu.conditionPassed = cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- VC
			[7]=function ()
                cpu.conditionPassed = not cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- HI
			[8]=function ()
                cpu.conditionPassed = cpu.cpsrC and not cpu.cpsrZ;
				return cpu.conditionPassed;
            end,
			-- LS
			[9]=function ()
                cpu.conditionPassed = not cpu.cpsrC or cpu.cpsrZ;
				return cpu.conditionPassed;
            end,
			-- GE
			[10]=function ()
                cpu.conditionPassed = not cpu.cpsrN == not cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- LT
			[11]=function ()
                cpu.conditionPassed = not cpu.cpsrN ~= not cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- GT
			[12]=function ()
                cpu.conditionPassed = not cpu.cpsrZ and not cpu.cpsrN == not cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- LE
			[13]=function ()
                cpu.conditionPassed = cpu.cpsrZ or not cpu.cpsrN ~= not cpu.cpsrV;
				return cpu.conditionPassed;
            end,
			-- AL
		};
end
function ARMCore:barrelShiftImmediate(shiftType, immediate, rm)
	local cpu = self;
	local gprs = self.gprs;
	local shiftOp = self.badOp;
	if shiftType == 0x00000000 then
		-- LSL
		if immediate~=0 then
			shiftOp = function ()
				cpu.shifterOperand = (gprs[rm] << immediate) & WB_32_MASK;
				cpu.shifterCarryOut =
					(gprs[rm] & (1 << (32 - immediate))) ~= 0;
            end
		else
			-- This boils down to no shift
			shiftOp = function ()
				cpu.shifterOperand = gprs[rm] & WB_32_MASK;
				cpu.shifterCarryOut = cpu.cpsrC;
            end
		end
	elseif shiftType == 0x00000020 then
			-- LSR
			if immediate~=0 then
				shiftOp = function ()
					cpu.shifterOperand = (gprs[rm] >> immediate) & WB_32_MASK;
					cpu.shifterCarryOut = (gprs[rm] & (1 << (immediate - 1))) ~= 0;
                end
			else
				shiftOp = function ()
					cpu.shifterOperand = 0;
					cpu.shifterCarryOut = (gprs[rm] & 0x80000000) ~= 0;
                end
			end
		elseif shiftType == 0x00000040 then
			-- ASR
			if immediate~=0 then
				shiftOp = function ()
                    local sign = gprs[rm] >> 31;
                    local prefill = 0
                    if sign ~= 0 then
                        prefill = 0xffffffff << (32 - immediate);
                    end 
					cpu.shifterOperand = ((gprs[rm] >> immediate) | prefill) & WB_32_MASK;
					cpu.shifterCarryOut = (gprs[rm] & (1 << (immediate - 1))) ~= 0;
                end
			else
				shiftOp = function ()
					cpu.shifterCarryOut = gprs[rm] & 0x80000000 ~= 0;
					if cpu.shifterCarryOut then
						cpu.shifterOperand = 0xffffffff;
					else
						cpu.shifterOperand = 0; 
                    end
                end
			end
		elseif shiftType == 0x00000060 then
			-- ROR
			if immediate~=0 then
				shiftOp = function ()
					cpu.shifterOperand =
						(gprs[rm] >> immediate) |
						(gprs[rm] << (32 - immediate)) & WB_32_MASK;
					cpu.shifterCarryOut = (gprs[rm] & (1 << (immediate - 1))) ~= 0;
                end
			else
				-- RRX
				shiftOp = function ()
					cpu.shifterOperand =
						((cpu.cpsrC and 1 or 0) << 31) | (gprs[rm] >> 1) & WB_32_MASK;
					cpu.shifterCarryOut = gprs[rm] & 0x00000001 ~= 0 ;
                end
			end
        end
	return shiftOp;
end


-- 算术/逻辑指令查找表 (用于 Data Processing)
local arithmeticHandlers = {
    [0x00000000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructANDS(rd, rn, shiftOp, condOp) or self.armCompiler:constructAND(rd, rn, shiftOp, condOp) end,
    [0x00200000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructEORS(rd, rn, shiftOp, condOp) or self.armCompiler:constructEOR(rd, rn, shiftOp, condOp) end,
    [0x00400000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructSUBS(rd, rn, shiftOp, condOp) or self.armCompiler:constructSUB(rd, rn, shiftOp, condOp) end,
    [0x00600000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructRSBS(rd, rn, shiftOp, condOp) or self.armCompiler:constructRSB(rd, rn, shiftOp, condOp) end,
    [0x00800000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructADDS(rd, rn, shiftOp, condOp) or self.armCompiler:constructADD(rd, rn, shiftOp, condOp) end,
    [0x00a00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructADCS(rd, rn, shiftOp, condOp) or self.armCompiler:constructADC(rd, rn, shiftOp, condOp) end,
    [0x00c00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructSBCS(rd, rn, shiftOp, condOp) or self.armCompiler:constructSBC(rd, rn, shiftOp, condOp) end,
    [0x00e00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructRSCS(rd, rn, shiftOp, condOp) or self.armCompiler:constructRSC(rd, rn, shiftOp, condOp) end,
    [0x01000000] = function(self, rd, rn, shiftOp, condOp, s) return self.armCompiler:constructTST(rd, rn, shiftOp, condOp) end,
    [0x01200000] = function(self, rd, rn, shiftOp, condOp, s) return self.armCompiler:constructTEQ(rd, rn, shiftOp, condOp) end,
    [0x01400000] = function(self, rd, rn, shiftOp, condOp, s) return self.armCompiler:constructCMP(rd, rn, shiftOp, condOp) end,
    [0x01600000] = function(self, rd, rn, shiftOp, condOp, s) return self.armCompiler:constructCMN(rd, rn, shiftOp, condOp) end,
    [0x01800000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructORRS(rd, rn, shiftOp, condOp) or self.armCompiler:constructORR(rd, rn, shiftOp, condOp) end,
    [0x01a00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructMOVS(rd, rn, shiftOp, condOp) or self.armCompiler:constructMOV(rd, rn, shiftOp, condOp) end,
    [0x01c00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructBICS(rd, rn, shiftOp, condOp) or self.armCompiler:constructBIC(rd, rn, shiftOp, condOp) end,
    [0x01e00000] = function(self, rd, rn, shiftOp, condOp, s) return s and self.armCompiler:constructMVNS(rd, rn, shiftOp, condOp) or self.armCompiler:constructMVN(rd, rn, shiftOp, condOp) end,
}

-- 乘法指令查找表
local multiplyHandlers = {
    [0x00000000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructMUL(rd, rs, rm, condOp) end,
    [0x00100000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructMULS(rd, rs, rm, condOp) end,
    [0x00200000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructMLA(rd, rn, rs, rm, condOp) end,
    [0x00300000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructMLAS(rd, rn, rs, rm, condOp) end,
    [0x00800000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructUMULL(rd, rn, rs, rm, condOp) end,
    [0x00900000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructUMULLS(rd, rn, rs, rm, condOp) end,
    [0x00a00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructUMLAL(rd, rn, rs, rm, condOp) end,
    [0x00b00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructUMLALS(rd, rn, rs, rm, condOp) end,
    [0x00c00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructSMULL(rd, rn, rs, rm, condOp) end,
    [0x00d00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructSMULLS(rd, rn, rs, rm, condOp) end,
    [0x00e00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructSMLAL(rd, rn, rs, rm, condOp) end,
    [0x00f00000] = function(self, rd, rn, rs, rm, condOp) return self.armCompiler:constructSMLALS(rd, rn, rs, rm, condOp) end,
}

local function funcTable(op)
    return setmetatable({}, {__call = op})
end

-- 主指令类别处理函数定义
local mainOpHandlers = {}

-- 0x00000000: Multiplies or Halfword/Signed Byte transfer
mainOpHandlers[0x00000000] = function(self, instruction, condOp)
    if (instruction & 0x010000f0) == 0x00000090 then
        -- Multiplies
        local rd = (instruction & 0x000f0000) >> 16
        local rn = (instruction & 0x0000f000) >> 12
        local rs = (instruction & 0x00000f00) >> 8
        local rm = instruction & 0x0000000f
        local subType = instruction & 0x00f00000
        
        local handler = multiplyHandlers[subType]
        if handler then
            local op = handler(self, rd, rn, rs, rm, condOp)
            op = funcTable(op)
            op.writesPC = (rd == self.PC)
            return op
        end
    else
        -- Halfword and signed byte data transfer
        local load = (instruction & 0x00100000) ~= 0
        local rd = (instruction & 0x0000f000) >> 12
        local hiOffset = (instruction & 0x00000f00) >> 4
        local rm = instruction & 0x0000000f
        local loOffset = rm
        local h = (instruction & 0x00000020) ~= 0
        local s = (instruction & 0x00000040) ~= 0
        local w = (instruction & 0x00200000) ~= 0
        local i = (instruction & 0x00400000) ~= 0

        local address
        if i then
            local immediate = loOffset | hiOffset
            address = self.armCompiler:constructAddressingMode23Immediate(instruction, immediate, condOp)
        else
            address = self.armCompiler:constructAddressingMode23Register(instruction, rm, condOp)
        end
        address.writesPC = w and (rd == self.PC) -- Note: using rd as rn placeholder logic from original if addressing uses base update

        local op
        if (instruction & 0x00000090) == 0x00000090 then
            if load then
                if h then
                    if s then op = self.armCompiler:constructLDRSH(rd, address, condOp) -- LDRSH
                    else op = self.armCompiler:constructLDRH(rd, address, condOp) end   -- LDRH
                else
                    if s then op = self.armCompiler:constructLDRSB(rd, address, condOp) end -- LDRSB
                end
            elseif not s and h then
                op = self.armCompiler:constructSTRH(rd, address, condOp) -- STRH
            end
        end
        
        if op then
            op = funcTable(op)
            op.writesPC = (rd == self.PC) or address.writesPC
            return op
        end
    end
    -- Fallback for unhandled ops in this block
    return self.badOp(instruction)
end

-- 0x04000000 & 0x06000000: LDR/STR
local function handleLdrStr(self, instruction, condOp)
    local rd = (instruction & 0x0000f000) >> 12
    local load = (instruction & 0x00100000) ~= 0
    local b = (instruction & 0x00400000) ~= 0
    local i = (instruction & 0x02000000) ~= 0

    local address
    if (instruction & 0x01000000) == 0 then
        -- Clear W bit if P bit is clear
        instruction = instruction & 0xffdfffff
    end

    if i then
        -- Register offset
        local rm = instruction & 0x0000000f
        local shiftType = instruction & 0x00000060
        local shiftImmediate = (instruction & 0x00000f80) >> 7
        
        if shiftType ~= 0 or shiftImmediate ~= 0 then
            local shiftOp = self:barrelShiftImmediate(shiftType, shiftImmediate, rm)
            address = self.armCompiler:constructAddressingMode2RegisterShifted(instruction, shiftOp, condOp)
        else
            address = self.armCompiler:constructAddressingMode23Register(instruction, rm, condOp)
        end
    else
        -- Immediate
        local offset = instruction & 0x00000fff
        address = self.armCompiler:constructAddressingMode23Immediate(instruction, offset, condOp)
    end

    local op
    if load then
        if b then op = self.armCompiler:constructLDRB(rd, address, condOp)
        else op = self.armCompiler:constructLDR(rd, address, condOp) end
    else
        if b then op = self.armCompiler:constructSTRB(rd, address, condOp)
        else op = self.armCompiler:constructSTR(rd, address, condOp) end
    end
    op = funcTable(op)
    op.writesPC = (rd == self.PC) or address.writesPC
    return op
end

mainOpHandlers[0x04000000] = handleLdrStr
mainOpHandlers[0x06000000] = handleLdrStr

-- 0x08000000: Block data transfer (LDM/STM)
mainOpHandlers[0x08000000] = function(self, instruction, condOp)
    local load = (instruction & 0x00100000) ~= 0
    local w = (instruction & 0x00200000) ~= 0
    local user = (instruction & 0x00400000) ~= 0
    local u = (instruction & 0x00800000) ~= 0
    local p = (instruction & 0x01000000) ~= 0
    local rs = instruction & 0x0000ffff
    local rn = (instruction & 0x000f0000) >> 16

    local address
    local immediate = 0
    local offset = 0
    local overlap = false

    if u then
        if p then immediate = 4 end
        local m = 0x01
        for idx = 0, 15 do
            if (rs & m) ~= 0 then
                if w and idx == rn and offset == 0 then
                    rs = rs & (~m)
                    immediate = immediate + 4
                    overlap = true
                end
                offset = offset + 4
            end
            m = m << 1
        end
    else
        if not p then immediate = 4 end
        local m = 0x01
        for idx = 0, 15 do
            if (rs & m) ~= 0 then
                if w and idx == rn and offset == 0 then
                    rs = rs & (~m)
                    immediate = immediate + 4
                    overlap = true
                end
                immediate = immediate - 4
                offset = offset - 4
            end
            m = m << 1
        end
    end

    if w then
        address = self.armCompiler:constructAddressingMode4Writeback(immediate, offset, rn, overlap)
    else
        address = self.armCompiler:constructAddressingMode4(immediate, rn)
    end

    local op
    if load then
        if user then op = self.armCompiler:constructLDMS(rs, address, condOp)
        else op = self.armCompiler:constructLDM(rs, address, condOp) end
        op = funcTable(op)
        op.writesPC = (rs & (1 << 15)) ~= 0
    else
        if user then op = self.armCompiler:constructSTMS(rs, address, condOp)
        else op = self.armCompiler:constructSTM(rs, address, condOp) end
        op = funcTable(op)
        op.writesPC = false
    end
    return op
end

-- 0x0a000000: Branch (B/BL)
mainOpHandlers[0x0a000000] = function(self, instruction, condOp)
    local immediate = instruction & 0x00ffffff
    if (immediate & 0x00800000) ~= 0 then
        immediate = immediate | 0xff000000
    end
    immediate = immediate << 2
    local link = (instruction & 0x01000000) ~= 0
    
    local op
    if link then
        op = self.armCompiler:constructBL(immediate, condOp)
    else
        op = self.armCompiler:constructB(immediate, condOp)
    end
    op = funcTable(op)
    op.writesPC = true
    op.fixedJump = true
    return op
end

-- 0x0e000000: Coprocessor / SWI
mainOpHandlers[0x0e000000] = function(self, instruction, condOp)
    -- Coprocessor operations generally ignored or simplified here, mostly SWI
    if (instruction & 0x0f000000) == 0x0f000000 then
        -- SWI
        local immediate = instruction & 0x00ffffff
        local op = self.armCompiler:constructSWI(immediate, condOp)
        op = funcTable(op)
        op.writesPC = false
        return op
    end
    return self.badOp(instruction)
end
-- 0x0c000000 Coprocessor transfer 留空或抛错
mainOpHandlers[0x0c000000] = function(self, instruction, condOp)
    -- Coprocessor data transfer - Unimplemented
    return self.badOp(instruction)
end


function ARMCore:compileArm(instruction)
    local op = self.badOp(instruction)
    local i = instruction & 0x0e000000
    local condOp = self.conds[(instruction & 0xf0000000) >> 28]

    if (instruction & 0x0ffffff0) == 0x012fff10 then
        -- BX
        local rm = instruction & 0x0000000f
        op = self.armCompiler:constructBX(rm, condOp)
        op = funcTable(op)
        op.writesPC = true
        op.fixedJump = false
    elseif (instruction & 0x0c000000) == 0 and (i == 0x02000000 or (instruction & 0x00000090) ~= 0x00000090) then
        -- Data processing
        local opcode = instruction & 0x01e00000
        local s = (instruction & 0x00100000) ~= 0
        
        if (opcode & 0x01800000) == 0x01000000 and not s then
            -- MSR / MRS
            local r = (instruction & 0x00400000)
            if (instruction & 0x00b0f000) == 0x0020f000 then
                -- MSR
                local rm = instruction & 0x0000000f
                local immediate = instruction & 0x000000ff
                local rotateImm = (instruction & 0x00000f00) >> 7
                immediate = ((immediate >> rotateImm) | (immediate << (32 - rotateImm)))&WB_32_MASK
                op = funcTable(self.armCompiler:constructMSR(rm, r, instruction, immediate, condOp))
                op = funcTable(op)
                op.writesPC = false
            elseif (instruction & 0x00bf0000) == 0x000f0000 then
                -- MRS
                local rd = (instruction & 0x0000f000) >> 12
                op = funcTable(self.armCompiler:constructMRS(rd, r, condOp))
                op = funcTable(op)
                op.writesPC = rd == self.PC
            end
        else
            -- Standard Data Processing
            local rn = (instruction & 0x000f0000) >> 16
            local rd = (instruction & 0x0000f000) >> 12
            
            -- Parse shifter operand
            local shiftType = instruction & 0x00000060
            local rm = instruction & 0x0000000f
            local shiftOp 
            
            if (instruction & 0x02000000) ~= 0 then
                -- Immediate
                local immediate = instruction & 0x000000ff
                local rotate = (instruction & 0x00000f00) >> 7
                if rotate == 0 then
                    shiftOp = self.armCompiler:constructAddressingMode1Immediate(immediate)
                else
                    shiftOp = self.armCompiler:constructAddressingMode1ImmediateRotate(immediate, rotate)
                end
            elseif (instruction & 0x00000010) ~= 0 then
                -- Register shift
                local rs = (instruction & 0x00000f00) >> 8
                if shiftType == 0x00000000 then shiftOp = self.armCompiler:constructAddressingMode1LSL(rs, rm)
                elseif shiftType == 0x00000020 then shiftOp = self.armCompiler:constructAddressingMode1LSR(rs, rm)
                elseif shiftType == 0x00000040 then shiftOp = self.armCompiler:constructAddressingMode1ASR(rs, rm)
                elseif shiftType == 0x00000060 then shiftOp = self.armCompiler:constructAddressingMode1ROR(rs, rm)
                end
            else
                -- Immediate shift
                local immediate = (instruction & 0x00000f80) >> 7
                shiftOp = self:barrelShiftImmediate(shiftType, immediate, rm)
            end
            
            if not shiftOp then error("BUG: invalid barrel shifter") end

            local handler = arithmeticHandlers[opcode]
            if handler then
                op = handler(self, rd, rn, shiftOp, condOp, s)
                op = funcTable(op)
                op.writesPC = (rd == self.PC)
            else
                error("Bad opcode: " .. string.format("0x%x", instruction))
            end
        end
    elseif (instruction & 0x0fb00ff0) == 0x01000090 then
        -- Single data swap
        local rm = instruction & 0x0000000f
        local rd = (instruction >> 12) & 0x0000000f
        local rn = (instruction >> 16) & 0x0000000f
        if (instruction & 0x00400000) ~= 0 then
            op = self.armCompiler:constructSWPB(rd, rn, rm, condOp)
        else
            op = self.armCompiler:constructSWP(rd, rn, rm, condOp)
        end
        op = funcTable(op)
        op.writesPC = (rd == self.PC)
    else
        -- Main Dispatch (formerly switch(i))
        local handler = mainOpHandlers[i]
        if handler then
            op = handler(self, instruction, condOp)
        else
             error("Bad opcode: " .. string.format("0x%x", instruction))
        end
    end

    op.execMode = self.MODE_ARM
    op.fixedJump = op.fixedJump or false
    return op
end

-- Thumb ALU (0x4000)
local thumbAluHandlers = {
    [0x0000] = function(self, rd, rm) return self.thumbCompiler:constructAND(rd, rm) end,
    [0x0040] = function(self, rd, rm) return self.thumbCompiler:constructEOR(rd, rm) end,
    [0x0080] = function(self, rd, rm) return self.thumbCompiler:constructLSL2(rd, rm) end,
    [0x00c0] = function(self, rd, rm) return self.thumbCompiler:constructLSR2(rd, rm) end,
    [0x0100] = function(self, rd, rm) return self.thumbCompiler:constructASR2(rd, rm) end,
    [0x0140] = function(self, rd, rm) return self.thumbCompiler:constructADC(rd, rm) end,
    [0x0180] = function(self, rd, rm) return self.thumbCompiler:constructSBC(rd, rm) end,
    [0x01c0] = function(self, rd, rm) return self.thumbCompiler:constructROR(rd, rm) end,
    [0x0200] = function(self, rd, rm) return self.thumbCompiler:constructTST(rd, rm) end,
    [0x0240] = function(self, rd, rm) return self.thumbCompiler:constructNEG(rd, rm) end,
    [0x0280] = function(self, rd, rm) return self.thumbCompiler:constructCMP2(rd, rm) end,
    [0x02c0] = function(self, rd, rm) return self.thumbCompiler:constructCMN(rd, rm) end,
    [0x0300] = function(self, rd, rm) return self.thumbCompiler:constructORR(rd, rm) end,
    [0x0340] = function(self, rd, rm) return self.thumbCompiler:constructMUL(rd, rm) end,
    [0x0380] = function(self, rd, rm) return self.thumbCompiler:constructBIC(rd, rm) end,
    [0x03c0] = function(self, rd, rm) return self.thumbCompiler:constructMVN(rd, rm) end,
}

-- Special Data / BX (0x4400)
local thumbSpecialHandlers = {
    [0x0000] = function(self, rd, rm)
        local op = self.thumbCompiler:constructADD4(rd, rm)
        op = funcTable(op)
        op.writesPC = (rd == self.PC)
        return op
    end,
    [0x0100] = function(self, rd, rm)
        local op = self.thumbCompiler:constructCMP3(rd, rm)
        op = funcTable(op)
        op.writesPC = false
        return op
    end,
    [0x0200] = function(self, rd, rm)
        local op = self.thumbCompiler:constructMOV3(rd, rm)
        op = funcTable(op)
        op.writesPC = (rd == self.PC)
        return op
    end,
    [0x0300] = function(self, rd, rm)
        local op = self.thumbCompiler:constructBX(rd, rm)
        op = funcTable(op)
        op.writesPC = true
        op.fixedJump = false
        return op
    end,
}

-- Add/Subtract (0x1800)
local thumbAddSubHandlers = {
    [0x0000] = function(self, rd, rn, arg) return self.thumbCompiler:constructADD3(rd, rn, arg) end, -- arg is rm
    [0x0200] = function(self, rd, rn, arg) return self.thumbCompiler:constructSUB3(rd, rn, arg) end, -- arg is rm
    [0x0400] = function(self, rd, rn, arg) return self.thumbCompiler:constructADD1(rd, rn, arg) end, -- arg is immediate (if immediate != 0 check handled by caller usually, but here we separate by bitmask)
    [0x0600] = function(self, rd, rn, arg) return self.thumbCompiler:constructSUB1(rd, rn, arg) end, -- arg is immediate
}

-- Shift Immediate (0x0000 - 0x1800 range logic)
local thumbShiftImmHandlers = {
    [0x0000] = function(self, rd, rm, imm) return self.thumbCompiler:constructLSL1(rd, rm, imm) end,
    [0x0800] = function(self, rd, rm, imm) return self.thumbCompiler:constructLSR1(rd, rm, imm) end,
    [0x1000] = function(self, rd, rm, imm) return self.thumbCompiler:constructASR1(rd, rm, imm) end,
}

-- Imm ALU (0x2000)
local thumbImmAluHandlers = {
    [0x0000] = function(self, rn, imm) return self.thumbCompiler:constructMOV1(rn, imm) end,
    [0x0800] = function(self, rn, imm) return self.thumbCompiler:constructCMP1(rn, imm) end,
    [0x1000] = function(self, rn, imm) return self.thumbCompiler:constructADD2(rn, imm) end,
    [0x1800] = function(self, rn, imm) return self.thumbCompiler:constructSUB2(rn, imm) end,
}

-- Load/Store Relative (0x5000)
local thumbLoadStoreRelHandlers = {
    [0x0000] = function(self, rd, rn, rm) return self.thumbCompiler:constructSTR2(rd, rn, rm) end,
    [0x0200] = function(self, rd, rn, rm) return self.thumbCompiler:constructSTRH2(rd, rn, rm) end,
    [0x0400] = function(self, rd, rn, rm) return self.thumbCompiler:constructSTRB2(rd, rn, rm) end,
    [0x0600] = function(self, rd, rn, rm) return self.thumbCompiler:constructLDRSB(rd, rn, rm) end,
    [0x0800] = function(self, rd, rn, rm) return self.thumbCompiler:constructLDR2(rd, rn, rm) end,
    [0x0a00] = function(self, rd, rn, rm) return self.thumbCompiler:constructLDRH2(rd, rn, rm) end,
    [0x0c00] = function(self, rd, rn, rm) return self.thumbCompiler:constructLDRB2(rd, rn, rm) end,
    [0x0e00] = function(self, rd, rn, rm) return self.thumbCompiler:constructLDRSH(rd, rn, rm) end,
}

-- Upper Half Handlers (0x8000+)
local thumbUpperHalfHandlers = {
    -- 0x8000: Load/Store Halfword
    [0x0000] = function(self, instruction)
        local rd = instruction & 0x0007
        local rn = (instruction & 0x0038) >> 3
        local immediate = (instruction & 0x07c0) >> 5
        local op
        if (instruction & 0x0800) ~= 0 then
            op = self.thumbCompiler:constructLDRH1(rd, rn, immediate)
        else
            op = self.thumbCompiler:constructSTRH1(rd, rn, immediate)
        end
        op = funcTable(op)
        op.writesPC = false
        return op
    end,
    -- 0x9000: SP-relative load/store
    [0x1000] = function(self, instruction)
        local rd = (instruction & 0x0700) >> 8
        local immediate = (instruction & 0x00ff) << 2
        local op
        if (instruction & 0x0800) ~= 0 then
            op = self.thumbCompiler:constructLDR4(rd, immediate)
        else
            op = self.thumbCompiler:constructSTR3(rd, immediate)
        end
        op = funcTable(op)
        op.writesPC = false
        return op
    end,
    -- 0xA000: Load Address
    [0x2000] = function(self, instruction)
        local rd = (instruction & 0x0700) >> 8
        local immediate = (instruction & 0x00ff) << 2
        local op
        if (instruction & 0x0800) ~= 0 then
            op = self.thumbCompiler:constructADD6(rd, immediate) -- SP
        else
            op = self.thumbCompiler:constructADD5(rd, immediate) -- PC
        end
        op = funcTable(op)
        op.writesPC = false
        return op
    end,
    -- 0xB000: Misc (Adjust SP)
    [0x3000] = function(self, instruction)
        if (instruction & 0x0f00) == 0 then
            -- Adjust stack pointer ADD(7)/SUB(4)
            local b = (instruction & 0x0080) ~= 0
            local immediate = (instruction & 0x7f) << 2
            if b then
                immediate = -immediate
            end
            local op = self.thumbCompiler:constructADD7(immediate)
            op = funcTable(op)
            op.writesPC = false
            return op
        end
        -- If here, it falls through to undefined warning in original, handling gracefully
        return self.badOp(instruction)
    end,
    -- 0xC000: Multiple Load/Store
    [0x4000] = function(self, instruction)
        local rn = (instruction & 0x0700) >> 8
        local rs = instruction & 0x00ff
        local op
        if (instruction & 0x0800) ~= 0 then
            op = self.thumbCompiler:constructLDMIA(rn, rs)
        else
            op = self.thumbCompiler:constructSTMIA(rn, rs)
        end
        op = funcTable(op)
        op.writesPC = false
        return op
    end,
    -- 0xD000: Conditional Branch / SWI
    [0x5000] = function(self, instruction)
        local cond = (instruction & 0x0f00) >> 8
        local immediate = instruction & 0x00ff
        local op
        if cond == 0xf then
            -- SWI
            op = self.thumbCompiler:constructSWI(immediate)
            op = funcTable(op)
            op.writesPC = false
        else
            -- B(1)
            if (instruction & 0x0080) ~= 0 then
                immediate = immediate | 0xffffff00
            end
            immediate = immediate << 1
            local condOp = self.conds[cond]
            op = self.thumbCompiler:constructB1(immediate, condOp)
            op = funcTable(op)
            op.writesPC = true
            op.fixedJump = true
        end
        return op
    end,
    -- 0xE000: BL(X) Suffix / B(2)
    [0x6000] = function(self, instruction) return self:handleBLTypes(instruction) end,
    -- 0xF000: BL(X) Prefix
    [0x7000] = function(self, instruction) return self:handleBLTypes(instruction) end,
}

-- 辅助函数：处理 BL/BLX 复杂的位逻辑
function ARMCore:handleBLTypes(instruction)
    local immediate = instruction & 0x07ff
    local h = instruction & 0x1800
    local op
    
    if h == 0x0000 then
        -- B(2)
        if (immediate & 0x0400) ~= 0 then
            immediate = immediate | 0xfffff800
        end
        immediate = immediate << 1
        op = self.thumbCompiler:constructB2(immediate)
        op = funcTable(op)
        op.writesPC = true
        op.fixedJump = true
    elseif h == 0x0800 then
        -- BLX (ARMv5T) - Not implemented in JS source
        -- Fallback or empty implementation
        op = self.badOp(instruction)
    elseif h == 0x1000 then
        -- BL(1)
        if (immediate & 0x0400) ~= 0 then
            immediate = immediate | 0xfffffc00
        end
        immediate = immediate << 12
        op = self.thumbCompiler:constructBL1(immediate)
        op = funcTable(op)
        op.writesPC = false
    elseif h == 0x1800 then
        -- BL(2)
        op = self.thumbCompiler:constructBL2(immediate)
        op = funcTable(op)
        op.writesPC = true
        op.fixedJump = false
    else
        op = self.badOp(instruction)
    end
    return op
end


function ARMCore:compileThumb(instruction)
    -- Normalize to 16-bit
    instruction = instruction & 0xffff
    local op = self.badOp(instruction)
    
    -- Top-level dispatch based on bit patterns
    
    if (instruction & 0xfc00) == 0x4000 then
        -- Data-processing register
        local rm = (instruction & 0x0038) >> 3
        local rd = instruction & 0x0007
        local handler = thumbAluHandlers[instruction & 0x03c0]
        if handler then
            op = handler(self, rd, rm)
            op = funcTable(op)
            op.writesPC = false
        end

    elseif (instruction & 0xfc00) == 0x4400 then
        -- Special data processing / branch/exchange
        local rm = (instruction & 0x0078) >> 3
        local rn = instruction & 0x0007
        local h1 = instruction & 0x0080
        local rd = rn | (h1 >> 4)
        local handler = thumbSpecialHandlers[instruction & 0x0300]
        if handler then
            op = handler(self, rd, rm)
        end

    elseif (instruction & 0xf800) == 0x1800 then
        -- Add/subtract
        local rm = (instruction & 0x01c0) >> 6
        local rn = (instruction & 0x0038) >> 3
        local rd = instruction & 0x0007
        local subCode = instruction & 0x0600
        
        -- Special logic for MOV(2) vs ADD(1) because they share opcode space 
        -- but differ on whether immediate is used, though the JS logic implies 
        -- 0x0400 covers both depending on implementation details.
        -- JS logic: case 0x0400: immediate ? ADD(1) : MOV(2)
        
        if subCode == 0x0400 then
            local immediate = (instruction & 0x01c0) >> 6
            if immediate ~= 0 then
                op = self.thumbCompiler:constructADD1(rd, rn, immediate)
            else
                op = self.thumbCompiler:constructMOV2(rd, rn, rm) -- Note: in MOV2 context, arg 3 is usually rm register index, check if immediate bits act as register index here? 
                -- In Thumb specs: if format is ADD Rd, Rs, Rn (0001100), rm is register.
                -- If format is ADD Rd, Rs, #Imm3 (0001110), immediate is value.
                -- The JS code uses: if (immediate) ADD1 else MOV2. 
                -- When immediate is 0, it treats it as MOV Rd, Rn (conceptually ADD Rd, Rn, #0). 
                -- However, MOV(2) in many docs refers to "ADD Rd, Rn, #0" or similar.
                -- We follow the JS logic exactly:
            end
        else
             local handler = thumbAddSubHandlers[subCode]
             if handler then
                 local arg
                 if subCode == 0x0600 then
                     arg = (instruction & 0x01c0) >> 6 -- immediate for SUB(1)
                 else
                     arg = rm -- register for others
                 end
                 op = handler(self, rd, rn, arg)
             end
        end
        op = funcTable(op)
        op.writesPC = false

    elseif (instruction & 0xe000) == 0 then
        -- Shift by immediate
        local rd = instruction & 0x0007
        local rm = (instruction & 0x0038) >> 3
        local immediate = (instruction & 0x07c0) >> 6
        local handler = thumbShiftImmHandlers[instruction & 0x1800]
        if handler then
            op = handler(self, rd, rm, immediate)
            op = funcTable(op)
            op.writesPC = false
        end

    elseif (instruction & 0xe000) == 0x2000 then
        -- Add/subtract/compare/move immediate
        local immediate = instruction & 0x00ff
        local rn = (instruction & 0x0700) >> 8
        local handler = thumbImmAluHandlers[instruction & 0x1800]
        if handler then
            op = handler(self, rn, immediate)
            op = funcTable(op)
            op.writesPC = false
        end

    elseif (instruction & 0xf800) == 0x4800 then
        -- LDR(3) - PC relative load
        local rd = (instruction & 0x0700) >> 8
        local immediate = (instruction & 0x00ff) << 2
        op = self.thumbCompiler:constructLDR3(rd, immediate)
        op = funcTable(op)
        op.writesPC = false

    elseif (instruction & 0xf000) == 0x5000 then
        -- Load and store with relative offset
        local rd = instruction & 0x0007
        local rn = (instruction & 0x0038) >> 3
        local rm = (instruction & 0x01c0) >> 6
        local handler = thumbLoadStoreRelHandlers[instruction & 0x0e00]
        if handler then
            op = handler(self, rd, rn, rm)
            op = funcTable(op)
            op.writesPC = false
        end

    elseif (instruction & 0xe000) == 0x6000 then
        -- Load and store with immediate offset
        local rd = instruction & 0x0007
        local rn = (instruction & 0x0038) >> 3
        local immediate = (instruction & 0x07c0) >> 6
        local b = (instruction & 0x1000) ~= 0
        
        -- JS logic: immediate = (instruction & 0x07c0) >> 4; if(b) imm >>= 2;
        -- This implies: Word transfer: imm is 5 bits << 2. Byte transfer: imm is 5 bits.
        -- Let's recalculate based on standard thumb specs:
        -- STR/LDR (imm): offset is (bits 6-10) << 2.
        -- STRB/LDRB (imm): offset is (bits 6-10).
        -- The JS code extracts bits 6-10 into variable `immediate` (shifted down by 4).
        -- Then if 'b' is set (byte access), it shifts right by 2. This seems backwards or specific to internal compiler expectation.
        -- Let's strictly translate the JS:
        -- var immediate = (instruction & 0x07c0) >> 4;
        -- if (b) immediate >>= 2;
        
        immediate = (instruction & 0x07c0) >> 4
        if b then
            immediate = immediate >> 2
        end
        
        local load = (instruction & 0x0800) ~= 0
        if load then
            if b then op = self.thumbCompiler:constructLDRB1(rd, rn, immediate)
            else      op = self.thumbCompiler:constructLDR1(rd, rn, immediate) end
        else
            if b then op = self.thumbCompiler:constructSTRB1(rd, rn, immediate)
            else      op = self.thumbCompiler:constructSTR1(rd, rn, immediate) end
        end
        op = funcTable(op)
        op.writesPC = false

    elseif (instruction & 0xf600) == 0xb400 then
        -- Push and pop registers
        local r = (instruction & 0x0100) 
        local rs = instruction & 0x00ff
        if (instruction & 0x0800) ~= 0 then
            -- POP
            op = self.thumbCompiler:constructPOP(rs, r)
            op = funcTable(op)
            op.writesPC = r ~= 0
            op.fixedJump = false
        else
            -- PUSH
            op = self.thumbCompiler:constructPUSH(rs, r)
            op = funcTable(op)
            op.writesPC = false
        end

    elseif (instruction & 0x8000) ~= 0 then
        -- Upper half (0x8000 - 0xFFFF)
        local handler = thumbUpperHalfHandlers[instruction & 0x7000]
        if handler then
            op = handler(self, instruction)
        else
            error("Undefined instruction: 0x" .. string.format("%x", instruction))
        end
        
    else
        error("Bad opcode: 0x" .. string.format("%x", instruction))
    end

    op.execMode = self.MODE_THUMB
    op.fixedJump = op.fixedJump or false
    return op
end

return ARMCore