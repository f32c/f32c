LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_misc.ALL;

ENTITY except IS
   PORT( 
      clk     : IN     std_logic  ;
      opa     : IN     std_logic_vector (31 downto 0) ;
      opb     : IN     std_logic_vector (31 downto 0) ;
      ind     : OUT    std_logic  ;
      inf     : OUT    std_logic  ;
      opa_00  : OUT    std_logic  ;
      opa_dn  : OUT    std_logic  ;
      opa_inf : OUT    std_logic  ;
      opa_nan : OUT    std_logic  ;
      opb_00  : OUT    std_logic  ;
      opb_dn  : OUT    std_logic  ;
      opb_inf : OUT    std_logic  ;
      opb_nan : OUT    std_logic  ;
      qnan    : OUT    std_logic  ;
      snan    : OUT    std_logic 
   );
END except ;
ARCHITECTURE arch OF except IS
    signal expa, expb : std_logic_vector (7 downto 0);
    signal fracta, fractb : std_logic_vector (22 downto 0);
    signal expa_ff, infa_f_r, qnan_r_a, snan_r_a : std_logic ;
    signal expb_ff, infb_f_r, qnan_r_b, snan_r_b : std_logic ;
    signal expa_00, expb_00, fracta_00, fractb_00 : std_logic ;
BEGIN
    expa <= opa(30 downto 23);
    expb <= opb(30 downto 23);
    fracta <= opa(22 downto 0);
    fractb <= opb(22 downto 0);

    ---------------------------------------------------------------------------
    -- Determine if any of the input operators is a INF or NAN or any other special number
    ---------------------------------------------------------------------------

    PROCESS (clk)
    BEGIN 
        IF clk'event AND clk = '1' THEN
            expa_ff <= and_reduce(expa);
            expb_ff <= and_reduce(expb);
            infa_f_r <= NOT or_reduce(fracta);
            infb_f_r <= NOT or_reduce(fractb);
            qnan_r_a <= fracta(22);
            snan_r_a <= NOT fracta(22) AND or_reduce(fracta(21 downto 0));
            qnan_r_b <= fractb(22);
            snan_r_b <= NOT fractb(22) and or_reduce(fractb(21 downto 0));
            ind <= (expa_ff and infa_f_r) and (expb_ff and infb_f_r);
            inf <= (expa_ff and infa_f_r) or (expb_ff and infb_f_r);
            qnan <= (expa_ff and qnan_r_a) or (expb_ff and qnan_r_b);
            snan <= (expa_ff and snan_r_a) or (expb_ff and snan_r_b);
            opa_nan <= and_reduce(expa) and or_reduce(fracta(22 downto 0));
            opb_nan <= and_reduce(expb) and or_reduce(fractb(22 downto 0));
            opa_inf <= (expa_ff and infa_f_r);
            opb_inf <= (expb_ff and infb_f_r);
            expa_00 <= NOT or_reduce(expa);
            expb_00 <= NOT or_reduce(expb);
            fracta_00 <= NOT or_reduce(fracta);
            fractb_00 <= NOT or_reduce(fractb);
            opa_00 <= expa_00 and fracta_00;
            opb_00 <= expb_00 and fractb_00;
            opa_dn <= expa_00;
            opb_dn <= expb_00;
        END IF;
    END PROCESS;
 
END arch;
