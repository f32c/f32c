-- Emard
-- LICENSE=BSD

library IEEE;
use IEEE.std_logic_1164.all;
library ecp5u;
use ecp5u.components.all;

entity ddr_out is
  port
  (
    iclkp: in  std_logic;
    iclkn: in  std_logic;
    ireset: in  std_logic;
    idata: in  std_logic_vector(1 downto 0);
    odata: out std_logic
  );
end ddr_out;

architecture Structure of ddr_out is
    -- local component declarations
    component ODDRX1F
        port (D0: in  std_logic; D1: in  std_logic; SCLK: in  std_logic; 
              RST: in  std_logic; Q: out  std_logic);
    end component;
begin
    ddr_module: ODDRX1F
        port map (D0=>idata(0), D1=>idata(1), SCLK=>iclkp, RST=>ireset, 
                  Q=>odata);
end Structure;
