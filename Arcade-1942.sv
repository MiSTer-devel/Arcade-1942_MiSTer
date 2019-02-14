//============================================================================
//  Arcade: 1942  by Jose Tejada Gomez. Twitter: @topapate 
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
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
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd1;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd1;


`include "build_id.v" 
localparam CONF_STR = {
	"A.1942;;", 
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"OCD,Difficulty,Normal,Easy,Hard,Very Hard;",
	"O67,Lives,3,1,2,5;",
	"O89,Bonus,30/100,30/80,20/100,20/80;",
	"OA,Invulnerability,No,Yes;",
	"-;",
	"R0,Reset;",
	"J,Fire,Loop,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys)
);

reg ce_12, ce_6, ce_3, ce_1p5;
always @(posedge clk_sys) begin
	reg [3:0] div;
	
	div <= div + 1'd1;
	ce_12  <= !div[0:0];
	ce_6   <= !div[1:0];
	ce_3   <= !div[2:0];
	ce_1p5 <= !div[3:0];
end


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joy_0, joy_1;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joy_0),
	.joystick_1(joy_1),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		case(code)
			'h75: btn_up         <= pressed; // up
			'h72: btn_down       <= pressed; // down
			'h6B: btn_left      	<= pressed; // left
			'h74: btn_right      <= pressed; // right
			'h05: btn_one_player <= pressed; // F1
			'h06: btn_two_players<= pressed; // F2
			'h04: btn_coin			<= pressed; // F3
			'h0C: btn_pause		<= pressed; // F4
			'h14: btn_fire1 		<= pressed; // ctrl
			'h11: btn_fire1 		<= pressed; // alt
			'h29: btn_fire2   	<= pressed; // Space
		endcase
	end
end

reg btn_one_player = 0;
reg btn_two_players = 0;
reg btn_left = 0;
reg btn_right = 0;
reg btn_down = 0;
reg btn_up = 0;
reg btn_fire1 = 0;
reg btn_fire2 = 0;
reg btn_coin  = 0;
reg btn_pause = 0;

wire [15:0] joy = joy_0 | joy_1;

wire m_up     = btn_up    | joy[3];
wire m_down   = btn_down  | joy[2];
wire m_left   = btn_left  | joy[1];
wire m_right  = btn_right | joy[0];
wire m_fire   = btn_fire1 | joy[4];
wire m_jump   = btn_fire2 | joy[5];
wire m_pause  = btn_pause | joy[9];

wire m_start1 = btn_one_player  | joy[6];
wire m_start2 = btn_two_players | joy[7];
wire m_coin   = btn_coin        | joy[8];

reg pause = 0;
always @(posedge clk_sys) begin
	reg old_pause;
	
	old_pause <= m_pause;
	if(~old_pause & m_pause) pause <= ~pause;
	if(status[0] | buttons[1]) pause <= 0;
end

///////////////////////////////////////////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

arcade_rotate_fx #(256,224,12,1) arcade_video
(
	.*,

	.clk_video(clk_sys),
	.ce_pix(ce_6),

	.RGB_in({r,g,b}),
	.HBlank(~hblank),
	.VBlank(~vblank),
	.HSync(hs),
	.VSync(vs),
	
	.fx(status[5:3]),
	.no_rotate(status[2])
);

///////////////////////////////////////////////////////////////////

reg prog_we;
always @(posedge clk_sys) prog_we <= ioctl_wr;

wire [16:0] prog_addr;
wire  [7:0] prog_data;
wire  [1:0] prog_mask; 
wire [15:0] rom_data;
wire [16:0] rom_addr;

jtgng_prom #(.dw(8), .aw(17)) u_rom_l
(
	.clk    ( clk_sys        ),
	.cen    ( 1              ),
	.rd_addr( rom_addr       ),
	.q      ( rom_data[7:0]  ),

	.wr_addr( prog_addr      ),
	.data   ( prog_data      ),
	.we     ( ~prog_mask[0] & prog_we )
);

jtgng_prom #(.dw(8), .aw(17)) u_rom_u
(
	.clk    ( clk_sys        ),
	.cen    ( 1              ),
	.rd_addr( rom_addr       ),
	.q      ( rom_data[15:8] ),

	.wr_addr( prog_addr      ),
	.data   ( prog_data      ),
	.we     ( ~prog_mask[1] & prog_we )
);

///////////////////////////////////////////////////////////////////

wire reset = RESET | status[0] | buttons[1];

jt1942_game game
(
	.rst(reset),

	.clk_rom(clk_sys),
	.clk(clk_sys),
	.cen12(ce_12),
	.cen6(ce_6),
	.cen3(ce_3),
	.cen1p5(ce_1p5),

	.red(r),
	.green(g),
	.blue(b),
	.LHBL(hblank),
	.LVBL(vblank),
	.HS(hs),
	.VS(vs),

	.joystick1(~{m_jump,m_fire,m_up,m_down,m_left,m_right}),
	.joystick2(~{m_jump,m_fire,m_up,m_down,m_left,m_right}),
	.start_button(~{m_start2,m_start1}),
	.coin_input(~{1'b0,m_coin}),

	// SDRAM interface
	.downloading ( ioctl_download ),
	.loop_rst    ( reset    ),
	.sdram_addr  ( rom_addr ),
	.data_read   ( rom_data ),

	// PROM programming
	.ioctl_addr(ioctl_addr),
	.ioctl_data(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.prog_addr(prog_addr),
	.prog_data(prog_data),
	.prog_mask(prog_mask),

	.cheat_invincible( status[10]  ),
	.dip_pause   ( ~pause         ),
	.dip_level   ( ~status[13:12] ),
	.dip_upright ( 0              ),
	.dip_planes  ( ~status[7:6]   ),
	.dip_price   ( 3'b111         ), // 1 credit, 1 coin
	.dip_bonus   ( ~status[9:8]   ),
	.dip_test    ( 1              ),
	.snd         ( audio          )
);

wire [8:0] audio;
assign AUDIO_R = {audio,5'd0};
assign AUDIO_L = {audio,5'd0};
assign AUDIO_S = 0;

endmodule
