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
	shift_fn: out std_logic_vector(1 downto 0);
	read_alt: out boolean;
	use_immediate, ignore_reg2: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	mult, mult_signed: out boolean;
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
	variable imm32_signed: std_logic_vector(31 downto 0);
    begin
	-- Fixed decoding
	reg1_addr <= instruction(19 downto 15);
	reg2_addr <= instruction(24 downto 20);
	case instruction(13 downto 12) is
	when RV32_MEM_SIZE_B => mem_size <= MEM_SIZE_8;
	when RV32_MEM_SIZE_H => mem_size <= MEM_SIZE_16;
	when RV32_MEM_SIZE_W => mem_size <= MEM_SIZE_32;
	when others => mem_size <= MEM_SIZE_64;
	end case;

	-- Internal signals
	if instruction(31) = '1' then
	    imm32_signed := x"fffff" & instruction(31 downto 20);
	else
	    imm32_signed := x"00000" & instruction(31 downto 20);
	end if;

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
	mem_read_sign_extend <= '-';
	latency <= LATENCY_EX;
	alt_sel <= ALT_PC_8;
	read_alt <= false;
	flush_i_line <= '0';
	flush_d_line <= '0';
	mult <= false;
	mult_signed <= false;
	ll <= false;
	sc <= false;
	exception <= false;
	di <= false;
	ei <= false;
	cop0_write <= false;
	cop0_wait <= false;
	
	-- Main instruction decoder
	case instruction(6 downto 0) is
	when RV32I_OP_LUI =>
	    use_immediate <= true;
	    immediate_value <= instruction(31 downto 12) & x"000";
	    op_minor <= OP_MINOR_OR;
	    ignore_reg2 <= true;
	when RV32I_OP_AUIPC =>
	    use_immediate <= true;
	    immediate_value <= instruction(31 downto 12) & x"000";
	    op_minor <= OP_MINOR_ADD;
	    ignore_reg2 <= true;
	when RV32I_OP_JAL =>
	    use_immediate <= true;
	    ignore_reg2 <= true;
	    -- XXX immediate_value <= XXX?
	when RV32I_OP_JALR =>
	    use_immediate <= true;
	    ignore_reg2 <= true;
	    jump_register <= true;
	when RV32I_OP_BRANCH =>
	    branch_cycle <= true;
	    target_addr <= RV32_REG_ZERO;
	when RV32I_OP_LOAD =>
	    use_immediate <= true;
	    latency <= LATENCY_WB;
	    ignore_reg2 <= true;
	    mem_cycle <= '1';
	    mem_read_sign_extend <= not instruction(14);
	when RV32I_OP_STORE =>
	    use_immediate <= true;
	    immediate_value(4 downto 0) <= instruction(11 downto 7);
	    target_addr <= RV32_REG_ZERO;
	    mem_cycle <= '1';
	    mem_write <= '1';
	when RV32I_OP_REG_IMM =>
	    use_immediate <= true;
	    ignore_reg2 <= true;
	    case instruction(14 downto 12) is
	    when RV32_FN3_ADD =>
		-- implicit OP_MAJOR_ALU, OP_MINOR_ADD;
	    when RV32_FN3_SL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		-- XXX incomplete
	    when RV32_FN3_SLT =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		sign_extend <= true;
	    when RV32_FN3_SLTU =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		sign_extend <= false;
	    when RV32_FN3_XOR =>
		op_minor <= OP_MINOR_XOR;
	    when RV32_FN3_SR =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		-- XXX incomplete
	    when RV32_FN3_OR =>
		op_minor <= OP_MINOR_OR;
	    when RV32_FN3_AND =>
		op_minor <= OP_MINOR_AND;
	    when others =>
		-- nothing to do here, just appease ISE warnings
	    end case;
	when RV32I_OP_REG_REG =>
	    use_immediate <= false;
	    case instruction(14 downto 12) is
	    when RV32_FN3_ADD =>
		if instruction(30) = '0' then
		    op_minor <= OP_MINOR_ADD;
		else
		    op_minor <= OP_MINOR_SUB;
		end if;
	    when RV32_FN3_SL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		-- XXX incomplete
	    when RV32_FN3_SLT =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		sign_extend <= true;
	    when RV32_FN3_SLTU =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		sign_extend <= false;
	    when RV32_FN3_XOR =>
		op_minor <= OP_MINOR_XOR;
	    when RV32_FN3_SR =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		-- XXX incomplete
	    when RV32_FN3_OR =>
		op_minor <= OP_MINOR_OR;
	    when RV32_FN3_AND =>
		op_minor <= OP_MINOR_AND;
	    when others =>
		-- nothing to do here, just appease ISE warnings
	    end case;
	when others =>
	end case;
    end process;
end Behavioral;
