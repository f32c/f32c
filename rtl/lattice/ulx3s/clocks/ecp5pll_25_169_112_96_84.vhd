
library IEEE;
use IEEE.std_logic_1164.all;

entity pll_25m is
    port (
	clk_25m: in std_logic; 
	clk_168m75: out std_logic; 
	clk_112m5: out std_logic; 
	clk_96m43: out std_logic; 
	clk_84m34: out std_logic; 
	lock: out std_logic
    );
end pll_25m;

architecture Structure of pll_25m is
    signal S_clocks: std_logic_vector(3 downto 0);
begin
    clk25: entity work.ecp5pll
    generic map
    (
        in_Hz =>  25000000,
      out0_Hz => 112500000,
      out1_Hz => 168750000,
      out2_Hz =>  96428571,
      out3_Hz =>  84375000
    )
    port map
    (
      clk_i   => clk_25m,
      clk_o   => S_clocks,
      locked  => lock
    );
    clk_112m5  <= S_clocks(0); 
    clk_168m75 <= S_clocks(1); 
    clk_96m43  <= S_clocks(2); 
    clk_84m34  <= S_clocks(3); 
end Structure;
