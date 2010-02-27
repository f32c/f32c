--
-- Copyright 2008 University of Zagreb, Croatia.
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

-- $Id: $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity alu is
   port(
		x, y: in STD_LOGIC_VECTOR(31 downto 0);
		funct: in std_logic_vector(1 downto 0);
		sign_extend: in boolean;
		addsubx: out std_logic_vector(32 downto 0);
		logic: out std_logic_vector(31 downto 0);
		equal: out boolean
	);
end alu;

architecture Behavioral of alu is
	signal ex, ey: std_logic_vector(32 downto 0);
begin

	-- sign extenstion used only for SLT/SLTI/SLTU/SLTIU
	ex <= x(31) & x when sign_extend	else '0' & x;
	ey <= y(31) & y when sign_extend else '0' & y;
	
	process(x, y, funct)
	begin
		case funct(1) is
			when '0' =>	addsubx <= ex + ey;
			when '1' =>	addsubx <= ex - ey;
			when others =>
		end case;
	end process;
	
	process(x, y, funct)
	begin
		case funct is
			when "00" =>	logic <= x and y;
			when "01" =>	logic <= x or y;
			when "10" =>	logic <= x xor y;
			when "11" =>	logic <= not(x or y);
			when others =>
		end case;
	end process;
	
	equal <= x = y;
	
end Behavioral;

