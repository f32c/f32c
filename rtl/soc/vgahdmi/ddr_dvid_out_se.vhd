-- Emard
-- LICENSE=BSD
-- instantiates vendor specific DDR output buffers

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ddr_dvid_out_se is
	Port (
		clk	  : in	STD_LOGIC; -- positive clock 125MHz (phase 0)
		clk_n	  : in	STD_LOGIC; -- negative clock 125MHz (phase 180)
		-- input hdmi data for DDR out, 2 bits per clock period
		in_red	  : in STD_LOGIC_VECTOR(1 downto 0);
		in_green  : in STD_LOGIC_VECTOR(1 downto 0);
		in_blue   : in STD_LOGIC_VECTOR(1 downto 0);
		in_clock  : in STD_LOGIC_VECTOR(1 downto 0);
		-- single-ended DDR out suitable for onboard hardware driver
		out_red	  : out STD_LOGIC;
		out_green : out STD_LOGIC;
		out_blue  : out STD_LOGIC;
		out_clock : out STD_LOGIC
	);
end ddr_dvid_out_se;

architecture Behavioral of ddr_dvid_out_se is
begin

  -- DDR vendor specific primitives
  ddr_out_red: entity work.ddr_out
  port map
  (
    iclkp=>clk, iclkn=>clk_n, ireset=>'0',
    idata(1 downto 0)=>in_red(1 downto 0), odata=>out_red
  );

  ddr_out_green: entity work.ddr_out
  port map
  (
    iclkp=>clk, iclkn=>clk_n, ireset=>'0',
    idata(1 downto 0)=>in_green(1 downto 0), odata=>out_green
  );

  ddr_out_blue: entity work.ddr_out
  port map
  (
    iclkp=>clk, iclkn=>clk_n, ireset=>'0',
    idata(1 downto 0)=>in_blue(1 downto 0), odata=>out_blue
  );

  ddr_out_clock: entity work.ddr_out
  port map
  (
    iclkp=>clk, iclkn=>clk_n, ireset=>'0',
    idata(1 downto 0)=>in_clock(1 downto 0), odata=>out_clock
  );

end Behavioral;
