//------------------------------------------------------------------------------
//           i2s 2 Channel for DAC PCM5102
//------------------------------------------------------------------------------
// http://www.ti.com/product/PCM5101A-Q1/datasheet/specifications#slase121473
module i2s_v
#(
  parameter    fmt = 0,            // 0:i2s standard, 1:left justified
  parameter    clk_hz  = 25000000, // Hz input clock frequency
  parameter    lrck_hz = 48000     // Hz output PCM frequency
)
(
  input        clk,  // 25-100 MHz
  input [15:0] l,r,  // PCM 16-bit signed
  output       din,  // pin on pcm5102 data
  output       bck,  // pin on pcm5102 bit clock
  output       lrck  // pin on pcm5102 L/R clock
);
  parameter c_pa_bits = 32; // number of bits in phase accumulator
  parameter [63:0] pa_inc = 2**(c_pa_bits+5) * lrck_hz / clk_hz;
  parameter [c_pa_bits-2:0] c_pa_inc = pa_inc;

  // phase accumulator
  reg [c_pa_bits-1:0] pa;
  always @(posedge clk)
    pa <= pa[c_pa_bits-2:0] + c_pa_inc;

  reg [31:0] i2s_data;
  reg [5:0] i2s_cnt; // 6 extra bits, 5 for 32-bit data, 1 for clock
  parameter [4:0] latch_phase = fmt ? ~0 : 0;
  always @(posedge clk)
  begin
    if(pa[c_pa_bits-1])
    begin
      if(i2s_cnt[0])
      begin
        if(i2s_cnt[5:1] == latch_phase)
          i2s_data <= {l,r};
        else
          i2s_data[31:1] <= i2s_data[30:0];
      end
      i2s_cnt <= i2s_cnt + 1;
    end
  end
  assign lrck = fmt ? ~i2s_cnt[5] : i2s_cnt[5];
  assign bck  = i2s_cnt[0];
  assign din  = i2s_data[31]; // MSB first, but 1 bit delayed after lrck edge
endmodule
