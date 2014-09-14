--
-- Copyright 2014 Marko Zec, University of Zagreb.
--
-- Neither this file nor any parts of it may be used unless an explicit 
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id$

library ieee;
use ieee.std_logic_1164.all;

package rv32_pack is

-- RV32I Base Instruction Set Opcodes
constant RV32I_OP_LUI:		std_logic_vector := "0110111";
constant RV32I_OP_AUIPC:	std_logic_vector := "0010111";
constant RV32I_OP_JAL:		std_logic_vector := "1101111";
constant RV32I_OP_JALR:		std_logic_vector := "1100111";
constant RV32I_OP_BRANCH:	std_logic_vector := "1100011";
constant RV32I_OP_LOAD:		std_logic_vector := "0000011";
constant RV32I_OP_STORE:	std_logic_vector := "0100011";
constant RV32I_OP_REG_IMM:	std_logic_vector := "0010011";
constant RV32I_OP_REG_REG:	std_logic_vector := "0110011";
constant RV32I_OP_FENCE:	std_logic_vector := "0001111";
constant RV32I_OP_SYS:		std_logic_vector := "1110011";

-- RV64I Base Instruction Set Opcodes
constant RV64I_OP_REG_IMM:	std_logic_vector := "0011011";
constant RV64I_OP_REG_REG:	std_logic_vector := "0111011";

-- funct3 codes
constant RV32_FN3_ADD:		std_logic_vector := "000";
constant RV32_FN3_SL:		std_logic_vector := "001";
constant RV32_FN3_SLT:		std_logic_vector := "010";
constant RV32_FN3_SLTU:		std_logic_vector := "011";
constant RV32_FN3_XOR:		std_logic_vector := "100";
constant RV32_FN3_SR:		std_logic_vector := "101";
constant RV32_FN3_OR:		std_logic_vector := "110";
constant RV32_FN3_AND:		std_logic_vector := "111";

-- Specialized registers: zero, exception slots, return address
constant RV32_REG_ZERO:		std_logic_vector := "00000";
constant RV32_REG_RA:		std_logic_vector := "00001";

-- Branch conditions
constant RV32_COND_EQ:		std_logic_vector := "000";
constant RV32_COND_NE:		std_logic_vector := "001";
constant RV32_COND_LT:		std_logic_vector := "100";
constant RV32_COND_GE:		std_logic_vector := "101";
constant RV32_COND_LTU:		std_logic_vector := "110";
constant RV32_COND_GEU:		std_logic_vector := "111";

-- Memory access width
constant RV32_MEM_SIZE_B:	std_logic_vector := "00";
constant RV32_MEM_SIZE_H:	std_logic_vector := "01";
constant RV32_MEM_SIZE_W:	std_logic_vector := "10";
constant RV32_MEM_SIZE_D:	std_logic_vector := "11";

end;
