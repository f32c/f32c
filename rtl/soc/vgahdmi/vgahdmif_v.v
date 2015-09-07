// 640x480 video display

// Emard:
// fetch data from FIFO
// adding both HDMI and VGA output
// no vendor-specific modules here
// (differential buffers, PLLs)

// LICENSE=BSD

// some code taken from
// (c) fpga4fun.com & KNJN LLC 2013

////////////////////////////////////////////////////////////////////////
module vgahdmi_v(
        input wire clk, /* CPU clock */
        input wire clk_pixel, /* 25 MHz */
        input wire clk_tmds, /* 250 MHz (set to 0 for VGA-only) */
        input wire [7:0] red_byte, green_byte, blue_byte, bright_byte, // get data from fifo
        output wire rd, // rd=1: read cycle is complete, fetch next data
        output wire vga_hsync, vga_vsync, // active low, vsync will reset fifo
        output wire [2:0] vga_r, vga_g, vga_b,
	output wire [2:0] TMDS_out_RGB
);

parameter test_picture = 0;
// pixel doubling may not work (long time not maintained)
parameter dbl_x = 0; // 0-normal X, 1-double X
parameter dbl_y = 0; // 0-normal Y, 1-double Y

parameter resolution_x = 640;
parameter hsync_front_porch = 16;
parameter hsync_pulse = 96;
parameter hsync_back_porch = 44; // 48
parameter frame_x = resolution_x + hsync_front_porch + hsync_pulse + hsync_back_porch;
// frame_x = 640 + 16 + 96 + 48 = 800;
parameter resolution_y = 480;
parameter vsync_front_porch = 10;
parameter vsync_pulse = 2;
parameter vsync_back_porch = 31; // 33
parameter frame_y = resolution_y + vsync_front_porch + vsync_pulse + vsync_back_porch;
// frame_y = 480 + 10 + 2 + 33 = 525;
// refresh_rate = pixel_clock/(frame_x*frame_y) = 25MHz / (800*525) = 59.52Hz
////////////////////////////////////////////////////////////////////////

wire clk_TMDS;
wire pixclk;

assign clk_TMDS = clk_tmds; // 250 MHz
assign pixclk = clk_pixel;  //  25 MHz

reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
always @(posedge pixclk) DrawArea <= (CounterX<resolution_x) && (CounterY<resolution_y);

wire fetcharea; // when to fetch data, must be 1 byte earlier than draw area
assign fetcharea = (CounterX[9:3]<(resolution_x/8-1) || CounterX[9:3]==(frame_x/8-1)) && (CounterY<resolution_y);

always @(posedge pixclk) CounterX <= (CounterX==frame_x-1) ? 0 : CounterX+1;
always @(posedge pixclk) if(CounterX==frame_x-1) CounterY <= (CounterY==frame_y-1) ? 0 : CounterY+1;

always @(posedge pixclk) hSync <= (CounterX>=resolution_x + hsync_front_porch) && (CounterX<resolution_x + hsync_front_porch + hsync_pulse);
always @(posedge pixclk) vSync <= (CounterY>=resolution_y + vsync_front_porch) && (CounterY<resolution_y + vsync_front_porch + vsync_pulse);

// signal when to change address (to get new data from the memory)
// phase shifted some pixels after the data fetch
// so memory will have enough time to select new address and
// stabilize data on the bus
//wire changeaddr;
//assign changeaddr = CounterX[2+dbl_x:0] == 2;

parameter synclen = 3; // >=3, bit length of the clock synchronizer shift register
reg [synclen-1:0] clksync; /* fifo to clock synchronizer shift register */

// signal: when to shift pixel data and when to get new data from the memory
wire getbyte;
assign getbyte = CounterX[2+dbl_x:0] == 0;

/* clk-to-pixclk synchronizer:
** pixclk rising edge is detected using shift register
** edge detection happens after delay (clk * synclen)
** then rd is set high for one clk cycle
** intiating fetch from new data from RAM fifo
** for various clk and pixclk ratios, synclen may need to be adjusted
** in order not to change dispData before content is copied to shift_red register
*/
reg toggle_read_complete;
always @(posedge pixclk)
  if(getbyte != 0 && fetcharea != 0)
    toggle_read_complete <= ~toggle_read_complete; // changes when read data is complete
// synchronize pixclk to clk
always @(negedge clk) // clk > pixclk/8 for this to work
  clksync <= {clksync[synclen-2:0], toggle_read_complete}; // at bit 0 enter new pixclk value
// XOR: difference in 2 consecutive clksync values
// create a short rd pulse that lasts one clk period.
// This signal is request to fetch new data
assign rd = clksync[synclen-2] ^ clksync[synclen-1];  // rd = read cycle complete

reg [7:0] shift_red, shift_green, shift_blue, shift_bright;
always @(posedge pixclk)
  begin
    if(dbl_x == 0 || CounterX[0] == 0)
      begin
        shift_red     <= getbyte != 0 ?    red_byte : shift_red[7:1];
        shift_green   <= getbyte != 0 ?  green_byte : shift_green[7:1];
        shift_blue    <= getbyte != 0 ?   blue_byte : shift_blue[7:1];
        shift_bright  <= getbyte != 0 ? bright_byte : shift_bright[7:1];
      end
  end

wire [7:0] colorValue[0:3];
// todo: 2 same black colors, introduce a table
// to have one gray other true black
assign colorValue[0] = shift_red[0]    != 0 ? colorValue[3] : 0;
assign colorValue[1] = shift_green[0]  != 0 ? colorValue[3] : 0;
assign colorValue[2] = shift_blue[0]   != 0 ? colorValue[3] : 0;
assign colorValue[3][7]   = shift_bright[0];
assign colorValue[3][6:0] = 7'h7F;

// test picture generator
wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] test_red, test_green, test_blue;
always @(posedge pixclk) test_red <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge pixclk) test_green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
always @(posedge pixclk) test_blue <= CounterY[7:0] | W | A;

// generate VGA output, mixing with test picture if enabled
assign vga_r = DrawArea ? (test_picture ? test_red[7:5]  : colorValue[0][7:5]) : 0;
assign vga_g = DrawArea ? (                                colorValue[1][7:5]) : 0;
assign vga_b = DrawArea ? (test_picture ? test_blue[7:5] : colorValue[2][7:5]) : 0;
assign vga_hsync = ~hSync;
assign vga_vsync = ~vSync;

// generate HDMI output, mixing with test picture if enabled
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;

TMDS_encoder encode_R
(
  .clk(pixclk),
  .VD(test_picture ? test_red : colorValue[0]),
  .CD(2'b00),
  .VDE(DrawArea),
  .TMDS(TMDS_red)
);
TMDS_encoder encode_G
(
  .clk(pixclk),
  .VD(colorValue[1]),
  .CD(2'b00),
  .VDE(DrawArea),
  .TMDS(TMDS_green)
);
TMDS_encoder encode_B
(
  .clk(pixclk),
  .VD(test_picture ? test_blue : colorValue[2]),
  .CD({vSync,hSync}),
  .VDE(DrawArea),
  .TMDS(TMDS_blue)
);

////////////////////////////////////////////////////////////////////////
reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
reg TMDS_shift_load=0;
always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
	TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:1];
	TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:1];
	TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:1];
	TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : TMDS_mod10+4'd1;
end

// ******* HDMI OUTPUT ********
assign TMDS_out_RGB = {TMDS_shift_red[0], TMDS_shift_green[0], TMDS_shift_blue[0]};
endmodule

////////////////////////////////////////////////////////////////////////
module TMDS_encoder(
	input clk,
	input [7:0] VD,  // video data (red, green or blue)
	input [1:0] CD,  // control data
	input VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
	output reg [9:0] TMDS = 0
);

wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
wire XNOR = (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
wire [8:0] q_m = {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};

reg [3:0] balance_acc = 0;
wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
wire balance_sign_eq = (balance[3] == balance_acc[3]);
wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);

always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
endmodule

////////////////////////////////////////////////////////////////////////
