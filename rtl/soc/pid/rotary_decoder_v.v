//////////////////////////////////////////////////////////////////////////////////
// Engineer: 		 EDGAR RODRIGO MANCIPE TOLOZA
// University: 	 UPB
// Module Name:    encoder_cuadratura 
// Project Name: 	 ControlPID
// Target Devices: DE0-Nano
//////////////////////////////////////////////////////////////////////////////////
module rotary_decoder_v(clk, A, B, reset, counter);

parameter cw = 24; // count width

input clk, A, B, reset;
output reg [cw-1:0] counter = 0; // by default it counts 24-bit

//output of the FFD      
reg [2:0] A_delayed, B_delayed;

//Circuit for encoder, shift register
always @(posedge clk) A_delayed <= {A_delayed[1:0], A};//3 ffD
always @(posedge clk) B_delayed <= {B_delayed[1:0], B};//3 ffD

//XOR logic 
wire count_enable = (A_delayed[1] ^ A_delayed[2] 
                   ^ B_delayed[1] ^ B_delayed[2]);
									
wire count_direction = A_delayed[1] ^ B_delayed[2];

//rotation of encoder 
always @(posedge clk)
begin
  if (reset) 
    counter = 0;//reset the counter
  if(count_enable)// count enable signal
    begin
      if(count_direction) 
        counter = counter + 1;
      else 
        counter = counter - 1;
    end

end
endmodule
