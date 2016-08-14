--
-- Copyright (c) 2008 - 2014 Marko Zec, University of Zagreb
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
use ieee.std_logic_unsigned.all;

entity alu is
    generic (
	C_sign_extend: boolean
    );
    port(
	x, y: in std_logic_vector(31 downto 0);
	funct: in std_logic_vector(1 downto 0);
	seb_seh_cycle: in boolean;
	seb_seh_select: in std_logic;
	addsubx: out std_logic_vector(32 downto 0);
	logic: out std_logic_vector(31 downto 0)
    );
end alu;

architecture Behavioral of alu is
    signal ex, ey: std_logic_vector(32 downto 0);
begin

    ex <= '0' & x;
    ey <= '0' & y;

    addsubx <= ex + ey when funct(1) = '0' else ex - ey;

    process(x, y, funct, seb_seh_cycle, seb_seh_select)
	variable x_logic: std_logic_vector(31 downto 0);
    begin
	case funct is
	when "00" =>	x_logic := x and y;
	when "01" =>	x_logic := x or y;
	when "10" =>	x_logic := x xor y;
	when others => 	x_logic := not(x or y);
	end case;

	if C_sign_extend and seb_seh_cycle then
	    if seb_seh_select = '1' then
		logic(31 downto 16) <= (others => x_logic(15));
		logic(15 downto 0) <= x_logic(15 downto 0);
	    else
		logic(31 downto 8) <= (others => x_logic(7));
		logic(7 downto 0) <= x_logic(7 downto 0);
	    end if;
	else
	    logic <= x_logic;
	end if;
    end process;

end Behavioral;

