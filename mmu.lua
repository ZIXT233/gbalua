local ClassUtils = require("ClassUtils")
local memory = require("memory")
local MemoryView = memory.MemoryView
local MemoryBlock = memory.MemoryBlock
local savedata = require("savedata")
local DataView = require("hal.DataView")
local ArrayBuffer = require("hal.ArrayBuffer")

local SRAMSaveData = savedata.SRAMSaveData
local FlashSaveData = savedata.FlashSaveData
local EEPROMSaveData = savedata.EEPROMSaveData

local ROMView = ClassUtils.class("ROMView", MemoryView)

function ROMView:ctor(rom, offset)
	self.super.ctor(self, rom, offset);
	self.ICACHE_PAGE_BITS = 10;
	self.PAGE_MASK = (2 << self.ICACHE_PAGE_BITS) - 1;
	self.icache = {};
	self.mask = 0x01ffffff;
	self:resetMask();
end
function ROMView:store8(offset, value) end
function ROMView:store16(offset, value) 
	if offset < 0xca and offset >= 0xc4 then
		if not self.gpio then
			self.gpio = self.mmu:allocGPIO(self);
		end
		self.gpio:store16(offset, value);
	end
end
function ROMView:store32(offset, value) 
	if offset < 0xca and offset >= 0xc4 then
		if not self.gpio then
			self.gpio = self.mmu:allocGPIO(self);
		end
		self.gpio:store32(offset, value);
	end
end



local BIOSView = ClassUtils.class("BIOSView", MemoryView)

function BIOSView:ctor(rom, offset)
	self.super.ctor(self, rom, offset);
	self.ICACHE_PAGE_BITS = 16;
	self.PAGE_MASK = (2 << self.ICACHE_PAGE_BITS) - 1;
	self.icache = {};
end
function BIOSView:load8(offset)
	if offset >= self.buffer.byteLength then
		return -1;
	end
	return self.view:getInt8(offset);
end
function BIOSView:load16(offset)
	if offset >= self.buffer.byteLength then
		return -1;
	end
	return self.view:getInt16(offset, true);
end
function BIOSView:loadU8(offset)
	if offset >= self.buffer.byteLength then
		return -1;
	end
	return self.view:getUint8(offset);
end
function BIOSView:loadU16(offset)
	if offset >= self.buffer.byteLength then
		return -1;
	end
	return self.view:getUint16(offset, true);
end
function BIOSView:load32(offset)
	if offset >= self.buffer.byteLength then
		return -1;
	end
	return self.view:getInt32(offset, true);
end
function BIOSView:store8(offset, value) end
function BIOSView:store16(offset, value) end
function BIOSView:store32(offset, value) end



local BadMemory = ClassUtils.class("BadMemory")

function BadMemory:ctor(mmu, cpu)
	self.cpu = cpu;
	self.mmu = mmu;
end
function BadMemory:load8(offset)
	return self.mmu:load8(
		self.cpu.gprs[self.cpu.PC] -
			self.cpu.instructionWidth +
			(offset & 0x3)
	);
end
function BadMemory:loadU8(offset)
	return self.mmu:loadU8(
		self.cpu.gprs[self.cpu.PC] -
			self.cpu.instructionWidth +
			(offset & 0x3)
	);
end
function BadMemory:loadU16(offset)
	return self.mmu:loadU16(
		self.cpu.gprs[self.cpu.PC] -
			self.cpu.instructionWidth +
			(offset & 0x2)
	);
end
function BadMemory:load32(offset)
	if self.cpu.execMode == self.cpu.MODE_ARM then
		return self.mmu:load32(
			self.cpu.gprs[self.cpu.gprs.PC] - self.cpu.instructionWidth
		);
	else
		local halfword = self.mmu:loadU16(
			self.cpu.gprs[self.cpu.PC] - self.cpu.instructionWidth
		);
		return halfword | (halfword << 16);
	end
end
function BadMemory:store8(offset, value) end
function BadMemory:store16(offset, value) end
function BadMemory:store32(offset, value) end
function BadMemory:invalidatePage(address) end



local GameBoyAdvanceMMU = ClassUtils.class("GameBoyAdvanceMMU")
function GameBoyAdvanceMMU:ctor()
	self.REGION_BIOS = 0x0;
	self.REGION_WORKING_RAM = 0x2;
	self.REGION_WORKING_IRAM = 0x3;
	self.REGION_IO = 0x4;
	self.REGION_PALETTE_RAM = 0x5;
	self.REGION_VRAM = 0x6;
	self.REGION_OAM = 0x7;
	self.REGION_CART0 = 0x8;
	self.REGION_CART1 = 0xa;
	self.REGION_CART2 = 0xc;
	self.REGION_CART_SRAM = 0xe;

	self.BASE_BIOS = 0x00000000;
	self.BASE_WORKING_RAM = 0x02000000;
	self.BASE_WORKING_IRAM = 0x03000000;
	self.BASE_IO = 0x04000000;
	self.BASE_PALETTE_RAM = 0x05000000;
	self.BASE_VRAM = 0x06000000;
	self.BASE_OAM = 0x07000000;
	self.BASE_CART0 = 0x08000000;
	self.BASE_CART1 = 0x0a000000;
	self.BASE_CART2 = 0x0c000000;
	self.BASE_CART_SRAM = 0x0e000000;

	self.BASE_MASK = 0x0f000000;
	self.BASE_OFFSET = 24;
	self.OFFSET_MASK = 0x00ffffff;

	self.SIZE_BIOS = 0x00004000;
	self.SIZE_WORKING_RAM = 0x00040000;
	self.SIZE_WORKING_IRAM = 0x00008000;
	self.SIZE_IO = 0x00000400;
	self.SIZE_PALETTE_RAM = 0x00000400;
	self.SIZE_VRAM = 0x00018000;
	self.SIZE_OAM = 0x00000400;
	self.SIZE_CART0 = 0x02000000;
	self.SIZE_CART1 = 0x02000000;
	self.SIZE_CART2 = 0x02000000;
	self.SIZE_CART_SRAM = 0x00008000;
	self.SIZE_CART_FLASH512 = 0x00010000;
	self.SIZE_CART_FLASH1M = 0x00020000;
	self.SIZE_CART_EEPROM = 0x00002000;

	self.DMA_TIMING_NOW = 0;
	self.DMA_TIMING_VBLANK = 1;
	self.DMA_TIMING_HBLANK = 2;
	self.DMA_TIMING_CUSTOM = 3;

	self.DMA_INCREMENT = 0;
	self.DMA_DECREMENT = 1;
	self.DMA_FIXED = 2;
	self.DMA_INCREMENT_RELOAD = 3;

	self.DMA_OFFSET = {[0]=1, -1, 0, 1};

	self.WAITSTATES = {[0]=0, 0, 2, 0, 0, 0, 0, 0, 4, 4, 4, 4, 4, 4, 4};
	self.WAITSTATES_32 ={[0]=0, 0, 5, 0, 0, 1, 0, 1, 7, 7, 9, 9, 13, 13, 8};
	self.WAITSTATES_SEQ = {[0]=0, 0, 2, 0, 0, 0, 0, 0, 2, 2, 4, 4, 8, 8, 4};
	self.WAITSTATES_SEQ_32 = {
		[0]=0,
		0,
		5,
		0,
		0,
		1,
		0,
		1,
		5,
		5,
		9,
		9,
		17,
		17,
		8
	};
	self.NULLWAIT = {[0]=0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

	for i = 15, 256-1 do
		self.WAITSTATES[i] = 0;
		self.WAITSTATES_32[i] = 0;
		self.WAITSTATES_SEQ[i] = 0;
		self.WAITSTATES_SEQ_32[i] = 0;
		self.NULLWAIT[i] = 0;
	end

	self.ROM_WS = {[0]=4, 3, 2, 8};
	self.ROM_WS_SEQ = {
		[0] = {[0]=2, 1},
		{[0]=4, 1},
		{[0]=8, 1}
	};

	self.ICACHE_PAGE_BITS = 8;
	self.PAGE_MASK = (2 << self.ICACHE_PAGE_BITS) - 1;

	self.bios = nil;
end

local NOMAP = -1;
function GameBoyAdvanceMMU:mmap(region,object)
	self.memory[region] = object;
end

local table_shallow_copy = function(table)
	local newTable = {}
	for k, v in pairs(table) do
		newTable[k] = v
	end
	return newTable
end
function GameBoyAdvanceMMU:clear()
	self.badMemory = BadMemory.new(self, self.cpu);
	self.memory = {
	[0]=self.bios,
		self.badMemory,
		MemoryBlock.new(self.SIZE_WORKING_RAM, 9),
		MemoryBlock.new(self.SIZE_WORKING_IRAM, 7),
		NOMAP, -- this is owned by GameBoyAdvanceIO
		NOMAP, -- this is owned by GameBoyAdvancePalette
		NOMAP, -- this is owned by GameBoyAdvanceVRAM
		NOMAP, -- this is owned by GameBoyAdvanceOAM
		self.badMemory,
		self.badMemory,
		self.badMemory,
		self.badMemory,
		self.badMemory,
		self.badMemory,
		self.badMemory,
		self.badMemory -- Unused
	}
	for i=16,256-1 do
		self.memory[i] = self.badMemory;
	end
	self.waitstates = table_shallow_copy(self.WAITSTATES);
	self.waitstatesSeq = table_shallow_copy(self.WAITSTATES_SEQ);
	self.waitstates32 = table_shallow_copy(self.WAITSTATES_32);
	self.waitstatesSeq32 = table_shallow_copy(self.WAITSTATES_SEQ_32);
	self.waitstatesPrefetch = table_shallow_copy(self.WAITSTATES_SEQ);
	self.waitstatesPrefetch32 = table_shallow_copy(self.WAITSTATES_SEQ_32);

	self.cart = nil;
	self.save = nil;

	self.DMA_REGISTER = {
	[0]=self.core.io.DMA0CNT_HI >> 1,
		self.core.io.DMA1CNT_HI >> 1,
		self.core.io.DMA2CNT_HI >> 1,
		self.core.io.DMA3CNT_HI >> 1
	}
end

function GameBoyAdvanceMMU:freeze()
	return {
		ram = Serializer.prefix(self.memory[self.REGION_WORKING_RAM].buffer),
		iram= Serializer.prefix(
			self.memory[self.REGION_WORKING_IRAM].buffer
		)
	}
end

function GameBoyAdvanceMMU:defrost(frost) 
	self.memory[self.REGION_WORKING_RAM].replaceData(frost.ram);
	self.memory[self.REGION_WORKING_IRAM].replaceData(frost.iram);
end

function GameBoyAdvanceMMU:loadBios(bios, real) 
	self.bios = BIOSView.new(bios);
	self.bios.real = real;
end

function GameBoyAdvanceMMU:loadRomSimple(rom)

	local lo = ROMView.new(rom);
	

	lo.mmu = self;
	self.memory[self.REGION_CART0] = lo;
	self.memory[self.REGION_CART1] = lo;
	self.memory[self.REGION_CART2] = lo;

	if rom.byteLength > 0x01000000 then
		local hi = ROMView.new(rom, 0x01000000);
		self.memory[self.REGION_CART0 + 1] = hi;
		self.memory[self.REGION_CART1 + 1] = hi;
		self.memory[self.REGION_CART2 + 1] = hi;
	end
end

function GameBoyAdvanceMMU:loadRom(rom, process)
	local cart = {
		title = nil,
		code = nil,
		make = nil,
		memory = rom,
		saveType = nil
	};

	local lo = ROMView.new(rom);
	if lo.view:getUint8(0xb2) ~= 0x96 then
		return nil;
	end

	lo.mmu = self;
	self.memory[self.REGION_CART0] = lo;
	self.memory[self.REGION_CART1] = lo;
	self.memory[self.REGION_CART2] = lo;

	if rom.byteLength > 0x01000000 then
		local hi = ROMView.new(rom, 0x01000000);
		self.memory[self.REGION_CART0 + 1] = hi;
		self.memory[self.REGION_CART1 + 1] = hi;
		self.memory[self.REGION_CART2 + 1] = hi;
	end

	if process then
		local name = ""
		for i=0,12-1 do
			local c = lo:loadU8(i + 0xa0);
			if not c then
				break;
			end
			name = name .. string.char(c);
		end

		cart.title = name;

		local code = ""
		for i=0, 4-1 do
			local c = lo:loadU8(i + 0xac);
			if not c then
				break;
			end
			code = code .. string.char(c);
		end

		cart.code = code;

		local maker = ""
		for i=0, 2-1 do
			local c = lo:loadU8(i + 0xb0);
			if not c then
				break;
			end
			maker = maker .. string.char(c);
		end
		cart.maker = maker;

		-- Find savedata type
		local state = "";
		local next;
		local terminal = 0;
		local if_terminal = {
			F = 0,
			FL = 0,
			FLA = 0,
			FLAS = 0,
			FLASH = 0,
			FLASH_ = 0,
			FLASH5 = 0,
			FLASH51 = 0,
			FLASH512 = 0,
			FLASH512_ = 0,
			FLASH1 = 0,
			FLASH1M = 0,
			FLASH1M_ = 0,
			S = 0,
			SR = 0,
			SRA = 0,
			SRAM = 0,
			SRAM_ = 0,
			E = 0,
			EE = 0,
			EEP = 0,
			EEPR = 0,
			EEPRO = 0,
			EEPROM = 0,
			EEPROM_ = 0,
			FLASH_V = 1,
			FLASH512_V = 1,
			FLASH1M_V = 1,
			SRAM_V = 1,
			EEPROM_V = 1,
		}
		local i = 0xe4;
		print(string.format("Scanning save type..."))
		while i< rom.byteLength and terminal ~= 1 do
			next = string.char(lo:loadU8(i));
			state = state .. next;
			terminal = if_terminal[state];
			if terminal == nil then
				terminal = 0;
				state = next;
			end
			i = i+1;
		end
		print(string.format("Find save type= %s in %d", state, i))

		if terminal == 1 then
			cart.saveType = state;
			if state == "FLASH_V" or state == "FLASH512_V" then
				self.save  = FlashSaveData.new(self.SIZE_CART_FLASH512);
				self.memory[self.REGION_CART_SRAM] = self.save;
			elseif state == "FLASH1M_V" then
				self.save = FlashSaveData.new(self.SIZE_CART_FLASH1M);
				self.memory[self.REGION_CART_SRAM] = self.save;
			elseif state == "SRAM_V" then
				self.save = SRAMSaveData.new(self.SIZE_CART_SRAM);
				self.memory[self.REGION_CART_SRAM] = self.save;
			elseif state == "EEPROM_V" then
				self.save = EEPROMSaveData.new(self.SIZE_CART_EEPROM, self);
				self.memory[self.REGION_CART2 + 1] = self.save;
			end
		end

		if not self.save then
			self.save = SRAMSaveData.new(self.SIZE_CART_SRAM);
			self.memory[self.REGION_CART_SRAM] = self.save;
		end
	end

	self.cart = cart;
	return cart;
end

function GameBoyAdvanceMMU:loadSavedata(save)
	self.save:replaceData(save);
end

function GameBoyAdvanceMMU:load8(offset) 
	return self.memory[offset >> self.BASE_OFFSET]:load8(
		offset & 0x00ffffff
	);
end
function GameBoyAdvanceMMU:load16(offset) 
	return self.memory[offset>> self.BASE_OFFSET]:load16(
		offset & 0x00ffffff
	);
end

function GameBoyAdvanceMMU:load32(offset) 
	return self.memory[offset >> self.BASE_OFFSET]:load32(
		offset & 0x00ffffff
	);
end
function GameBoyAdvanceMMU:loadU8(offset) 
	return self.memory[offset >> self.BASE_OFFSET]:loadU8(
		offset & 0x00ffffff
	);
end
function GameBoyAdvanceMMU:loadU16(offset) 
	return self.memory[offset >> self.BASE_OFFSET]:loadU16(
		offset & 0x00ffffff
	);
end


function GameBoyAdvanceMMU:store8(offset, value) 
	local maskedOffset = offset & 0x00ffffff;
	local memory = self.memory[offset >> self.BASE_OFFSET];
	memory:store8(maskedOffset, value);
	memory:invalidatePage(maskedOffset);
end
function GameBoyAdvanceMMU:store16(offset, value) 
	local maskedOffset = offset & 0x00fffffe;
	local memory = self.memory[offset >> self.BASE_OFFSET];
	memory:store16(maskedOffset, value);
	memory:invalidatePage(maskedOffset);
end
function GameBoyAdvanceMMU:store32(offset, value) 
	local maskedOffset = offset & 0x00fffffc; 
	local memory = self.memory[offset >> self.BASE_OFFSET];
	--print(string.format("%X %X",maskedOffset, offset >> self.BASE_OFFSET))
	memory:store32(maskedOffset, value);
	memory:invalidatePage(maskedOffset);
	memory:invalidatePage(maskedOffset + 2);
end
function GameBoyAdvanceMMU:waitPrefetch(memory) 
	self.cpu.cycles = self.cpu.cycles +
		1 + self.waitstatesPrefetch[memory >> self.BASE_OFFSET];
end
function GameBoyAdvanceMMU:waitPrefetch32(memory) 
	self.cpu.cycles = self.cpu.cycles +
		1 + self.waitstatesPrefetch32[memory >> self.BASE_OFFSET];
end



function GameBoyAdvanceMMU:wait(memory) 
	self.cpu.cycles = self.cpu.cycles + 1 + self.waitstates[memory >> self.BASE_OFFSET];
end
function GameBoyAdvanceMMU:wait32(memory) 
	self.cpu.cycles = self.cpu.cycles + 1 + self.waitstates32[memory >> self.BASE_OFFSET];
end
function GameBoyAdvanceMMU:waitSeq(memory) 
	self.cpu.cycles = self.cpu.cycles + 1 + self.waitstatesSeq[memory >> self.BASE_OFFSET];
end
function GameBoyAdvanceMMU:waitSeq32(memory) 
	self.cpu.cycles = self.cpu.cycles +
		1 + self.waitstatesSeq32[memory >> self.BASE_OFFSET];
end
function GameBoyAdvanceMMU:waitMul(rs) 
	if (rs & 0xffffff00) == 0xffffff00 or not (rs & 0xffffff00) then
		self.cpu.cycles = self.cpu.cycles + 1;
	elseif (rs & 0xffff0000) == 0xffff0000 or not (rs & 0xffff0000) then
		self.cpu.cycles = self.cpu.cycles + 2;
	elseif (rs & 0xff000000) == 0xff000000 or not (rs & 0xff000000) then
		self.cpu.cycles = self.cpu.cycles + 3;
	else
		self.cpu.cycles = self.cpu.cycles + 4;
	end
end
function GameBoyAdvanceMMU:waitMulti32(memory, seq) 
	self.cpu.cycles = self.cpu.cycles + 1 + self.waitstates32[memory >> self.BASE_OFFSET];
	self.cpu.cycles = self.cpu.cycles +
		(1 + self.waitstatesSeq32[memory >> self.BASE_OFFSET]) * (seq - 1);
end

function GameBoyAdvanceMMU:addressToPage(region, address) 
	--debugprint(string.format("addressToPage: region=%X, address=%X", region, address))
	return address >> self.memory[region].ICACHE_PAGE_BITS;
end
function GameBoyAdvanceMMU:accessPage(region, pageId) 
	local memory = self.memory[region];
	local page = memory.icache[pageId];
	if not page or page.invalid then
		page = {
			thumb = {},
			arm = {},
			invalid = false
		};
		memory.icache[pageId] = page;
	end
	return page;
end

function GameBoyAdvanceMMU:scheduleDma(number, info) 
	if self.core.debugHooks and self.core.debugHooks.dma then
		print(string.format("[DMA%d schedule] src=0x%08X dst=0x%08X count=%d timing=%d enable=%s",
			number, info.nextSource, info.nextDest, info.nextCount, info.timing, info.enable and "Y" or "N"))
	end
	if info.timing == self.DMA_TIMING_NOW then
		self:serviceDma(number, info);
	elseif info.timing == self.DMA_TIMING_HBLANK then
		-- Handled implicitly
	elseif info.timing == self.DMA_TIMING_VBLANK then
		-- Handled implicitly
	elseif info.timing == self.DMA_TIMING_CUSTOM then
		if number == 0 then
			self.core:WARN("Discarding invalid DMA0 scheduling");
		elseif number == 1 or number == 2 then
			--blockself.cpu.irq.audio:scheduleFIFODma(number, info);
		elseif number == 3 then
			self.cpu.irq.video:scheduleVCaptureDma(dma, info);
		end
	end
end


function GameBoyAdvanceMMU:runHblankDmas() 
	local dma;
	for i = 0, #self.cpu.irq.dma do
		dma = self.cpu.irq.dma[i];
		if dma.enable and dma.timing == self.DMA_TIMING_HBLANK then
			self:serviceDma(i, dma);
		end
	end
end
function GameBoyAdvanceMMU:runVblankDmas() 
	local dma;
	for i = 0, #self.cpu.irq.dma do
		dma = self.cpu.irq.dma[i];
		if dma.enable and dma.timing == self.DMA_TIMING_VBLANK then
			self:serviceDma(i, dma);
		end
	end
end
function GameBoyAdvanceMMU:serviceDma(number, info) 
	if not info.enable then
		-- There was a DMA scheduled that got canceled
		return;
	end
	if self.core.debugHooks and self.core.debugHooks.dma then
		local srcR = info.nextSource >> self.BASE_OFFSET
		local dstR = info.nextDest >> self.BASE_OFFSET
		print(string.format("[DMA%d execute] src=0x%08X(region%X) dst=0x%08X(region%X) words=%d %dbit",
			number, info.nextSource, srcR, info.nextDest, dstR, info.nextCount, info.width * 8))
	end

	local width = info.width;
	local sourceOffset = self.DMA_OFFSET[info.srcControl] * width;
	local destOffset = self.DMA_OFFSET[info.dstControl] * width;
	local wordsRemaining = info.nextCount;
	local source = info.nextSource & self.OFFSET_MASK;
	local dest = info.nextDest & self.OFFSET_MASK;
	local sourceRegion = info.nextSource >> self.BASE_OFFSET;
	local destRegion = info.nextDest >> self.BASE_OFFSET;
	local sourceBlock = self.memory[sourceRegion];
	local destBlock = self.memory[destRegion];
	local sourceView = nil;
	local destView = nil;
	local sourceMask = 0xffffffff;
	local destMask = 0xffffffff;
	local word;

	if destBlock.ICACHE_PAGE_BITS then
		local endPage = (dest + wordsRemaining * width) >> destBlock.ICACHE_PAGE_BITS;
		for i = dest >> destBlock.ICACHE_PAGE_BITS, endPage do
			destBlock:invalidatePage(i << destBlock.ICACHE_PAGE_BITS);
		end
	end

	if destRegion == self.REGION_WORKING_RAM or destRegion == self.REGION_WORKING_IRAM then
		destView = destBlock.view;
		destMask = destBlock.mask;
	end

	if sourceRegion == self.REGION_WORKING_RAM or sourceRegion == self.REGION_WORKING_IRAM or sourceRegion == self.REGION_CART0 or sourceRegion == self.REGION_CART1 then
		sourceView = sourceBlock.view;
		sourceMask = sourceBlock.mask;
	end

	if sourceBlock and destBlock then
		if sourceView and destView then
			if width == 4 then
				source = source & 0xfffffffc;
				dest = dest & 0xfffffffc;
				while wordsRemaining > 0 do
					word = sourceView:getInt32(source & sourceMask);
					destView:setInt32(dest & destMask, word);
					source = source +  sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			else
				while wordsRemaining > 0 do
					word = sourceView:getUint16(source & sourceMask);
					destView:setUint16(dest & destMask, word);
					source = source + sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			end
		elseif sourceView then
			if width == 4 then
				source = source & 0xfffffffc;
				dest = dest & 0xfffffffc;
				while wordsRemaining > 0 do
					word = sourceView:getInt32(source & sourceMask, true);
					destBlock:store32(dest, word);
					source = source + sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			else
				while wordsRemaining > 0 do
					word = sourceView:getUint16(source & sourceMask, true);
					destBlock:store16(dest, word);
					source = source + sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			end
		else
			if width == 4 then
				source = source & 0xfffffffc;
				dest = dest & 0xfffffffc;
				while wordsRemaining > 0 do
					word = sourceBlock:load32(source);
					destBlock:store32(dest, word);
					source = source + sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			else 
				while wordsRemaining > 0 do
					word = sourceBlock:loadU16(source);
					destBlock:store16(dest, word);
					source = source + sourceOffset;
					dest = dest + destOffset;
					wordsRemaining = wordsRemaining - 1;
				end
			end
		end
	else
		self.core:WARN("Invalid DMA");
	end

	if info.doIrq then
		info.nextIRQ = self.cpu.cycles + 2;
		if width == 4 then
			info.nextIRQ = info.nextIRQ + self.waitstates32[sourceRegion] + self.waitstates32[destRegion];
			info.nextIRQ = info.nextIRQ + (info.count - 1) * (self.waitstatesSeq32[sourceRegion] + self.waitstatesSeq32[destRegion]);
		else
			info.nextIRQ = info.nextIRQ + self.waitstates[sourceRegion] + self.waitstates[destRegion];
			info.nextIRQ = info.nextIRQ + (info.count - 1) * (self.waitstatesSeq[sourceRegion] + self.waitstatesSeq[destRegion]);
		end
	end

	info.nextSource = source | (sourceRegion << self.BASE_OFFSET);
	info.nextDest = dest | (destRegion << self.BASE_OFFSET);
	info.nextCount = wordsRemaining;
	if not info["repeat"] then
		info.enable = false;

		-- Clear the enable bit in memory
		local io = self.memory[self.REGION_IO];
		io.registers[self.DMA_REGISTER[number]] = io.registers[self.DMA_REGISTER[number]] & 0x7fe0;
	else
		info.nextCount = info.count;
		if info.dstControl == self.DMA_INCREMENT_RELOAD then
			info.nextDest = info.dest;
		end
		self:scheduleDma(number, info);
	end
end


function GameBoyAdvanceMMU:adjustTimings(word) 
	local sram = word & 0x0003;
	local ws0 = (word & 0x000c) >> 2;
	local ws0seq = (word & 0x0010) >> 4;
	local ws1 = (word & 0x0060) >> 5;
	local ws1seq = (word & 0x0080) >> 7;
	local ws2 = (word & 0x0300) >> 8;
	local ws2seq = (word & 0x0400) >> 10;
	local prefetch = word & 0x4000;

	self.waitstates[self.REGION_CART_SRAM] = self.ROM_WS[sram];
	self.waitstatesSeq[self.REGION_CART_SRAM] = self.ROM_WS[sram];
	self.waitstates32[self.REGION_CART_SRAM] = self.ROM_WS[sram];
	self.waitstatesSeq32[self.REGION_CART_SRAM] = self.ROM_WS[sram];

	self.waitstates[self.REGION_CART0 + 1] = self.ROM_WS[ws0];
	self.waitstates[self.REGION_CART0] = self.ROM_WS[ws0];


	self.waitstates[self.REGION_CART1 + 1] = self.ROM_WS[ws1];
	self.waitstates[self.REGION_CART1] = self.ROM_WS[ws1];

	self.waitstates[self.REGION_CART2 + 1] = self.ROM_WS[ws2];
	self.waitstates[self.REGION_CART2] = self.ROM_WS[ws2];

	self.waitstatesSeq[self.REGION_CART0] = self.ROM_WS_SEQ[0][ws0seq];
	self.waitstatesSeq[self.REGION_CART0 + 1] = self.ROM_WS_SEQ[0][ws0seq];



	self.waitstatesSeq[self.REGION_CART1] = self.ROM_WS_SEQ[1][ws1seq];
	self.waitstatesSeq[self.REGION_CART1 + 1] = self.ROM_WS_SEQ[1][ws1seq];


	self.waitstatesSeq[self.REGION_CART2] = self.ROM_WS_SEQ[2][ws2seq];
	self.waitstatesSeq[self.REGION_CART2 + 1] = self.ROM_WS_SEQ[2][ws2seq];

	self.waitstates32[self.REGION_CART0] = self.waitstates[self.REGION_CART0] + 1 + self.waitstatesSeq[self.REGION_CART0];
	self.waitstates32[self.REGION_CART0 + 1] = self.waitstates[self.REGION_CART0 + 1] + 1 + self.waitstatesSeq[self.REGION_CART0 + 1];
	
	self.waitstates32[self.REGION_CART1] = self.waitstates[self.REGION_CART1] + 1 + self.waitstatesSeq[self.REGION_CART1];
	self.waitstates32[self.REGION_CART1 + 1] = self.waitstates[self.REGION_CART1 + 1] + 1 + self.waitstatesSeq[self.REGION_CART1 + 1];


	self.waitstates32[self.REGION_CART2] = self.waitstates[self.REGION_CART2] + 1 + self.waitstatesSeq[self.REGION_CART2];
	self.waitstates32[self.REGION_CART2 + 1] = self.waitstates[self.REGION_CART2 + 1] + 1 + self.waitstatesSeq[self.REGION_CART2 + 1];

	self.waitstatesSeq32[self.REGION_CART0] = 2 * self.waitstatesSeq[self.REGION_CART0] + 1;
	self.waitstatesSeq32[self.REGION_CART0 + 1] = 2 * self.waitstatesSeq[self.REGION_CART0 + 1] + 1;

	self.waitstatesSeq32[self.REGION_CART1] = 2 * self.waitstatesSeq[self.REGION_CART1] + 1;
	self.waitstatesSeq32[self.REGION_CART1 + 1] = 2 * self.waitstatesSeq[self.REGION_CART1 + 1] + 1;

	self.waitstatesSeq32[self.REGION_CART2] = 2 * self.waitstatesSeq[self.REGION_CART2] + 1;
	self.waitstatesSeq32[self.REGION_CART2 + 1] = 2 * self.waitstatesSeq[self.REGION_CART2 + 1] + 1;

	if prefetch then
		self.waitstatesPrefetch[self.REGION_CART0] = 0;
		self.waitstatesPrefetch[self.REGION_CART0 + 1] = 0;
		self.waitstatesPrefetch[self.REGION_CART1] = 0;
		self.waitstatesPrefetch[self.REGION_CART1 + 1] = 0;
		self.waitstatesPrefetch[self.REGION_CART2] = 0;
		self.waitstatesPrefetch[self.REGION_CART2 + 1] = 0;

		self.waitstatesPrefetch32[self.REGION_CART0] = 0;
		self.waitstatesPrefetch32[self.REGION_CART0 + 1] = 0;
		self.waitstatesPrefetch32[self.REGION_CART1] = 0;
		self.waitstatesPrefetch32[self.REGION_CART1 + 1] = 0;
		self.waitstatesPrefetch32[self.REGION_CART2] = 0;
		self.waitstatesPrefetch32[self.REGION_CART2 + 1] = 0;
	else
		self.waitstatesPrefetch[self.REGION_CART0] = self.waitstatesSeq[self.REGION_CART0];
		self.waitstatesPrefetch[self.REGION_CART0 + 1] = self.waitstatesSeq[self.REGION_CART0];

		self.waitstatesPrefetch[self.REGION_CART1] = self.waitstatesSeq[self.REGION_CART1];
		self.waitstatesPrefetch[self.REGION_CART1 + 1] = self.waitstatesSeq[self.REGION_CART1 + 1];


		self.waitstatesPrefetch[self.REGION_CART2] = self.waitstatesSeq[self.REGION_CART2];
		self.waitstatesPrefetch[self.REGION_CART2 + 1] = self.waitstatesSeq[self.REGION_CART2 + 1];

		self.waitstatesPrefetch32[self.REGION_CART0] = self.waitstatesSeq32[self.REGION_CART0];
		self.waitstatesPrefetch32[self.REGION_CART0 + 1] = self.waitstatesSeq32[self.REGION_CART0 + 1];

		self.waitstatesPrefetch32[self.REGION_CART1] = self.waitstatesSeq32[self.REGION_CART1];
		self.waitstatesPrefetch32[self.REGION_CART1 + 1] = self.waitstatesSeq32[self.REGION_CART1 + 1];

		self.waitstatesPrefetch32[self.REGION_CART2] = self.waitstatesSeq32[self.REGION_CART2];
		self.waitstatesPrefetch32[self.REGION_CART2 + 1] = self.waitstatesSeq32[self.REGION_CART2 + 1];

	end
end

function GameBoyAdvanceMMU:saveNeedsFlush() 
	if not self.save then return false end
	return self.save.writePending;
end

function GameBoyAdvanceMMU:flushSave()
	if self.save then
		self.save.writePending = false;
	end
end

function GameBoyAdvanceMMU:allocGPIO(rom)
	return GameBoyAdvanceGPIO.new(self.core, rom);
end

return {
	MMU = GameBoyAdvanceMMU,
	MemoryBlock = MemoryBlock,
}