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

 parameter       aw = 1; // address width (number of bits in PID address)
 parameter       an = (1<<aw); // number of addressable PIDs = 2^aw
 parameter       ow = 12; // width of output bits (precision + ow >= 9)
 parameter       ew = 24; // number of error bits (ew < pw)
 parameter       pw = 32; // number of bits in pid calculation 
 parameter       cw =  6; // number of bits in pid coefficients
// **** iteration control loop frequency ****
// clock_pid/number_of_states
// number of states is number of clocks needed for calculation of PID
// number of states is 8 (not counting reset state executed only once)
// choose freq = 2^n Hz, e.g.
// clk=81.25MHz, psc = 12, states = 8
// 81.25e6 / 2^12 / 8 = 2479 Hz = control loop frequency (too fast? should be about 256 Hz)
// if control loop frequency is 256 Hz
// fp = 8 (2^8 = 256) // 8 used as f=2^fp for bit shift calculation
// f(clk_pid) = 2^fp * number_of_states
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
 output wire ce;
 output [aw-1:0] a; // the pid memory address
 input signed [ew-1:0] error;
 input signed [cw-1:0] KP,KI,KD; // input 2^n shifting -31..31
 /*
 valid range for precision=1
 KP =  -1..30
 KI = -30..30
 KD = -30..30
 */
 output signed [ow-1:0] m_k_out; // motor power

 reg signed [ow-1:0] m_k[an-1:0];       //muestra actual
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

 reg [2:0] state;
 
 parameter psc = 12; // prescaler number of bits
 
 // **** TODO: extend uswitch bits to count the state ****
 reg [psc-1:0] uswitch; // unit switch phase
 
 always @(posedge clk_pid)
   uswitch <= uswitch + 1;
 /*
 uswitch
 [11:10] =  0  a++, next_state
 [11:10] =  1  calculation
 [11:10] =  2  a++
 [11:10] =  3  calculation
 */
 // ce = data available for external reading
 assign ce =  uswitch[psc-1-aw] == 0 && uswitch[psc-2-aw:0] == 0 ? 1 : 0;

 wire sw_next;
 assign sw_next =  uswitch == 0 ? 1 : 0;
 
 assign a = uswitch[psc-1:psc-aw];
 
 wire calc;
 assign calc = uswitch[psc-1-aw] == 1 && uswitch[psc-2-aw:0] == 0 ? 1 : 0;

 always @(posedge clk_pid)
   if(sw_next)
     state <= state + 1;

 always @(posedge clk_pid)
   if(calc)
        case(state[2:0])
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
	  0: e_k_0[a]   <= xerror; // copy sign extended error value
          // discrete fixed point PID
          // m(k) = m(k-1) + (Kp + Kd/T + Ki*T/2)*e(k)
          //               + (Ki*T/2 - Kp - 2Kd/T)*e(k-1) 
          //               + (Kd/T)*e(k-2)
          // T = 1/f
          1: u_k[a]     <= u_k[a] + (e_k_0[a]<<<Kp)        // +Kp * e(k)
                                  - (e_k_1[a]<<<Kp);       // -Kp * e(k-1)
          2: if(Kdfp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Kdfp))    // +Kd / T * e(k)
                                  + (e_k_2[a]<<<(Kdfp));   // +Kd / T * e(k-2)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Kdfp))   // +Kd / T * e(k)
                                  + (e_k_2[a]>>>(-Kdfp));  // +Kd / T * e(k-2)
          3: if(Ki1fp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Ki1fp))   // +Ki * T/2 * e(k)
                                  + (e_k_1[a]<<<(Ki1fp));  // +Ki * T/2 * e(k-1)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Ki1fp))  // +Ki * T/2 * e(k)
                                  + (e_k_1[a]>>>(-Ki1fp)); // +Ki * T/2 * e(k-1)
          4: if(Kd1fp >= 0)
                u_k[a]  <= u_k[a] - (e_k_1[a]<<<(Kd1fp));  // -Kd * 2/T * e(k-1)
              else
                u_k[a]  <= u_k[a] - (e_k_1[a]>>>(-Kd1fp)); // -Kd * 2/T * e(k-1)
              // ***************** P only, debugging
              // u_k[a] <= e_k <<< Kp;
              // *****************
              // antiwindup
	  5: if(u_k[a] >   antiwindup)
                 u_k[a] <=  antiwindup;        // max positiva value
          6: if(u_k[a] <  -antiwindup)
                 u_k[a] <= -antiwindup;        // min negative value
          // E8: m_k[a] <= u_k[a] >>> precision; // m(k) = u(k)  output
          // E8: m_k[a] <= u_k[a][precision+ow-1:precision]; // m(k) = u(k)  output
	  7:
	   begin
            // m_k[a] <= u_k[a] >>> precision; // m(k) = u(k)  output
            m_k[a] <= u_k[a][precision+ow-1:precision]; // m(k) = u(k)  output
	    e_k_2[a] <= e_k_1[a];  //  e(k-2) = e(k-1)
	    e_k_1[a] <= e_k_0[a];  //  e(k-1) = e(k)
           end
        endcase

 assign m_k_out = m_k[a]; // bit shifting, output scaling

endmodule
