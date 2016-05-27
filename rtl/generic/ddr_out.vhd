-- AUTHOR=EMARD
-- LICENSE=BSD

-- untested attempt to make generic DDR output driver
-- 2 bits parallel are taken as input at rising edge of the clock
-- output serialized bit(0) first, then bit(1)

library IEEE;
use IEEE.std_logic_1164.all;

entity ddr_out is
    port (
        iclkp: in std_logic;
        iclkn: in std_logic; -- not used
        ireset: in std_logic; -- not used
        idata: in std_logic_vector(1 downto 0);
        odata: out std_logic := '0'
    );
end ddr_out;

architecture Structure of ddr_out is
  signal R_idata: std_logic_vector(1 downto 0);
begin
  process(iclkp)
  begin
    if rising_edge(iclkp) then
      R_idata <= idata;
    end if;
  end process;
  odata <= R_idata(0) when iclkp='1' else R_idata(1);
end Structure;
