//============================================================================
//
// VS NES Arcade for MiSTer FPGA
// Copyright (c) 2025 Blue212
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 0;
assign AUDIO_L = (mixaudio == 2'b01) ? audio_output2 : audio_output;//either nes1 or 2 audio only or both each with their own CH
assign AUDIO_R = (mixaudio == 2'b00) ? audio_output : audio_output2;

assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.VSnes;;",
	"-;",
	"O[10],SNAC,Off,On;",
	"O[14],Light Gun,No,Yes;",	
	"O[13],Swap Joysticks,No,Yes;",
	"-;",
	//"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	//"O[2],TV Mode,NTSC,PAL;",	
	//"O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",	
	"O[6],Palette Overide,No,Yes;",	
	"h0O[9:7],Palette,2C02,2C03,2C04-0000,2C04-0001,2C04-0002,2C04-0003,2C04-0004,2C05-99;",
	"O[12],Swap Screen,No,Yes;",
	"O[15],System Type,Uni,Dual;",
	"h1O[17:16],Split Screen,No,Vert,Horz;",
	"h2O[11],Divider,No,Yes;",	
	"-;",	
	"O[18],Shared RAM,Yes,No;",
	"O[20:19],Audio Mix,NES1,NES2,Both;",	
	"-;",
	"DIP;",	
	"-;",	 
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,A,B,Start3(4),Start1(2),Coin,Service;",
	"jn,A,B,Select,Start,Y,X;",// name mapping 
	"jp,B,Y,Select,Start,A,X;",// positional mapping 
	"v,0;", // [optional] config version 0-99. 
	        // If CONF_STR options are changed in incompatible way, then change version number too,
			  // so all options will get default values on first start.
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;

wire [23:0] joyA,joyB,joyC,joyD;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),
	
	.ioctl_download(ioctl_download),
	.ioctl_addr(ioctl_addr),
	.ioctl_wr(ioctl_wr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(ioctl_index),

	.forced_scandoubler(forced_scandoubler),
	
	.joystick_0(joyA),
	.joystick_1(joyB),
	.joystick_2(joyC),
	.joystick_3(joyD),

	.buttons(buttons),
	.status(status),
	.status_menumask({divide_status,status[15],status[6]}),
	
	.ps2_key(ps2_key)
);

wire         ioctl_download;
wire [24:0]  ioctl_addr;
wire         ioctl_wait;
wire         ioctl_wr; 
wire [15:0]  ioctl_index;  
wire [7:0]   ioctl_dout;

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire clk_mem;
wire locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_mem),
	.outclk_1(clk_sys),
	.locked(locked)
);

wire reset = RESET | status[0] | buttons[1];

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

//////////////////////////////////////////////////////////////////
// Video
wire [23:0] video_output,video_output2;// 24-bit RGB
wire [15:0] audio_output,audio_output2;  

wire [7:0] R1 = video_output[23:16];
wire [7:0] G1 = video_output[15:8];
wire [7:0] B1 = video_output[7:0];

wire [7:0] R2 = video_output2[23:16];
wire [7:0] G2 = video_output2[15:8];
wire [7:0] B2 = video_output2[7:0];

wire hblank,hblank2;
wire hsync,hsync2;
wire vblank,vblank2;
wire vsync,vsync2;
wire ce_pix,ce_pix2;

wire [21:0] gamma_bus;

/*
assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = screenswap ^ dual ? ~(hblank2 | vblank2) : ~(hblank | vblank);
assign VGA_HS = screenswap ^ dual ? hsync2 : hsync;
assign VGA_VS = screenswap ^ dual ? vsync2 : vsync;
assign VGA_G  = screenswap ^ dual ? G2 : G1;
assign VGA_R  = screenswap ^ dual ? R2 : R1;
assign VGA_B  = screenswap ^ dual ? B2 : B1;
*/


arcade_video#(256,24,0) arcade_video
(
	.*,
	
	.clk_video(clk_sys),
	.ce_pix((screenswap ^ dual) ? ce_pix2 : ce_pix),
	
	.RGB_in((screenswap ^ dual) ? {R2,G2,B2} : {R1,G1,B1}),
	.HBlank((screenswap ^ dual) ? hblank2 : hblank),
	.VBlank((screenswap ^ dual) ? vblank2 : vblank),
	.HSync((screenswap ^ dual) ? hsync2 : hsync),
	.VSync((screenswap ^ dual) ? vsync2 : vsync),
	.fx(status[5:3]),
	.forced_scandoubler(1'b0)
	//.gamma_bus(gamma_bus)
	
);


//////////////////////////////////////////////////////////////////
// NES System 1
nes_system nes1 (
	.Clk(clk_sys),
	//.Clk4x(clk_mem),	 
	.Reset(reset),
	.VideoOut(video_output),
	.AudioOut(audio_output),
	
	.VBlank(vblank),
	.HBlank(hblank),
	.VSync(vsync),
	.HSync(hsync),
	.PCLK(ce_pix),
	
	.NVramAddress(NVramAddress1),	 
	.NVDataOut(NVDataOut1),
	.NVDataq(NVDataq),
	.NVcs(NVcs1),
	
	.primary(1'b1),	 
	.IRQin(OUT2[1]),	 
	
	.PALETTE(PALETTE),
	.PPUtype(PPUtype),
	.Mapper(Mapper),
	
	.dipsw(dip_sw[0]),
	
	.romreadCHR(romreadCHR1),
	.romreadPRG(romreadPRG1),
	.PPU_nRD(PPU_nRD1),
	.CPU_nRD(CPU_nRD1),
	.CPUAddr(CPUAddr1),
	.PPUAddr(PPUAddr1),	 
	
	.OUT(OUT1),
	.nIN(nIN1),
	.controller1_data(joypad1_data | controller1_data1),
	.controller2_data(joypad2_data | controller2_data1), 
	.service(service1),
	.coin1(coin1_1),
	.coin2(coin2_1)    	
);
 
//NES 2 
 nes_system nes2 (
	.Clk(clk_sys),
	//.Clk4x(clk_mem), 
	.Reset(reset),
	.VideoOut(video_output2),
	.AudioOut(audio_output2),
	
	.VBlank(vblank2),
	.HBlank(hblank2),
	.VSync(vsync2),
	.HSync(hsync2),
	.PCLK(ce_pix2),
	
	.NVramAddress(NVramAddress2),	 
	.NVDataOut(NVDataOut2),
	.NVDataq(sharedram ? NVDataq : NVDataq2),	 
	.NVcs(NVcs2),
	
	.primary(1'b0),	 
	.IRQin(OUT1[1]),		 
	
	.PALETTE(PALETTE2),
	.PPUtype(PPUtype2),
	.Mapper(Mapper2),
	
	.dipsw(dip_sw[1]),
	
	.romreadCHR(romreadCHR2),
	.romreadPRG(romreadPRG2),
	.PPU_nRD(PPU_nRD2),
	.CPU_nRD(CPU_nRD2),
	.CPUAddr(CPUAddr2),
	.PPUAddr(PPUAddr2),	 
	
	.OUT(OUT2),
	.nIN(nIN2),
	.controller1_data(controller3_data2),
	.controller2_data(controller4_data2),
	.service(service2),
	.coin1(coin1_2),
	.coin2(coin2_2)    	
);  
 
////////////////////////////////////////////////////////////////// 
//palette  
wire palOveride = status[6];
wire [3:0] PALETTE  = palOveride ? {1'b0,status[9:7]} : Palette;
wire [3:0] PALETTE2 = palOveride ? {1'b0,status[9:7]} : Palette2;
//0	2C02
//1	2C03
//2	2C04-0000
//3	2C04-0001
//4	2C04-0002
//5	2C04-0003
//6	2C04-0004
//7	2C05-01       - Ninja Jajamaru Kun
//8	2C05-02       - Mighty Bomb Jack
//9	2C05-03       - Gumshoe
//A	2C05-04       - Top Gun

//mapper
//0 mapper 99 - most games
//1 mmc1 - drmario
//2 unrom - castlevania, top gun
//3 special - gumshoe
//4 206 (Namco 108)super xevious, rbi, tko,freedom force,skykid
//5 VRC1 151 - goonies, gradius 
//6 SUNSOFT-3 067 platoon
//7 

reg [3:0] Palette,Palette2;
reg [2:0] Mapper,Mapper2;
reg [3:0] PPUtype,PPUtype2;
reg REVcntl,REVcntl2;//some games use left stick, others use right stick as P1.swap stick and buttons but not start

always @(posedge clk_sys) begin
	if(ioctl_wr && (ioctl_index==1)) begin
		Palette <= ioctl_dout[3:0];
		PPUtype <= ioctl_dout[3:0];
		Mapper  <= ioctl_dout[6:4];
		REVcntl <= ioctl_dout[7]; 		
	end
	if(ioctl_wr && (ioctl_index==2)) begin
		Palette2 <= ioctl_dout[3:0];
		PPUtype2 <= ioctl_dout[3:0];
		Mapper2  <= ioctl_dout[6:4];
		REVcntl2 <= ioctl_dout[7]; 		
	end	 
end

//dips
reg [7:0] dip_sw[8]; 
always @(posedge clk_sys) begin
    if(ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3])
        dip_sw[ioctl_addr[2:0]] <= ioctl_dout;
end

wire joyswap = status[13];
wire snac = status[10];
wire gunEN = status[14];
wire dual = status[15];
wire sharedram = ~status[18]; 
wire vertical = status[17:16] == 2'd1;
wire horizontal = status[17:16] == 2'd2; 
wire screenswap = status[12];//if system = Uni swap will show either nes1 or nes2 on both screens, if dual is active nes1 will be hdmi and nes2 will be vga. there's H and V switches, swap will then switch the position in FB and switch VGA
wire [1:0] mixaudio = status[20:19];
wire divider = status[11];
wire divide_status = dual && (vertical | horizontal);

//////////////////////////////////////////////////////////////////
//controller section

//Keyboard
reg btn_up,btn_down,btn_left,btn_right,btn_a,btn_b;
reg btn_coin1,btn_coin2,btn_coin3,btn_coin4,btn_service,btn_service2; 
reg btn_1p_start,btn_2p_start,btn_3p_start,btn_4p_start;

wire pressed = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	if(old_state != ps2_key[10]) begin
		case(code)
			'h16: btn_1p_start <= pressed; // 1
			'h1E: btn_2p_start <= pressed; // 2
			'h26: btn_3p_start <= pressed; // 3
			'h25: btn_4p_start <= pressed; // 4				
			'h2E: btn_coin1    <= pressed; // 5
			'h36: btn_coin2    <= pressed; // 6
			'h3d: btn_coin3    <= pressed; // 7
			'h3E: btn_coin4    <= pressed; // 8				
			'h46: btn_service  <= pressed; // 9
			'h45: btn_service2 <= pressed; // 0				
			'h75: btn_up       <= pressed; // up
			'h72: btn_down     <= pressed; // down
			'h6B: btn_left     <= pressed; // left
			'h74: btn_right    <= pressed; // right
			'h14: btn_a        <= pressed; // ctrl
			'h11: btn_b        <= pressed; // alt
		endcase
	end
end

//NES1
wire service1 = joyA[9] | joyB[9] | btn_service;
wire coin1_1  = joyA[8] | btn_coin1;
wire coin2_1  = joyB[8] | btn_coin2;
//NES2	
wire service2 = joyC[9] | joyD[9] | btn_service2;
wire coin1_2  = joyC[8] | btn_coin3;
wire coin2_2  = joyD[8] | btn_coin4; 

reg controller1_data1, controller2_data1, controller3_data2, controller4_data2; 
reg [7:0] shift_reg1,shift_reg2,shift_reg3,shift_reg4;
wire [2:0] OUT1,OUT2;
wire [1:0] nIN1,nIN2; 
reg [1:0]oldnIN1,oldnIN2;
reg joypad1_data,joypad2_data;
 
//usb indexs - service,coin,start,select,B,A,u,d,l,r
//A,B,1,3,u,d,l,r - order in shift register
 
//74LS165 at 6M, 6N, 7P, 8P 
always @(posedge clk_sys) begin
	if (OUT1[0]) begin
		shift_reg1 <= REVcntl  && joyswap  ? {(joyA[4]|btn_a),(joyA[5]|btn_b),(joyB[7]|btn_1p_start),joyB[6],(gunEN ? 1'b1 : (joyA[3]|btn_up)),(joyA[2]|btn_down),(gunEN ? Sensor : (joyA[1]|btn_left)),(gunEN ? Trigger : (joyA[0]|btn_right))} :
						  REVcntl  && !joyswap ? {(joyB[4]|btn_a),(joyB[5]|btn_b),(joyA[7]|btn_1p_start),joyA[6],(gunEN ? 1'b1 : (joyB[3]|btn_up)),(joyB[2]|btn_down),(gunEN ? Sensor : (joyB[1]|btn_left)),(gunEN ? Trigger : (joyB[0]|btn_right))} :
					     !REVcntl && joyswap  ? {(joyB[4]|btn_a),(joyB[5]|btn_b),(joyB[7]|btn_1p_start),joyB[6],(gunEN ? 1'b1 : (joyB[3]|btn_up)),(joyB[2]|btn_down),(gunEN ? Sensor : (joyB[1]|btn_left)),(gunEN ? Trigger : (joyB[0]|btn_right))} :
														 {(joyA[4]|btn_a),(joyA[5]|btn_b),(joyA[7]|btn_1p_start),joyA[6],(gunEN ? 1'b1 : (joyA[3]|btn_up)),(joyA[2]|btn_down),(gunEN ? Sensor : (joyA[1]|btn_left)),(gunEN ? Trigger : (joyA[0]|btn_right))};

		shift_reg2 <= REVcntl  && joyswap  ? {joyB[4],joyB[5],(joyA[7]|btn_2p_start),joyA[6],joyB[3],joyB[2],joyB[1],joyB[0]} :
					     REVcntl  && !joyswap ? {joyA[4],joyA[5],(joyB[7]|btn_2p_start),joyB[6],joyA[3],joyA[2],joyA[1],joyA[0]} :  
					     !REVcntl && joyswap  ? {joyA[4],joyA[5],(joyA[7]|btn_2p_start),joyA[6],joyA[3],joyA[2],joyA[1],joyA[0]} :
														 {joyB[4],joyB[5],(joyB[7]|btn_2p_start),joyB[6],joyB[3],joyB[2],joyB[1],joyB[0]};
	end 
	if (OUT2[0]) begin
		shift_reg3 <= REVcntl2  && joyswap  ? {joyC[4],joyC[5],(joyD[7]|btn_3p_start),joyD[6],joyC[3],joyC[2],joyC[1],joyC[0]} :
						  REVcntl2  && !joyswap ? {joyD[4],joyD[5],(joyC[7]|btn_3p_start),joyC[6],joyD[3],joyD[2],joyD[1],joyD[0]} :
						  !REVcntl2 && joyswap  ? {joyD[4],joyD[5],(joyD[7]|btn_3p_start),joyD[6],joyD[3],joyD[2],joyD[1],joyD[0]} :
														  {joyC[4],joyC[5],(joyC[7]|btn_3p_start),joyC[6],joyC[3],joyC[2],joyC[1],joyC[0]};

		shift_reg4 <= REVcntl2  && joyswap  ? {joyD[4],joyD[5],(joyC[7]|btn_4p_start),joyC[6],joyD[3],joyD[2],joyD[1],joyD[0]} :
						  REVcntl2  && !joyswap ? {joyC[4],joyC[5],(joyD[7]|btn_4p_start),joyD[6],joyC[3],joyC[2],joyC[1],joyC[0]} :  
						  !REVcntl2 && joyswap  ? {joyC[4],joyC[5],(joyC[7]|btn_4p_start),joyC[6],joyC[3],joyC[2],joyC[1],joyC[0]} :
														  {joyD[4],joyD[5],(joyD[7]|btn_4p_start),joyD[6],joyD[3],joyD[2],joyD[1],joyD[0]};
	end		
	
	if (oldnIN1[0] && !nIN1[0]) begin
		shift_reg1 <= {shift_reg1[6:0], 1'b1};
		controller1_data1 <= shift_reg1[7];
	end 
	if (oldnIN1[1] && !nIN1[1]) begin	
		shift_reg2 <= {shift_reg2[6:0], 1'b1};
		controller2_data1 <= shift_reg2[7];			
	end
	
	if (oldnIN2[0] && !nIN2[0]) begin
		shift_reg3 <= {shift_reg3[6:0], 1'b1};
		controller3_data2 <= shift_reg3[7];			
	end 
	if (oldnIN2[1] && !nIN2[1]) begin	
		shift_reg4 <= {shift_reg4[6:0], 1'b1};
		controller4_data2 <= shift_reg4[7];			
	end		
	oldnIN1 <= nIN1;
	oldnIN2 <= nIN2;		
end 

//zapper	
//P1 Joystick Right - Zapper Trigger
//P1 Joystick Left - Zapper Sensor
//P1 Joystick Up - Ground on harness to disable alarm

reg Sensor;
reg Trigger; 

always_comb begin
	if (snac) begin
		USER_OUT[0]   = OUT1[0];//Strobe
		USER_OUT[1]   = (REVcntl ^ joyswap) ? nIN1[1] : nIN1[0];//Clk p1
		USER_OUT[2]   = 1'b1;
		USER_OUT[3]   = (REVcntl ^ joyswap) ? nIN1[0] : nIN1[1];//Clk p2
		USER_OUT[6:4] = 3'b111;	 
		joypad1_data = (REVcntl ^ joyswap) ? ~USER_IN[6] : ~USER_IN[5];//P1D0		 
		joypad2_data =  (REVcntl ^ joyswap) ? ~USER_IN[5] : ~USER_IN[6];//P2D0
		Sensor = USER_IN[2];//D3
		Trigger = ~USER_IN[4];//D4 
	end else begin  
		USER_OUT = '1;      
		joypad1_data = 1'b0;
		joypad2_data = 1'b0;
		Sensor = 1'b0;
		Trigger = 1'b0; 
	end
end

//////////////////////////////////////////////////////////////////
//NVram
 
wire [10:0]NVramAddress1,NVramAddress2;	 
wire [7:0]NVDataOut1,NVDataOut2;
wire [7:0]NVDataq,NVDataq2;
wire NVcs1,NVcs2;

//74ls157 at 5j 5k 6j 6k - only primary nes controls the selector  
//74ls245 3k 8k - simplified for now
	 
//2kB RAM for NVRAM () 8L - shared between both systems
ram2k nvram (
	.address(~OUT1[1] ? NVramAddress2 : NVramAddress1),
	.clock(clk_sys),
	.data(~OUT1[1] ? NVDataOut2 : NVDataOut1),
	.wren(sharedram ? ~OUT1[1] ? NVcs2 : NVcs1 : NVcs1),
	.q(NVDataq)
);

// Super mario wants the ram to itself, so add another to make 2 instances work, have to turn off shared ram in osd  
ram2k nvram2 (
	.address(NVramAddress2),
	.clock(clk_sys),
	.data(NVDataOut2),
	.wren(NVcs2),
	.q(NVDataq2)
);  

//////////////////////////////////////////////////////////////////
//sdram

wire [7:0] romreadPRG1,romreadPRG2;
wire [7:0] romreadCHR1,romreadCHR2;
wire PPU_nRD1,PPU_nRD2;
wire CPU_nRD1,CPU_nRD2;
wire [16:0] CPUAddr1,CPUAddr2;
wire [16:0] PPUAddr1,PPUAddr2;

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_mem),
	
	.ch0_addr(ioctl_download ? ioctl_addr : CPUAddr1),
	.ch0_rd(!CPU_nRD1),
	.ch0_wr(ioctl_wr && ioctl_index==0),// && ioctl_addr < 25'h80000),
	.ch0_din(ioctl_dout),
	.ch0_dout(romreadPRG1),
	.ch0_busy(ioctl_wait),
	
	.ch1_addr(0),//PPUAddr1 + 25'h20000),
	.ch1_rd(0),//!PPU_nRD1),
	.ch1_wr(0),	
	.ch1_din(0),	
	.ch1_dout(),//romreadCHR1),
	.ch1_busy(),
	
	.ch2_addr(CPUAddr2 + 25'h40000),
	.ch2_rd(!CPU_nRD2),	
	.ch2_wr(0),	
	.ch2_din(0),
	.ch2_dout(romreadPRG2),
	.ch2_busy(),	
	
	.ch3_addr(0),//PPUAddr2 + 25'h60000),
	.ch3_rd(0),//!PPU_nRD2),
	.ch3_wr(0),	
	.ch3_din(0),
	.ch3_dout(),//romreadCHR2),
	.ch3_busy(),
	
	.refresh(0)	
);

//  ram128k romPRG1
//(
//	.address(ioctl_download ? ioctl_addr : CPUAddr1),	
//	.clock(clk_sys),
//	.data(ioctl_dout),
//	.wren(ioctl_wr && ioctl_index==0 && ioctl_addr < 25'h20000 ),	
//	.q(romreadPRG1)
//);

  ram128k romCHR1
(
	.address(ioctl_download ? (ioctl_addr - 25'h20000) : PPUAddr1),
	.clock(clk_sys),	
	.data(ioctl_dout),
	.wren(ioctl_wr && ioctl_index==0 && (ioctl_addr >= 25'h20000 && ioctl_addr < 25'h40000) ),
	.q(romreadCHR1)
);

//  ram128k romPRG2
//(
//	.address(ioctl_download ? (ioctl_addr - 25'h40000) : CPUAddr2),	
//	.clock(clk_sys),
//	.data(ioctl_dout),
//	.wren(ioctl_wr && ioctl_index==0 && (ioctl_addr >= 25'h40000 && ioctl_addr < 25'h60000) ),	
//	.q(romreadPRG2)
//);

  ram128k romCHR2
(
	.address(ioctl_download ? (ioctl_addr - 25'h60000) : PPUAddr2),
	.clock(clk_sys),
	.data(ioctl_dout),
	.wren(ioctl_wr && ioctl_index==0 && (ioctl_addr >= 25'h60000 && ioctl_addr < 25'h80000) ),
	.q(romreadCHR2)
);

//////////////////////////////////////////////////////////////////
//framebuffer

ddram ddram(
	.*,
	.ch1_addr({fb_addr[27:20],oddframe,fb_addr[18:0]}),
	.ch1_dout(),
	.ch1_din(fb_data1),
	.ch1_req(fb_req),
	.ch1_rnw(1'b0),
	.ch1_ready(fb_ready),
	
	.ch2_addr({fb_addr2[27:20],oddframe,fb_addr2[18:0]}),
	.ch2_dout(),
	.ch2_din(fb_data2),
	.ch2_req(fb_req2),
	.ch2_rnw(1'b0),
	.ch2_ready(fb_ready2)
);

lineram lineram1 (
	.clock(clk_mem),
	.data(RGBdata),
	.rdaddress(cnt),
	.wraddress(offset1 + colorcnt),
	.wren(ce_pix && !hblank && !vblank),
	.q(fb_data1)
);

lineram lineram2 (
	.clock(clk_mem),
	.data(RGBdata2),
	.rdaddress(cnt2),
	.wraddress(offset2 + colorcnt2),
	.wren(ce_pix2 && !hblank2 && !vblank2),
	.q(fb_data2)  
);	 

`ifdef MISTER_FB
assign DDRAM_CLK       = clk_mem;
assign FB_EN           = dual;
assign FB_BASE         = oddframe ? 32'h30000000 : 32'h30080000;
assign FB_WIDTH        = horizontal ? 12'd512 : 12'd256;
assign FB_HEIGHT       = vertical ? 12'd480 : 12'd240;
assign FB_FORMAT       = 5'b00101;
assign FB_STRIDE       = 0;
assign FB_FORCE_BLANK  = 0;
`endif

wire [7:0] RGBdata  = (colorcnt == 0) ? RGBcap[23:16] : (colorcnt == 1) ? RGBcap[15:8] : RGBcap[7:0];
wire [7:0] RGBdata2 = (colorcnt2 == 0) ? RGBcap2[23:16] : (colorcnt2 == 1) ? RGBcap2[15:8] : RGBcap2[7:0];
reg [23:0] RGBcap,RGBcap2;
reg [1:0] colorcnt,colorcnt2;
reg oddframe;
	 
reg [27:0] fb_addr,fb_addr2;
wire [63:0] fb_data1,fb_data2;
wire fb_req, fb_req2;
wire fb_ready, fb_ready2;

reg [9:0] offset1,offset2;
reg [7:0] cnt,cnt2;
reg [8:0] linecnt,linecnt2;

reg oldce_pix,oldce_pix2;
reg oldhblank,oldhblank2;
reg oldvblank;
reg done,done2;
reg active1,active2;

always @(posedge clk_mem) begin
	oldce_pix <= ce_pix;
	oldhblank <= hblank;
	oldce_pix2 <= ce_pix2;
	oldhblank2 <= hblank2;
	oldvblank <= vblank;
end
	 
always @(posedge clk_mem) begin
	if (reset) begin
		offset1  <= 10'd0;
		fb_addr <= 28'h0;
		fb_req  <= 1'b0;
		cnt <= 8'h0;
		linecnt <= 9'h0;		
		colorcnt <= 2'd0;
		active1 <= 1'b0;
		oddframe <= 1'b0;
	end else begin
		if (!oldce_pix && ce_pix && !hblank && !vblank) begin           //rising edge of pixel clk, capture the RGB 
			RGBcap  <= {R1,G1,B1};
			if (divider && horizontal && screenswap && (offset1 == 0 || offset1 == 3)) RGBcap <= 24'h0;//insert black pixel for horz divider
			if (divider && vertical && screenswap && (linecnt == 1 || linecnt == 2)) RGBcap <= 24'h0;//insert black pixel for vert divider
		end else if (ce_pix && !hblank && !vblank) begin                //cycle through to write 3 bytes
			if (colorcnt < 2) colorcnt <= colorcnt + 2'b1;
		end else if (oldce_pix && !ce_pix && !hblank && !vblank) begin  //falling edge of pix clk
			offset1 <= offset1 + 10'd3;
			colorcnt <= 2'd0;
		end else if (hblank && !vblank) begin                           //transfer the line to ddram during hblank
			offset1 <= 10'd0;
			if (cnt != 8'd96 && !active2) active1 <= 1'b1;               //let either system transfer from ram to ddram without contention
			else active1 <= 1'b0;					  
			if (!fb_req && cnt < 8'd96 && !done && !DDRAM_BUSY && !active2) begin
				fb_req  <= 1'b1;
			//end else if (fb_req && fb_ready && cnt < 8'd96 && !done && !DDRAM_BUSY) begin
			end else if (fb_req && fb_ready && !DDRAM_BUSY) begin
				fb_req  <= 1'b0;
				fb_addr <= fb_addr + 28'd8;
				cnt <= cnt + 8'd1;
			end
		end else if (oldhblank && !hblank) begin                        //falling edge of hblank. it happens after vblank also currently
			cnt <= 8'h0;
			linecnt <= linecnt + 1'b1;
			if (horizontal && !done) fb_addr <= fb_addr + 28'd768;
			done <= 1'b0;
		end else if (vblank) begin                                      //reset everything for the next frame
			if(!oldvblank) oddframe <= ~oddframe;
			if (horizontal) fb_addr <= screenswap ? 28'd768 : 28'h0;
			else fb_addr <= screenswap ? 28'd184320 : 28'h0 ;
			cnt <= 8'h0;
			offset1 <= 10'd0;
			linecnt <= 9'h0;			
			done <= 1'b1;
		end
	end	  
end	 
	 
always @(posedge clk_mem) begin
	if (reset) begin
		offset2  <= 10'd0;
		fb_addr2 <= 28'h0;
		fb_req2  <= 1'b0;
		cnt2 <= 8'h0;
		linecnt2 <= 9'h0;		
		colorcnt2 <= 2'd0;
		active2 <= 1'b0;
	end else begin
		if (!oldce_pix2 && ce_pix2 && !hblank2 && !vblank2) begin 
			RGBcap2 <= {R2,G2,B2};
			if (divider && horizontal && !screenswap && (offset2 == 0 || offset2 == 3)) RGBcap2 <= 24'h0;
			if (divider && vertical && !screenswap && (linecnt2 == 1 || linecnt2 == 2)) RGBcap2 <= 24'h0;			
		end else if (ce_pix2 && !hblank2 && !vblank2) begin
			if (colorcnt2 < 2) colorcnt2 <= colorcnt2 + 2'b1;		  
		end else if (oldce_pix2 && !ce_pix2 && !hblank2 && !vblank2) begin
			offset2 <= offset2 + 10'd3;
			colorcnt2 <= 2'd0;
		end else if (hblank2 && !vblank2) begin
			offset2 <= 10'd0;
			if (cnt2 != 8'd96 && !active1) active2 <= 1'b1;
			else active2 <= 1'b0;
			if (!fb_req2 && cnt2 < 8'd96 && !done2 && !DDRAM_BUSY && !active1) begin
				fb_req2  <= 1'b1;
			//end else if (fb_req2 && fb_ready2 && cnt2 < 8'd96 && !done2 && !DDRAM_BUSY) begin
			end else if (fb_req2 && fb_ready2 && !DDRAM_BUSY) begin
				fb_req2  <= 1'b0;
				fb_addr2 <= fb_addr2 + 8'd8;
				cnt2 <= cnt2 + 8'd1;
			end
		end else if (oldhblank2 && !hblank2) begin 
			cnt2 <= 8'h0;
			linecnt2 <= linecnt2 + 1'b1;			
			if (horizontal && !done2) fb_addr2 <= fb_addr2 + 28'd768;
			done2 <= 1'b0;
		end else if (vblank2) begin
			if (horizontal) fb_addr2 <= screenswap ? 28'h0 : 28'd768;
			else fb_addr2 <= screenswap ? 28'h0 : 28'd184320;// for both vertical and no splitscreen
			cnt2 <= 8'h0;
			linecnt2 <= 9'h0;			
			offset2 <= 10'd0;
			done2 <= 1'b1;
		end  
	end	 
end

endmodule
