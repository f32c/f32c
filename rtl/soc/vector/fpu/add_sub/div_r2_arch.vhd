LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
USE ieee.std_logic_arith.ALL;

ENTITY div_r2 IS
   PORT( 
      clk       : IN     std_logic  ;
      opa       : IN     std_logic_vector (49 downto 0) ;
      opb       : IN     std_logic_vector (23 downto 0) ;
      quo       : OUT    std_logic_vector (49 downto 0) ;
      remainder : OUT    std_logic_vector (49 downto 0)
   );
END div_r2 ;


ARCHITECTURE arch OF div_r2 IS
    SIGNAL quo1, rem1 : std_logic_vector (49 downto 0);
BEGIN
    PROCESS (clk)
        VARIABLE opa_int, opb_int, quo1_int, rem1_int : integer;
    BEGIN 
        --opa_int := conv_integer(opa);
        --opb_int := conv_integer(opb);
        IF clk'event AND clk = '1' THEN
            --quo1_int := opa_int/opb_int;
            --rem1_int := opa_int REM opb_int;
            --quo1 <= conv_std_logic_vector(quo1_int, 50);
            --rem1 <= conv_std_logic_vector(rem1_int, 50);
            --quo <= quo1;
            --remainder <= rem1;
            quo <= opa;
            remainder <= opa;
        END IF;
    END PROCESS;
END arch;
