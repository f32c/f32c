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
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
use work.rv32_pack.all;


entity idecode_rv32 is
    generic(
	C_cache: boolean;
	C_ll_sc: boolean;
	C_exceptions: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle: out boolean;
	jump_register: out boolean;
	reg1_zero, reg2_zero: out boolean;
	reg1_addr, reg2_addr, target_addr: out std_logic_vector(4 downto 0);
	immediate_value: out std_logic_vector(31 downto 0);
	sign_extension: out std_logic_vector(15 downto 0);
	sign_extend: out boolean; -- for SLT / SLTU
	op_major: out std_logic_vector(1 downto 0);
	op_minor: out std_logic_vector(2 downto 0);
	alt_sel: out std_logic_vector(2 downto 0);
	read_alt: out boolean;
	use_immediate, ignore_reg2: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	ll, sc: out boolean;
	flush_i_line, flush_d_line: out std_logic;
	latency: out std_logic_vector(1 downto 0);
	exception, di, ei: out boolean;
	cop0_write, cop0_wait: out boolean
    );  
end idecode_rv32;

architecture Behavioral of idecode_rv32 is
    signal unsupported_instr: boolean; -- currently unused
begin

    process(instruction)
	variable imm32_unsigned, imm32_signed: std_logic_vector(31 downto 0);
    begin
	-- Fixed decoding
	reg1_addr <= instruction(19 downto 15);
	reg2_addr <= instruction(24 downto 20);

	-- Default output values, overrided later
	unsupported_instr <= false;
	branch_cycle <= false;
	jump_register <= false;
	reg1_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
	reg2_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
	target_addr <= instruction(11 downto 7);
	immediate_value <= imm32_signed;
	sign_extend <= true;
	op_major <= OP_MAJOR_ALU;
	op_minor <= OP_MINOR_ADD;
	use_immediate <= false; -- should be dont' care
	ignore_reg2 <= instruction(24 downto 20) = RV32_REG_ZERO;
	branch_condition <= TEST_UNDEFINED;
	mem_cycle <= '0';
	mem_write <= '0';
	mem_size <= MEM_SIZE_UNDEFINED;
	mem_read_sign_extend <= '-';
	latency <= LATENCY_EX;
	alt_sel <= ALT_PC_8;
	read_alt <= false;
	flush_i_line <= '0';
	flush_d_line <= '0';
	ll <= false;
	sc <= false;
	exception <= false;
	di <= false;
	ei <= false;
	cop0_write <= false;
	cop0_wait <= false;
	
    end process;

end Behavioral;
