LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY mul_r2 IS
   PORT( 
      clk  : IN     std_logic  ;
      opa  : IN     std_logic_vector (23 downto 0) ;
      opb  : IN     std_logic_vector (23 downto 0) ;
      prod : OUT    std_logic_vector (47 downto 0)
   );
END mul_r2 ;

ARCHITECTURE arch OF mul_r2 IS
    SIGNAL prod1 : std_logic_vector(47 DOWNTO 0);
BEGIN
    PROCESS (clk)
    BEGIN
        IF clk'event AND clk = '1' THEN
            prod1 <= opa * opb;
            prod <= prod1;
        END IF;
    END PROCESS;
END arch;
