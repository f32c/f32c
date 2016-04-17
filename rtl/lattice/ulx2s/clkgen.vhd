--
-- Copyright (c) 2011-2015 Marko Zec, University of Zagreb
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

library xp2;
use xp2.components.all;

entity clkgen is
	generic (
		C_clk_freq: integer
	);
	port (
		clk_25m: in std_logic;
		ena_325m: in std_logic;
		res: in std_logic;
		clk, clk_325m: out std_logic
	);
end clkgen;

architecture Behavioral of clkgen is
	signal pll_clk, pll_clk_325m: std_logic;
	signal pll_lock: std_logic;
	signal resl: std_logic;

begin
	-- PLL generator
	G_pll_325:
	if C_clk_freq = 81 generate
	PLL: entity work.pll
	generic map (
		C_pll_freq => 325
	)
	port map (
        	clk => clk_25m, reset => res,
		lock => pll_lock, clkok => pll_clk, clkop => pll_clk_325m
	);
	DCS_325: DCS
	generic map (
		dcsmode => "POS"
	)
	port map (
		sel => ena_325m, clk0 => '0', clk1 => pll_clk_325m,
		dcsout => clk_325m
	);
	clk <= pll_clk;
	end generate;

	G_pll:
	if C_clk_freq /= 81 generate
	PLL: entity work.pll
	generic map (
		C_pll_freq => C_clk_freq
	)
	port map (
        	clk => clk_25m, reset => res,
		lock => pll_lock, clkok => open, clkop => pll_clk
	);
	clk_325m <= '0';
	clk <= pll_clk;
	end generate;

	resl <= not res and pll_lock;

	-- reset
	gsr_inst: GSR
	port map (
		gsr => resl
	);
end Behavioral;

