--
-- Copyright 2011 University of Zagreb, Croatia.
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

-- $Id: clkgen.vhd 116 2011-03-28 12:43:12Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;

entity clkgen is
	generic (
		C_debug: boolean
	);
	port (
		clk_25m: in std_logic;
		sel: in std_logic;
		key: in std_logic; -- one-step clocking
		clk: out std_logic
	);
end clkgen;

architecture Behavioral of clkgen is
	signal pll_clkout: std_logic;
	signal pll_lock: std_logic;
	signal key_d: std_logic_vector(19 downto 0) := x"00000";
	signal key_r: std_logic := '0';
	signal sel_r: std_logic := '0';
begin

	-- PLL generator
	PLL: entity pll
	port map (
        	CLK => clk_25m, CLKOP => pll_clkout, LOCK => pll_lock
	);

	G_nodebug:
	if not C_debug generate
	begin
	clk <= pll_clkout and pll_lock;
	end generate;

	G_debug:
	if C_debug generate
	begin
	-- key debuncer
	process(clk_25m)
	begin
		if (rising_edge(clk_25m)) then
			if (key_d = x"fffff") then
				if (key /= key_r) then
					key_d <= x"00000";
				end if;
				key_r <= key;
			else
				key_d <= key_d + 1;
			end if;
			sel_r <= sel or not pll_lock;
		end if;
	end process;

	-- Clock selector
	DCS_0: DCS
	generic map (
		dcsmode => "POS"
	)
	port map (
		sel => sel_r, clk0 => pll_clkout, clk1 => key_r, dcsout => clk
	);
	end generate;
	
end Behavioral;

