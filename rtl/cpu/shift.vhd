--
-- Copyright (c) 2008 - 2014 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;

use work.f32c_pack.all;


entity shift is
    generic (
	C_load_aligner: boolean
    );
    port (
	shamt_8_16: in std_logic_vector(1 downto 0);
	shamt_1_2_4: in std_logic_vector(2 downto 0);
	funct_8_16, funct_1_2_4: in std_logic_vector(1 downto 0);
	stage8_in, stage1_in: in std_logic_vector(31 downto 0);
	stage16_out, stage4_out: out std_logic_vector(31 downto 0);
	mem_multicycle_lh_lb: in boolean;
	mem_read_sign_extend_multicycle: in std_logic;
	mem_size_multicycle: in std_logic
    );
end shift;

architecture Behavioral of shift is
    signal stage1, stage2, stage4: std_logic_vector(31 downto 0);
    signal stage8, stage16: std_logic_vector(31 downto 0);
    signal sel16, sel8, sel4, sel2, sel1: std_logic_vector(1 downto 0);
begin
    -- shift by 8 and 16 occurs in EX stage; shift by 1, 2 and 4 is in MEM stage

    sel8 <= funct_8_16 when shamt_8_16(0) = '1' else OP_SHIFT_BYPASS;
    sel16 <= funct_8_16 when shamt_8_16(1) = '1' else OP_SHIFT_BYPASS;
    sel1 <= funct_1_2_4 when shamt_1_2_4(0) = '1' else OP_SHIFT_BYPASS;
    sel2 <= funct_1_2_4 when shamt_1_2_4(1) = '1' else OP_SHIFT_BYPASS;
    sel4 <= funct_1_2_4 when shamt_1_2_4(2) = '1' else OP_SHIFT_BYPASS;

    with sel8 select stage8 <=
	stage8_in(23 downto 0) & x"00" when OP_SHIFT_LL,
	x"00" & stage8_in(31 downto 8) when OP_SHIFT_RL,
	stage8_in(31) & stage8_in(31) & stage8_in(31) & stage8_in(31) &
	    stage8_in(31) & stage8_in(31) & stage8_in(31) & stage8_in(31) &
	    stage8_in(31 downto 8) when OP_SHIFT_RA,
	stage8_in when others;

    with sel16 select stage16 <=
	stage8(15 downto 0) & x"0000" when OP_SHIFT_LL,
	x"0000" & stage8(31 downto 16) when OP_SHIFT_RL,
	stage8(31) & stage8(31) & stage8(31) & stage8(31) &
	  stage8(31) & stage8(31) & stage8(31) & stage8(31) &
	  stage8(31) & stage8(31) & stage8(31) & stage8(31) &
	  stage8(31) & stage8(31) & stage8(31) & stage8(31) &
	  stage8(31 downto 16) when OP_SHIFT_RA,
	stage8 when others;
	
    stage16_out <= stage16;

    -- the bottom part is separated from the upper by a register
    -- on EX to MEM boundary.

    with sel1 select stage1 <=
	stage1_in(30 downto 0) & "0" when OP_SHIFT_LL,
	"0" & stage1_in(31 downto 1) when OP_SHIFT_RL,
	stage1_in(31) & stage1_in(31 downto 1) when OP_SHIFT_RA,
	stage1_in when others;

    with sel2 select stage2 <=
	stage1(29 downto 0) & "00" when OP_SHIFT_LL,
	"00" & stage1(31 downto 2) when OP_SHIFT_RL,
	stage1(31) & stage1(31) & stage1(31 downto 2) when OP_SHIFT_RA,
	stage1 when others;

    with sel4 select stage4 <=
	stage2(27 downto 0) & x"0" when OP_SHIFT_LL,
	x"0" & stage2(31 downto 4) when OP_SHIFT_RL,
	stage2(31) & stage2(31) & stage2(31) & stage2(31) &
	stage2(31 downto 4) when OP_SHIFT_RA,
	stage2 when others;
   	
    process(stage4, mem_multicycle_lh_lb, mem_read_sign_extend_multicycle,
      mem_size_multicycle)
    begin
	if not C_load_aligner and mem_multicycle_lh_lb then
	    if mem_size_multicycle = '0' then -- byte load
		if mem_read_sign_extend_multicycle = '1' then
		    if stage4(7) = '1' then
			stage4_out <= x"ffffff" & stage4(7 downto 0);
		    else
			stage4_out <= x"000000" & stage4(7 downto 0);
		    end if;
		else
		    stage4_out <= x"000000" & stage4(7 downto 0);
		end if;
	    else -- half word load
		if mem_read_sign_extend_multicycle = '1' then
		    if stage4(15) = '1' then
			stage4_out <= x"ffff" & stage4(15 downto 0);
		    else
			stage4_out <= x"0000" & stage4(15 downto 0);
		    end if;
		else
		    stage4_out <= x"0000" & stage4(15 downto 0);
		end if;
	    end if;
	else
	    stage4_out <= stage4;
	end if;
    end process;
end Behavioral;
