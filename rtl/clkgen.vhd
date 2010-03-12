--
-- Copyright 2008, 2010 University of Zagreb, Croatia.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity clkgen is
	generic(
		clk_mhz: integer := 50
	);
	port(
		clk_in: in std_logic; -- 50 MHz signal expected here
		key: in std_logic; -- one-step clocking
		sel: in std_logic_vector(1 downto 0);
		clk_out, clk_out_slow: out std_logic;
		gate_out: out std_logic
	);
end clkgen;

architecture Behavioral of clkgen is
	signal clkfx, gate: std_logic;
	signal cnt: std_logic_vector(15 downto 0);
	signal slowcnt: std_logic_vector(11 downto 0);
begin

	-- main clock synthesizer
	DCM0: DCM
		generic map (
			CLKDV_DIVIDE => 2.0,
				-- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
				-- 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
			CLKFX_DIVIDE => 10, -- Can be any integer from 1 to 32
			CLKFX_MULTIPLY => (clk_mhz / 5), -- from 2 to 32
			CLKIN_DIVIDE_BY_2 => false, -- TRUE/FALSE to enable CLKIN divide by two feature
			CLKIN_PERIOD => 20.0, -- Specify period of input clock
			CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift of NONE, FIXED or VARIABLE
			CLK_FEEDBACK => "NONE", -- Specify clock feedback of NONE, 1X or 2X
			DESKEW_ADJUST => "SOURCE_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
			DFS_FREQUENCY_MODE => "HIGH", -- HIGH or LOW frequency mode for frequency synthesis
			DLL_FREQUENCY_MODE => "HIGH", -- HIGH or LOW frequency mode for DLL
			DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
			FACTORY_JF => X"C080", -- FACTORY JF Values
			PHASE_SHIFT => 0, -- Amount of fixed phase shift from - 255 to 255
			STARTUP_WAIT => TRUE) -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
		port map (
			CLK0 => open, -- 0 degree DCM CLK ouptput
			CLK180 => open, -- 180 degree DCM CLK output
			CLK270 => open, -- 270 degree DCM CLK output
			CLK2X => open, -- 2X DCM CLK output
			CLK2X180 => open, -- 2X, 180 degree DCM CLK out
			CLK90 => open, -- 90 degree DCM CLK output
			CLKDV => open, -- Divided DCM CLK out (CLKDV_DIVIDE)
			CLKFX => clkfx, -- DCM CLK synthesis out (M/D)
			CLKFX180 => open, -- 180 degree CLK synthesis out
			LOCKED => open, -- DCM LOCK status output
			PSDONE => open, -- Dynamic phase adjust done output
			STATUS => open, -- 8-bit DCM status bits output
			CLKFB => open, -- DCM clock feedback
			CLKIN => clk_in, -- Clock input (from IBUFG, BUFG or DCM)
			PSCLK => open, -- Dynamic phase adjust clock input
			PSEN => open, -- Dynamic phase adjust enable input
			PSINCDEC => open, -- Dynamic phase adjust increment/decrement
			RST => '0' -- DCM asynchronous reset input
		);
	
	--
	-- Clock selector:
	--
	-- "11" normal synthesized clock
	-- "10" emit only one in N ticks of synthesized clock
	-- "01" same signal as with "10", but gated with a key press
	-- "00" single-stepping - one tick on each key press
	--
	
	fixed_clock:
	if (clk_mhz >= 100) generate
	begin
		clk_out <= clkfx;
	end generate;

	modulated_clock:
	if (clk_mhz < 100) generate
	begin

	gatedclk_bufg: BUFGMUX
		port map (I0 => '0', I1 => clkfx, S => gate, O => clk_out);

	slowclk_bufg: BUFG
		port map (I => slowcnt(11), O => clk_out_slow);

   gate_out <= gate;
	
   -- Slow clock, used by the debug logic
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			slowcnt <= slowcnt + 1;
		end if;
	end process;

   -- Main synthesized clock, with runtime configurable output
	process(clkfx)
	begin
		if rising_edge(clkfx) then
			if sel /= "00" or key = '0' or cnt /= x"0001" then
				cnt <= cnt + 1;
			end if;
			if sel = "11" then
				gate <= '1';
			elsif sel = "10" then
				if cnt = x"0000" then
					gate <= '1';
				else
					gate <= '0';
				end if;
			else
				if cnt = x"0000" and key = '1' then
					gate <= '1';
				else
					gate <= '0';
				end if;
			end if;
		end if;
	end process;

	end generate; -- clk_mhz < 100 MHz
	
end Behavioral;

