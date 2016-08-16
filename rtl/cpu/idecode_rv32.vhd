--
-- Copyright (c) 2014, 2016 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
use work.rv32_pack.all;


entity idecode_rv32 is
    generic(
	C_cache: boolean;
	C_mul_reg: boolean;
	C_ll_sc: boolean;
	C_exceptions: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle: out boolean;
	branch_offset: out std_logic_vector(31 downto 2);
	jump_register: out boolean;
	reg1_zero, reg2_zero, reg1_pc: out boolean;
	reg1_addr, reg2_addr, target_addr: out std_logic_vector(4 downto 0);
	immediate_value: out std_logic_vector(31 downto 0);
	slt_signed: out boolean;
	op_major: out std_logic_vector(1 downto 0);
	op_minor: out std_logic_vector(2 downto 0);
	alt_sel: out std_logic_vector(2 downto 0);
	shift_fn: out std_logic_vector(1 downto 0);
	shift_variable: out boolean;
	shift_amount: out std_logic_vector(4 downto 0);
	read_alt: out boolean;
	use_immediate, ignore_reg2: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	mult, mult_signed, madd, mul_compound, mthi, mtlo: out boolean;
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
	variable imm32_i: std_logic_vector(31 downto 0);
	variable imm32_s: std_logic_vector(31 downto 0);
	variable imm32_sb: std_logic_vector(31 downto 0);
	variable imm32_u: std_logic_vector(31 downto 0);
	variable imm32_uj: std_logic_vector(31 downto 0);
    begin
	-- Fixed decoding
	case instruction(13 downto 12) is
	when RV32_MEM_SIZE_B => mem_size <= MEM_SIZE_8;
	when RV32_MEM_SIZE_H => mem_size <= MEM_SIZE_16;
	when RV32_MEM_SIZE_W => mem_size <= MEM_SIZE_32;
	when others => mem_size <= MEM_SIZE_64;
	end case;
	shift_amount <= instruction(24 downto 20);

	-- Extract and sign extend immediate values
	imm32_u := instruction(31 downto 12) & x"000";
	if instruction(31) = '1' then
	    imm32_i := x"fffff" & instruction(31 downto 20);
	    imm32_s := x"fffff" & instruction(31 downto 25) &
	      instruction(11 downto 7);
	    imm32_sb := x"fffff" & instruction(7) & instruction(30 downto 25) &
	      instruction(11 downto 8) & '0';
	    imm32_uj := x"fff" & instruction(19 downto 12) & instruction(20) &
	      instruction(30 downto 21) & '0';
	else
	    imm32_i := x"00000" & instruction(31 downto 20);
	    imm32_s := x"00000" & instruction(31 downto 25) &
	      instruction(11 downto 7);
	    imm32_sb := x"00000" & instruction(7) & instruction(30 downto 25) &
	      instruction(11 downto 8) & '0';
	    imm32_uj := x"000" & instruction(19 downto 12) & instruction(20) &
	      instruction(30 downto 21) & '0';
	end if;

	-- Default output values, overrided later
	reg1_addr <= instruction(19 downto 15);
	reg2_addr <= instruction(24 downto 20);
	reg1_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
	reg2_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
	ignore_reg2 <= instruction(24 downto 20) = RV32_REG_ZERO;
	reg1_pc <= false;
	unsupported_instr <= false;
	branch_cycle <= false;
	jump_register <= false;
	target_addr <= instruction(11 downto 7);
	shift_variable <= false;
	shift_fn <= OP_SHIFT_LL; -- memory store align
	immediate_value <= (others => '-');
	slt_signed <= false;
	op_major <= OP_MAJOR_ALU;
	op_minor <= OP_MINOR_ADD;
	use_immediate <= false; -- should be dont' care
	branch_condition <= (others => '-');
	branch_offset <= (others => '-');
	mem_cycle <= '0';
	mem_write <= '0';
	mem_read_sign_extend <= '-';
	latency <= LATENCY_EX;
	alt_sel <= ALT_PC_RET;
	read_alt <= false;
	flush_i_line <= '0';
	flush_d_line <= '0';
	mult <= false;
	mult_signed <= true;
	madd <= false;
	mul_compound <= false;
	mthi <= false;
	mtlo <= false;
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
	    immediate_value <= imm32_u;
	    reg1_addr <= RV32_REG_ZERO;
	    reg1_zero <= true;
	    ignore_reg2 <= true;
	when RV32I_OP_AUIPC =>
	    use_immediate <= true;
	    immediate_value <= imm32_u;
	    reg1_addr <= RV32_REG_ZERO;
	    reg1_zero <= true;
	    reg1_pc <= true;
	    ignore_reg2 <= true;
	when RV32I_OP_JAL =>
	    ignore_reg2 <= true;
	    branch_cycle <= true;
	    branch_offset <= imm32_uj(31 downto 2);
	    branch_condition <= RV32_TEST_ALWAYS;
	    read_alt <= true;
	when RV32I_OP_JALR =>
	    use_immediate <= true;
	    ignore_reg2 <= true;
	    branch_cycle <= true;
	    jump_register <= true;
	    immediate_value <= imm32_i;
	    branch_condition <= RV32_TEST_ALWAYS;
	    read_alt <= true;
	when RV32I_OP_BRANCH =>
	    branch_cycle <= true;
	    branch_offset <= imm32_sb(31 downto 2);
	    branch_condition <= instruction(14 downto 12);
	    target_addr <= RV32_REG_ZERO;
	    op_minor <= OP_MINOR_SUB;
	when RV32I_OP_LOAD =>
	    use_immediate <= true;
	    latency <= LATENCY_WB;
	    ignore_reg2 <= true;
	    mem_cycle <= '1';
	    mem_read_sign_extend <= not instruction(14);
	    immediate_value <= imm32_i;
	when RV32I_OP_STORE =>
	    use_immediate <= true;
	    immediate_value <= imm32_s;
	    target_addr <= RV32_REG_ZERO;
	    mem_cycle <= '1';
	    mem_write <= '1';
	    immediate_value <= imm32_s;
	when RV32I_OP_REG_IMM =>
	    use_immediate <= true;
	    immediate_value <= imm32_i;
	    ignore_reg2 <= true;
	    case instruction(14 downto 12) is
	    when RV32_FN3_ADD =>
		op_major <= OP_MAJOR_ALU;
		op_minor <= OP_MINOR_ADD;
	    when RV32_FN3_SLT =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		slt_signed <= true;
	    when RV32_FN3_SLTU =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		slt_signed <= false;
	    when RV32_FN3_XOR =>
		op_minor <= OP_MINOR_XOR;
	    when RV32_FN3_OR =>
		op_minor <= OP_MINOR_OR;
	    when RV32_FN3_AND =>
		op_minor <= OP_MINOR_AND;
	    when RV32_FN3_SL =>
		reg1_addr <= instruction(24 downto 20);
		reg2_addr <= instruction(19 downto 15);
		reg1_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
		reg2_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
		ignore_reg2 <= instruction(19 downto 15) = RV32_REG_ZERO;
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		shift_fn <= OP_SHIFT_LL;
	    when RV32_FN3_SR =>
		reg1_addr <= instruction(24 downto 20);
		reg2_addr <= instruction(19 downto 15);
		reg1_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
		reg2_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
		ignore_reg2 <= instruction(19 downto 15) = RV32_REG_ZERO;
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
		if instruction(30) = '1' then
		    shift_fn <= OP_SHIFT_RA;
		else
		    shift_fn <= OP_SHIFT_RL;
		end if;
	    when others =>
		-- nothing to do here, just appease ISE warnings
	    end case;
	when RV32I_OP_REG_REG =>
	    use_immediate <= false;
	    if instruction(25) = '0' then
		case instruction(14 downto 12) is
		when RV32_FN3_ADD =>
		    if instruction(30) = '0' then
			op_minor <= OP_MINOR_ADD;
		    else
			op_minor <= OP_MINOR_SUB;
		    end if;
		when RV32_FN3_SLT =>
		    op_major <= OP_MAJOR_SLT;
		    op_minor <= OP_MINOR_SUB;
		    slt_signed <= true;
		when RV32_FN3_SLTU =>
		    op_major <= OP_MAJOR_SLT;
		    op_minor <= OP_MINOR_SUB;
		    slt_signed <= false;
		when RV32_FN3_XOR =>
		    op_minor <= OP_MINOR_XOR;
		when RV32_FN3_OR =>
		    op_minor <= OP_MINOR_OR;
		when RV32_FN3_AND =>
		    op_minor <= OP_MINOR_AND;
		when RV32_FN3_SL =>
		    reg1_addr <= instruction(24 downto 20);
		    reg2_addr <= instruction(19 downto 15);
		    reg1_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
		    reg2_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
		    ignore_reg2 <= instruction(19 downto 15) = RV32_REG_ZERO;
		    op_major <= OP_MAJOR_SHIFT;
		    latency <= LATENCY_MEM;
		    shift_fn <= OP_SHIFT_LL;
		    shift_variable <= true;
		when RV32_FN3_SR =>
		    reg1_addr <= instruction(24 downto 20);
		    reg2_addr <= instruction(19 downto 15);
		    reg1_zero <= instruction(24 downto 20) = RV32_REG_ZERO;
		    reg2_zero <= instruction(19 downto 15) = RV32_REG_ZERO;
		    ignore_reg2 <= instruction(19 downto 15) = RV32_REG_ZERO;
		    op_major <= OP_MAJOR_SHIFT;
		    latency <= LATENCY_MEM;
		    shift_variable <= true;
		    if instruction(30) = '1' then
			shift_fn <= OP_SHIFT_RA;
		    else
			shift_fn <= OP_SHIFT_RL;
		    end if;
		when others =>
		    -- nothing to do here, just appease ISE warnings
		end case;
	    elsif C_mul_reg then
		mult <= true;
		mul_compound <= true;
		op_major <= OP_MAJOR_ALT;
		alt_sel <= ALT_LO;
		read_alt <= C_mul_reg;
	    end if;
	when RV32I_OP_SYS =>
	    read_alt <= true;
	    alt_sel <= ALT_COP0;
	when others =>
	end case;
    end process;
end Behavioral;
