LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_misc.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;
--USE ieee.numeric_std.ALL;
--USE ieee.numeric_bit.ALL;


ENTITY pre_norm IS
   PORT( 
      add              : IN     std_logic  ;
      clk              : IN     std_logic  ;
      opa              : IN     std_logic_vector (31 downto 0) ;
      opa_nan          : IN     std_logic  ;
      opb              : IN     std_logic_vector (31 downto 0) ;
      opb_nan          : IN     std_logic  ;
      rmode            : IN     std_logic_vector (1 downto 0) ;
      exp_dn_out       : OUT    std_logic_vector (7 downto 0) ;
      fasu_op          : OUT    std_logic  ;
      fracta_out       : OUT    std_logic_vector (26 downto 0) ;
      fractb_out       : OUT    std_logic_vector (26 downto 0) ;
      nan_sign         : OUT    std_logic  ;
      result_zero_sign : OUT    std_logic  ;
      sign             : OUT    std_logic 
   );
END pre_norm ;

ARCHITECTURE arch OF pre_norm IS
    
    signal signa, signb : std_logic ;
    signal signd_sel : std_logic_vector(2 DOWNTO 0) ;
    signal add_d_sel : std_logic_vector(2 DOWNTO 0) ;
    signal expa, expb : std_logic_vector (7 downto 0);
    signal fracta, fractb : std_logic_vector (22 downto 0);
    signal expa_lt_expb : std_logic ;
    signal fractb_lt_fracta : std_logic ;
    signal exp_small, exp_large : std_logic_vector (7 downto 0);
    signal exp_diff : std_logic_vector (7 downto 0);
    signal adj_op : std_logic_vector (22 downto 0);
    signal adj_op_tmp : std_logic_vector (26 downto 0);
    signal adj_op_out : std_logic_vector (26 downto 0);
    signal fracta_n, fractb_n : std_logic_vector (26 downto 0);
    signal fracta_s, fractb_s : std_logic_vector (26 downto 0);
    signal sign_d : std_logic ;
    signal add_d : std_logic ;
    signal expa_dn, expb_dn : std_logic ;
    signal sticky : std_logic ;
    signal add_r, signa_r, signb_r : std_logic ;
    signal exp_diff_sft : std_logic_vector (4 downto 0);
    signal exp_lt_27 : std_logic ;
    signal op_dn : std_logic ;
    signal adj_op_out_sft : std_logic_vector (26 downto 0);
    signal fracta_lt_fractb, fracta_eq_fractb : std_logic ;
    signal nan_sign1 : std_logic ;
    signal exp_diff1, exp_diff1a, exp_diff2 : std_logic_vector (7 downto 0);
    
    
BEGIN

    signa <= opa(31);
    signb <= opb(31);
    expa <= opa(30 downto 23);
    expb <= opb(30 downto 23);
    fracta <= opa(22 downto 0);
    fractb <= opb(22 downto 0);

    expa_lt_expb <= '1' WHEN (expa > expb) ELSE '0';

    expa_dn <= NOT or_reduce(expa);
    expb_dn <= NOT or_reduce(expb);

    -- Calculate the difference between the smaller and larger exponent

    exp_small <= expb WHEN (expa_lt_expb = '1') ELSE expa;
    exp_large <= expa WHEN (expa_lt_expb = '1') ELSE expb;
    exp_diff1 <= exp_large - exp_small;
    exp_diff1a <= exp_diff1 - '1';
    -- if one of the exponents is zero then exp_diff1a else exp_diff1
    exp_diff2 <= exp_diff1a WHEN ((expa_dn OR expb_dn) = '1') ELSE
                 exp_diff1;
    -- exp_diff is 0 if both exponents are zero
    exp_diff <= X"00" WHEN ((expa_dn AND expb_dn) = '1') ELSE
                exp_diff2;

    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            IF ((add_d = '0') AND  (expa = expb) AND  (fracta = fractb)) THEN
                exp_dn_out <= X"00";
            ELSE
                exp_dn_out <= exp_large;
            END IF;
        END IF;
    END PROCESS;

    -- Adjust the smaller fraction
    
    op_dn <= expb_dn WHEN (expa_lt_expb = '1') ELSE expa_dn;
    adj_op <= fractb WHEN (expa_lt_expb = '1') ELSE fracta;
    adj_op_tmp <= (NOT op_dn) & adj_op & "000";

    -- adj_op_out is 27 bits wide, so can only be shifted
    -- 27 bits to the right (8'd27)
    exp_lt_27 <= '1' WHEN (exp_diff  > "00011011") ELSE '0';
    exp_diff_sft <= "11011" WHEN (exp_lt_27 = '1') ELSE exp_diff(4 downto 0);

    -- adj_op_tmp_bitvec <= STD_LOGIC_VECTORtoBIT_VECTOR(adj_op_tmp);
    -- adj_op_out_sft <= To_StdLogicVector(adj_op_tmp_bitvec SRL conv_integer(exp_diff_sft));
    -- (conv_integer(exp_diff_sft));

    adj_op_out_sft <= shr(adj_op_tmp,exp_diff_sft);
    adj_op_out <= adj_op_out_sft(26 DOWNTO 1) &
                  (adj_op_out_sft(0) OR sticky);

    -- Get truncated portion (sticky bit)
    PROCESS (exp_diff_sft,adj_op_tmp)
    BEGIN
        CASE exp_diff_sft IS 
            WHEN "00000" => sticky <= '0';
            WHEN "00001" => sticky <= adj_op_tmp(0); 
            WHEN "00010" => sticky <= or_reduce(adj_op_tmp(1 downto 0));
            WHEN "00011" => sticky <= or_reduce(adj_op_tmp(2 downto 0));
            WHEN "00100" => sticky <= or_reduce(adj_op_tmp(3 downto 0));
            WHEN "00101" => sticky <= or_reduce(adj_op_tmp(4 downto 0));
            WHEN "00110" => sticky <= or_reduce(adj_op_tmp(5 downto 0));
            WHEN "00111" => sticky <= or_reduce(adj_op_tmp(6 downto 0));
            WHEN "01000" => sticky <= or_reduce(adj_op_tmp(7 downto 0));
            WHEN "01001" => sticky <= or_reduce(adj_op_tmp(8 downto 0));
            WHEN "01010" => sticky <= or_reduce(adj_op_tmp(9 downto 0));
            WHEN "01011" => sticky <= or_reduce(adj_op_tmp(10 downto 0));
            WHEN "01100" => sticky <= or_reduce(adj_op_tmp(11 downto 0));
            WHEN "01101" => sticky <= or_reduce(adj_op_tmp(12 downto 0));
            WHEN "01110" => sticky <= or_reduce(adj_op_tmp(13 downto 0));
            WHEN "01111" => sticky <= or_reduce(adj_op_tmp(14 downto 0));
            WHEN "10000" => sticky <= or_reduce(adj_op_tmp(15 downto 0));
            WHEN "10001" => sticky <= or_reduce(adj_op_tmp(16 downto 0));
            WHEN "10010" => sticky <= or_reduce(adj_op_tmp(17 downto 0));
            WHEN "10011" => sticky <= or_reduce(adj_op_tmp(18 downto 0));
            WHEN "10100" => sticky <= or_reduce(adj_op_tmp(19 downto 0));
            WHEN "10101" => sticky <= or_reduce(adj_op_tmp(20 downto 0));
            WHEN "10110" => sticky <= or_reduce(adj_op_tmp(21 downto 0));
            WHEN "10111" => sticky <= or_reduce(adj_op_tmp(22 downto 0));
            WHEN "11000" => sticky <= or_reduce(adj_op_tmp(23 downto 0));
            WHEN "11001" => sticky <= or_reduce(adj_op_tmp(24 downto 0));
            WHEN "11010" => sticky <= or_reduce(adj_op_tmp(25 downto 0));
            WHEN "11011" => sticky <= or_reduce(adj_op_tmp(26 downto 0));
            WHEN OTHERS => sticky <= '0';
        END CASE;        
    END PROCESS;

    -- Select operands for add/sub (recover hidden bit)
    fracta_n <= ((NOT expa_dn) & fracta & "000") WHEN (expa_lt_expb = '1') else
                adj_op_out;
    fractb_n <= adj_op_out WHEN (expa_lt_expb = '1') else
                ((NOT expb_dn) & fractb & "000");

    -- Sort operands (for sub only)
    fractb_lt_fracta <= '1' WHEN (fractb_n > fracta_n) ELSE '0';
    fracta_s <= fractb_n WHEN (fractb_lt_fracta = '1') ELSE fracta_n;
    fractb_s <= fracta_n WHEN (fractb_lt_fracta = '1') ELSE fractb_n;
    
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            fracta_out <= fracta_s;
            fractb_out <= fractb_s;
        END IF;
    END PROCESS;

    -- Determine sign for the output
    -- sign: 0=Positive Number; 1=Negative Number

    signd_sel <= signa & signb & add;
    PROCESS (signd_sel, fractb_lt_fracta)
    BEGIN 
        CASE signd_sel IS 
            -- Add
            WHEN "001" => sign_d <= '0';
            WHEN "011" => sign_d <= fractb_lt_fracta;
            WHEN "101" => sign_d <= NOT fractb_lt_fracta;
            WHEN "111" => sign_d <= '1';
                            
            -- Sub          
            WHEN "000" => sign_d <= fractb_lt_fracta;
            WHEN "010" => sign_d <= '0';
            WHEN "100" => sign_d <= '1';
            WHEN "110" => sign_d <= NOT fractb_lt_fracta;
            WHEN OTHERS => sign_d <= 'X';
        END CASE;
    END PROCESS;
    
    
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            sign <= sign_d;
            -- Fix sign for ZERO result
            signa_r <= signa;
            signb_r <= signb;
            add_r <= add;
            result_zero_sign <= ( add_r AND  signa_r AND  signb_r) OR
                                (NOT add_r AND  signa_r AND NOT signb_r) OR
                                ( add_r AND (signa_r OR  signb_r) AND
                                  (rmode(1) AND rmode(0))) OR
                                (NOT add_r AND NOT (signa_r xor signb_r) AND
                                 (rmode(1) AND rmode(0)));
        END IF;
    END PROCESS;

    -- Fix sign for NAN result
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            IF (fracta < fractb) THEN
                fracta_lt_fractb <= '1';
            ELSE
                fracta_lt_fractb <= '0';
            END IF;
            IF fracta = fractb THEN
                fracta_eq_fractb <= '1';
            ELSE
                fracta_eq_fractb <= '0';
            END IF;
            IF ((opa_nan AND opb_nan) = '1') THEN
                nan_sign <= nan_sign1;
            ELSIF (opb_nan = '1') THEN
                nan_sign <= signb_r;    
            ELSE
                nan_sign <= signa_r;
            END IF;
        END IF;
    END PROCESS;
     
    nan_sign1 <= (signa_r AND signb_r) WHEN (fracta_eq_fractb = '1') ELSE
                 signb_r WHEN (fracta_lt_fractb = '1') ELSE
                 signa_r;

    add_d_sel <= signa & signb & add;
    -- Decode Add/Sub operation
    -- add: 1=Add; 0=Subtract
    PROCESS (add_d_sel)
    BEGIN 
        CASE add_d_sel IS 
            -- Add
            WHEN "001" => add_d <= '1';
            WHEN "011" => add_d <= '0';
            WHEN "101" => add_d <= '0';
            WHEN "111" => add_d <= '1';
                    
             -- Sub 
            WHEN "000" => add_d <= '0';
            WHEN "010" => add_d <= '1';
            WHEN "100" => add_d <= '1';
            WHEN "110" => add_d <= '0';
            WHEN OTHERS => add_d <= 'X';
        END CASE;
    END PROCESS;

    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            fasu_op <= add_d;
        END IF;
    END PROCESS;
    

END arch;
