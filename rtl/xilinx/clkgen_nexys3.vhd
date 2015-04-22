--
-- Copyright (c) 2015 Marko Zec, University of Zagreb.
-- All rights reserved.
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
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity clkgen is
    generic(
	C_clk_freq: integer
    );
    port(
	clk_100m: in std_logic; -- 100 MHz signal expected here
	clk: out std_logic
    );
end clkgen;

architecture Behavioral of clkgen is
    signal clkfx: std_logic;
begin

    -- main clock synthesizer
    DCM0: DCM
    generic map (
	CLKDV_DIVIDE => 2.0,
	-- Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5
	-- 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
	CLKFX_DIVIDE => 10, -- Can be any integer from 1 to 32
	CLKFX_MULTIPLY => (C_clk_freq / 10), -- from 2 to 32
	CLKIN_DIVIDE_BY_2 => false, -- TRUE/FALSE to enable CLKIN divide by two feature
	CLKIN_PERIOD => 10.0, -- Specify period of input clock
	CLKOUT_PHASE_SHIFT => "NONE", -- Specify phase shift of NONE, FIXED or VARIABLE
	CLK_FEEDBACK => "NONE", -- Specify clock feedback of NONE, 1X or 2X
	DESKEW_ADJUST => "SOURCE_SYNCHRONOUS", -- SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
	DFS_FREQUENCY_MODE => "HIGH", -- HIGH or LOW frequency mode for frequency synthesis
	DLL_FREQUENCY_MODE => "HIGH", -- HIGH or LOW frequency mode for DLL
	DUTY_CYCLE_CORRECTION => TRUE, -- Duty cycle correction, TRUE or FALSE
	FACTORY_JF => X"C080", -- FACTORY JF Values
	PHASE_SHIFT => 0, -- Amount of fixed phase shift from - 255 to 255
	STARTUP_WAIT => TRUE -- Delay configuration DONE until DCM LOCK, TRUE/FALSE
    )
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
	CLKIN => clk_100m, -- Clock input (from IBUFG, BUFG or DCM)
	PSCLK => open, -- Dynamic phase adjust clock input
	PSEN => open, -- Dynamic phase adjust enable input
	PSINCDEC => open, -- Dynamic phase adjust increment/decrement
	RST => '0' -- DCM asynchronous reset input
    );

    clk <= clkfx;

end Behavioral;

