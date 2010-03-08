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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity shift is
	port(
		shamt_8_16: in std_logic_vector(1 downto 0);
		shamt_1_2_4: in std_logic_vector(2 downto 0);
		funct_8_16, funct_1_2_4: in std_logic_vector(1 downto 0);
		stage8_in, stage1_in: in std_logic_vector(31 downto 0);
		stage16_out, stage4_out: out std_logic_vector(31 downto 0)
	);
end shift;

architecture Behavioral of shift is
	signal stage1, stage2, stage8: std_logic_vector(31 downto 0);
	signal sel16, sel8, sel4, sel2, sel1: std_logic_vector(1 downto 0);
begin
	-- shift by 8 and 16 occurs in EX stage; shift by 1, 2 and 4 is in MEM stage

	sel8 <= funct_8_16 when shamt_8_16(0) = '1' else "01";
	sel16 <= funct_8_16 when shamt_8_16(1) = '1' else "01";
	sel1 <= funct_1_2_4 when shamt_1_2_4(0) = '1' else "01";
	sel2 <= funct_1_2_4 when shamt_1_2_4(1) = '1' else "01";
	sel4 <= funct_1_2_4 when shamt_1_2_4(2) = '1' else "01";

	-- sel: "00" left logical, "10" right logical, "11" right artihm, "01" bypass
	
	with sel8 select
		stage8 <= stage8_in(23 downto 0) & x"00" when "00",
			x"00" & stage8_in(31 downto 8) when "10",
			stage8_in(31) & stage8_in(31) & stage8_in(31) & stage8_in(31) &
			stage8_in(31) & stage8_in(31) & stage8_in(31) & stage8_in(31) &
			stage8_in(31 downto 8) when "11",
			stage8_in when others;

	with sel16 select
		stage16_out <= stage8(15 downto 0) & x"0000" when "00",
			x"0000" & stage8(31 downto 16) when "10",
			stage8(31) & stage8(31) & stage8(31) & stage8(31) &
			stage8(31) & stage8(31) & stage8(31) & stage8(31) &
			stage8(31) & stage8(31) & stage8(31) & stage8(31) &
			stage8(31) & stage8(31) & stage8(31) & stage8(31) &
			stage8(31 downto 16) when "11",
			stage8 when others;
	
	-- the bottom part is separated from the upper by a register
	-- on EX to MEM boundary.

	with sel1 select
		stage1 <= stage1_in(30 downto 0) & "0" when "00",
			"0" & stage1_in(31 downto 1) when "10",
			stage1_in(31) & stage1_in(31 downto 1) when "11",
			stage1_in when others;

	with sel2 select
		stage2 <= stage1(29 downto 0) & "00" when "00",
			"00" & stage1(31 downto 2) when "10",
			stage1(31) & stage1(31) & stage1(31 downto 2) when "11",
			stage1 when others;

	with sel4 select
		stage4_out <= stage2(27 downto 0) & x"0" when "00",
			x"0" & stage2(31 downto 4) when "10",
			stage2(31) & stage2(31) & stage2(31) & stage2(31) &
			stage2(31 downto 4) when "11",
			stage2 when others;
   	
end Behavioral;

