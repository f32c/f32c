-- A clock output that uses a DDR output with hardcoded data inputs 1 and 0 to
-- output the clock edges.

library ieee;
use ieee.std_logic_1164.all;

entity clock_output is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    q   : out std_logic);
end entity;

architecture asic of clock_output is
begin
  p : process(rst, clk)
  begin
    if rst = '1' then
      q <= '0';
    else
    --elsif clk'event then
      q <= clk;
    end if;
  end process;
end architecture;
