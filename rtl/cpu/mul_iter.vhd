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
    generic (
	C_skip_mux: boolean := true
    );
    port (
	clk, clk_enable: in std_logic;
	start, mult_signed, mthi: in boolean;
	x, y: in std_logic_vector(31 downto 0);
	hi_lo: out std_logic_vector(63 downto 0);
	done: out boolean
    );
end mul;

architecture arch_x of mul is
    signal R_x, R_hi_lo: std_logic_vector(63 downto 0);
    signal R_y, R_cmp: std_logic_vector(31 downto 0);
    signal R_done: boolean;
begin

    process(clk)
    begin
	if rising_edge(clk) and clk_enable = '1' then
	    if start then
		R_done <= false;
		R_hi_lo <= (others => '0');
		R_x(31 downto 0) <= x;
		if mult_signed and x(31) = '1' then
		    R_x(63 downto 32) <= (others => '1');
		else
		    R_x(63 downto 32) <= (others => '0');
		end if;
		if mult_signed and y(31) = '1' then
		    R_y <= y - 1;
		    R_cmp <= (others => '1');
		else
		    R_y <= y;
		    R_cmp <= (others => '0');
		end if;
	    elsif R_y /= R_cmp then
		R_done <= R_y(31 downto 1) = R_cmp(31 downto 1);
		if R_y(0) /= R_cmp(0) then
		    if R_cmp(0) = '0' then
			R_hi_lo <= R_hi_lo + R_x;
		    else
			R_hi_lo <= R_hi_lo - R_x;
		    end if;
		end if;
		if C_skip_mux and R_y(1) = R_cmp(1) then
		    R_x <= R_x(61 downto 0) & "00";
		    R_y <= R_cmp(1 downto 0) & R_y(31 downto 2);
		else
		    R_x <= R_x(62 downto 0) & '0';
		    R_y <= R_cmp(0) & R_y(31 downto 1);
		end if;
	    else
		R_done <= true;
	    end if;
	end if;
    end process;

    done <= R_done;
    hi_lo <= R_hi_lo;
end arch_x;
