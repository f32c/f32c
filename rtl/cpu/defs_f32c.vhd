--
-- Copyright 2013, 2014 Marko Zec, University of Zagreb.
--
-- Neither this file nor any parts of it may be used unless an explicit 
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id$

library ieee;
use ieee.std_logic_1164.all;

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

-- ALT mux select
constant ALT_HI:		std_logic_vector := "000";
constant ALT_LO:		std_logic_vector := "001";
constant ALT_PC_8:		std_logic_vector := "010";
constant ALT_COP0:		std_logic_vector := "011";

end;
