
library ieee;
use ieee.std_logic_1164.all;

package f32c_pack is

-- Main MIPS32 / MIPS64 opcodes
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
constant MIPS64_OP_DADDI:	std_logic_vector := "011000";
constant MIPS64_OP_DADDIU:	std_logic_vector := "011001";
constant MIPS64_OP_LDL:		std_logic_vector := "011010";
constant MIPS64_OP_LDR:		std_logic_vector := "011011";
constant MIPS32_OP_SPECIAL2:	std_logic_vector := "011100";
constant MIPS32_OP_JALX:	std_logic_vector := "011101";
constant MIPS64_OP_MDMX:	std_logic_vector := "011110";
constant MIPS32_OP_SPECIAL3:	std_logic_vector := "011111";
constant MIPS32_OP_LB:		std_logic_vector := "100000";
constant MIPS32_OP_LH:		std_logic_vector := "100001";
constant MIPS32_OP_LWL:		std_logic_vector := "100010";
constant MIPS32_OP_LW:		std_logic_vector := "100011";
constant MIPS32_OP_LBU:		std_logic_vector := "100100";
constant MIPS32_OP_LHU:		std_logic_vector := "100101";
constant MIPS32_OP_LWR:		std_logic_vector := "100110";
constant MIPS64_OP_LWU:		std_logic_vector := "100111";
constant MIPS32_OP_SB:		std_logic_vector := "101000";
constant MIPS32_OP_SH:		std_logic_vector := "101001";
constant MIPS32_OP_SWL:		std_logic_vector := "101010";
constant MIPS32_OP_SW:		std_logic_vector := "101011";
constant MIPS64_OP_SDL:		std_logic_vector := "101100";
constant MIPS64_OP_SDR:		std_logic_vector := "101101";
constant MIPS32_OP_SWR:		std_logic_vector := "101110";
constant MIPS32_OP_CACHE:	std_logic_vector := "101111";
constant MIPS32_OP_LL:		std_logic_vector := "110000";
constant MIPS32_OP_LWC1:	std_logic_vector := "110001";
constant MIPS32_OP_LWC2:	std_logic_vector := "110010";
constant MIPS32_OP_PREF:	std_logic_vector := "110011";
constant MIPS64_OP_LLD:		std_logic_vector := "110100";
constant MIPS32_OP_LDC1:	std_logic_vector := "110101";
constant MIPS32_OP_LDC2:	std_logic_vector := "110110";
constant MIPS64_OP_LD:		std_logic_vector := "110111";
constant MIPS32_OP_SC:		std_logic_vector := "111000";
constant MIPS32_OP_SWC1:	std_logic_vector := "111001";
constant MIPS32_OP_SWC2:	std_logic_vector := "111010";
constant MIPS64_OP_SCD:		std_logic_vector := "111100";
constant MIPS32_OP_SDC1:	std_logic_vector := "111101";
constant MIPS32_OP_SDC2:	std_logic_vector := "111110";
constant MIPS64_OP_SD:		std_logic_vector := "111111";

-- SPECIAL function codes
constant MIPS32_SPEC_SLL:	std_logic_vector := "000000";
constant MIPS32_SPEC_MOVCI:	std_logic_vector := "000001";
constant MIPS32_SPEC_SRL:	std_logic_vector := "000010";
constant MIPS32_SPEC_SRA:	std_logic_vector := "000011";
constant MIPS32_SPEC_SLLV:	std_logic_vector := "000100";
constant MIPS32_SPEC_SRLV:	std_logic_vector := "000110";
constant MIPS32_SPEC_SRAV:	std_logic_vector := "000111";
constant MIPS32_SPEC_JR:	std_logic_vector := "001000";
constant MIPS32_SPEC_JALR:	std_logic_vector := "001001";
constant MIPS32_SPEC_MOVZ:	std_logic_vector := "001010";
constant MIPS32_SPEC_MOVN:	std_logic_vector := "001011";
constant MIPS32_SPEC_SYSCALL:	std_logic_vector := "001100";
constant MIPS32_SPEC_BREAK:	std_logic_vector := "001101";
constant MIPS32_SPEC_SYNC:	std_logic_vector := "001111";
constant MIPS32_SPEC_MFHI:	std_logic_vector := "010000";
constant MIPS32_SPEC_MTHI:	std_logic_vector := "010001";
constant MIPS32_SPEC_MFLO:	std_logic_vector := "010010";
constant MIPS32_SPEC_MTLO:	std_logic_vector := "010011";
constant MIPS64_SPEC_DSLLV:	std_logic_vector := "010100";
constant MIPS64_SPEC_DSRLV:	std_logic_vector := "010110";
constant MIPS64_SPEC_DSRAV:	std_logic_vector := "010111";
constant MIPS32_SPEC_MULT:	std_logic_vector := "011000";
constant MIPS32_SPEC_MULTU:	std_logic_vector := "011001";
constant MIPS32_SPEC_DIV:	std_logic_vector := "011010";
constant MIPS32_SPEC_DIVU:	std_logic_vector := "011011";
constant MIPS64_SPEC_DMULT:	std_logic_vector := "011100";
constant MIPS64_SPEC_DMULTU:	std_logic_vector := "011101";
constant MIPS64_SPEC_DDIV:	std_logic_vector := "011110";
constant MIPS64_SPEC_DDIVU:	std_logic_vector := "011111";
constant MIPS32_SPEC_ADD:	std_logic_vector := "100000";
constant MIPS32_SPEC_ADDU:	std_logic_vector := "100001";
constant MIPS32_SPEC_SUB:	std_logic_vector := "100010";
constant MIPS32_SPEC_SUBU:	std_logic_vector := "100011";
constant MIPS32_SPEC_AND:	std_logic_vector := "100100";
constant MIPS32_SPEC_OR:	std_logic_vector := "100101";
constant MIPS32_SPEC_XOR:	std_logic_vector := "100110";
constant MIPS32_SPEC_NOR:	std_logic_vector := "100111";
constant MIPS32_SPEC_SLT:	std_logic_vector := "101010";
constant MIPS32_SPEC_SLTU:	std_logic_vector := "101011";
constant MIPS64_SPEC_DADD:	std_logic_vector := "101100";
constant MIPS64_SPEC_DADDU:	std_logic_vector := "101101";
constant MIPS64_SPEC_DSUB:	std_logic_vector := "101110";
constant MIPS64_SPEC_DSUBU:	std_logic_vector := "101111";
constant MIPS32_SPEC_TGE:	std_logic_vector := "110000";
constant MIPS32_SPEC_TGEU:	std_logic_vector := "110001";
constant MIPS32_SPEC_TLT:	std_logic_vector := "110010";
constant MIPS32_SPEC_TLTU:	std_logic_vector := "110011";
constant MIPS32_SPEC_TEQ:	std_logic_vector := "110100";
constant MIPS32_SPEC_TNE:	std_logic_vector := "110110";
constant MIPS64_SPEC_DSLL:	std_logic_vector := "111000";
constant MIPS64_SPEC_DSRL:	std_logic_vector := "111010";
constant MIPS64_SPEC_DSRA:	std_logic_vector := "111011";
constant MIPS64_SPEC_DSLL32:	std_logic_vector := "111100";
constant MIPS64_SPEC_DSRL32:	std_logic_vector := "111110";
constant MIPS64_SPEC_DSRA32:	std_logic_vector := "111111";

-- SPECIAL2 function codes
constant MIPS32_SPEC2_MADD:	std_logic_vector := "000000";
constant MIPS32_SPEC2_MADDU:	std_logic_vector := "000001";
constant MIPS32_SPEC2_MUL:	std_logic_vector := "000010";
constant MIPS32_SPEC2_MSUB:	std_logic_vector := "000100";
constant MIPS32_SPEC2_MSUBU:	std_logic_vector := "000101";
constant MIPS32_SPEC2_CLZ:	std_logic_vector := "100000";
constant MIPS32_SPEC2_CLO:	std_logic_vector := "100001";
constant MIPS32_SPEC2_DCLZ:	std_logic_vector := "100100";
constant MIPS32_SPEC2_DCLO:	std_logic_vector := "100101";
constant MIPS32_SPEC2_SDBBP:	std_logic_vector := "111111";

-- SPECIAL3 function codes
constant MIPS32_SPEC3_EXT:	std_logic_vector := "000000";
constant MIPS64_SPEC3_DEXTM:	std_logic_vector := "000001";
constant MIPS64_SPEC3_DEXTU:	std_logic_vector := "000010";
constant MIPS64_SPEC3_DEXT:	std_logic_vector := "000011";
constant MIPS32_SPEC3_INS:	std_logic_vector := "000100";
constant MIPS64_SPEC3_DINSM:	std_logic_vector := "000101";
constant MIPS64_SPEC3_DINSU:	std_logic_vector := "000110";
constant MIPS64_SPEC3_DINS:	std_logic_vector := "000111";
constant MIPS32_SPEC3_BSHFL:	std_logic_vector := "100000";
constant MIPS64_SPEC3_DBSHFL:	std_logic_vector := "100100";
constant MIPS32_SPEC3_RDHWR:	std_logic_vector := "111011";

-- REGIMM function encoding
constant MIPS32_RIMM_BLTZ:	std_logic_vector := "00000";
constant MIPS32_RIMM_BGEZ:	std_logic_vector := "00001";
constant MIPS32_RIMM_BLTZL:	std_logic_vector := "00010";
constant MIPS32_RIMM_BGEZL:	std_logic_vector := "00011";
constant MIPS32_RIMM_TGEI:	std_logic_vector := "01000";
constant MIPS32_RIMM_TGEIU:	std_logic_vector := "01001";
constant MIPS32_RIMM_TLTI:	std_logic_vector := "01010";
constant MIPS32_RIMM_TLTIU:	std_logic_vector := "01011";
constant MIPS32_RIMM_TEQI:	std_logic_vector := "01100";
constant MIPS32_RIMM_TNEI:	std_logic_vector := "01110";
constant MIPS32_RIMM_BLTZAL:	std_logic_vector := "10000";
constant MIPS32_RIMM_BGEZAL:	std_logic_vector := "10001";
constant MIPS32_RIMM_BLTZALL:	std_logic_vector := "10010";
constant MIPS32_RIMM_BGEZALL:	std_logic_vector := "10011";
constant MIPS32_RIMM_SYNCI:	std_logic_vector := "11111";

-- Specialized registers: zero and return address
constant MIPS32_REG_ZERO:	std_logic_vector := "00000";
constant MIPS32_REG_RA:		std_logic_vector := "11111";

-- COP0 registers
constant MIPS_COP0_TLB_INDEX:	std_logic_vector := "00000";
constant MIPS_COP0_TLB_RANDOM:	std_logic_vector := "00001";
constant MIPS_COP0_TLB_L00:	std_logic_vector := "00010";
constant MIPS_COP0_TLB_L01:	std_logic_vector := "00011";
constant MIPS_COP0_TLB_CONTEXT:	std_logic_vector := "00100";
constant MIPS_COP0_TLB_PG_MASK:	std_logic_vector := "00101";
constant MIPS_COP0_TLB_WIRED:	std_logic_vector := "00110";
constant MIPS_COP0_INFO:	std_logic_vector := "00111";
constant MIPS_COP0_BAD_VADDR:	std_logic_vector := "01000";
constant MIPS_COP0_COUNT:	std_logic_vector := "01001";
constant MIPS_COP0_TLB_HI:	std_logic_vector := "01010";
constant MIPS_COP0_COMPARE:	std_logic_vector := "01011";
constant MIPS_COP0_STATUS:	std_logic_vector := "01100";
constant MIPS_COP0_CAUSE:	std_logic_vector := "01101";
constant MIPS_COP0_EXC_PC:	std_logic_vector := "01110";
constant MIPS_COP0_PRID:	std_logic_vector := "01111";
constant MIPS_COP0_CONFIG:	std_logic_vector := "10000";
constant MIPS_COP0_LLADDR:	std_logic_vector := "10001";
constant MIPS_COP0_WATCH_LO:	std_logic_vector := "10010";
constant MIPS_COP0_WATCH_HI:	std_logic_vector := "10011";
constant MIPS_COP0_TLB_XCONTEXT: std_logic_vector := "10100";
constant MIPS_COP0_RESERVED_21:	std_logic_vector := "10101";
constant MIPS_COP0_RESERVED_22:	std_logic_vector := "10110";
constant MIPS_COP0_DEBUG:	std_logic_vector := "10111";
constant MIPS_COP0_DEPC:	std_logic_vector := "11000";
constant MIPS_COP0_PERFCNT:	std_logic_vector := "11001";
constant MIPS_COP0_ECC:		std_logic_vector := "11010";
constant MIPS_COP0_CACHE_ERR:	std_logic_vector := "11011";
constant MIPS_COP0_DATA_LO:	std_logic_vector := "11100";
constant MIPS_COP0_DATA_HI:	std_logic_vector := "11101";
constant MIPS_COP0_ERROR_PC:	std_logic_vector := "11110";
constant MIPS_COP0_DESAVE:	std_logic_vector := "11111";

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

-- Test conditions (branch / trap)
constant TEST_UNDEFINED:	std_logic_vector := "---";
constant TEST_EQ:		std_logic_vector := "100";
constant TEST_NE:		std_logic_vector := "101";
constant TEST_LEZ:		std_logic_vector := "110";
constant TEST_GTZ:		std_logic_vector := "111";
constant TEST_LTZ:		std_logic_vector := "010";
constant TEST_GEZ:		std_logic_vector := "011";

-- Branch predictor saturation counter values
constant BP_STRONG_TAKEN:	std_logic_vector := "11";
constant BP_WEAK_TAKEN:		std_logic_vector := "10";
constant BP_WEAK_NOT_TAKEN:	std_logic_vector := "01";
constant BP_STRONG_NOT_TAKEN:	std_logic_vector := "00";

constant OP_MAJOR_ALU:		std_logic_vector := "00";
constant OP_MAJOR_SLT:		std_logic_vector := "01";
constant OP_MAJOR_SHIFT:	std_logic_vector := "10";
constant OP_MAJOR_ALT:		std_logic_vector := "11";

constant ALT_HI:		std_logic_vector := "000";
constant ALT_LO:		std_logic_vector := "001";
constant ALT_PC_8:		std_logic_vector := "010";
constant ALT_COP0:		std_logic_vector := "011";


--
-- SRAM port type
--
type sram_port_type is
    record
	addr: std_logic_vector(19 downto 2);
	data_in: std_logic_vector(31 downto 0);
	byte_sel: std_logic_vector(3 downto 0);
	addr_strobe: std_logic;
	write: std_logic;
    end record;

type sram_port_array is array(integer range <>) of sram_port_type;
type sram_ready_array is array(integer range <>) of std_logic;

end;
