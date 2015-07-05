//////////////////////////////////////////////////////////////////////////////////
// Copyright Davor Jadrijevic
// Improved signed shift PID arithmetics
//
// Copyright EDGAR RODRIGO MANCIPE TOLOZA, UPB
// Original PID module
// 
// LICENSE=BSD
//
// Module Name: ctrlpid
// Project Name: ControlPID
// Target Devices: F32C FPGArduino
//////////////////////////////////////////////////////////////////////////////////
module ctrlpid_v(clk_pid, ce, error, a, m_k_out, reset, KP, KI, KD);

 parameter       psc = 15; // prescaler number of bits - defines control loop frequency
 parameter       aw = 1;  // address width (number of bits in PID address)
 parameter       an = (1<<aw); // number of addressable PIDs = 2^aw (max an = psc-4)
 parameter       ow = 12; // width of output bits (precision + ow >= 9)
 parameter       ew = 24; // number of error bits (ew < pw)
 parameter       pw = 32; // number of bits in pid calculation 
 parameter       cw =  6; // number of bits in pid coefficients
// **** iteration control loop frequency ****
// clock_pid/number_of_states
// number of states is number of clocks needed for calculation of PID
// number of states is 16
// choose freq = 2^n Hz, e.g.
// clk=81.25MHz, psc = 15
// 81.25e6 / 2^15 = 2479 Hz = f(clk_pid) control loop frequency (too fast? should be about 2 kHz)
// find approx integer fp, closest to control loop frequency
// fp = 9 (2^9 = 512) // 9 used as f=2^fp for bit shift calculation
// f(clk_pid) = 2^fp * number_of_states = 2^9 * 16 = 8192 Hz
// PID values can stay the same:
// after chaging control loop frequency adjust fp parameter
 parameter signed [cw-1:0] fp = 9;  // fp = log(f(clk_pid)/Number_of_states)/log(2)

// ***** precision = log scaling for the fixed point arithmetics *****
// defines precision of the calculation using fixed point arithmetics
// lower value = lower precision, lower chance for overflow
// higher value = higher precision, higher chance for overflow
 parameter [3:0] precision = 1; 
 // output precision to fit output width
 // if output is 17 bits (16 bit abs pwm value + 1 bit sign),
 // then clamp slightly less than 16bit e.g. 32'hFF00
 // if output is 12 bits (11 bit abs pwm value + 1 bit sign)
 // then clamp slightly less than 11bit e.g. 32'h7D0 or 32'h7F0
 // 5 is for changing 16-bit pwm to 11-bit pwm 
 // limit of the unscaled output
 parameter signed [pw-1:0] antiwindup = 8'hFF << (precision + ow - 9);

 input clk_pid, reset;
 output reg ce;
 output [aw-1:0] a; // the pid memory address
 input signed [ew-1:0] error;
 input signed [cw-1:0] KP,KI,KD; // input 2^n shifting -31..31
 /*
 valid range for precision=1 fp=9
 KP =   0..21
 KI = -21..21
 KD = -21..21
 */
 output signed [ow-1:0] m_k_out; // motor power

 reg signed [pw-1:0] e_k_0[an-1:0];     //error actual
 reg signed [pw-1:0] e_k_1[an-1:0];     //error 1 cycle before
 reg signed [pw-1:0] e_k_2[an-1:0];     //error 2 cycles before
 reg signed [pw-1:0] u_k[an-1:0];       //result of PID equation

 wire signed [pw-1:0] xerror; // sign-extended error
 assign xerror = { {(pw-ew){error[ew-1]}}, error };

 wire signed [cw-1:0] Kp;  //proportional gain
 wire signed [cw-1:0] Ki;  //integral gain
 wire signed [cw-1:0] Kd;  //derivativative gain

 // those assigmnents make input PID parameters 
 // invariant to changing of precision
 assign Kp = KP + precision;
 assign Ki = KI + precision;
 assign Kd = KD + precision;
 
 wire signed [cw-1:0] Kdfp;
 assign Kdfp = Kd+fp;
 wire signed [cw-1:0] Ki1fp;
 assign Ki1fp = Ki-1-fp;
 wire signed [cw-1:0] Kd1fp;
 assign Kd1fp = Kd+1+fp;

 parameter statew = 4; // state bit width 4 bits -> 16 states
 wire [statew-1:0] state;
 
 // **** TODO: extend uswitch bits to count the state ****
 // reg [psc-1:0] uswitch; // unit switch phase
 reg [psc-1:0] uswitch; // unit switch phase
 assign state = uswitch[psc-aw-1:psc-aw-statew];
 
 always @(posedge clk_pid)
   uswitch <= uswitch + 1;
 /*
 uswitch: a..as..sx..x
 assign state = uswitch[psc-aw-1:psc-aw-statew]; 
 ce = data available for external reading
 */
 
 assign a = uswitch[psc-1:psc-aw];

 // do one calculation step at each state increment 
 wire calc;
 assign calc = uswitch[psc-aw-statew-1:0] == 0 ? 1 : 0;

 always @(posedge clk_pid)
   if(calc)
        case(state)
                // state 0 NOP
                // after changing of address it allows data to stabilize
                // *** reset logic removed ***
	        // reset all accumulated values
	        // this creates counter-direction
	        // after step change of the setpoint
	        /*
                m_k[a]   <= 0;
                u_k[a]   <= 0;
                e_k_1[a] <= 0;
                e_k_2[a] <= 0;
                */
	  1: e_k_0[a]   <= xerror; // copy sign extended error value
          // discrete fixed point PID
          // m(k) = m(k-1) + (Kp + Kd/T + Ki*T/2)*e(k)
          //               + (Ki*T/2 - Kp - 2Kd/T)*e(k-1) 
          //               + (Kd/T)*e(k-2)
          // T = 1/f
          2: u_k[a]     <= u_k[a] + (e_k_0[a]<<<Kp)        // +Kp * e(k)
                                  - (e_k_1[a]<<<Kp);       // -Kp * e(k-1)
          3: if(Kdfp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Kdfp))    // +Kd / T * e(k)
                                  + (e_k_2[a]<<<(Kdfp));   // +Kd / T * e(k-2)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Kdfp))   // +Kd / T * e(k)
                                  + (e_k_2[a]>>>(-Kdfp));  // +Kd / T * e(k-2)
          4: if(Ki1fp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Ki1fp))   // +Ki * T/2 * e(k)
                                  + (e_k_1[a]<<<(Ki1fp));  // +Ki * T/2 * e(k-1)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Ki1fp))  // +Ki * T/2 * e(k)
                                  + (e_k_1[a]>>>(-Ki1fp)); // +Ki * T/2 * e(k-1)
          5: if(Kd1fp >= 0)
                u_k[a]  <= u_k[a] - (e_k_1[a]<<<(Kd1fp));  // -Kd * 2/T * e(k-1)
              else
                u_k[a]  <= u_k[a] - (e_k_1[a]>>>(-Kd1fp)); // -Kd * 2/T * e(k-1)
              // ***************** P only, debugging
              // u_k[a] <= e_k <<< Kp;
              // *****************
              // antiwindup
	  6: if(u_k[a] >   antiwindup)
                 u_k[a] <=  antiwindup;        // max positiva value
          7: if(u_k[a] <  -antiwindup)
                 u_k[a] <= -antiwindup;        // min negative value
	  8: begin
               // m_k_out <= u_k[a] >>> precision; // m(k) = u(k)  output
               // m_k_out <= u_k[a][precision+ow-1:precision]; // m(k) = u(k)  output
	       e_k_2[a] <= e_k_1[a];  //  e(k-2) = e(k-1)
	       e_k_1[a] <= e_k_0[a];  //  e(k-1) = e(k)
	       ce <= 1; // output data available
             end
         15: ce <= 0; // output data not available
        endcase

 assign m_k_out = u_k[a][precision+ow-1:precision]; // bit shifting, output scaling

endmodule
