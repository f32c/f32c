--------------------------------------------------------------------------------
-- Engineer:		Mike Field <hamster@snap.net.nz>
-- Description:	Converts VGA signals into DVID bitstreams.
--
--	'clk' and 'clk_n' should be 5x clk_pixel.
--
--------------------------------------------------------------------------------
-- See: http://hamsterworks.co.nz/mediawiki/index.php/Dvid_test
--		http://hamsterworks.co.nz/mediawiki/index.php/FPGA_Projects
--
-- Copyright (c) 2012 Mike Field <hamster@snap.net.nz>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

-- this file came from splitting dvid.vhd in two

-- takes 5x pixel clock and 2 bits at a time
-- outputs single-ended signals for hardware output

-- contains vendor specific DDR output buffers

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
	ddr_out_red : entity work.ddr_out
	port map (clkop=>clk, clkos=>clk_n, clkout=>open, reset=>'0', sclk=>open, 
		dataout(1 downto 0)=>in_red(1 downto 0), dout(0)=>out_red);
		
	ddr_out_green : entity work.ddr_out
	port map (clkop=>clk, clkos=>clk_n, clkout=>open, reset=>'0', sclk=>open, 
		dataout(1 downto 0)=>in_green(1 downto 0), dout(0)=>out_green);		
		
	ddr_out_blue : entity work.ddr_out
	port map (clkop=>clk, clkos=>clk_n, clkout=>open, reset=>'0', sclk=>open, 
		dataout(1 downto 0)=>in_blue(1 downto 0), dout(0)=>out_blue);			

	ddr_out_clock : entity work.ddr_out
	port map (clkop=>clk, clkos=>clk_n, clkout=>open, reset=>'0', sclk=>open, 
		dataout(1 downto 0)=>in_clock(1 downto 0), dout(0)=>out_clock);	

end Behavioral;
