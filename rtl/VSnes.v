//============================================================================
//
// VS NES Arcade
// Copyright (c) 2025 Blue212
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//============================================================================

module nes_system (
	input Clk,
	//input Clk4x,	 
	input Reset,
	output [23:0] VideoOut,
	output [15:0] AudioOut,
	
	output VBlank,
	output HBlank,
	output VSync,
	output HSync,
	output PCLK,
	
	output [10:0]NVramAddress,	 
	output [7:0]NVDataOut,
	input [7:0]NVDataq,
	output NVcs,
	
	input primary,
	input IRQin,
	
	input [3:0]PALETTE,
	input [3:0]PPUtype,
	input [2:0]Mapper,	 
	
	input [7:0] dipsw,
	
	input [7:0] romreadCHR,
	input [7:0] romreadPRG,	 
	output PPU_nRD,
	output CPU_nRD,
	output [16:0] CPUAddr,
	output [16:0] PPUAddr,
	
	output [2:0] OUT,
	output [1:0] nIN,
	input controller1_data,
	input controller2_data, 
	input service,
	input coin1,
	input coin2	
);

wire [7:0] CPU_DataBus;
reg [7:0] PPU_DataBus;
wire [15:0] CPU_AddressBus;
wire [13:0] PPU_AddressBus;
wire M2;
wire CPURnW;
wire nIRQ;
wire nROMSEL = ~(M2 && CPU_AddressBus[15]);
wire PPU_nWR;
wire ALE;
//wire CIRAMCE;
wire nNMI;
//wire CIRAMA10;
wire PPURnW;
wire [7:0] cpuq;
wire [7:0] ppuq;
wire [7:0] CHRramq;
reg [7:0] NV_DataOut;	 
reg [7:0] CPU_DataIn;
reg [7:0] PPU_DataOut;
wire [7:0] DBIN;	 
wire DB_PAR;
reg [7:0] cpuCSn;
wire useCHRram;


//*watchdog not implemented
  
///////////////////////////////////////////////////////////////
//ram 
//MDST-21-13 HM6116 2k x 8bit Static RAM, 250ns (1E,6E)
//MDST-21-14 MB8416-15 2k x 8bit Static CMOS RAM 150ns (8L)
//MDST-21-15 TC5533P-A 4k x 8bit Static RAM (2C)
//MDST-21-16 TC5533P-B 4k x 8bit Static RAM (8C)
 
//2kB RAM for CPU Work RAM () 1E,6E
ram2k cpuram (
	.address(CPU_AddressBus[10:0]),
	.clock(Clk),
	.data(CPU_DataBus),
	.wren(!cpuCSn[0] && !CPURnW),
	.q(cpuq)
); 

//4kB RAM for PPU Video RAM (VRAM) 2C,8C
ram4k vram (
	.address({PPU_AddressBus[11:8], BA}),
	.clock(Clk),
	.data(PPU_DataOut),
	.wren(PPU_AddressBus[13] && !PPU_nWR),
	.q(ppuq)
);

//8kB RAM for CHR ram (on daughtercard) 
ram8k chrram (
	.address({PPU_AddressBus[12:8], BA}),
	.clock(Clk),
	.data(PPU_DataOut),
	.wren(!PPU_AddressBus[13] && !PPU_nWR),
	.q(CHRramq)
);

///////////////////////////////////////////////////////////////	 
  
//CPU (RP2A03) 2J,8J 
RP2A03 cpu1 (
	.Clk(Clk),
	.PAL(1'b0),                               // NTSC Mode (PAL disabled)
	.nNMI(~nNMI), //seems backwards.          // CPU Non-maskable Interrupt
	//.nNMI(nNMI),
	.nIRQ_EXT(nIRQ),                          // CPU External IRQ
	.nRES(~Reset),                            // Active-low Reset
	.DB(CPU_DataBus),                         // CPU Data Bus
	.ADDR_BUS(CPU_AddressBus),                // CPU Address Bus
	.RnW(CPURnW),                             // CPU Read/Write Signal 0=write, 1=read
	.M2_out(M2),                              // M2 Phase
	.SOUT(SOUT),                              // Mixed Audio Output
	.SQA(SQA),
	.SQB(SQB),
	.RND(RND),
	.TRIA(TRIA),
	.DMC(DMC),
	.OUT(OUT),
	.nIN(nIN) //{nR4017, nR4016} 		  
);

//PPU (RP2C0?) 2F,8F
RP2C02 ppu1 (
	.Clk(Clk),                                // PPU Clock
	.Clk2(Clk),                               // Clock 21.477/26.601 for divider
	.MODE(1'b0),                              // PAL/NTSC mode
	.DENDY(1'b0),                             // DENDY Mode Disabled
	.nRES(~Reset),                            // Active-low Reset
	.RnW(CPURnW),                             // External Pin Read/Write
	.nDBE((cpuCSn[1] || !M2)),                // PPU access strobe
	.PALETTE(PALETTE),                        // Palette selector
	.PPUtype(PPUtype),
	.A(CPU_AddressBus[2:0]),                  // Register address
	.PD(PPU_DataBus),                         // PPU Graphics Data Bus Input
	.DB(CPU_DataBus),                         // CPU External Data Bus		  
	.PCLK(PCLK),                              // PIX Clock
	.RGB(VideoOut),                           // RGB Video Output
	.PAD(PPU_AddressBus),                     // PPU Address Bus
	.INT(nNMI),                               // Non-maskable Interrupt
	.ALE(ALE),                                // ALE VRAM Address Low Byte Latch Strobe
	.nWR(PPU_nWR),                            // VRAM Write
	.nRD(PPU_nRD),                            // VRAM Read
	.DBIN(DBIN),                              // CPU Internal Data Bus
	.DB_PAR(DB_PAR),                          // Forwarding CPU data to PPU bus	
	.HS(HSync),
	.VS(VSync),
	.HB(HBlank),
	.VB(VBlank)
);  

///////////////////////////////////////////////////////////////
//mappers
Mappers mappers (
	.Clk(Clk),
	.Reset(Reset),	
	.CPU_AddressBus(CPU_AddressBus),	
	.CPU_DataBus(CPU_DataBus),
	.PPU_AddressBus(PPU_AddressBus),
	.BA(BA),
	.Mapper(Mapper),
	.M2(M2),
	.CPURnW(CPURnW),
	.OUT(OUT),
	.cpuCSn(cpuCSn),	
	.CPUAddr(CPUAddr),
	.PPUAddr(PPUAddr),
	.useCHRram(useCHRram)    	
);

///////////////////////////////////////////////////////////////
//nvram 

assign NVramAddress = CPU_AddressBus[10:0];
assign NVDataOut = NV_DataOut;
assign NVcs = !cpuCSn[3] && !M2 && !CPURnW;

always @(posedge Clk) begin//Clked to get rid of latch
	if ((!cpuCSn[3] || !M2) && !CPURnW) NV_DataOut <= CPU_DataBus;
end  

/////////////////////////////////////////////////////////////// 
//ppu 

always @(*) begin
	if (!PPU_nRD && PPU_AddressBus[13]) begin
		PPU_DataBus = ppuq;
	end else if (!PPU_nRD && !PPU_AddressBus[13]) begin
		PPU_DataBus = useCHRram ? CHRramq : romreadCHR;		
	end else 
		PPU_DataBus = 8'hFF;//8'bz;
end

always @(posedge Clk) begin//Clked to get rid of latch
	if (!PPU_nWR) begin
		if (DB_PAR) PPU_DataOut <= DBIN;
	else
		PPU_DataOut <= PPU_AddressBus[7:0];
	end
end 

//74LS373 at 2E 
reg [7:0] BA;
 
always @(posedge Clk) begin//Clked to get rid of latch
	if (ALE) BA <= PPU_AddressBus[7:0];
end  

/////////////////////////////////////////////////////////////// 
//cpu

assign CPU_nRD = ~(CPURnW && M2 && CPU_AddressBus[15]);  

assign CPU_DataBus = CPURnW && cpuCSn[1] ? CPU_DataIn : 8'bz;//when nDBE(cpuCSn[1]) is low this lets ppu output data to the CPU_DataBus from DB

always @(posedge Clk) begin//Clked to get rid of latch
	if (!cpuCSn[0] && CPURnW)
		CPU_DataIn <= cpuq;
	else if (!cpuCSn[1] && CPURnW)
		CPU_DataIn <= DBIN;
	else if (!cpuCSn[3] && CPURnW)
		CPU_DataIn <= NVDataq;
	else if (!nROMSEL && CPURnW)
		CPU_DataIn <= romreadPRG;
	else if (!nIN[0] && CPURnW)
		CPU_DataIn <= {~primary, coin2, coin1, dipsw[1:0], service, 1'b0, controller1_data};
	else if (!nIN[1] && CPURnW)
		CPU_DataIn <= {dipsw[7:2], 1'b0, controller2_data};
end   

//74LS138 at 1F
always @(*) begin
	case ({CPU_AddressBus[15], CPU_AddressBus[14], CPU_AddressBus[13]})
		3'b000: cpuCSn = 8'b11111110;//0000-1FFF
		3'b001: cpuCSn = 8'b11111101;//2000-3FFF
		3'b010: cpuCSn = 8'b11111011;//4000-5FFF
		3'b011: cpuCSn = 8'b11110111;//6000-7FFF
		3'b100: cpuCSn = 8'b11101111;//8000-9FFF
		3'b101: cpuCSn = 8'b11011111;//A000-BFFF
		3'b110: cpuCSn = 8'b10111111;//C000-DFFF
		3'b111: cpuCSn = 8'b01111111;//E000-FFFF
		default: ;
	endcase
end

assign nIRQ = IRQin;//(Mapper == 6) ? irq6 : IRQin;

/////////////////////////////////////////////////////////////// 
//audio

wire [3:0] SQA;
wire [3:0] SQB;
wire [3:0] RND;
wire [3:0] TRIA;
wire [6:0] DMC;
wire [5:0] SOUT;//unused

//pulse_table [n] = 95.52 / (8128.0 / n + 100)
//tnd_table [n] = 163.67 / (24329.0 / n + 100)
//scaled to 15 bit

//31 values
logic [15:0] pulse_table[32];
assign pulse_table = '{
	16'h0000, 16'h017C, 16'h02F0, 16'h045A, 16'h05BC, 16'h0716, 16'h0868, 16'h09B2,
	16'h0AF5, 16'h0C30, 16'h0D65, 16'h0E93, 16'h0FBA, 16'h10DC, 16'h11F7, 16'h130C,
	16'h141C, 16'h1526, 16'h162B, 16'h172A, 16'h1825, 16'h191A, 16'h1A0B, 16'h1AF7,
	16'h1BDF, 16'h1CC2, 16'h1DA2, 16'h1E7D, 16'h1F54, 16'h2027, 16'h20F6, 16'h0000 //padding
};

//203 values
logic [15:0] tnd_table[256];
assign tnd_table = '{
	16'h0000, 16'h00DC, 16'h01B5, 16'h028D, 16'h0363, 16'h0438, 16'h050B, 16'h05DC,
	16'h06AB, 16'h0779, 16'h0845, 16'h0910, 16'h09D9, 16'h0AA0, 16'h0B66, 16'h0C2B,
	16'h0CED, 16'h0DAF, 16'h0E6E, 16'h0F2D, 16'h0FEA, 16'h10A5, 16'h115F, 16'h1218,
	16'h12CF, 16'h1385, 16'h143A, 16'h14ED, 16'h159F, 16'h1650, 16'h16FF, 16'h17AD,
	16'h185A, 16'h1906, 16'h19B0, 16'h1A59, 16'h1B01, 16'h1BA7, 16'h1C4D, 16'h1CF1,
	16'h1D94, 16'h1E36, 16'h1ED7, 16'h1F77, 16'h2016, 16'h20B3, 16'h2150, 16'h21EB,
	16'h2285, 16'h231F, 16'h23B7, 16'h244E, 16'h24E4, 16'h2579, 16'h260D, 16'h26A0,
	16'h2733, 16'h27C4, 16'h2854, 16'h28E3, 16'h2972, 16'h29FF, 16'h2A8B, 16'h2B17,
	16'h2BA2, 16'h2C2B, 16'h2CB4, 16'h2D3C, 16'h2DC3, 16'h2E49, 16'h2ECF, 16'h2F53,
	16'h2FD7, 16'h305A, 16'h30DC, 16'h315D, 16'h31DD, 16'h325D, 16'h32DC, 16'h335A,
	16'h33D7, 16'h3453, 16'h34CF, 16'h354A, 16'h35C4, 16'h363E, 16'h36B6, 16'h372E,
	16'h37A6, 16'h381C, 16'h3892, 16'h3907, 16'h397B, 16'h39EF, 16'h3A62, 16'h3AD5,
	16'h3B46, 16'h3BB7, 16'h3C28, 16'h3C97, 16'h3D06, 16'h3D75, 16'h3DE2, 16'h3E50,
	16'h3EBC, 16'h3F28, 16'h3F93, 16'h3FFE, 16'h4068, 16'h40D1, 16'h413A, 16'h41A2,
	16'h420A, 16'h4271, 16'h42D8, 16'h433D, 16'h43A3, 16'h4408, 16'h446C, 16'h44D0,
	16'h4533, 16'h4595, 16'h45F7, 16'h4659, 16'h46BA, 16'h471A, 16'h477A, 16'h47DA,
	16'h4839, 16'h4897, 16'h48F5, 16'h4952, 16'h49AF, 16'h4A0B, 16'h4A67, 16'h4AC3,
	16'h4B1E, 16'h4B78, 16'h4BD2, 16'h4C2C, 16'h4C85, 16'h4CDD, 16'h4D35, 16'h4D8D,
	16'h4DE4, 16'h4E3B, 16'h4E91, 16'h4EE7, 16'h4F3D, 16'h4F92, 16'h4FE6, 16'h503A,
	16'h508E, 16'h50E1, 16'h5134, 16'h5187, 16'h51D9, 16'h522A, 16'h527C, 16'h52CC,
	16'h531D, 16'h536D, 16'h53BD, 16'h540C, 16'h545B, 16'h54A9, 16'h54F7, 16'h5545,
	16'h5592, 16'h55DF, 16'h562C, 16'h5678, 16'h56C4, 16'h570F, 16'h575A, 16'h57A5,
	16'h57EF, 16'h583A, 16'h5883, 16'h58CD, 16'h5916, 16'h595E, 16'h59A6, 16'h59EE,
	16'h5A36, 16'h5A7D, 16'h5AC4, 16'h5B0B, 16'h5B51, 16'h5B97, 16'h5BDD, 16'h5C22,
	16'h5C67, 16'h5CAC, 16'h5CF0, 16'h5D34, 16'h5D78, 16'h5DBC, 16'h5DFF, 16'h5E42,
	16'h5E84, 16'h5EC6, 16'h5F08, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,//padding
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000,
	16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000, 16'h0000	 
};

wire [4:0] pulse_index = SQA + SQB;
wire [7:0] tnd_index = (TRIA << 1) + TRIA + (RND << 1) + DMC;  // 3*TRIA + 2*RND + DMC

wire [15:0] pulse_mix = pulse_table[pulse_index];
wire [15:0] tnd_mix = tnd_table[tnd_index];

assign AudioOut = pulse_mix + tnd_mix;  


endmodule
