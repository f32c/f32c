LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_misc.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY pre_norm_fmul IS
   PORT( 
      clk       : IN     std_logic  ;
      fpu_op    : IN     std_logic_vector (2 downto 0) ;
      opa       : IN     std_logic_vector (31 downto 0) ;
      opb       : IN     std_logic_vector (31 downto 0) ;
      exp_out   : OUT    std_logic_vector (7 downto 0) ;
      exp_ovf   : OUT    std_logic_vector (1 downto 0) ;
      fracta    : OUT    std_logic_vector (23 downto 0) ;
      fractb    : OUT    std_logic_vector (23 downto 0) ;
      inf       : OUT    std_logic  ;
      sign      : OUT    std_logic  ;
      sign_exe  : OUT    std_logic  ;
      underflow : OUT    std_logic_vector (2 downto 0)
   );
END pre_norm_fmul ;

ARCHITECTURE arch OF pre_norm_fmul IS
    signal signa, signb : std_logic ;
    signal sign_d : std_logic ;
    signal exp_ovf_d : std_logic_vector (1 downto 0);
    signal expa, expb : std_logic_vector (7 downto 0);
    signal expa_int, expb_int : std_logic_vector (8 downto 0);
    signal exp_tmp1, exp_tmp2 : std_logic_vector (7 downto 0);
    signal exp_tmp1_int, exp_tmp2_int : std_logic_vector (8 downto 0);
    signal co1, co2 : std_logic ;
    signal expa_dn, expb_dn : std_logic ;
    signal exp_out_a : std_logic_vector (7 downto 0);
    signal opa_00, opb_00, fracta_00, fractb_00 : std_logic ;
    signal exp_tmp3, exp_tmp4, exp_tmp5 : std_logic_vector (7 downto 0);
    signal underflow_d : std_logic_vector (2 downto 0);
    signal op_div : std_logic ;
    signal exp_out_mul, exp_out_div : std_logic_vector (7 downto 0);
    signal exp_out_div_p1, exp_out_div_p2 : std_logic_vector (7 downto 0);
    SIGNAL signacatsignb : std_logic_vector(1 DOWNTO 0);
BEGIN

    -- Aliases
    signa <= opa(31);
    signb <= opb(31);
    expa <= opa(30 downto 23);
    expb <= opb(30 downto 23);

    -- Calculate Exponent
    expa_dn <= NOT (or_reduce(expa));
    expb_dn <= NOT (or_reduce(expb));
    opa_00 <= NOT (or_reduce(opa(30 downto 0)));
    opb_00 <= NOT (or_reduce(opb(30 downto 0)));
    fracta_00 <= NOT (or_reduce(opa(22 downto 0)));
    fractb_00 <= NOT (or_reduce(opb(22 downto 0)));

    -- Recover hidden bit
    fracta <= (NOT expa_dn) & opa(22 downto 0);	
    -- Recover hidden bit
    fractb <= (NOT expb_dn) & opb(22 downto 0);	

    op_div <= '1' WHEN (fpu_op = "011") ELSE '0';
    expa_int <= '0' & expa;
    expb_int <= '0' & expb;
    exp_tmp1_int <= (expa_int - expb_int) WHEN (op_div = '1') ELSE
                    (expa_int + expb_int);
    exp_tmp1 <= exp_tmp1_int(7 DOWNTO 0);
    co1 <= exp_tmp1_int(8);
    
    exp_tmp2_int <= ((co1 & exp_tmp1) + X"7F") WHEN (op_div = '1') ELSE
                    ((co1 & exp_tmp1) - X"7F");

    exp_tmp2 <= exp_tmp2_int(7 DOWNTO 0);
    co2 <= exp_tmp2_int(8);
        
    exp_tmp3 <= exp_tmp2 + '1';
    exp_tmp4 <= X"7F" - exp_tmp1;
    exp_tmp5 <= (exp_tmp4+'1') WHEN (op_div = '1') ELSE
                (exp_tmp4-'1');
    
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            IF op_div = '1' THEN
                exp_out <= exp_out_div;
            ELSE
                exp_out <= exp_out_mul;
            END IF;
        END IF;
    END PROCESS;
    
    exp_out_div_p1 <= exp_tmp5 WHEN (co2 = '1') ELSE
                      exp_tmp3;
    exp_out_div_p2 <= exp_tmp4 WHEN (co2 = '1') ELSE
                      exp_tmp2;
    exp_out_div <= exp_out_div_p1 WHEN ((expa_dn OR expb_dn) = '1') ELSE
                   exp_out_div_p2;
    exp_out_mul <= exp_out_a WHEN (exp_ovf_d(1) = '1') ELSE
                   exp_tmp3 WHEN ((expa_dn OR expb_dn) = '1') ELSE
                   exp_tmp2;
    exp_out_a <= exp_tmp5  WHEN ((expa_dn OR expb_dn) = '1') ELSE
                 exp_tmp4;
    exp_ovf_d(0) <= (expa(7) AND  NOT expb(7)) WHEN (op_div = '1') ELSE
                    (co2 AND expa(7) AND expb(7));
    exp_ovf_d(1) <= co2 WHEN (op_div = '1') ELSE
                    ((NOT expa(7) AND NOT expb(7) AND exp_tmp2(7)) OR co2);
   
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            exp_ovf <= exp_ovf_d;
        END IF;
    END PROCESS;

    underflow_d(0) <= '1' WHEN ((exp_tmp1 < X"7f") AND (co1='0') AND
                                ((opa_00 OR opb_00 OR
                                  expa_dn OR expb_dn) = '0')) ELSE
                      '0';      
    underflow_d(1) <= '1' WHEN ((((expa(7) OR expb(7)) = '1') AND
                                 (opa_00 = '0') AND
                                 (opb_00 = '0')) OR
                                ((expa_dn AND NOT fracta_00) = '1') OR
                                ((expb_dn AND NOT fractb_00) = '1')) ELSE
                      '0';
    underflow_d(2) <= '1' WHEN (((NOT opa_00 AND NOT opb_00) = '1') AND
                                (exp_tmp1 = X"7F")) ELSE
                      '0';
    
    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            underflow <= underflow_d;
            IF op_div = '1' THEN
                inf <= expb_dn AND NOT expa(7);
            ELSE
                IF ((co1 & exp_tmp1) > "101111110") THEN  -- X"17e"
                    inf <= '1';
                ELSE
                    inf <= '0';   
                END IF;
            END IF;
        END IF;
    END PROCESS;

    signacatsignb <= signa & signb;
    -- Determine sign for the output
    PROCESS (signacatsignb)
    BEGIN
        CASE signacatsignb IS
            WHEN "00" => sign_d <= '0';
            WHEN "01" => sign_d <= '1';
            WHEN "10" => sign_d <= '1';
            WHEN "11" => sign_d <= '0';
            WHEN OTHERS => sign_d <= 'X';
        END CASE;
    END PROCESS;

    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            sign <= sign_d;
            sign_exe <= signa AND signb;
        END IF;
    END PROCESS;
    
END arch;
