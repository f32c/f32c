--
-- Copyright 2012 University of Zagreb.
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
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


entity idecode is
    generic(
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_movn_movz: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle, branch_likely: out boolean;
	jump_cycle, jump_register: out boolean;
	reg1_zero, reg2_zero: out boolean;
	reg1_addr, reg2_addr, target_addr: out std_logic_vector(4 downto 0);
	immediate_value: out std_logic_vector(31 downto 0);
	sign_extension: out std_logic_vector(15 downto 0);
	sign_extend: out boolean; -- for SLT / SLTU
	op_major: out std_logic_vector(1 downto 0);
	op_minor: out std_logic_vector(2 downto 0);
	use_immediate, ignore_reg2: out boolean;
	cmov_cycle, cmov_condition: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	latency: out std_logic_vector(1 downto 0);
	seb_seh_cycle: out boolean;
	seb_seh_select: out std_logic
    );  
end idecode;

architecture Behavioral of idecode is
    signal unsupported_instr: boolean; -- currently unused
begin

    process(instruction)
	variable imm32_unsigned, imm32_signed: std_logic_vector(31 downto 0);
    begin
	-- Fixed decoding
	reg1_addr <= instruction(25 downto 21);
	reg2_addr <= instruction(20 downto 16);

	-- Internal signals
	imm32_unsigned := x"0000" & instruction(15 downto 0);
	if instruction(15) = '1' then
	    imm32_signed := x"ffff" & instruction(15 downto 0);
	    sign_extension <= x"ffff";
	else
	    imm32_signed := x"0000" & instruction(15 downto 0);
	    sign_extension <= x"0000";
	end if;

	-- Default output values, overrided later
	unsupported_instr <= false;
	branch_cycle <= false;
	branch_likely <= false; -- should be don't care
	jump_cycle <= false;
	jump_register <= false; -- should be don't care
	reg1_zero <= instruction(25 downto 21) = MIPS32_REG_ZERO;
	reg2_zero <= instruction(20 downto 16) = MIPS32_REG_ZERO;
	target_addr <= "-----";
	immediate_value <= imm32_signed;
	sign_extend <= false; -- should be don't care
	op_major <= "00";
	op_minor <= "000"; -- should be ADD
	use_immediate <= false; -- should be dont' care
	ignore_reg2 <= instruction(20 downto 16) = MIPS32_REG_ZERO;
	cmov_cycle <= false;
	cmov_condition <= false; -- should be don't care
	branch_condition <= "---";
	mem_cycle <= instruction(31);
	mem_write <= instruction(29);
	mem_size <= instruction(27 downto 26);
	mem_read_sign_extend <= not instruction(27);
	latency <= "00";
	seb_seh_cycle <= false;
	seb_seh_select <= '-';
	
	-- Main instruction decoder
	case instruction(31 downto 26) is
	when MIPS32_OP_J =>
	    jump_cycle <= true;
	    target_addr <= MIPS32_REG_ZERO;
	    ignore_reg2 <= true;
	when MIPS32_OP_JAL =>
	    jump_cycle <= true;
	    target_addr <= MIPS32_REG_RA;
	    ignore_reg2 <= true;
	when MIPS32_OP_BEQ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= "100";
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BNE =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= "101";
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BLEZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= "110";
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BGTZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= "111";
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_ADDI =>
	    op_major <= "00"; -- ALU
	    op_minor <= "000"; -- ADD
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_ADDIU =>
	    op_major <= "00"; -- ALU
	    op_minor <= "000"; -- ADD
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SLTI =>
	    op_major <= "01"; -- SLTI / SLTIU
	    op_minor <= "010"; -- SUB
	    use_immediate <= true;
	    sign_extend <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SLTIU =>
	    op_major <= "01"; -- SLTI / SLTIU
	    op_minor <= "010"; -- SUB
	    use_immediate <= true;
	    sign_extend <= false;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_ANDI =>
	    op_minor <= "100"; -- AND
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_ORI =>
	    op_minor <= "101"; -- OR
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_XORI =>
	    op_minor <= "110"; -- XOR
	    use_immediate <= true;
	    immediate_value <= imm32_unsigned;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LUI =>
	    op_major <= "00"; -- ADD
	    op_minor <= "000"; -- ADD
	    use_immediate <= true;
	    immediate_value <= instruction(15 downto 0) & x"0000";
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_BEQL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= "100";
		target_addr <= MIPS32_REG_ZERO;
	    else
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BNEL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= "101";
		target_addr <= MIPS32_REG_ZERO;
	    else
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BLEZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= "110";
		target_addr <= MIPS32_REG_ZERO;
	    else
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BGTZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= "111";
		target_addr <= MIPS32_REG_ZERO;
	    else
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_LB =>
	    latency <= "11";
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LH =>
	    latency <= "11";
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LW =>
	    latency <= "01";
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LBU =>
	    latency <= "11";
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LHU =>
	    latency <= "11";
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SB =>
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SH =>
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SWL =>			-- XXX revisit!
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SW =>
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_REGIMM =>
	    target_addr <= MIPS32_REG_ZERO;
	    branch_cycle <= true;
	    case instruction(20 downto 16) is
	    when MIPS32_RIMM_BLTZ =>
		branch_condition <= "010";
		branch_likely <= false;
	    when MIPS32_RIMM_BGEZ =>
		branch_condition <= "011";
		branch_likely <= false;
	    when MIPS32_RIMM_BLTZL =>
		branch_condition <= "010";
		branch_likely <= true;
	    when MIPS32_RIMM_BGEZL =>
		branch_condition <= "011";
		branch_likely <= true;
	    when MIPS32_RIMM_BLTZAL =>
		branch_condition <= "010";
		branch_likely <= false;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BGEZAL =>
		branch_condition <= "011";
		branch_likely <= false;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BLTZALL =>
		branch_condition <= "010";
		branch_likely <= true;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BGEZALL =>
		branch_condition <= "011";
		branch_likely <= true;
		target_addr <= MIPS32_REG_RA;
	    when others =>
		unsupported_instr <= true;
	    end case;
	when MIPS32_OP_SPECIAL =>
	    target_addr <= instruction(15 downto 11);
	    case instruction(5 downto 0) is
	    when MIPS32_SPEC_SLL =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_SRL =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_SRA =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_SLLV =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_SRLV =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_SRAV =>
		op_major <= "10";
		latency <= "01";
	    when MIPS32_SPEC_JR =>
		jump_register <= true;
	    when MIPS32_SPEC_JALR =>
		jump_register <= true;
	    when MIPS32_SPEC_MOVZ =>
		if C_movn_movz then
		    op_minor <= "000"; -- ADD
		    cmov_cycle <= true;
		    cmov_condition <= true;
		else
		    unsupported_instr <= true;
		end if;
	    when MIPS32_SPEC_MOVN =>
		if C_movn_movz then
		    op_minor <= "000"; -- ADD
		    cmov_cycle <= true;
		    cmov_condition <= false;
		else
		    unsupported_instr <= true;
		end if;
	    when MIPS32_SPEC_MFHI =>
		op_major <= "11";
		op_minor <= "-0-"; -- XXX revisit
	    when MIPS32_SPEC_MTHI =>
		op_major <= "11";
	    when MIPS32_SPEC_MFLO =>
		op_major <= "11";
		op_minor <= "-1-"; -- XXX revisit
	    when MIPS32_SPEC_MTLO =>
		op_major <= "11";
	    when MIPS32_SPEC_MULT =>
		op_major <= "11";
	    when MIPS32_SPEC_MULTU =>
		op_major <= "11";
	    when MIPS32_SPEC_ADD =>
		op_minor <= "000"; -- ADD
	    when MIPS32_SPEC_ADDU =>
		op_minor <= "000"; -- ADD
	    when MIPS32_SPEC_SUB =>
		op_minor <= "010"; -- SUB
	    when MIPS32_SPEC_SUBU =>
		op_minor <= "010"; -- SUB
	    when MIPS32_SPEC_AND =>
		op_minor <= "100"; -- AND
	    when MIPS32_SPEC_OR =>
		op_minor <= "101"; -- OR
	    when MIPS32_SPEC_XOR =>
		op_minor <= "110"; -- XOR
	    when MIPS32_SPEC_NOR =>
		op_minor <= "111"; -- NOR
	    when MIPS32_SPEC_SLT =>
		op_major <= "01"; -- SLTI / SLTIU
		op_minor <= "010"; -- SUB
		sign_extend <= true;
	    when MIPS32_SPEC_SLTU =>
		op_major <= "01"; -- SLTI / SLTIU
		op_minor <= "010"; -- SUB
		sign_extend <= false;
	    when others =>
		unsupported_instr <= true;
	    end case;
	when MIPS32_OP_SPECIAL2 =>
	    target_addr <= instruction(15 downto 11);
	    unsupported_instr <= true;
	when MIPS32_OP_SPECIAL3 =>
	    target_addr <= instruction(15 downto 11);
	    op_minor <= "110";
	    case instruction(5 downto 0) is
	    when MIPS32_SPEC3_BSHFL =>
		if C_sign_extend then
		    seb_seh_cycle <= true;
		    seb_seh_select <= instruction(9);
		else
		    unsupported_instr <= true;
		end if;
	    when others =>
		unsupported_instr <= true;
	    end case;
	when others =>
	    unsupported_instr <= true;
	end case;
    end process;

end Behavioral;
