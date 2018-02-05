`include "defines.v"
module ieee_adder_prepare_input( input add_sub_bit, input `WIDTH_NUMBER number, output sign, output `WIDTH_EXPO exponent, output `WIDTH_SIGNIF signif, output isnan, output isinf);
        //Take input and convert it to suitable format.
        assign sign = number[`LASTBIT] ^ add_sub_bit;
        assign exponent = number[`EXPO_LASTBIT:`EXPO_FIRSTBIT];
        //Add bit 1 in front in case that exponent is non-zero
        assign signif = {|exponent, number[`SIGNIF_LASTBIT:`SIGNIF_FIRSTBIT], `GUARD_BITS'b0};
        wire expo_full = & exponent;
        wire signif_nonzero = | number[`SIGNIF_LASTBIT:`SIGNIF_FIRSTBIT];
        assign isnan = expo_full && signif_nonzero;
        assign isinf = expo_full && !signif_nonzero;
endmodule
module ieee_adder_compare( input `WIDTH_EXPO exponentA, input `WIDTH_EXPO exponentB, input `WIDTH_SIGNIF signifA, input `WIDTH_SIGNIF signifB, output expA_bigger_expB, output inputA_bigger_inputB, output `WIDTH_EXPO shift_amount);
        // Compare exponents and significands between inputs
        wire sub_borrow;
        assign {sub_borrow, shift_amount} = exponentA - exponentB;
        assign expA_bigger_expB = !sub_borrow;
        assign inputA_bigger_inputB = {exponentA, signifA} > {exponentB, signifB};
endmodule
module ieee_adder_shift_signif( input expA_bigger_expB, input `WIDTH_SIGNIF signifA, input `WIDTH_SIGNIF signifB, input `WIDTH_EXPO shift_amount, output `WIDTH_SIGNIF signifA_shift_preswap, output `WIDTH_SIGNIF signifB_shift_preswap);
        //Store shifted significands, significand with smaller exponent will be shifted to the right
        assign signifA_shift_preswap = expA_bigger_expB ? signifA : signifA >> -shift_amount;
        assign signifB_shift_preswap = expA_bigger_expB ? signifB >> shift_amount : signifB;
endmodule
module ieee_adder_swap_signif( input inputA_bigger_inputB, input `WIDTH_SIGNIF signifA_shift_preswap, input `WIDTH_SIGNIF signifB_shift_preswap, output `WIDTH_SIGNIF signifA_shift, output `WIDTH_SIGNIF signifB_shift);
        assign {signifA_shift,signifB_shift} = { inputA_bigger_inputB ? {signifA_shift_preswap, signifB_shift_preswap} :	{signifB_shift_preswap, signifA_shift_preswap} };
endmodule
module ieee_adder_bigger_exp( input inputA_bigger_inputB, input `WIDTH_EXPO exponentA, input `WIDTH_EXPO exponentB, output `WIDTH_EXPO big_expo);
        assign big_expo = inputA_bigger_inputB ? exponentA : exponentB;
endmodule
module ieee_adder_opadd( input `WIDTH_SIGNIF signifA_shift, input `WIDTH_SIGNIF signifB_shift, input `WIDTH_EXPO big_expo, output `WIDTH_SIGNIF out_signif_add, output `WIDTH_EXPO out_exponent_add);
        //Add two significands and store the carry of addition
        wire carry_signif;
        wire `WIDTH_SIGNIF out_signif_add_1;
        assign {carry_signif, out_signif_add_1} = signifA_shift + signifB_shift;
        wire `WIDTH_EXPO out_exponent_add_1;
        wire exponent_overflow_add;
        assign {exponent_overflow_add, out_exponent_add_1} = carry_signif ? 1 + big_expo : {1'b0, big_expo};
        assign out_signif_add = { carry_signif ? {1'b1, out_signif_add_1[`SIGNIF_LEN:-`GUARD_BITS+1]} :out_signif_add_1 };
        assign out_exponent_add = out_exponent_add_1;
endmodule
module ieee_adder_opsub( input `WIDTH_SIGNIF signifA_shift, input `WIDTH_SIGNIF signifB_shift, input `WIDTH_EXPO big_expo, output `WIDTH_SIGNIF out_signif_sub_prenorm, output signif_nonzero);
        //Subtract two significands and store the borrow borrow_signif
        assign out_signif_sub_prenorm = signifA_shift - signifB_shift;
        assign signif_nonzero = |(out_signif_sub_prenorm);
endmodule
module ieee_adder_normalize_sub( input `WIDTH_SIGNIF out_signif_sub_prenorm, output `WIDTH_SIGNIF out_signif_sub, input `WIDTH_EXPO big_expo, output `WIDTH_EXPO out_exponent_sub);
        function `WIDTH_EXPO normalize5;
                //Priority encoder for normalization
                input `WIDTH_SIGNIF __number;
                casex (1'b1)
                        __number[23]: normalize5 = 0;
                        __number[22]: normalize5 = 1;
                        __number[21]: normalize5 = 2;
                        __number[20]: normalize5 = 3;
                        __number[19]: normalize5 = 4;
                        __number[18]: normalize5 = 5;
                        __number[17]: normalize5 = 6;
                        __number[16]: normalize5 = 7;
                        __number[15]: normalize5 = 8;
                        __number[14]: normalize5 = 9;
                        __number[13]: normalize5 = 10;
                        __number[12]: normalize5 = 11;
                        __number[11]: normalize5 = 12;
                        __number[10]: normalize5 = 13;
                        __number[9]: normalize5 = 14;
                        __number[8]: normalize5 = 15;
                        __number[7]: normalize5 = 16;
                        __number[6]: normalize5 = 17;
                        __number[5]: normalize5 = 18;
                        __number[4]: normalize5 = 19;
                        __number[3]: normalize5 = 20;
                        __number[2]: normalize5 = 21;
                        __number[1]: normalize5 = 22;
                        __number[0]: normalize5 = 23;
                        __number[-1]: normalize5 = 24;
                        __number[-2]: normalize5 = 25;
                        __number[-3]: normalize5 = 26;
                endcase
        endfunction
        wire `WIDTH_EXPO normal_shift = normalize5(out_signif_sub_prenorm);
        wire `WIDTH_SIGNIF out_signif_sub_2 = out_signif_sub_prenorm << normal_shift;
        wire `WIDTH_SIGNIF out_signif_sub_3 = out_signif_sub_prenorm << (big_expo - 1);
        wire borrow;
        wire `WIDTH_EXPO sub_expo;
        assign {borrow, sub_expo} = big_expo - normal_shift;
        assign out_exponent_sub = borrow ? 0 : sub_expo;
        assign out_signif_sub = (borrow || sub_expo == 0 ) ? out_signif_sub_3 : out_signif_sub_2;
endmodule
module ieee_adder_round( input `WIDTH_SIGNIF number, output `WIDTH_SIGNIF_PART round_signif);
        wire `WIDTH_SIGNIF_PART number1;
        assign number1 = number[`SIGNIF_LEN-1:0];
        assign round_signif = { ((number[-1:-`GUARD_BITS] > `ROUND_EVEN) || (number[-1:-`GUARD_BITS] == `ROUND_EVEN && number[0] == 1'b1 )) ? number1 + 1 : number1 };
endmodule
module ieee_adder_final( input signA, input signB, input inputA_bigger_inputB, input `WIDTH_EXPO out_exponent_add, input `WIDTH_SIGNIF_PART round_signif_add, input `WIDTH_EXPO out_exponent_sub, input `WIDTH_SIGNIF_PART round_signif_sub, input signif_nonzero, input `WIDTH_EXPO shift_amount, input isnanA, input isnanB, input isinfA, input isinfB, output `WIDTH_NUMBER outputC);
        wire neg_op = signA ^ signB;
        wire out_sign = inputA_bigger_inputB ? signA : signB;
        wire nonequal = (|shift_amount) | signif_nonzero;
        // emard: add infinity handling: isinfA || isinfB ||
        wire is_infinity = isinfA || isinfB || (neg_op ? (out_exponent_sub == `EXPO_ONES) : (out_exponent_add == `EXPO_ONES));
        wire `WIDTH_NUMBER out_infinity = {out_sign, `EXPO_ONES, `SIGNIF_LEN'b0};
        wire `WIDTH_NUMBER out_nan =  {1'b1, `EXPO_ONES, `SIGNIF_LEN'b1111};
        assign outputC = (isnanA || isnanB) ? out_nan : is_infinity ? out_infinity : { neg_op ? { nonequal ? {out_sign, out_exponent_sub, round_signif_sub} :	`TOTALBITS'b0 } : {out_sign, out_exponent_add, round_signif_add} };
endmodule