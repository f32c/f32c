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
// number of states is 10 (not counting reset state executed only once)
// choose freq = 2^n Hz, e.g. 
// 2560 Hz/10 = 256 Hz = control loop frequency
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
 input [cw-1:0] KP,KI,KD;  // input 2^n shifting -31..31
 output signed [ow-1:0] m_k_out; // motor power

 reg signed [ow-1:0] m_k[an-1:0];       //muestra actual
 reg signed [pw-1:0] e_k_0[an-1:0];     //error actual
 reg signed [pw-1:0] e_k_1[an-1:0];     //error 1 cycle before
 reg signed [pw-1:0] e_k_2[an-1:0];     //error 2 cycles before
 reg signed [pw-1:0] u_k[an-1:0];       //result of PID equation

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


 parameter [3:0] E0=4'd0;
 parameter [3:0] E1=4'd1;
 parameter [3:0] E2=4'd2;
 parameter [3:0] E3=4'd3;
 parameter [3:0] E4=4'd4;
 parameter [3:0] E5=4'd5;
 parameter [3:0] E6=4'd6;
 parameter [3:0] E7=4'd7;
 parameter [3:0] E8=4'd8;
 parameter [3:0] E9=4'd9;
 parameter [3:0] E10=4'd10;

 reg [3:0] state=4'd0;
 reg [3:0] next_state;
 
 parameter psc = 12; // prescaler number of bits
 
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
 
 always@(posedge clk_pid or posedge reset) // RTL logic for next state
     if (reset)
       begin
         state<=E0;
       end
     else
       begin
          if(sw_next)
            state<=next_state;
       end

 // state machine to off-load arithmetic processing
 always @*	// sequential logic
	case(state[3:0])
		E0: next_state[3:0]=E1;
		E1: next_state[3:0]=E2;
		E2: next_state[3:0]=E3;
		E3: next_state[3:0]=E4;
		E4: next_state[3:0]=E5;
		E5: next_state[3:0]=E6;
		E6: next_state[3:0]=E7;
		E7: next_state[3:0]=E8;
		E8: next_state[3:0]=E9;
		E9: next_state[3:0]=E10;
		E10: next_state[3:0]=E1;
		default: next_state[3:0]=E0;
	endcase

 always @(posedge clk_pid)
   if(calc)
        case(state[3:0])
	  E0: begin
	        // reset all accumulated values
	        // this creates counter-direction
	        // after step change of the setpoint
	        /*
                m_k[a]   <= 0;
                u_k[a]   <= 0;
                e_k_1[a] <= 0;
                e_k_2[a] <= 0;
                */
              end
	  E1: // first copy minimal necessary data
	      e_k_0[a][ew-1:0] = error;
          E2: begin
              /* sign expansion */
              if(e_k_0[a][ew-1])
	          // sign expansion for negative e(k) error
	          e_k_0[a][pw-1:ew] <= -8'd1;
              else
                  // expansion for positive e(k) error
                  e_k_0[a][pw-1:ew] <= 8'd0;
              end
          // discrete fixed point PID
          // m(k) = m(k-1) + (Kp + Kd/T + Ki*T/2)*e(k)
          //               + (Ki*T/2 - Kp - 2Kd/T)*e(k-1) 
          //               + (Kd/T)*e(k-2)
          // T = 1/f
          E3: u_k[a]    <= u_k[a] + (e_k_0[a]<<<Kp)        // +Kp * e(k)
                                  - (e_k_1[a]<<<Kp);       // -Kp * e(k-1)
          E4: if(Kdfp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Kdfp))    // +Kd / T * e(k)
                                  + (e_k_2[a]<<<(Kdfp));   // +Kd / T * e(k-2)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Kdfp))   // +Kd / T * e(k)
                                  + (e_k_2[a]>>>(-Kdfp));  // +Kd / T * e(k-2)
          E5: if(Ki1fp >= 0)
                u_k[a]  <= u_k[a] + (e_k_0[a]<<<(Ki1fp))   // +Ki * T/2 * e(k)
                                  + (e_k_1[a]<<<(Ki1fp));  // +Ki * T/2 * e(k-1)
              else
                u_k[a]  <= u_k[a] + (e_k_0[a]>>>(-Ki1fp))  // +Ki * T/2 * e(k)
                                  + (e_k_1[a]>>>(-Ki1fp)); // +Ki * T/2 * e(k-1)
          E6: if(Kd1fp >= 0)
                u_k[a]  <= u_k[a] - (e_k_1[a]<<<(Kd1fp));  // -Kd * 2/T * e(k-1)
              else
                u_k[a]  <= u_k[a] - (e_k_1[a]>>>(-Kd1fp)); // -Kd * 2/T * e(k-1)
              // ***************** P only, debugging
              // u_k[a] <= e_k <<< Kp;
              // *****************
              // antiwindup
	  E7: if(u_k[a] >   antiwindup)
                 u_k[a] <=  antiwindup;        // max positiva value
          E8: if(u_k[a] <  -antiwindup)
                 u_k[a] <= -antiwindup;        // min negative value
          // E9:  m_k[a] <= u_k[a] >>> precision; // m(k) = u(k)  output
          E9:  m_k[a] <= u_k[a][precision+ow-1:precision]; // m(k) = u(k)  output
	  E10: 
	   begin
	    e_k_2[a] <= e_k_1[a];  //  e(k-2) = e(k-1)
	    e_k_1[a] <= e_k_0[a];  //  e(k-1) = e(k)
           end
        endcase

 assign m_k_out = m_k[a]; // bit shifting, output scaling

endmodule
