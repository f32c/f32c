LIBRARY ieee ;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY add_sub27 IS
   PORT( 
      add : IN     std_logic  ;
      opa : IN     std_logic_vector (26 downto 0) ;
      opb : IN     std_logic_vector (26 downto 0) ;
      co  : OUT    std_logic  ;
      sum : OUT    std_logic_vector (26 downto 0)
   );
END add_sub27 ;

ARCHITECTURE arch OF add_sub27 IS
    signal opa_int : std_logic_vector (27 downto 0) ;
    signal opb_int : std_logic_vector (27 downto 0) ;
    signal sum_int : std_logic_vector (27 downto 0) ;
BEGIN

    opa_int <= '0' & opa;
    opb_int <= '0' & opb;
    
    sum_int <= opa_int + opb_int WHEN (add = '1') else
               opa_int - opb_int;

    sum <= sum_int(26 downto 0);
    co <= sum_int(27);

END arch;
