--
-- Copyright (c) 2016 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity mul is
    port(
	clk, clk_enable: in std_logic;
	start, mult_signed, mthi: in boolean;
	x, y: in std_logic_vector(31 downto 0);
	hi_lo: out std_logic_vector(63 downto 0);
	done: out boolean
    );
end mul;

architecture arch_x of mul is
    signal R_mul_res: signed(66 downto 0);
    signal R_mul_x: signed(32 downto 0);
    signal R_mul_y: signed(33 downto 0);
    signal R_mul_run: std_logic;
begin

    done <= true; -- this is a single-cycle multiplier

    process(clk)
    begin
	if rising_edge(clk) then
	    R_mul_run <= clk_enable;
	end if;
	if falling_edge(clk) then
	    if clk_enable = '1' or R_mul_run = '1' then
		R_mul_x(31 downto 0) <= CONV_SIGNED(UNSIGNED(x), 32);
		R_mul_y(31 downto 0) <= CONV_SIGNED(UNSIGNED(y), 32);
		if mult_signed then
		    R_mul_x(32) <= x(31);
		    R_mul_y(33 downto 32) <= (others => y(31));
		else
		    R_mul_x(32) <= '0';
		    R_mul_y(33 downto 32) <= (others => '0');
		end if;
		if mthi then
		    R_mul_y(32) <= '1';
		end if;
		R_mul_res <= R_mul_x * R_mul_y;
	    end if;
	end if;
    end process;

    hi_lo(63 downto 32) <= conv_std_logic_vector(R_mul_res(63 downto 32), 32);
    hi_lo(31 downto 0) <= conv_std_logic_vector(R_mul_res(31 downto 0), 32);
end arch_x;
