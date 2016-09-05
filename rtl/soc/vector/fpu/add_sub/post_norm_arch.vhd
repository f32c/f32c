LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_misc.ALL;

ENTITY post_norm IS
   PORT( 
      clk          : IN     std_logic  ;
      div_opa_ldz  : IN     std_logic_vector (4 downto 0) ;
      exp_in       : IN     std_logic_vector (7 downto 0) ;
      exp_ovf      : IN     std_logic_vector (1 downto 0) ;
      fpu_op       : IN     std_logic_vector (0 downto 0) ;
      fract_in     : IN     std_logic_vector (47 downto 0) ;
      opa_dn       : IN     std_logic  ;
      opas         : IN     std_logic  ;
      opb_dn       : IN     std_logic  ;
      output_zero  : IN     std_logic  ;
      rem_00       : IN     std_logic  ;
      rmode        : IN     std_logic_vector (1 downto 0) ;
      sign         : IN     std_logic  ;
      f2i_out_sign : OUT    std_logic  ;
      fpout        : OUT    std_logic_vector (30 downto 0) ;
      ine          : OUT    std_logic  ;
      overflow     : OUT    std_logic  ;
      underflow    : OUT    std_logic 
   );
END post_norm ;

ARCHITECTURE arch OF post_norm IS
    signal f2i_out_sign_p1,  f2i_out_sign_p2: std_logic;
    signal fract_out : std_logic_vector (22 downto 0);
    signal exp_out : std_logic_vector (7 downto 0);
    signal exp_out1_co : std_logic ;
    signal fract_out_final : std_logic_vector (22 downto 0);
    signal fract_out_rnd : std_logic_vector (22 downto 0);
    signal exp_next_mi : std_logic_vector (8 downto 0);
    signal dn : std_logic ;
    signal exp_rnd_adj : std_logic ;
    signal exp_out_final : std_logic_vector (7 downto 0);
    signal exp_out_rnd : std_logic_vector (7 downto 0);
    signal op_dn : std_logic ;
    signal op_mul : std_logic ;
    signal op_div : std_logic ;
    signal op_i2f : std_logic ;
    signal op_f2i : std_logic ;
    signal fi_ldz : std_logic_vector (5 downto 0);
    signal g, r, s : std_logic ;
    signal round, round2, round2a, round2_fasu, round2_fmul : std_logic ;
    signal exp_out_rnd0, exp_out_rnd1, exp_out_rnd2, exp_out_rnd2a : std_logic_vector (7 downto 0);
    signal fract_out_rnd0, fract_out_rnd1, fract_out_rnd2, fract_out_rnd2a : std_logic_vector (22 downto 0);
    signal exp_rnd_adj0, exp_rnd_adj2a : std_logic ;
    signal r_sign : std_logic ;
    signal ovf0, ovf1 : std_logic ;
    signal fract_out_pl1 : std_logic_vector (23 downto 0);
    signal exp_out_pl1, exp_out_mi1 : std_logic_vector (7 downto 0);
    signal exp_out_00, exp_out_fe, exp_out_ff, exp_in_00, exp_in_ff : std_logic ;
    signal exp_out_final_ff, fract_out_7fffff : std_logic ;
    signal fract_trunc : std_logic_vector (24 downto 0);
    signal exp_out1 : std_logic_vector (7 downto 0);
    signal grs_sel : std_logic ;
    signal fract_out_00, fract_in_00 : std_logic ;
    signal shft_co : std_logic ;
    signal exp_in_pl1, exp_in_mi1 : std_logic_vector (8 downto 0);
    signal fract_in_shftr : std_logic_vector (47 downto 0);
    signal fract_in_shftl : std_logic_vector (47 downto 0);
    signal exp_div : std_logic_vector (7 downto 0);
    signal shft2 : std_logic_vector (7 downto 0);
    signal exp_out1_mi1 : std_logic_vector (7 downto 0);
    signal div_dn : std_logic ;
    signal div_nr : std_logic ;
    signal grs_sel_div : std_logic ;
    signal div_inf : std_logic ;
    signal fi_ldz_2a : std_logic_vector (6 downto 0);
    signal fi_ldz_2 : std_logic_vector (7 downto 0);
    signal div_shft1, div_shft2, div_shft3, div_shft4 : std_logic_vector (7 downto 0);
    signal div_shft1_co : std_logic ;
    signal div_exp1 : std_logic_vector (8 downto 0);
    signal div_exp2, div_exp3 : std_logic_vector (7 downto 0);
    signal div_exp2_temp : std_logic_vector (8 downto 0);
    signal left_right, lr_mul, lr_div : std_logic ;
    signal shift_right, shftr_mul, shftr_div : std_logic_vector (7 downto 0);
    signal shift_left, shftl_mul, shftl_div : std_logic_vector (7 downto 0);
    signal fasu_shift_p1 : std_logic_vector (7 downto 0);
    signal fasu_shift : std_logic_vector (7 downto 0);
    signal exp_fix_div : std_logic_vector (7 downto 0);
    signal exp_fix_diva, exp_fix_divb : std_logic_vector (7 downto 0);
    signal fi_ldz_mi1 : std_logic_vector (5 downto 0);
    signal fi_ldz_mi22 : std_logic_vector (5 downto 0);
    signal exp_zero : std_logic ;
    signal ldz_all : std_logic_vector (6 downto 0);
    signal ldz_dif : std_logic_vector (7 downto 0);
    signal div_scht1a : std_logic_vector (8 downto 0);
    signal f2i_shft : std_logic_vector (7 downto 0);
    signal exp_f2i_1 : std_logic_vector (55 downto 0);
    signal f2i_zero, f2i_max : std_logic ;
    signal f2i_emin : std_logic_vector (7 downto 0);
    signal conv_shft : std_logic_vector (7 downto 0);
    signal exp_i2f, exp_f2i, conv_exp : std_logic_vector (7 downto 0);
    signal round2_f2i : std_logic ;
    signal round2_f2i_p1 : std_logic ;
    signal exp_in_80 : std_logic ;
    signal rmode_00, rmode_01, rmode_10, rmode_11 : std_logic ;
    signal max_num, inf_out : std_logic ;
    signal max_num_t1, max_num_t2, max_num_t3,max_num_t4,inf_out_t1 : std_logic ;
    signal underflow_fmul : std_logic ;
    signal overflow_fdiv : std_logic ;
    signal undeflow_div : std_logic ;
    signal f2i_ine : std_logic ;
    signal fracta_del, fractb_del : std_logic_vector (26 downto 0);
    signal grs_del : std_logic_vector (2 downto 0);
    signal dn_del : std_logic ;
    signal exp_in_del : std_logic_vector (7 downto 0);
    signal exp_out_del : std_logic_vector (7 downto 0);
    signal fract_out_del : std_logic_vector (22 downto 0);
    signal fract_in_del : std_logic_vector (47 downto 0);
    signal overflow_del : std_logic ;
    signal exp_ovf_del : std_logic_vector (1 downto 0);
    signal fract_out_x_del, fract_out_rnd2a_del : std_logic_vector (22 downto 0);
    signal trunc_xx_del : std_logic_vector (24 downto 0);
    signal exp_rnd_adj2a_del : std_logic ;
    signal fract_dn_del : std_logic_vector (22 downto 0);
    signal div_opa_ldz_del : std_logic_vector (4 downto 0);
    signal fracta_div_del : std_logic_vector (23 downto 0);
    signal fractb_div_del : std_logic_vector (23 downto 0);
    signal div_inf_del : std_logic ;
    signal fi_ldz_2_del : std_logic_vector (7 downto 0);
    signal inf_out_del, max_out_del : std_logic ;
    signal fi_ldz_del : std_logic_vector (5 downto 0);
    signal rx_del : std_logic ;
    signal ez_del : std_logic ;
    signal lr : std_logic ;
    signal exp_div_del : std_logic_vector (7 downto 0);
    signal z : std_logic;
    signal undeflow_div_p1 : std_logic ;
    signal undeflow_div_p2 : std_logic ;
    signal undeflow_div_p3 : std_logic ;
    signal undeflow_div_p4 : std_logic ;
    signal undeflow_div_p5 : std_logic ;
    signal undeflow_div_p6 : std_logic ;
    signal undeflow_div_p7 : std_logic ;
    signal undeflow_div_p8 : std_logic ;
    signal undeflow_div_p9 : std_logic ;
    signal undeflow_div_p10 : std_logic ;

    CONSTANT f2i_emax : std_logic_vector(7 DOWNTO 0) := X"9d";
    
BEGIN
    op_dn <= opa_dn or opb_dn ;

    ---------------------------------------------------------------------------
    -- Normalize and Round Logic
    ---------------------------------------------------------------------------
    
    -- Count Leading zeros in fraction
    PROCESS (fract_in)
    BEGIN 
        IF fract_in(47) =  '1' THEN fi_ldz <=  conv_std_logic_vector(1,6);
        ELSIF fract_in(47 DOWNTO 46) = "01" THEN fi_ldz <=  conv_std_logic_vector(2,6);
        ELSIF fract_in(47 DOWNTO 45) = "001" THEN fi_ldz <=  conv_std_logic_vector(3,6);
        ELSIF fract_in(47 DOWNTO 44) = "0001" THEN fi_ldz <=  conv_std_logic_vector(4,6);
        ELSIF fract_in(47 DOWNTO 43) = "00001" THEN fi_ldz <=  conv_std_logic_vector(5,6);
        ELSIF fract_in(47 DOWNTO 42) = "000001" THEN fi_ldz <=  conv_std_logic_vector(6,6);
        ELSIF fract_in(47 DOWNTO 41) = "0000001" THEN fi_ldz <=  conv_std_logic_vector(7,6);
        ELSIF fract_in(47 DOWNTO 40) = "00000001" THEN fi_ldz <=  conv_std_logic_vector(8,6);
        ELSIF fract_in(47 DOWNTO 39) = "000000001" THEN fi_ldz <=  conv_std_logic_vector(9,6);
        ELSIF fract_in(47 DOWNTO 38) = "0000000001" THEN fi_ldz <=  conv_std_logic_vector(10,6);
        ELSIF fract_in(47 DOWNTO 37) = "00000000001" THEN fi_ldz <=  conv_std_logic_vector(11,6);
        ELSIF fract_in(47 DOWNTO 36) = "000000000001" THEN fi_ldz <=  conv_std_logic_vector(12,6);
        ELSIF fract_in(47 DOWNTO 35) = "0000000000001" THEN fi_ldz <=  conv_std_logic_vector(13,6);
        ELSIF fract_in(47 DOWNTO 34) = "00000000000001" THEN fi_ldz <=  conv_std_logic_vector(14,6);
        ELSIF fract_in(47 DOWNTO 33) = "000000000000001" THEN fi_ldz <=  conv_std_logic_vector(15,6);
        ELSIF fract_in(47 DOWNTO 32) = "0000000000000001" THEN fi_ldz <=  conv_std_logic_vector(16,6);
        ELSIF fract_in(47 DOWNTO 31) = "00000000000000001" THEN fi_ldz <=  conv_std_logic_vector(17,6);
        ELSIF fract_in(47 DOWNTO 30) = "000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(18,6);
        ELSIF fract_in(47 DOWNTO 29) = "0000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(19,6);
        ELSIF fract_in(47 DOWNTO 28) = "00000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(20,6);
        ELSIF fract_in(47 DOWNTO 27) = "000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(21,6);
        ELSIF fract_in(47 DOWNTO 26) = "0000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(22,6);
        ELSIF fract_in(47 DOWNTO 25) = "00000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(23,6);
        ELSIF fract_in(47 DOWNTO 24) = "000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(24,6);
        ELSIF fract_in(47 DOWNTO 23) = "0000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(25,6);
        ELSIF fract_in(47 DOWNTO 22) = "00000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(26,6);
        ELSIF fract_in(47 DOWNTO 21) = "000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(27,6);
        ELSIF fract_in(47 DOWNTO 20) = "0000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(28,6);
        ELSIF fract_in(47 DOWNTO 19) = "00000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(29,6);
        ELSIF fract_in(47 DOWNTO 18) = "000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(30,6);
        ELSIF fract_in(47 DOWNTO 17) = "0000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(31,6);
        ELSIF fract_in(47 DOWNTO 16) = "00000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(32,6);
        ELSIF fract_in(47 DOWNTO 15) = "000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(33,6);
        ELSIF fract_in(47 DOWNTO 14) = "0000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(34,6);
        ELSIF fract_in(47 DOWNTO 13) = "00000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(35,6);
        ELSIF fract_in(47 DOWNTO 12) = "000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(36,6);
        ELSIF fract_in(47 DOWNTO 11) = "0000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(37,6);
        ELSIF fract_in(47 DOWNTO 10) = "00000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(38,6);
        ELSIF fract_in(47 DOWNTO 9) = "000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(39,6);
        ELSIF fract_in(47 DOWNTO 8) = "0000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(40,6);
        ELSIF fract_in(47 DOWNTO 7) = "00000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(41,6);
        ELSIF fract_in(47 DOWNTO 6) = "000000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(42,6);
        ELSIF fract_in(47 DOWNTO 5) = "0000000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(43,6);
        ELSIF fract_in(47 DOWNTO 4) = "00000000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(44,6);
        ELSIF fract_in(47 DOWNTO 3) = "000000000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(45,6);
        ELSIF fract_in(47 DOWNTO 2) = "0000000000000000000000000000000000000000000001" THEN fi_ldz <=  conv_std_logic_vector(46,6);
        ELSIF fract_in(47 DOWNTO 1) = "00000000000000000000000000000000000000000000001"  THEN fi_ldz <=  conv_std_logic_vector(47,6);
        ELSIF fract_in(47 DOWNTO 1) = "00000000000000000000000000000000000000000000000" THEN fi_ldz <=  conv_std_logic_vector(48,6);
        ELSE fi_ldz <= (OTHERS => 'X');
        END IF;
    END PROCESS;

    -- Normalize
    exp_in_ff <= and_reduce(exp_in);
    exp_in_00 <= NOT (or_reduce(exp_in));
    exp_in_80 <= exp_in(7) AND NOT (or_reduce(exp_in(6 DOWNTO 0)));
    exp_out_ff <= and_reduce(exp_out);
    exp_out_00 <= NOT (or_reduce(exp_out));
    exp_out_fe <= (and_reduce(exp_out(7 DOWNTO 1))) AND NOT exp_out(0);
    exp_out_final_ff <= and_reduce(exp_out_final);

    fract_out_7fffff <= and_reduce(fract_out);
    fract_out_00 <= NOT (or_reduce(fract_out));
    fract_in_00 <= NOT (or_reduce(fract_in));

    rmode_00 <= '1' WHEN (rmode = "00") ELSE '0';
    rmode_01 <= '1' WHEN (rmode = "01") ELSE '0';
    rmode_10 <= '1' WHEN (rmode = "10") ELSE '0';
    rmode_11 <= '1' WHEN (rmode = "11") ELSE '0';

    -- Fasu Output will be denormalized ...
    dn <= (exp_in_00 OR (exp_next_mi(8) AND NOT fract_in(47)) );

    ---------------------------------------------------------------------------
    -- Fraction Normalization
    ---------------------------------------------------------------------------
    
    -- Incremented fraction for rounding
    fract_out_pl1 <= ('0' & fract_out) + '1';

    
    -- Calculate various shifting options
    shft_co <= '0' WHEN ((NOT exp_ovf(1) AND exp_in_00) ='1') else exp_in_mi1(8) ;

    -- Select shifting direction
    left_right <= '1';

    -- Select Left and Right shift value
    fasu_shift_p1 <= X"02" WHEN (exp_in_00 = '1') ELSE exp_in_pl1(7 downto 0);
    fasu_shift <= fasu_shift_p1 WHEN ((dn OR exp_out_00) = '1') ELSE ("00" & fi_ldz);

    --shift_right <= shftr_div WHEN (op_div = '1') ELSE shftr_mul;

    conv_shft <= "00" & fi_ldz;

    shift_left <= fasu_shift;

    -- Do the actual shifting
    --fract_in_shftr <= (OTHERS => '0') WHEN (or_reduce(shift_right(7 DOWNTO 6)) = '1')
    --             else shr(fract_in,shift_right(5 DOWNTO 0));

    fract_in_shftl <= (OTHERS => '0') WHEN (or_reduce(shift_left(7 DOWNTO 6))='1')
                 else (shl(fract_in,shift_left(5 DOWNTO 0)));

    -- Chose final fraction output
    --fract_trunc <= fract_in_shftl(24 DOWNTO 0) WHEN (left_right = '1') else
    --               fract_in_shftr(24 DOWNTO 0);
    fract_out <= fract_in_shftl(47 DOWNTO 25) WHEN (left_right = '1') else
                 fract_in_shftr(47 DOWNTO 25);
    ---------------------------------------------------------------------------
    --  Exponent Normalization
    ---------------------------------------------------------------------------
    fi_ldz_mi1 <= fi_ldz - '1';
    fi_ldz_mi22 <= fi_ldz - "10110";
    exp_out_pl1 <= exp_out + '1';
    exp_out_mi1 <= exp_out - '1';
    -- 9 bits - includes carry out
    exp_in_pl1 <= ('0' & exp_in)  + '1';
    -- 9 bits - includes carry out
    exp_in_mi1 <= ('0' & exp_in)  - '1';     
    exp_out1_mi1 <= exp_out1 - '1';
    
    -- 9 bits - includes carry out
    exp_next_mi <= exp_in_pl1 - fi_ldz_mi1; 

    exp_fix_diva <= exp_in - fi_ldz_mi22;
    exp_fix_divb <= exp_in - fi_ldz_mi1;

    exp_zero  <= (exp_ovf(1) AND NOT exp_ovf(0) AND op_mul AND
                  (NOT exp_rnd_adj2a OR NOT rmode(1))) OR
                 (op_mul AND  exp_out1_co);

    exp_out1 <= exp_in_pl1(7 DOWNTO 0) WHEN (fract_in(47) = '1') else
                exp_next_mi(7 DOWNTO 0);
    exp_out1_co <= exp_in_pl1(8) WHEN (fract_in(47) = '1') else
                   exp_next_mi(8);

    exp_out <= --exp_div WHEN (op_div = '1') ELSE
               --conv_exp WHEN ((op_f2i OR op_i2f)='1') ELSE
               --X"00" WHEN (exp_zero = '1') ELSE
               ("000000" & fract_in(47 downto 46)) WHEN (dn = '1') else
               exp_out1;

    ---------------------------------------------------------------------------
    -- ROUND
    ---------------------------------------------------------------------------
    -- Extract rounding (GRS) bits
    grs_sel_div <= op_div and (exp_ovf(1) or div_dn or exp_out1_co or exp_out_00);

    g <= fract_out(0) WHEN (grs_sel_div = '1') ELSE fract_out(0);
    r <= (fract_trunc(24) AND NOT div_nr) WHEN (grs_sel_div = '1') ELSE fract_trunc(24);
    s <= or_reduce(fract_trunc(24 DOWNTO 0)) WHEN (grs_sel_div = '1') ELSE
         (or_reduce(fract_trunc(23 DOWNTO 0)) OR (fract_trunc(24) AND op_div));

    -- Round to nearest even
    round <= (g and r) or (r and s) ;
    fract_out_rnd0 <= fract_out_pl1(22 DOWNTO 0) WHEN (round = '1') ELSE fract_out;
    exp_rnd_adj0 <= fract_out_pl1(23) WHEN (round = '1') ELSE '0';

    exp_out_rnd0 <=  exp_out_pl1 WHEN (exp_rnd_adj0 = '1') else exp_out;
    ovf0 <= exp_out_final_ff and NOT rmode_01 AND NOT op_f2i;

    -- round to zero
    fract_out_rnd1 <= ("111" & X"fffff") WHEN
                      ((exp_out_ff and NOT op_div AND
                        NOT dn and NOT op_f2i) = '1')
                      ELSE fract_out;
    --exp_fix_div <= exp_fix_diva  WHEN (fi_ldz>"010110")
    --               else exp_fix_divb;
    exp_out_rnd1 <= --exp_fix_div WHEN ((g and r and s and exp_in_ff AND op_div)='1') else
                    --exp_next_mi(7 DOWNTO 0) WHEN ((g and r and s and exp_in_ff AND NOT op_div)='1') else
                    --exp_in when ((exp_out_ff and not op_f2i)='1') else
                    exp_out;        
    ovf1 <= exp_out_ff and NOT dn;

    -- round to +inf (UP) and -inf (DOWN)
    r_sign <= sign;

    round2a <= NOT exp_out_fe or NOT fract_out_7fffff or
               (exp_out_fe and fract_out_7fffff);
    round2_fasu <= ((r or s) and NOT r_sign) and
                   (NOT exp_out(7) OR (exp_out(7) AND  round2a));

    noround2: if false generate
    round2_fmul <= NOT r_sign and 
                (
                        (exp_ovf(1) and not fract_in_00 and
                                ( ((not exp_out1_co or op_dn) and (r or s or (not rem_00 and op_div) )) or fract_out_00 or (not op_dn and not op_div))
                         ) or
                        (
                                (r or s or (not rem_00 and op_div)) and (
                                                (not exp_ovf(1) and (exp_in_80 or not exp_ovf(0))) or op_div or
                                                ( exp_ovf(1) and not exp_ovf(0) and exp_out1_co)
                                        )
                        )
                );

    round2_f2i_p1 <= '1' WHEN (exp_in<X"80" ) ELSE '0';
    round2_f2i <= rmode_10 and (( or_reduce(fract_in(23 DOWNTO 0)) AND
                                  NOT opas AND round2_f2i_p1) OR (or_reduce(fract_trunc)));
    end generate;
    
    round2 <= --round2_fmul WHEN ((op_mul or op_div) = '1') ELSE
              --round2_f2i WHEN (op_f2i = '1') else
              round2_fasu;

    fract_out_rnd2a <= fract_out_pl1(22 DOWNTO 0)  WHEN (round2 = '1') else fract_out;
    exp_rnd_adj2a <= fract_out_pl1(23)  WHEN (round2 = '1') else '0';
    exp_out_rnd2a <= exp_out_mi1 WHEN ((exp_rnd_adj2a AND (exp_ovf(1) and op_mul))='1')ELSE 
                     exp_out_pl1 WHEN ((exp_rnd_adj2a AND
                                        NOT (exp_ovf(1) AND op_mul))='1') ELSE
                     exp_out;

    fract_out_rnd2 <= "111" & X"FFFFF" WHEN
                      ((r_sign and exp_out_ff and NOT op_div and
                        NOT dn AND  NOT op_f2i) = '1') ELSE
                      fract_out_rnd2a;
    exp_out_rnd2 <= X"FE"  WHEN
                    ((r_sign and exp_out_ff AND NOT op_f2i) = '1')
                    else exp_out_rnd2a;

    -- Choose rounding mode
    PROCESS (rmode,exp_out_rnd0,exp_out_rnd1,exp_out_rnd2)
    BEGIN 
        CASE rmode IS
            WHEN "00" => exp_out_rnd <= exp_out_rnd0;
            WHEN "01" => exp_out_rnd <= exp_out_rnd1;
            WHEN "10" => exp_out_rnd <= exp_out_rnd2;
            WHEN "11" => exp_out_rnd <= exp_out_rnd2;
            WHEN OTHERS => exp_out_rnd <= (OTHERS => 'X');
        END CASE;
    END PROCESS;

    PROCESS (rmode,fract_out_rnd0,fract_out_rnd1,fract_out_rnd2)
    BEGIN 
        CASE rmode IS
            WHEN "00" => fract_out_rnd <= fract_out_rnd0;
            WHEN "01" => fract_out_rnd <= fract_out_rnd1;
            WHEN "10" => fract_out_rnd <= fract_out_rnd2;
            WHEN "11" => fract_out_rnd <= fract_out_rnd2;
            WHEN OTHERS => fract_out_rnd <= (OTHERS => 'X');
        END CASE;
    END PROCESS;

    ---------------------------------------------------------------------------
    -- Final Output Mux
    ---------------------------------------------------------------------------
    -- Fix Output for denormalized and special numbers

    fract_out_final <= fract_out_rnd;
    exp_out_final <= exp_out_rnd;

    ---------------------------------------------------------------------------
    -- Pack Result
    ---------------------------------------------------------------------------
    fpout <= exp_out_final & fract_out_final;
END arch;
