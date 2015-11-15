--------------------------------------------------------------------------------
-- Engineer:		Mike Field <hamster@snap.net.nz>
-- Description:	Converts VGA signals into DVID bitstreams.
--
--				'blank' must be asserted during the non-display
--				portions of the frame
--
-- NOTE due to the PLL frequency limits, changes are needed in dvid_out_clocking
-- to select pixel rates between 40 and 100 Mhz pixel clocks, or between 20 and
-- 50 MHz.
--------------------------------------------------------------------------------
--
-- Tweaked by Xark (https://hackaday.io/Xark) for use in f32c project.
--
-- See: http://hamsterworks.co.nz/mediawiki/index.php/Dvid_test
--		http://hamsterworks.co.nz/mediawiki/index.php/MiniSpartan6%2B_DVID_Output
--		http://hamsterworks.co.nz/mediawiki/index.php/FPGA_Projects
--
-- Copyright (c) 2012-2015 Mike Field <hamster@snap.net.nz>
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity dvid_out is
	Generic (
		C_depth:	integer := 8	-- 1 to 8 bit color depth for 8 to 16.7-million colors
	);
	Port (
		-- Clocking
		clk_pixel:	in std_logic;		-- 25 MHz for 640x480 @ 60Hz
		clk_tmds:	in std_logic;		-- 250 MHz (or 10x pixel clock)
		-- Pixel data
		red_p:		in std_logic_vector(C_depth-1 downto 0);
		green_p:	in std_logic_vector(C_depth-1 downto 0);
		blue_p:		in std_logic_vector(C_depth-1 downto 0);
		blank:		in std_logic;
		hsync:		in std_logic;
		vsync:		in std_logic;
		-- TMDS output
		TMDS_out_RGB : out std_logic_vector(2 downto 0)
	);
end dvid_out;

architecture Behavioral of dvid_out is

	signal encoded_red, encoded_green, encoded_blue: std_logic_vector(9 downto 0);
	signal latched_red, latched_green, latched_blue : std_logic_vector(9 downto 0) := (others => '0');
	signal shift_red,	shift_green,	shift_blue	: std_logic_vector(9 downto 0) := (others => '0');

	signal shift_clock	: std_logic_vector(9 downto 0) := "0000011111";

	constant c_red: std_logic_vector(1 downto 0) := (others => '0');
	constant c_green: std_logic_vector(1 downto 0) := (others => '0');
	signal	c_blue: std_logic_vector(1 downto 0);

	signal red_s: std_logic;
	signal green_s: std_logic;
	signal blue_s: std_logic;
	signal clock_s: std_logic;

	signal red_d: std_logic_vector(7 downto 0);
	signal green_d: std_logic_vector(7 downto 0);
	signal blue_d: std_logic_vector(7 downto 0);

begin
	-- compute 8-bit color as C_depth may be less (by doing it as last step here saves LUTs)
	red_d(7 downto 8-C_depth) <= red_p(C_depth-1 downto 0);
	green_d(7 downto 8-C_depth) <= green_p(C_depth-1 downto 0);
	blue_d(7 downto 8-C_depth) <= blue_p(C_depth-1 downto 0);

	-- fill any unset low-bits with value repeated (so value is mapped to full 8-bit range)
	G_bits: for i in 8-C_depth-1 downto 0 generate
		red_d(i) <= red_p((C_depth-1-i) MOD C_depth);
		green_d(i) <= green_p((C_depth-1-i) MOD C_depth);
		blue_d(i) <= blue_p((C_depth-1-i) MOD C_depth);
	end generate;

	-- Send the pixels to the encoder
	c_blue <= vsync & hsync;
	TMDS_encoder_red:	entity work.TMDS_encoder port map (clk => clk_pixel, data => red_d, c => c_red, blank => blank, encoded => encoded_red);
	TMDS_encoder_green: entity work.TMDS_encoder port map (clk => clk_pixel, data => green_d, c => c_green, blank => blank, encoded => encoded_green);
	TMDS_encoder_blue:	entity work.TMDS_encoder port map (clk => clk_pixel, data => blue_d, c => c_blue, blank => blank, encoded => encoded_blue);

	-- TMDS encoded serial output
	TMDS_out_RGB <= shift_red(0) & shift_green(0) & shift_blue(0);

	-- latch newly encoded pixels to be shifted out
	process(clk_pixel)
	begin
		if rising_edge(clk_pixel) then
			latched_red	<= encoded_red;
			latched_green <= encoded_green;
			latched_blue <= encoded_blue;
		end if;
	end process;

	-- shift out TMDS encoded pixels
	process(clk_tmds)
	begin
		if rising_edge(clk_tmds) then
		if shift_clock = "0000011111" then
			shift_red	<= latched_red;
			shift_green <= latched_green;
			shift_blue	<= latched_blue;
		else
			shift_red	<= "0" & shift_red	(9 downto 1);
			shift_green <= "0" & shift_green(9 downto 1);
			shift_blue	<= "0" & shift_blue (9 downto 1);
		end if;
		shift_clock <= shift_clock(0) & shift_clock(9 downto 1);
		end if;
	end process;
end Behavioral;