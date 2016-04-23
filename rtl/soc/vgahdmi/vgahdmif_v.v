// 640x480 video display

// Emard:
// fetch data from FIFO
// adding both HDMI and VGA output
// no vendor-specific modules here
// (differential buffers, PLLs)

// the pixel data in *_byte registers
// should be present ahead of time
// signal 'fetch_next' is set high for 1 clk_pixel
// period as soon as current pixel data is consumed
// there should be enough time for fifo to fetch
// new data

// LICENSE=BSD

// some code taken from
// (c) fpga4fun.com & KNJN LLC 2013

////////////////////////////////////////////////////////////////////////
module vgahdmi_v(
        input wire clk_pixel, /* 25 MHz */
        input wire clk_tmds, /* 250 MHz (set to 0 for VGA-only) */
        input wire test_picture, // show test picture instead of bitmap
        input wire [7:0] red_byte, green_byte, blue_byte, bright_byte, // get data from fifo
        output wire fetch_next, // fetch_next=1: read cycle is complete, fetch next data
        output wire line_repeat, // repeat video line
        output wire vga_hsync, vga_vsync, // active low, vsync will reset fifo
        output wire vga_vblank, vga_blank, // vertical and combined v+h blank signal
        output wire [7:0] vga_r, vga_g, vga_b
);

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

wire pixclk;

assign pixclk = clk_pixel;  //  25 MHz

reg [9:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
reg vBlank;

// wire fetcharea; // when to fetch data, must be 1 byte earlier than draw area
wire fetcharea = (CounterX<resolution_x) && (CounterY<resolution_y);
// DrawArea is fetcharea delayed one clock later
always @(posedge pixclk) DrawArea <= fetcharea;
// reset X and Y counters at frame boundary
always @(posedge pixclk) CounterX <= (CounterX==frame_x-1) ? 0 : CounterX+1;
always @(posedge pixclk) if(CounterX==frame_x-1) CounterY <= (CounterY==frame_y-1) ? 0 : CounterY+1;

always @(posedge pixclk)
  begin
    if(CounterX == resolution_x + hsync_front_porch)
      hSync <= 1;
    if(CounterX == resolution_x + hsync_front_porch + hsync_pulse)
      hSync <= 0;
  end
always @(posedge pixclk)
  begin
    if(CounterY == resolution_y)
      vBlank <= 1;
    if(CounterY == resolution_y + vsync_front_porch)
      vSync <= 1;
    if(CounterY == resolution_y + vsync_front_porch + vsync_pulse)
    begin
      vSync <= 0;
      vBlank <= 0;
    end
  end

parameter synclen = 3; // >=3, bit length of the clock synchronizer shift register
reg [synclen-1:0] clksync; /* fifo to clock synchronizer shift register */

// fetch new data every pixel
assign fetch_next = fetcharea;

reg [7:0] shift_red, shift_green, shift_blue;
always @(posedge pixclk)
    if(dbl_x == 0 || CounterX[0] == 0)
      begin
        shift_red     <= red_byte;
        shift_green   <= green_byte;
        shift_blue    <= blue_byte;
      end

// test picture generator
wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] test_red, test_green, test_blue;
always @(posedge pixclk) test_red <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge pixclk) test_green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
always @(posedge pixclk) test_blue <= CounterY[7:0] | W | A;

// generate VGA output, mixing with test picture if enabled
assign vga_r = DrawArea ? (test_picture ? test_red[7:0]   : red_byte[7:0]  ) : 0;
assign vga_g = DrawArea ? (test_picture ? test_green[7:0] : green_byte[7:0]) : 0;
assign vga_b = DrawArea ? (test_picture ? test_blue[7:0]  : blue_byte[7:0] ) : 0;
assign vga_hsync = hSync;
assign vga_vsync = vSync;
assign vga_vblank = vBlank;
assign vga_blank = ~DrawArea;
assign line_repeat = dbl_y ? vga_hsync & ~CounterY[0] : 0;

endmodule
