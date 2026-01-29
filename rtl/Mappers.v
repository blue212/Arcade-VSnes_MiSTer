// Copyright (c) 2025 Blue212


module Mappers (
	input Clk,
	input Reset,

	input [15:0] CPU_AddressBus,
	input [7:0] CPU_DataBus,
	input [13:0] PPU_AddressBus,
	input [7:0] BA,
	
	input [2:0] Mapper,
	input M2,
	input CPURnW,
	input [2:0] OUT,
	input [7:0] cpuCSn,	

	output reg [16:0] CPUAddr,
	output reg [16:0] PPUAddr,
	
	output useCHRram
);


///////////////////////////////////////////////////////////////   
//mappers
  
assign useCHRram = (Mapper == 4'd2);//only unrom uses CHRram

//wire irq6;  
 
wire [17:0] prg_addr1;
wire [16:0] chr_addr1;	 
 
wire [16:0] prg_addr2;
wire [16:0] chr_addr2;	 
 
wire [16:0] prg_addr3;
wire [16:0] chr_addr3;	
 
reg [17:0] prg_addr4;
reg [16:0] chr_addr4;

wire [16:0] prg_addr5;
wire [16:0] chr_addr5;		

wire [18:0] prg_addr6;
wire [16:0] chr_addr6;

always @(*) begin
	if (Mapper == 4'd1) begin//mmc1 
		CPUAddr = {1'b0,prg_addr1[15:0]};
		PPUAddr = {2'b0,chr_addr1[14:0]};  
	end else if (Mapper == 4'd2) begin//unrom
		CPUAddr = {(UNROMq[2]|CPU_AddressBus[14]),(UNROMq[1]|CPU_AddressBus[14]),(UNROMq[0]|CPU_AddressBus[14]),CPU_AddressBus[13],CPU_AddressBus[12:0]};
		PPUAddr = {4'b0,PPU_AddressBus[12:8], BA};		
	end else if (Mapper == 4'd3) begin//hack for gumshoe
		CPUAddr = {(!cpuCSn[4] ? OUT[2] : 1'b0),CPU_AddressBus[15:0]} - 17'h8000;
		PPUAddr = {3'b0,OUT[2],PPU_AddressBus[12:8], BA};		
	end else if (Mapper == 4'd4) begin//206
		CPUAddr = prg_addr4[16:0];
		PPUAddr = {1'b0,chr_addr4[15:0]};//64kb
	end else if (Mapper == 4'd5) begin//vrc1
		CPUAddr = prg_addr5[15:0];
		PPUAddr = chr_addr5;	
	end else if (Mapper == 4'd6) begin//67
		CPUAddr = prg_addr6[16:0];
		PPUAddr = chr_addr6; 		
	end else begin// default to mapper 0 (nes mapper 99)
		CPUAddr = {1'b0,CPU_AddressBus[15:0]} - 17'h8000;
		PPUAddr = {3'b0,OUT[2],PPU_AddressBus[12:8], BA};		
	end	 
end  

///////////////////////////////////////////////////////////////
//mapper 2 unrom - castlevania,Top Gun
  
//wire nROMSEL = ~(M2 && CPU_AddressBus[15]);   
reg [2:0] UNROMq;

//74ls161
//always @(posedge nROMSEL) begin
//	if (!CPURnW) begin
//		UNROMq <= CPU_DataBus[2:0];
//	end
//end  

always @(posedge Clk) begin
	if (!CPURnW && M2 && CPU_AddressBus[15]) begin
		UNROMq <= CPU_DataBus[2:0];
	end
end  

///////////////////////////////////////////////////////////////
// mmc1
   
reg [4:0] shift_regm1;
reg [2:0] shift_count1;

reg [4:0] control1;       // 8000–9FFF
reg [4:0] chr_bank0_1;    // A000–BFFF
reg [4:0] chr_bank1_1;    // C000–DFFF
reg [4:0] prg_bank_1;     // E000–FFFF
 
reg enabledelay1;
 
always @(posedge Clk) begin
	enabledelay1 <= write_enable1;
end	

wire write_enable1 = !CPURnW && M2 && CPU_AddressBus[15];

always @(posedge Clk) begin
	if (Reset) begin
		shift_regm1   <= 5'b10000;
		shift_count1 <= 0;
		control1     <= 5'b11100; //default: 16 KB PRG, switch upper, 8 KB CHR
		chr_bank0_1   <= 0;
		chr_bank1_1   <= 0;
		prg_bank_1    <= 0;
	end else if (!write_enable1 && enabledelay1) begin //wait until failing edge of m2 so data is valid and SR only writes once
		if (CPU_DataBus[7]) begin // reset to default
			shift_regm1   <= 5'b10000;
			shift_count1 <= 0;
			control1[4:2] <= 3'b111; 
		end else begin
			shift_regm1 <= {CPU_DataBus[0], shift_regm1[4:1]};
			shift_count1 <= shift_count1 + 1'b1;
		
			if (shift_count1 == 4) begin//write data on 5th write and reset SR
				case (CPU_AddressBus[14:13])
						2'b00: control1    <= {CPU_DataBus[0], shift_regm1[4:1]};
						2'b01: chr_bank0_1 <= {CPU_DataBus[0], shift_regm1[4:1]};
						2'b10: chr_bank1_1 <= {CPU_DataBus[0], shift_regm1[4:1]};
						2'b11: prg_bank_1  <= {CPU_DataBus[0], shift_regm1[4:1]};
				endcase
				shift_regm1   <= 5'b10000;
				shift_count1 <= 0;
			end
		end
	end
end
  
reg [3:0] prgsel1;

always @(*) begin
	prgsel1 = (control1[3] == 1'b0) ? {prg_bank_1[3:1], CPU_AddressBus[14]} : //32KB mode
												 ({control1[3:2], CPU_AddressBus[14]} == 3'b100)  ? 4'b0000 :
												 ({control1[3:2], CPU_AddressBus[14]} == 3'b101)  ? prg_bank_1[3:0] :
												 ({control1[3:2], CPU_AddressBus[14]} == 3'b110)  ? prg_bank_1[3:0] :
																													 4'b1111;
end
 
assign prg_addr1 = {prgsel1[2:0], CPU_AddressBus[13:0]};
 
assign chr_addr1 = (control1[4] == 0) ? // 8 KB mode
							{chr_bank0_1[4:1], PPU_AddressBus[12:0]} :
						 (PPU_AddressBus[12] == 0) ?
								  {chr_bank0_1, PPU_AddressBus[11:0]} :
								  {chr_bank1_1, PPU_AddressBus[11:0]};

/////////////////////////////////////////////////////////////// 
//vrc1

reg [3:0] prg_bank_8000_5;//(8 KB banks)
reg [3:0] prg_bank_a000_5;
reg [3:0] prg_bank_c000_5;

reg [4:0] chr_bank_0000_5;//(4 KB banks)
reg [4:0] chr_bank_1000_5;

//reg [1:0] mirroring5;

always @(posedge Clk) begin 
	if (!CPURnW && M2 && CPU_AddressBus[15]) begin
		case (CPU_AddressBus[15:12])
			4'h8: prg_bank_8000_5 <= CPU_DataBus[3:0];// 8000
			//4'h9: {chr_bank_1000_5[4],chr_bank_0000_5[4],mirroring5[0]} <= CPU_DataBus[2:0];// 9000
			4'h9: {chr_bank_1000_5[4],chr_bank_0000_5[4]} <= CPU_DataBus[2:1];// 9000					 
			4'hA: prg_bank_a000_5 <= CPU_DataBus[3:0];// A000
			4'hC: prg_bank_c000_5 <= CPU_DataBus[3:0];// C000
			4'hE: chr_bank_0000_5 <= CPU_DataBus[3:0];// E000	 
			4'hF: chr_bank_1000_5 <= CPU_DataBus[3:0];// F000					 
			default: ;
		endcase
	end
end

assign prg_addr5 = (CPU_AddressBus[15:13] == 3'b100) ? {prg_bank_8000_5, CPU_AddressBus[12:0]} :
						 (CPU_AddressBus[15:13] == 3'b101) ? {prg_bank_a000_5, CPU_AddressBus[12:0]} :
						 (CPU_AddressBus[15:13] == 3'b110) ? {prg_bank_c000_5, CPU_AddressBus[12:0]} :
																					{4'b1111, CPU_AddressBus[12:0]};// fixed last bank
					  
assign chr_addr5 = (PPU_AddressBus[12]) ? {chr_bank_1000_5,  {PPU_AddressBus[11:8], BA}} :
														{chr_bank_0000_5,  {PPU_AddressBus[11:8], BA}};

/////////////////////////////////////////////////////////////// 
//206

reg [2:0] bank_select4 = 3'b000; 

// PRG banks (8KB each, allowing 16 banks = 128KB)
reg [3:0] prg_bank_8000_4;// 8000-9FFF (Bank 0)
reg [3:0] prg_bank_a000_4;// A000-BFFF (Bank 1)

// CHR banks (2K banks use 5 bits for 32 banks, 1K banks use 6 bits for 64 banks)
reg [4:0] chr_2k_0000_4;// 0000-07FF (2K bank 0)
reg [4:0] chr_2k_0800_4;// 0800-0FFF (2K bank 2)
reg [5:0] chr_1k_1000_4;// 1000-13FF (1K bank 4)
reg [5:0] chr_1k_1400_4;// 1400-17FF (1K bank 5)
reg [5:0] chr_1k_1800_4;// 1800-1BFF (1K bank 6)
reg [5:0] chr_1k_1C00_4;// 1C00-1FFF (1K bank 7)

// Define fixed banks (Last 16KB = Banks 14 and 15 for 128KB PRG-ROM)
reg [3:0] PRG_FIXED_C000 = 4'b1110; // C000-DFFF (Bank 14)
reg [3:0] PRG_FIXED_E000 = 4'b1111; // E000-FFFF (Bank 15)


// --- Write Logic (8000-FFFF) ---
always @(posedge Clk) begin
	if (!CPURnW && M2 && CPU_AddressBus[15]) begin        
		if (CPU_AddressBus[15:13] == 3'b100) begin // 8000-9FFF
			// Mapper 206 uses only 8000 and 8001 for register writes?
			//if (CPU_AddressBus == 16'h8000) begin
			if (!CPU_AddressBus[0]) begin //even
				// Write to 8000: Selects the register to be written by 8001
				bank_select4 <= CPU_DataBus[2:0];
			//end else if (CPU_AddressBus == 16'h8001) begin
			end else begin //odd
				// Write to 8001: Writes data to the selected register
				case (bank_select4)
					3'b000: chr_2k_0000_4 <= CPU_DataBus[5:1];// R0: 2K bank for 0000
					3'b001: chr_2k_0800_4 <= CPU_DataBus[5:1];// R1: 2K bank for 0800			  
					3'b010: chr_1k_1000_4 <= CPU_DataBus[5:0];// R2: 1K bank for 1000
					3'b011: chr_1k_1400_4 <= CPU_DataBus[5:0];// R3: 1K bank for 1400
					3'b100: chr_1k_1800_4 <= CPU_DataBus[5:0];// R4: 1K bank for 1800
					3'b101: chr_1k_1C00_4 <= CPU_DataBus[5:0];// R5: 1K bank for 1C00
					3'b110: prg_bank_8000_4 <= CPU_DataBus[3:0];// R6: 8K bank for 8000
					3'b111: prg_bank_a000_4 <= CPU_DataBus[3:0];// R7: 8K bank for A000
					default: ;
				endcase
			end
		end
	end
end

always @(*) begin
	case (CPU_AddressBus[15:13]) // Check 8000, A000, C000, E000 regions
		3'b100: prg_addr4 = {prg_bank_8000_4, CPU_AddressBus[12:0]};  // 8000-9FFF, Swappable
		3'b101: prg_addr4 = {prg_bank_a000_4, CPU_AddressBus[12:0]};  // A000-BFFF, Swappable
		3'b110: prg_addr4 = {PRG_FIXED_C000, CPU_AddressBus[12:0]};   // C000-DFFF, Fixed to last 8K bank - 1
		3'b111: prg_addr4 = {PRG_FIXED_E000, CPU_AddressBus[12:0]};   // E000-FFFF, Fixed to last 8K bank
		default: prg_addr4 = 17'h0;// Should not be accessed (0000-7FFF)
	endcase
end

always @(*) begin
	case (PPU_AddressBus[12:10])
		3'b000: chr_addr4 = {chr_2k_0000_4, PPU_AddressBus[10:0]}; // 2K bank 0000-03FF
		3'b001: chr_addr4 = {chr_2k_0000_4, PPU_AddressBus[10:0]}; //         0400-07FF
		3'b010: chr_addr4 = {chr_2k_0800_4, PPU_AddressBus[10:0]}; // 2K bank 0800-0BFF
		3'b011: chr_addr4 = {chr_2k_0800_4, PPU_AddressBus[10:0]}; //         0C00-0FFF		  
		3'b100: chr_addr4 = {chr_1k_1000_4, PPU_AddressBus[9:0]};  // 1K bank 1000-13FF
		3'b101: chr_addr4 = {chr_1k_1400_4, PPU_AddressBus[9:0]};  // 1K bank 1400-17FF
		3'b110: chr_addr4 = {chr_1k_1800_4, PPU_AddressBus[9:0]};  // 1K bank 1800-1BFF
		3'b111: chr_addr4 = {chr_1k_1C00_4, PPU_AddressBus[9:0]};  // 1K bank 1C00-1FFF
		default: ;
	endcase
end

///////////////////////////////////////////////////////////////
//67  

reg [4:0] prg_bank6;//(16 KB at 8000)

reg [5:0] chr_bank_0000_6;//(2 KB each)
reg [5:0] chr_bank_0800_6;
reg [5:0] chr_bank_1000_6;
reg [5:0] chr_bank_1800_6;

//reg [15:0] irq_counter = 16'h0;
//reg        irq_enable = 0;
//reg        irq_pending = 0;
//reg        irq_write_toggle = 0;

always @(posedge Clk) begin
//	if (irq_enable) begin
//		if (irq_counter == 16'h0) begin
//			irq_pending <= 1;
//			irq_enable <= 0;
//		end else begin
//			irq_counter <= irq_counter - 1'b1;
//		end
//	end	  
	
	if (!CPURnW && M2 && CPU_AddressBus[15]) begin
		case (CPU_AddressBus & 16'hF800)
			16'h8800: chr_bank_0000_6 <= CPU_DataBus[5:0]; 
			16'h9800: chr_bank_0800_6 <= CPU_DataBus[5:0];
			16'hA800: chr_bank_1000_6 <= CPU_DataBus[5:0];
			16'hB800: chr_bank_1800_6 <= CPU_DataBus[5:0];
			16'hC800: begin
				//if (!irq_write_toggle)
					//irq_counter[15:8] <= CPU_DataBus;
				//else
					//irq_counter[7:0]  <= CPU_DataBus;
					//irq_write_toggle <= ~irq_write_toggle;
			end
			16'hD800: begin
				//irq_enable <= CPU_DataBus[0];
				//irq_write_toggle <= 0;
			end
			//16'hE800: mirroring6 <= CPU_DataBus[1:0];
			16'hF800: prg_bank6 <= CPU_DataBus[4:0];
		endcase
	end
end

assign prg_addr6 = (CPU_AddressBus[15:14] == 2'b10) ? {prg_bank6, CPU_AddressBus[13:0]} :
																		 {5'b11111, CPU_AddressBus[13:0]}; // fixed last bank

assign chr_addr6 = (PPU_AddressBus[12:11] == 2'b00) ? {chr_bank_0000_6, {PPU_AddressBus[10:8], BA}} :
						 (PPU_AddressBus[12:11] == 2'b01) ? {chr_bank_0800_6, {PPU_AddressBus[10:8], BA}} :
						 (PPU_AddressBus[12:11] == 2'b10) ? {chr_bank_1000_6, {PPU_AddressBus[10:8], BA}} :
																		{chr_bank_1800_6, {PPU_AddressBus[10:8], BA}};
																		
//assign irq6 = irq_pending;

endmodule
