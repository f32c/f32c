--
-- Copyright (c) 2012 - 2016 Marko Zec, University of Zagreb
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
use work.mi32_pack.all;


entity idecode_mi32 is
    generic(
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_mul_acc: boolean;
	C_mul_reg: boolean;
	C_cache: boolean;
	C_ll_sc: boolean;
	C_movn_movz: boolean;
	C_exceptions: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle, branch_likely: out boolean;
	branch_offset: out std_logic_vector(31 downto 2);
	jump_cycle, jump_register: out boolean;
	reg1_zero, reg2_zero: out boolean;
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
	cmov_cycle, cmov_condition: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	mult, mult_signed, madd, mul_compound, mthi, mtlo: out boolean;
	ll, sc: out boolean;
	flush_i_line, flush_d_line: out std_logic;
	latency: out std_logic_vector(1 downto 0);
	seb_seh_cycle: out boolean;
	seb_seh_select: out std_logic;
	exception, di, ei: out boolean;
	cop0_write, cop0_wait: out boolean
    );  
end idecode_mi32;

architecture Behavioral of idecode_mi32 is
    signal unsupported_instr: boolean; -- currently unused
begin

    process(instruction)
	variable imm32_unsigned, imm32_signed: std_logic_vector(31 downto 0);
    begin
	-- Internal signals
	imm32_unsigned := x"0000" & instruction(15 downto 0);
	if instruction(15) = '1' then
	    imm32_signed := x"ffff" & instruction(15 downto 0);
	else
	    imm32_signed := x"0000" & instruction(15 downto 0);
	end if;

	-- Fixed decoding
	reg1_addr <= instruction(25 downto 21);
	reg2_addr <= instruction(20 downto 16);
	reg1_zero <= instruction(25 downto 21) = MI32_REG_ZERO;
	reg2_zero <= instruction(20 downto 16) = MI32_REG_ZERO;
	case instruction(1 downto 0) is
	when "00" => shift_fn <= OP_SHIFT_LL;
	when "01" => shift_fn <= OP_SHIFT_BYPASS;
	when "10" => shift_fn <= OP_SHIFT_RL;
	when others => shift_fn <= OP_SHIFT_RA;
	end case;
	if instruction(31) = '1' then
	    shift_fn <= OP_SHIFT_LL; -- memory store align
	end if;
	shift_variable <= instruction(2) = '1';
	shift_amount <= instruction(10 downto 6);
	branch_offset <= imm32_signed(29 downto 0);
	mem_cycle <= instruction(31);

	-- Default output values, overrided later
	unsupported_instr <= false;
	branch_cycle <= false;
	branch_likely <= instruction(30) = '1';
	jump_cycle <= false;
	jump_register <= false; -- should be don't care
	target_addr <= "-----";
	immediate_value <= imm32_signed;
	slt_signed <= false; -- should be don't care
	op_major <= OP_MAJOR_ALU;
	op_minor <= OP_MINOR_ADD;
	use_immediate <= instruction(30 downto 29) = "01" or
	  instruction(31) = '1';
	ignore_reg2 <= instruction(20 downto 16) = MI32_REG_ZERO;
	cmov_cycle <= false;
	cmov_condition <= false; -- should be don't care
	branch_condition <= (others => '-');
	mem_write <= '0';
	mem_size <= MEM_SIZE_UNDEFINED;
	mem_read_sign_extend <= '-';
	latency <= LATENCY_EX;
	seb_seh_cycle <= false;
	seb_seh_select <= instruction(9);
	alt_sel <= ALT_PC_RET;
	read_alt <= false;
	flush_i_line <= '0';
	flush_d_line <= '0';
	mult <= false;
	mult_signed <= false;
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
	case instruction(31 downto 26) is
	when MI32_OP_J =>
	    jump_cycle <= true;
	    target_addr <= MI32_REG_ZERO;
	    ignore_reg2 <= true;
	    read_alt <= true;
	when MI32_OP_JAL =>
	    jump_cycle <= true;
	    target_addr <= MI32_REG_RA;
	    ignore_reg2 <= true;
	    read_alt <= true;
	when MI32_OP_BEQ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= MI32_TEST_EQ;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_BNE =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= MI32_TEST_NE;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_BLEZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= MI32_TEST_LEZ;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_BGTZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= MI32_TEST_GTZ;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_ADDI =>
	    op_minor <= OP_MINOR_ADD;
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_ADDIU =>
	    op_minor <= OP_MINOR_ADD;
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_SLTI =>
	    op_major <= OP_MAJOR_SLT;
	    op_minor <= OP_MINOR_SUB;
	    use_immediate <= true;
	    slt_signed <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_SLTIU =>
	    op_major <= OP_MAJOR_SLT;
	    op_minor <= OP_MINOR_SUB;
	    use_immediate <= true;
	    slt_signed <= false;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_ANDI =>
	    op_minor <= OP_MINOR_AND;
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_ORI =>
	    op_minor <= OP_MINOR_OR;
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_XORI =>
	    op_minor <= OP_MINOR_XOR;
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_LUI =>
	    use_immediate <= true;
	    op_minor <= OP_MINOR_OR;
	    immediate_value <= instruction(15 downto 0) & x"0000";
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_COP0 =>
	    read_alt <= true;
	    alt_sel <= ALT_COP0;
	    target_addr <= instruction(20 downto 16);
	    if C_exceptions and instruction(25 downto 21) = MI32_COP0_MFMC0 then
		if instruction(5) = '1' then
		    ei <= true;
		else
		    di <= true;
		end if;
	    end if;
	    if C_exceptions and instruction(25 downto 21) = MI32_COP0_MT then
		target_addr <= MI32_REG_ZERO;
		cop0_write <= true;
	    end if;
	    if C_exceptions and instruction(25) = '1' and
		instruction(5 downto 0) = MI32_COP0_CO_WAIT then
		cop0_wait <= true;
	    end if;
	when MI32_OP_BEQL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= MI32_TEST_EQ;
		target_addr <= MI32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MI32_OP_BNEL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= MI32_TEST_NE;
		target_addr <= MI32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MI32_OP_BLEZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= MI32_TEST_LEZ;
		target_addr <= MI32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MI32_OP_BGTZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= MI32_TEST_GTZ;
		target_addr <= MI32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MI32_OP_LB =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_8;
	    mem_read_sign_extend <= '1';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_LH =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_16;
	    mem_read_sign_extend <= '1';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_LW =>
	    latency <= LATENCY_MEM;
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_LL =>
	    if C_ll_sc then
		latency <= LATENCY_MEM;
		mem_size <= MEM_SIZE_32;
		use_immediate <= true;
		target_addr <= instruction(20 downto 16);
		ignore_reg2 <= true;
		ll <= true;
	    else
		unsupported_instr <= true;
	    end if;
	when MI32_OP_LBU =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_8;
	    mem_read_sign_extend <= '0';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_LHU =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_16;
	    mem_read_sign_extend <= '0';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MI32_OP_SB =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_8;
	    use_immediate <= true;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_SH =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_16;
	    use_immediate <= true;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_SWL =>			-- XXX revisit!
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_SWR =>			-- XXX revisit!
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_SW =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MI32_REG_ZERO;
	when MI32_OP_SC =>
	    if C_ll_sc then
		latency <= LATENCY_MEM;
		mem_write <= '1';
		mem_size <= MEM_SIZE_32;
		use_immediate <= true;
		sc <= true;
		target_addr <= instruction(20 downto 16);
	    else
		unsupported_instr <= true;
	    end if;
	when MI32_OP_CACHE =>
	    target_addr <= MI32_REG_ZERO;
	    if C_cache then
		latency <= LATENCY_UNDEFINED;
		use_immediate <= true;
		flush_i_line <= not instruction(16);
		flush_d_line <= instruction(16);
	    else
		unsupported_instr <= true;
	    end if;
	when MI32_OP_REGIMM =>
	    target_addr <= MI32_REG_ZERO;
	    branch_cycle <= true;
	    read_alt <= true;
	    case instruction(20 downto 16) is
	    when MI32_RIMM_BLTZ =>
		branch_condition <= MI32_TEST_LTZ;
		branch_likely <= false;
	    when MI32_RIMM_BGEZ =>
		branch_condition <= MI32_TEST_GEZ;
		branch_likely <= false;
	    when MI32_RIMM_BLTZL =>
		branch_condition <= MI32_TEST_LTZ;
		branch_likely <= true;
	    when MI32_RIMM_BGEZL =>
		branch_condition <= MI32_TEST_GEZ;
		branch_likely <= true;
	    when MI32_RIMM_BLTZAL =>
		branch_condition <= MI32_TEST_LTZ;
		branch_likely <= false;
		target_addr <= MI32_REG_RA;
	    when MI32_RIMM_BGEZAL =>
		branch_condition <= MI32_TEST_GEZ;
		branch_likely <= false;
		target_addr <= MI32_REG_RA;
	    when MI32_RIMM_BLTZALL =>
		branch_condition <= MI32_TEST_LTZ;
		branch_likely <= true;
		target_addr <= MI32_REG_RA;
	    when MI32_RIMM_BGEZALL =>
		branch_condition <= MI32_TEST_GEZ;
		branch_likely <= true;
		target_addr <= MI32_REG_RA;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when MI32_OP_SPECIAL =>
	    target_addr <= instruction(15 downto 11);
	    case instruction(5 downto 0) is
	    when MI32_SPEC_SLL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_SRL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_SRA =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_SLLV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_SRLV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_SRAV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MI32_SPEC_JR =>
		jump_cycle <= true;
		jump_register <= true;
		read_alt <= true;
	    when MI32_SPEC_JALR =>
		jump_cycle <= true;
		jump_register <= true;
		read_alt <= true;
	    when MI32_SPEC_MOVZ =>
		if C_movn_movz then
		    cmov_cycle <= true;
		    cmov_condition <= true;
		    use_immediate <= true;
		    immediate_value <= x"00000000";
		    latency <= LATENCY_MEM;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MI32_SPEC_MOVN =>
		if C_movn_movz then
		    cmov_cycle <= true;
		    cmov_condition <= false;
		    use_immediate <= true;
		    immediate_value <= x"00000000";
		    latency <= LATENCY_MEM;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MI32_SPEC_SYSCALL =>
		if C_exceptions then
		    exception <= true;
		    target_addr <= MI32_REG_K0;
		end if;
	    when MI32_SPEC_BREAK =>
		if C_exceptions then
		    exception <= true;
		    target_addr <= MI32_REG_K0;
		end if;
	    when MI32_SPEC_MFHI =>
		read_alt <= true;
		alt_sel <= ALT_HI;
	    when MI32_SPEC_MFLO =>
		read_alt <= true;
		alt_sel <= ALT_LO;
	    when MI32_SPEC_MTHI =>
		if C_exceptions or C_mul_acc then
		    mult <= true;
		    mthi <= true;
		    mul_compound <= true;
		    alt_sel <= ALT_LO;
		end if;
	    when MI32_SPEC_MTLO =>
		if C_exceptions or C_mul_acc then
		    mult <= true;
		    mtlo <= true;
		    mul_compound <= true;
		    alt_sel <= ALT_LO;
		end if;
	    when MI32_SPEC_MULT =>
		op_major <= OP_MAJOR_ALT;
		mult <= true;
		mult_signed <= true;
	    when MI32_SPEC_MULTU =>
		op_major <= OP_MAJOR_ALT;
		mult <= true;
	    when MI32_SPEC_ADD =>
		op_minor <= OP_MINOR_ADD;
	    when MI32_SPEC_ADDU =>
		op_minor <= OP_MINOR_ADD;
	    when MI32_SPEC_SUB =>
		op_minor <= OP_MINOR_SUB;
	    when MI32_SPEC_SUBU =>
		op_minor <= OP_MINOR_SUB;
	    when MI32_SPEC_AND =>
		op_minor <= OP_MINOR_AND;
	    when MI32_SPEC_OR =>
		op_minor <= OP_MINOR_OR;
	    when MI32_SPEC_XOR =>
		op_minor <= OP_MINOR_XOR;
	    when MI32_SPEC_NOR =>
		op_minor <= OP_MINOR_NOR;
	    when MI32_SPEC_SLT =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		slt_signed <= true;
	    when MI32_SPEC_SLTU =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= OP_MINOR_SUB;
		slt_signed <= false;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when MI32_OP_SPECIAL2 =>
	    if C_mul_acc or C_mul_reg then
		target_addr <= instruction(15 downto 11);
		op_major <= OP_MAJOR_ALT;
		alt_sel <= ALT_LO;
		read_alt <= C_mul_reg;
		mult <= true;
	    end if;
	    case instruction(5 downto 0) is
	    when MI32_SPEC2_MADD =>
		if C_mul_acc then
		    madd <= true;
		    mult_signed <= true;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MI32_SPEC2_MADDU =>
		if C_mul_acc then
		    madd <= true;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MI32_SPEC2_MUL =>
		if C_mul_reg then
		    mult_signed <= true;
		    mul_compound <= true;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when MI32_OP_SPECIAL3 =>
	    target_addr <= instruction(15 downto 11);
	    op_minor <= OP_MINOR_XOR;
	    case instruction(5 downto 0) is
	    when MI32_SPEC3_BSHFL =>
		if C_sign_extend then
		    seb_seh_cycle <= true;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when others =>
	    latency <= LATENCY_UNDEFINED;
	    unsupported_instr <= true;
	end case;
    end process;

end Behavioral;
