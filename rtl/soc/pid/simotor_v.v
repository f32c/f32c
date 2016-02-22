//-----------------------------------------------------
// Copyright: Davor Jadrijevic
// License: BSD
// Function: Simulates motor with encoder
// Input: bridge forward/reverse PWM (F, R)
// Output: encoder signals (A, B)
//-----------------------------------------------------
module simotor_v (
  CLOCK, //  fast clock (50 MHz) to scan the PWM
  F,     //  pwm forward input
  R,     //  pwm reverse input
  A,     //  encoder output A
  B      //  encoder output B
); // End of port list
  //-------------Input Ports-----------------------------
  input CLOCK;
  input	F;
  input	R;
  //-------------Output Ports----------------------------
  output A;
  output B;
  //-------------Input ports Data Type-------------------
  // By rule all the input ports should be wires
  wire CLOCK;
  wire F;
  wire R;
  wire A;
  wire B;
  //-------------Output Ports Data Type------------------
  // Output port can be a storage element (reg) or a wire
  reg [1:0] encoder;         // encoder output patter

  reg signed [31:0] speed;
  reg [31:0] counter;   // main motor position counter

/*
** slow motor, visible acceleration
   parameter [31:0] motor_power = 4;
   parameter [4:0]  motor_speed = 21;
   parameter [31:0] motor_friction = 1;
   pid parameters
   KP=9;
   KI=12;
   KD=0;

** fast motor,
   PID parameters from real motor approx working
   parameter [31:0] motor_power = 64*8;  // acceleration
   parameter [4:0]  motor_speed = 19-3;  // inverse log2 friction proportional to speed
   // larger motor_speed values allow higher motor top speed
   parameter [31:0] motor_friction = 8*8; // static friction
   pid parameters
   KP=4;
   KI=7;
   KD=-6;
*/
  
  parameter [9:0] motor_power = 512;  // acceleration
  parameter [4:0] motor_speed = 16;  // inverse log2 friction proportional to speed
  // larger motor_speed values allow higher motor top speed
  parameter [7:0] motor_friction = 60; // static friction
  // when motor_power > motor_friction it starts to move
  parameter [3:0] prescaler = 0; // number of bits in the counter for clock slowdown

  reg [31:0] applied_power;
  
  reg unsigned [prescaler:0] slowdown;
  
  // apply motor voltage 
  wire signed [31:0] speed_powered;
  assign speed_powered = speed+applied_power;

  wire signed [7:0] sfriction;
  assign sfriction = speed >= 0 ? motor_friction : -motor_friction;

  //------------Code Starts Here-------------------------
  // We trigger the below block with respect to positive
  // edge of the CLOCK.
  always @ (posedge CLOCK)
  begin : MOTOR_SIMULATOR // Block Name
    applied_power <= F == 1 && R == 0 ?  motor_power :
                     F == 0 && R == 1 ? -motor_power : 0;
    slowdown <= slowdown + 1;
    if(slowdown == 0)
    begin

    // accelerate
    speed <= speed_powered > motor_friction || speed_powered < -motor_friction ? 
             speed_powered 
             - (speed_powered >= 0 ? (speed_powered >> motor_speed) : -((-speed_powered) >> motor_speed) )
             - sfriction : 0;

    // add speed to the counter
    counter <= counter + speed;

    // generate encoder value
    case(counter[31:30])
      2'b00: encoder <= 2'b01;
      2'b01: encoder <= 2'b11;
      2'b10: encoder <= 2'b10;
      2'b11: encoder <= 2'b00;
    endcase
    
    end
    
  end // End of Block CLOCK_DIVIDER

  assign A = encoder[0];
  assign B = encoder[1];
endmodule // End of Module MOTOR_SIMULATOR
