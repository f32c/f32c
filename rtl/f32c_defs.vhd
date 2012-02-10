
library ieee;
use ieee.std_logic_1164.all;

package f32c_pack is

constant MIPS_REG_ZERO:		std_logic_vector := "00000";
constant MIPS_REG_RA:		std_logic_vector := "11111";

constant MIPS32_OP_SPECIAL:	std_logic_vector := "000000";
constant MIPS32_OP_REGIMM:	std_logic_vector := "000001";
constant MIPS32_OP_J:		std_logic_vector := "000010";
constant MIPS32_OP_JAL:		std_logic_vector := "000011";
constant MIPS32_OP_BEQ:		std_logic_vector := "000100";
constant MIPS32_OP_BNE:		std_logic_vector := "000101";
constant MIPS32_OP_BLEZ:	std_logic_vector := "000110";
constant MIPS32_OP_BGTZ:	std_logic_vector := "000111";
constant MIPS32_OP_ADDI:	std_logic_vector := "001000";
constant MIPS32_OP_ADDIU:	std_logic_vector := "001001";
constant MIPS32_OP_SLTI:	std_logic_vector := "001010";
constant MIPS32_OP_SLTIU:	std_logic_vector := "001011";
constant MIPS32_OP_ANDI:	std_logic_vector := "001100";
constant MIPS32_OP_ORI:		std_logic_vector := "001101";
constant MIPS32_OP_XORI:	std_logic_vector := "001110";
constant MIPS32_OP_LUI:		std_logic_vector := "001111";
constant MIPS32_OP_COP0:	std_logic_vector := "010000";
constant MIPS32_OP_COP1:	std_logic_vector := "010001";
constant MIPS32_OP_COP2:	std_logic_vector := "010010";
constant MIPS32_OP_COP1X:	std_logic_vector := "010011";
constant MIPS32_OP_BEQL:	std_logic_vector := "010100";
constant MIPS32_OP_BNEL:	std_logic_vector := "010101";
constant MIPS32_OP_BLEZL:	std_logic_vector := "010110";
constant MIPS32_OP_BGTZL:	std_logic_vector := "010111";
constant MIPS32_OP_SPECIAL2:	std_logic_vector := "011100";
constant MIPS32_OP_SPECIAL3:	std_logic_vector := "011111";
constant MIPS32_OP_LB:		std_logic_vector := "100000";
constant MIPS32_OP_LH:		std_logic_vector := "100001";
constant MIPS32_OP_LWL:		std_logic_vector := "100010";
constant MIPS32_OP_LW:		std_logic_vector := "100011";
constant MIPS32_OP_LBU:		std_logic_vector := "100100";
constant MIPS32_OP_LHU:		std_logic_vector := "100101";
constant MIPS32_OP_LWR:		std_logic_vector := "100110";
constant MIPS32_OP_CACHE:	std_logic_vector := "100111";
constant MIPS32_OP_SB:		std_logic_vector := "101000";
constant MIPS32_OP_SH:		std_logic_vector := "101001";
constant MIPS32_OP_SWL:		std_logic_vector := "101010";
constant MIPS32_OP_SW:		std_logic_vector := "101011";
constant MIPS32_OP_SWR:		std_logic_vector := "101110";

constant MIPS32_ALL_MEM:	std_logic_vector := "10----";
constant MIPS32_ALL_LOAD:	std_logic_vector := "100---";
constant MIPS32_ALL_STORE:	std_logic_vector := "101---";

end;
