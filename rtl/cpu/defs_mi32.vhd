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

package mi32_pack is

-- Main MI32 opcodes
constant MI32_OP_SPECIAL:	std_logic_vector := "000000";
constant MI32_OP_REGIMM:	std_logic_vector := "000001";
constant MI32_OP_J:		std_logic_vector := "000010";
constant MI32_OP_JAL:		std_logic_vector := "000011";
constant MI32_OP_BEQ:		std_logic_vector := "000100";
constant MI32_OP_BNE:		std_logic_vector := "000101";
constant MI32_OP_BLEZ:		std_logic_vector := "000110";
constant MI32_OP_BGTZ:		std_logic_vector := "000111";
constant MI32_OP_ADDI:		std_logic_vector := "001000";
constant MI32_OP_ADDIU:		std_logic_vector := "001001";
constant MI32_OP_SLTI:		std_logic_vector := "001010";
constant MI32_OP_SLTIU:		std_logic_vector := "001011";
constant MI32_OP_ANDI:		std_logic_vector := "001100";
constant MI32_OP_ORI:		std_logic_vector := "001101";
constant MI32_OP_XORI:		std_logic_vector := "001110";
constant MI32_OP_LUI:		std_logic_vector := "001111";
constant MI32_OP_COP0:		std_logic_vector := "010000";
constant MI32_OP_COP1:		std_logic_vector := "010001";
constant MI32_OP_COP2:		std_logic_vector := "010010";
constant MI32_OP_COP1X:		std_logic_vector := "010011";
constant MI32_OP_BEQL:		std_logic_vector := "010100";
constant MI32_OP_BNEL:		std_logic_vector := "010101";
constant MI32_OP_BLEZL:		std_logic_vector := "010110";
constant MI32_OP_BGTZL:		std_logic_vector := "010111";
constant MI32_OP_SPECIAL2:	std_logic_vector := "011100";
constant MI32_OP_JALX:		std_logic_vector := "011101";
constant MI32_OP_SPECIAL3:	std_logic_vector := "011111";
constant MI32_OP_LB:		std_logic_vector := "100000";
constant MI32_OP_LH:		std_logic_vector := "100001";
constant MI32_OP_LWL:		std_logic_vector := "100010";
constant MI32_OP_LW:		std_logic_vector := "100011";
constant MI32_OP_LBU:		std_logic_vector := "100100";
constant MI32_OP_LHU:		std_logic_vector := "100101";
constant MI32_OP_LWR:		std_logic_vector := "100110";
constant MI32_OP_SB:		std_logic_vector := "101000";
constant MI32_OP_SH:		std_logic_vector := "101001";
constant MI32_OP_SWL:		std_logic_vector := "101010";
constant MI32_OP_SW:		std_logic_vector := "101011";
constant MI32_OP_SWR:		std_logic_vector := "101110";
constant MI32_OP_CACHE:		std_logic_vector := "101111";
constant MI32_OP_LL:		std_logic_vector := "110000";
constant MI32_OP_LWC1:		std_logic_vector := "110001";
constant MI32_OP_LWC2:		std_logic_vector := "110010";
constant MI32_OP_PREF:		std_logic_vector := "110011";
constant MI32_OP_LDC1:		std_logic_vector := "110101";
constant MI32_OP_LDC2:		std_logic_vector := "110110";
constant MI32_OP_SC:		std_logic_vector := "111000";
constant MI32_OP_SWC1:		std_logic_vector := "111001";
constant MI32_OP_SWC2:		std_logic_vector := "111010";
constant MI32_OP_SDC1:		std_logic_vector := "111101";
constant MI32_OP_SDC2:		std_logic_vector := "111110";

-- SPECIAL function codes
constant MI32_SPEC_SLL:		std_logic_vector := "000000";
constant MI32_SPEC_MOVCI:	std_logic_vector := "000001";
constant MI32_SPEC_SRL:		std_logic_vector := "000010";
constant MI32_SPEC_SRA:		std_logic_vector := "000011";
constant MI32_SPEC_SLLV:	std_logic_vector := "000100";
constant MI32_SPEC_SRLV:	std_logic_vector := "000110";
constant MI32_SPEC_SRAV:	std_logic_vector := "000111";
constant MI32_SPEC_JR:		std_logic_vector := "001000";
constant MI32_SPEC_JALR:	std_logic_vector := "001001";
constant MI32_SPEC_MOVZ:	std_logic_vector := "001010";
constant MI32_SPEC_MOVN:	std_logic_vector := "001011";
constant MI32_SPEC_SYSCALL:	std_logic_vector := "001100";
constant MI32_SPEC_BREAK:	std_logic_vector := "001101";
constant MI32_SPEC_SYNC:	std_logic_vector := "001111";
constant MI32_SPEC_MFHI:	std_logic_vector := "010000";
constant MI32_SPEC_MTHI:	std_logic_vector := "010001";
constant MI32_SPEC_MFLO:	std_logic_vector := "010010";
constant MI32_SPEC_MTLO:	std_logic_vector := "010011";
constant MI32_SPEC_MULT:	std_logic_vector := "011000";
constant MI32_SPEC_MULTU:	std_logic_vector := "011001";
constant MI32_SPEC_DIV:		std_logic_vector := "011010";
constant MI32_SPEC_DIVU:	std_logic_vector := "011011";
constant MI32_SPEC_ADD:		std_logic_vector := "100000";
constant MI32_SPEC_ADDU:	std_logic_vector := "100001";
constant MI32_SPEC_SUB:		std_logic_vector := "100010";
constant MI32_SPEC_SUBU:	std_logic_vector := "100011";
constant MI32_SPEC_AND:		std_logic_vector := "100100";
constant MI32_SPEC_OR:		std_logic_vector := "100101";
constant MI32_SPEC_XOR:		std_logic_vector := "100110";
constant MI32_SPEC_NOR:		std_logic_vector := "100111";
constant MI32_SPEC_SLT:		std_logic_vector := "101010";
constant MI32_SPEC_SLTU:	std_logic_vector := "101011";
constant MI32_SPEC_TGE:		std_logic_vector := "110000";
constant MI32_SPEC_TGEU:	std_logic_vector := "110001";
constant MI32_SPEC_TLT:		std_logic_vector := "110010";
constant MI32_SPEC_TLTU:	std_logic_vector := "110011";
constant MI32_SPEC_TEQ:		std_logic_vector := "110100";
constant MI32_SPEC_TNE:		std_logic_vector := "110110";

-- SPECIAL2 function codes
constant MI32_SPEC2_MADD:	std_logic_vector := "000000";
constant MI32_SPEC2_MADDU:	std_logic_vector := "000001";
constant MI32_SPEC2_MUL:	std_logic_vector := "000010";
constant MI32_SPEC2_MSUB:	std_logic_vector := "000100";
constant MI32_SPEC2_MSUBU:	std_logic_vector := "000101";
constant MI32_SPEC2_CLZ:	std_logic_vector := "100000";
constant MI32_SPEC2_CLO:	std_logic_vector := "100001";
constant MI32_SPEC2_DCLZ:	std_logic_vector := "100100";
constant MI32_SPEC2_DCLO:	std_logic_vector := "100101";
constant MI32_SPEC2_SDBBP:	std_logic_vector := "111111";

-- SPECIAL3 function codes
constant MI32_SPEC3_EXT:	std_logic_vector := "000000";
constant MI32_SPEC3_INS:	std_logic_vector := "000100";
constant MI32_SPEC3_BSHFL:	std_logic_vector := "100000";
constant MI32_SPEC3_RDHWR:	std_logic_vector := "111011";

-- COP0 function codes
constant MI32_COP0_MF:		std_logic_vector := "00000";
constant MI32_COP0_MT:		std_logic_vector := "00100";
constant MI32_COP0_MFMC0:	std_logic_vector := "01011";
constant MI32_COP0_CO_WAIT:	std_logic_vector := "100000";
constant MI32_COP0_CO_ERET:	std_logic_vector := "011000";

-- REGIMM function encoding
constant MI32_RIMM_BLTZ:	std_logic_vector := "00000";
constant MI32_RIMM_BGEZ:	std_logic_vector := "00001";
constant MI32_RIMM_BLTZL:	std_logic_vector := "00010";
constant MI32_RIMM_BGEZL:	std_logic_vector := "00011";
constant MI32_RIMM_TGEI:	std_logic_vector := "01000";
constant MI32_RIMM_TGEIU:	std_logic_vector := "01001";
constant MI32_RIMM_TLTI:	std_logic_vector := "01010";
constant MI32_RIMM_TLTIU:	std_logic_vector := "01011";
constant MI32_RIMM_TEQI:	std_logic_vector := "01100";
constant MI32_RIMM_TNEI:	std_logic_vector := "01110";
constant MI32_RIMM_BLTZAL:	std_logic_vector := "10000";
constant MI32_RIMM_BGEZAL:	std_logic_vector := "10001";
constant MI32_RIMM_BLTZALL:	std_logic_vector := "10010";
constant MI32_RIMM_BGEZALL:	std_logic_vector := "10011";
constant MI32_RIMM_SYNCI:	std_logic_vector := "11111";

-- Specialized registers: zero, exception slots, return address
constant MI32_REG_ZERO:		std_logic_vector := "00000";
constant MI32_REG_K0:		std_logic_vector := "11010";
constant MI32_REG_K1:		std_logic_vector := "11011";
constant MI32_REG_RA:		std_logic_vector := "11111";

-- COP0 registers
constant MI32_COP0_TLB_INDEX:	std_logic_vector := "00000";
constant MI32_COP0_TLB_RANDOM:	std_logic_vector := "00001";
constant MI32_COP0_TLB_L00:	std_logic_vector := "00010";
constant MI32_COP0_TLB_L01:	std_logic_vector := "00011";
constant MI32_COP0_TLB_CONTEXT:	std_logic_vector := "00100";
constant MI32_COP0_TLB_PG_MASK:	std_logic_vector := "00101";
constant MI32_COP0_TLB_WIRED:	std_logic_vector := "00110";
constant MI32_COP0_INFO:	std_logic_vector := "00111";
constant MI32_COP0_BAD_VADDR:	std_logic_vector := "01000";
constant MI32_COP0_COUNT:	std_logic_vector := "01001";
constant MI32_COP0_TLB_HI:	std_logic_vector := "01010";
constant MI32_COP0_COMPARE:	std_logic_vector := "01011";
constant MI32_COP0_STATUS:	std_logic_vector := "01100";
constant MI32_COP0_CAUSE:	std_logic_vector := "01101";
constant MI32_COP0_EXC_PC:	std_logic_vector := "01110";
constant MI32_COP0_PRID:	std_logic_vector := "01111"; -- Sel #0
constant MI32_COP0_EBASE:	std_logic_vector := "01111"; -- Sel #1
constant MI32_COP0_CONFIG:	std_logic_vector := "10000";
constant MI32_COP0_LLADDR:	std_logic_vector := "10001";
constant MI32_COP0_WATCH_LO:	std_logic_vector := "10010";
constant MI32_COP0_WATCH_HI:	std_logic_vector := "10011";
constant MI32_COP0_TLB_XCONTEXT: std_logic_vector := "10100";
constant MI32_COP0_RESERVED_21:	std_logic_vector := "10101";
constant MI32_COP0_RESERVED_22:	std_logic_vector := "10110";
constant MI32_COP0_DEBUG:	std_logic_vector := "10111";
constant MI32_COP0_DEPC:	std_logic_vector := "11000";
constant MI32_COP0_PERFCNT:	std_logic_vector := "11001";
constant MI32_COP0_ECC:		std_logic_vector := "11010";
constant MI32_COP0_CACHE_ERR:	std_logic_vector := "11011";
constant MI32_COP0_DATA_LO:	std_logic_vector := "11100";
constant MI32_COP0_DATA_HI:	std_logic_vector := "11101";
constant MI32_COP0_ERROR_PC:	std_logic_vector := "11110";
constant MI32_COP0_DESAVE:	std_logic_vector := "11111";

-- Test conditions (branch / trap)
constant MI32_TEST_LTZ:		std_logic_vector := "010";
constant MI32_TEST_GEZ:		std_logic_vector := "011";
constant MI32_TEST_EQ:		std_logic_vector := "100";
constant MI32_TEST_NE:		std_logic_vector := "101";
constant MI32_TEST_LEZ:		std_logic_vector := "110";
constant MI32_TEST_GTZ:		std_logic_vector := "111";

end;
