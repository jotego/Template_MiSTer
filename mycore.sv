//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
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
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

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
	output	USER_OSD,
	output	[1:0] USER_MODE,
	input	[7:0] USER_IN,
	output	[7:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[31:29]}; //Assign 3 bits of status (31:29)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
localparam CONF_STR = {
	"MyCore;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O2,TV Mode,NTSC,PAL;",
	"O34,Noise,White,Red,Green,Blue;",
	"-;",
	"OUV,UserIO Joystick,Off,DB15 ,DB9MD;",
	"OT,UserIO Players, 1 Player,2 Players;",
	"-;",
	"P1-;",
	"P1O5,Option 1-1,Off,On;",
	"d0P1F1,BIN;",
	"H0P1O6,Option 1-2,Off,On;",
	"-;",
	"P2,Test Page 2;",
	"P2-;",
	"P2-, -= Options in page 2 =-;",
	"P2-;",
	"P2S0,DSK;",
	"P2O67,Option 2,1,2,3,4;",
	"-;",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire [15:0] joystick_0_USB,joystick_1_USB;

// Sample: 2 fire buttons + Start 1/2 players + Coin
// CO S2 S1 F2 F1 U D L R 
wire [31:0] Joystick_0 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[5:0]} : Joystick_0_USB;
wire [31:0] Joystick_1 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[5:0]} : joydb_1ena ? Joystick_0_USB : Joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joy_raw(joydb_1[5:0]),
	.ps2_key(ps2_key)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

wire [1:0] col = status[4:3];

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

mycore mycore
(
	.clk(clk_sys),
	.reset(reset),
	
	.pal(status[2]),
	.scandouble(forced_scandoubler),

	.ce_pix(ce_pix),

	.HBlank(HBlank),
	.HSync(HSync),
	.VBlank(VBlank),
	.VSync(VSync),

	.video(video)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
assign VGA_G  = (!col || col == 2) ? video : 8'd0;
assign VGA_R  = (!col || col == 1) ? video : 8'd0;
assign VGA_B  = (!col || col == 3) ? video : 8'd0;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

endmodule
