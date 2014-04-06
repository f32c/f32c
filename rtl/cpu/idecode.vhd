--
-- Copyright 2012 - 2014 Marko Zec, University of Zagreb.        
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


entity idecode is
    generic(
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_cache: boolean;
	C_ll_sc: boolean;
	C_movn_movz: boolean;
	C_exceptions: boolean
    );
    port(
	instruction: in std_logic_vector(31 downto 0);
	branch_cycle, branch_likely: out boolean;
	jump_cycle, jump_register, eret: out boolean;
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
	cmov_cycle, cmov_condition: out boolean;
	branch_condition: out std_logic_vector(2 downto 0);
	mem_cycle: out std_logic;
	mem_write: out std_logic;
	mem_size: out std_logic_vector(1 downto 0);
	mem_read_sign_extend: out std_logic; -- LB / LH
	ll, sc: out boolean;
	flush_i_line, flush_d_line: out std_logic;
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
	eret <= false;
	reg1_zero <= instruction(25 downto 21) = MIPS32_REG_ZERO;
	reg2_zero <= instruction(20 downto 16) = MIPS32_REG_ZERO;
	target_addr <= "-----";
	immediate_value <= imm32_signed;
	sign_extend <= false; -- should be don't care
	op_major <= OP_MAJOR_ALU;
	op_minor <= "000"; -- should be ADD
	use_immediate <= false; -- should be dont' care
	ignore_reg2 <= instruction(20 downto 16) = MIPS32_REG_ZERO;
	cmov_cycle <= false;
	cmov_condition <= false; -- should be don't care
	branch_condition <= TEST_UNDEFINED;
	mem_cycle <= instruction(31);
	mem_write <= '0';
	mem_size <= MEM_SIZE_UNDEFINED;
	mem_read_sign_extend <= '-';
	latency <= LATENCY_EX;
	seb_seh_cycle <= false;
	seb_seh_select <= instruction(9);
	alt_sel <= ALT_PC_8;
	read_alt <= false;
	flush_i_line <= '0';
	flush_d_line <= '0';
	ll <= false;
	sc <= false;
	
	-- Main instruction decoder
	case instruction(31 downto 26) is
	when MIPS32_OP_J =>
	    jump_cycle <= true;
	    target_addr <= MIPS32_REG_ZERO;
	    ignore_reg2 <= true;
	    read_alt <= true;
	when MIPS32_OP_JAL =>
	    jump_cycle <= true;
	    target_addr <= MIPS32_REG_RA;
	    ignore_reg2 <= true;
	    read_alt <= true;
	when MIPS32_OP_BEQ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= TEST_EQ;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BNE =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= TEST_NE;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BLEZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= TEST_LEZ;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_BGTZ =>
	    branch_cycle <= true;
	    branch_likely <= false;
	    branch_condition <= TEST_GTZ;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_ADDI =>
	    op_minor <= "000"; -- ADD
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_ADDIU =>
	    op_minor <= "000"; -- ADD
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SLTI =>
	    op_major <= OP_MAJOR_SLT;
	    op_minor <= "010"; -- SUB
	    use_immediate <= true;
	    sign_extend <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SLTIU =>
	    op_major <= OP_MAJOR_SLT;
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
	    use_immediate <= true;
	    immediate_value <= instruction(15 downto 0) & x"0000";
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_COP0 =>
	    read_alt <= true;
	    alt_sel <= ALT_COP0;
	    target_addr <= instruction(20 downto 16);
	    if C_exceptions and instruction(5 downto 0) = MIPS32_COP0_ERET then
		eret <= true;
		branch_cycle <= true;
	    end if;
	when MIPS32_OP_BEQL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= TEST_EQ;
		target_addr <= MIPS32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BNEL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= TEST_NE;
		target_addr <= MIPS32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BLEZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= TEST_LEZ;
		target_addr <= MIPS32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_BGTZL =>
	    if C_branch_likely then
		branch_cycle <= true;
		branch_likely <= true;
		branch_condition <= TEST_GTZ;
		target_addr <= MIPS32_REG_ZERO;
	    else
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_LB =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_8;
	    mem_read_sign_extend <= '1';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LH =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_16;
	    mem_read_sign_extend <= '1';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LW =>
	    latency <= LATENCY_MEM;
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LL =>
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
	when MIPS32_OP_LBU =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_8;
	    mem_read_sign_extend <= '0';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_LHU =>
	    latency <= LATENCY_WB;
	    mem_size <= MEM_SIZE_16;
	    mem_read_sign_extend <= '0';
	    use_immediate <= true;
	    target_addr <= instruction(20 downto 16);
	    ignore_reg2 <= true;
	when MIPS32_OP_SB =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_8;
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SH =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_16;
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SWL =>			-- XXX revisit!
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SWR =>			-- XXX revisit!
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SW =>
	    latency <= LATENCY_UNDEFINED;
	    mem_write <= '1';
	    mem_size <= MEM_SIZE_32;
	    use_immediate <= true;
	    target_addr <= MIPS32_REG_ZERO;
	when MIPS32_OP_SC =>
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
	when MIPS32_OP_CACHE =>
	    target_addr <= MIPS32_REG_ZERO;
	    if C_cache then
		latency <= LATENCY_UNDEFINED;
		use_immediate <= true;
		flush_i_line <= not instruction(16);
		flush_d_line <= instruction(16);
	    else
		unsupported_instr <= true;
	    end if;
	when MIPS32_OP_REGIMM =>
	    target_addr <= MIPS32_REG_ZERO;
	    branch_cycle <= true;
	    read_alt <= true;
	    case instruction(20 downto 16) is
	    when MIPS32_RIMM_BLTZ =>
		branch_condition <= TEST_LTZ;
		branch_likely <= false;
	    when MIPS32_RIMM_BGEZ =>
		branch_condition <= TEST_GEZ;
		branch_likely <= false;
	    when MIPS32_RIMM_BLTZL =>
		branch_condition <= TEST_LTZ;
		branch_likely <= true;
	    when MIPS32_RIMM_BGEZL =>
		branch_condition <= TEST_GEZ;
		branch_likely <= true;
	    when MIPS32_RIMM_BLTZAL =>
		branch_condition <= TEST_LTZ;
		branch_likely <= false;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BGEZAL =>
		branch_condition <= TEST_GEZ;
		branch_likely <= false;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BLTZALL =>
		branch_condition <= TEST_LTZ;
		branch_likely <= true;
		target_addr <= MIPS32_REG_RA;
	    when MIPS32_RIMM_BGEZALL =>
		branch_condition <= TEST_GEZ;
		branch_likely <= true;
		target_addr <= MIPS32_REG_RA;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when MIPS32_OP_SPECIAL =>
	    target_addr <= instruction(15 downto 11);
	    case instruction(5 downto 0) is
	    when MIPS32_SPEC_SLL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_SRL =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_SRA =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_SLLV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_SRLV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_SRAV =>
		op_major <= OP_MAJOR_SHIFT;
		latency <= LATENCY_MEM;
	    when MIPS32_SPEC_JR =>
		jump_register <= true;
		read_alt <= true;
	    when MIPS32_SPEC_JALR =>
		jump_register <= true;
		read_alt <= true;
	    when MIPS32_SPEC_MOVZ =>
		if C_movn_movz then
		    cmov_cycle <= true;
		    cmov_condition <= true;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MIPS32_SPEC_MOVN =>
		if C_movn_movz then
		    cmov_cycle <= true;
		    cmov_condition <= false;
		else
		    latency <= LATENCY_UNDEFINED;
		    unsupported_instr <= true;
		end if;
	    when MIPS32_SPEC_MFHI =>
		read_alt <= true;
		alt_sel <= ALT_HI;
	    when MIPS32_SPEC_MFLO =>
		read_alt <= true;
		alt_sel <= ALT_LO;
	    when MIPS32_SPEC_MULT =>
		op_major <= OP_MAJOR_ALT;
	    when MIPS32_SPEC_MULTU =>
		op_major <= OP_MAJOR_ALT;
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
		op_major <= OP_MAJOR_SLT;
		op_minor <= "010"; -- SUB
		sign_extend <= true;
	    when MIPS32_SPEC_SLTU =>
		op_major <= OP_MAJOR_SLT;
		op_minor <= "010"; -- SUB
		sign_extend <= false;
	    when others =>
		latency <= LATENCY_UNDEFINED;
		unsupported_instr <= true;
	    end case;
	when MIPS32_OP_SPECIAL2 =>
	    latency <= LATENCY_UNDEFINED;
	    unsupported_instr <= true;
	when MIPS32_OP_SPECIAL3 =>
	    target_addr <= instruction(15 downto 11);
	    op_minor <= "110";
	    case instruction(5 downto 0) is
	    when MIPS32_SPEC3_BSHFL =>
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
