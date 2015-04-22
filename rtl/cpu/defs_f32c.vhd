--
-- Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
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

use work.mi32_pack.all;
use work.rv32_pack.all;


package f32c_pack is

-- ISA / Architecture
constant ARCH_MI32:		integer := 0;
constant ARCH_RV32:		integer := 1;

--
-- f32c internal codes
--

-- Memory access width
constant MEM_SIZE_UNDEFINED:	std_logic_vector := "--";
constant MEM_SIZE_8:		std_logic_vector := "00";
constant MEM_SIZE_16:		std_logic_vector := "01";
constant MEM_SIZE_32:		std_logic_vector := "10";
constant MEM_SIZE_64:		std_logic_vector := "11";

-- Result availability latency
constant LATENCY_UNDEFINED:	std_logic_vector := "--";
constant LATENCY_EX:		std_logic_vector := "00";
constant LATENCY_MEM:		std_logic_vector := "01";
constant LATENCY_WB:		std_logic_vector := "11";

-- Branch predictor saturation counter values
constant BP_STRONG_TAKEN:	std_logic_vector := "11";
constant BP_WEAK_TAKEN:		std_logic_vector := "10";
constant BP_WEAK_NOT_TAKEN:	std_logic_vector := "01";
constant BP_STRONG_NOT_TAKEN:	std_logic_vector := "00";

-- EX stage result select
constant OP_MAJOR_ALU:		std_logic_vector := "00";
constant OP_MAJOR_SLT:		std_logic_vector := "01";
constant OP_MAJOR_SHIFT:	std_logic_vector := "10";
constant OP_MAJOR_ALT:		std_logic_vector := "11";

-- ALU operation select
constant OP_MINOR_ADD:		std_logic_vector := "00-";
constant OP_MINOR_SUB:		std_logic_vector := "01-";
constant OP_MINOR_AND:		std_logic_vector := "100";
constant OP_MINOR_OR:		std_logic_vector := "101";
constant OP_MINOR_XOR:		std_logic_vector := "110";
constant OP_MINOR_NOR:		std_logic_vector := "111";

-- Shift operation select
constant OP_SHIFT_LL:		std_logic_vector := "00";
constant OP_SHIFT_BYPASS:	std_logic_vector := "01";
constant OP_SHIFT_RL:		std_logic_vector := "10";
constant OP_SHIFT_RA:		std_logic_vector := "11";

-- ALT mux select
constant ALT_HI:		std_logic_vector := "000";
constant ALT_LO:		std_logic_vector := "001";
constant ALT_PC_RET:		std_logic_vector := "010";
constant ALT_COP0:		std_logic_vector := "011";

function ARCH_REG_ZERO(arch : integer) return std_logic_vector;

end f32c_pack;

package body f32c_pack is

-- Arch-dependent reg-zero
function ARCH_REG_ZERO(arch : integer)
    return std_logic_vector is
begin
   if arch = ARCH_MI32 then
	return MI32_REG_ZERO;
   else
	return RV32_REG_ZERO;
   end if;
end ARCH_REG_ZERO; 

end f32c_pack;
