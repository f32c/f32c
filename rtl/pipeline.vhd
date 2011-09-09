--
-- Copyright 2008, 2010, 2011 University of Zagreb.
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


entity pipeline is
    generic (
	-- ISA options
	C_big_endian: boolean := false;
	C_mult_enable: boolean;
	C_branch_likely: boolean;
	C_movn_movz: boolean;
	C_mips32_movn_movz: boolean;
	C_init_PC: std_logic_vector(31 downto 0) := x"00000000";

	-- optimization options
	C_result_forwarding: boolean := true;
	C_branch_prediction: boolean := true;
	C_load_aligner: boolean := true;
	C_fast_ID: boolean := true;
	C_register_technology: string := "unknown";

	-- debugging options
	C_debug: boolean := false
    );
    port (
	clk, reset: in std_logic;
	imem_addr: out std_logic_vector(31 downto 2);
	imem_data_in: in std_logic_vector(31 downto 0);
	imem_addr_strobe: out std_logic;
	imem_data_ready: in std_logic;
	dmem_addr: out std_logic_vector(31 downto 2);
	dmem_byte_we: out std_logic_vector(3 downto 0);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_addr_strobe: out std_logic;
	dmem_data_ready: in std_logic;
	-- debugging only
	trace_addr: in std_logic_vector(5 downto 0);
	trace_data: out std_logic_vector(31 downto 0)
    );
end pipeline;

architecture Behavioral of pipeline is

    signal debug_XXX: std_logic_vector(31 downto 0) := x"00000000";

    -- pipeline stage 1: instruction fetch
    signal IF_PC, IF_PC_next: std_logic_vector(31 downto 2);
    signal IF_PC_incr: std_logic;
    signal IF_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_bpredict_re: std_logic;
    signal IF_ID_instruction: std_logic_vector(31 downto 0);
    signal IF_ID_bpredict_score: std_logic_vector(1 downto 0);
    signal IF_ID_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_ID_branch_delay_slot: boolean;
    signal IF_ID_PC, IF_ID_PC_4, IF_ID_PC_next: std_logic_vector(31 downto 2);
	
    -- pipeline stage 2: instruction decode and register fetch
    signal ID_running: boolean;
    signal ID_reg1_zero, ID_reg2_zero: boolean;
    signal ID_branch_cycle, ID_branch_likely, ID_jump_cycle: boolean;
    signal ID_cmov_cycle, ID_cmov_condition: boolean;
    signal ID_reg1_addr, ID_reg2_addr: std_logic_vector(4 downto 0);
    signal ID_writeback_addr: std_logic_vector(4 downto 0);
    signal ID_reg1_data, ID_reg2_data: std_logic_vector(31 downto 0);
    signal ID_reg1_eff_data, ID_reg2_eff_data: std_logic_vector(31 downto 0);
    signal ID_alu_op2: std_logic_vector(31 downto 0);
    signal ID_fwd_ex_reg1, ID_fwd_ex_reg2, ID_fwd_ex_alu_op2: boolean;
    signal ID_fwd_mem_reg1, ID_fwd_mem_reg2, ID_fwd_mem_alu_op2: boolean;
    signal ID_jump_register: boolean;
    signal ID_op_major: std_logic_vector(1 downto 0);
    signal ID_op_minor: std_logic_vector(2 downto 0);
    signal ID_immediate: std_logic_vector(31 downto 0);
    signal ID_sign_extension: std_logic_vector(15 downto 0);
    signal ID_sign_extend: boolean;
    signal ID_use_immediate, ID_ignore_reg2: boolean;
    signal ID_predict_taken: boolean;
    signal ID_branch_target, ID_jump_target: std_logic_vector(31 downto 2);
    signal ID_branch_condition: std_logic_vector(2 downto 0);
    signal ID_mem_cycle, ID_mem_write: std_logic;
    signal ID_mem_size: std_logic_vector(1 downto 0);
    signal ID_mem_read_sign_extend: std_logic;
    signal ID_latency: std_logic_vector(1 downto 0);
    signal ID_load_align_hazard: boolean;
    signal ID_jump_register_hazard: boolean;
    signal ID_seb_cycle: boolean;
    -- boundary to stage 3
    signal ID_EX_PC_8: std_logic_vector(31 downto 2);
    signal ID_EX_bpredict_score: std_logic_vector(1 downto 0);
    signal ID_EX_writeback_addr: std_logic_vector(4 downto 0);
    signal ID_EX_reg1_data, ID_EX_reg2_data: std_logic_vector(31 downto 0);
    signal ID_EX_immediate, ID_EX_alu_op2: std_logic_vector(31 downto 0);
    signal ID_EX_fwd_ex_reg1, ID_EX_fwd_ex_reg2, ID_EX_fwd_ex_alu_op2: boolean;
    signal ID_EX_fwd_mem_reg1, ID_EX_fwd_mem_reg2: boolean;
    signal ID_EX_fwd_mem_alu_op2, ID_EX_sign_extend: boolean;
    signal ID_EX_cmov_cycle, ID_EX_cmov_condition: boolean;
    signal ID_EX_branch_cycle, ID_EX_branch_likely: boolean;
    signal ID_EX_jump_cycle, ID_EX_jump_register: boolean;
    signal ID_EX_cancel_next, ID_EX_predict_taken: boolean;
    signal ID_EX_bpredict_index: std_logic_vector(12 downto 0);
    signal ID_EX_branch_target: std_logic_vector(31 downto 2);
    signal ID_EX_branch_condition: std_logic_vector(2 downto 0);
    signal ID_EX_op_major: std_logic_vector(1 downto 0);
    signal ID_EX_op_minor: std_logic_vector(2 downto 0);
    signal ID_EX_mem_cycle, ID_EX_mem_write: std_logic;
    signal ID_EX_mem_size: std_logic_vector(1 downto 0);
    signal ID_EX_mem_read_sign_extend: std_logic;
    signal ID_EX_multicycle_lh_lb: boolean;
    signal ID_EX_latency: std_logic_vector(1 downto 0);
    signal ID_EX_seb_cycle: boolean;
    signal ID_EX_instruction: std_logic_vector(31 downto 0); -- debugging only
    signal ID_EX_PC: std_logic_vector(31 downto 2); -- debugging only
    signal ID_EX_sign_extend_debug: std_logic; -- debugging only
	
    -- pipeline stage 3: execute
    signal EX_running: boolean;
    signal EX_eff_reg1, EX_eff_reg2: std_logic_vector(31 downto 0);
    signal EX_eff_alu_op2: std_logic_vector(31 downto 0);
    signal EX_shamt: std_logic_vector(4 downto 0);
    signal EX_shift_funct_8_16: std_logic_vector(1 downto 0);
    signal EX_from_shift: std_logic_vector(31 downto 0);
    signal EX_from_alu_addsubx: std_logic_vector(32 downto 0);
    signal EX_from_alu_logic, EX_from_alt: std_logic_vector(31 downto 0);
    signal EX_from_alu_equal: boolean;
    signal EX_2bit_add: std_logic_vector(1 downto 0);
    signal EX_mem_byte_we: std_logic_vector(3 downto 0);
    signal EX_take_branch: boolean;
    -- boundary to stage 4
    signal EX_MEM_writeback_addr: std_logic_vector(4 downto 0);
    signal EX_MEM_addsub_data: std_logic_vector(31 downto 0);
    signal EX_MEM_logic_data: std_logic_vector(31 downto 0);
    signal EX_MEM_mem_data_out: std_logic_vector(31 downto 0);
    signal EX_MEM_branch_target: std_logic_vector(29 downto 0) :=
      C_init_PC(31 downto 2);
    signal EX_MEM_take_branch: boolean := true; -- jump to C_init_PC addr
    signal EX_MEM_branch_cycle, EX_MEM_branch_taken: boolean;
    signal EX_MEM_branch_likely: boolean;
    signal EX_MEM_bpredict_score: std_logic_vector(1 downto 0);
    signal EX_MEM_branch_hist: std_logic_vector(12 downto 0);
    signal EX_MEM_bpredict_index: std_logic_vector(12 downto 0);
    signal EX_MEM_latency: std_logic;
    signal EX_MEM_mem_cycle, EX_MEM_logic_cycle: std_logic;
    signal EX_MEM_mem_read_sign_extend: std_logic;
    signal EX_MEM_shamt_1_2_4: std_logic_vector(2 downto 0);
    signal EX_MEM_shift_funct: std_logic_vector(1 downto 0);
    signal EX_MEM_mem_size: std_logic_vector(1 downto 0);
    signal EX_MEM_multicycle_lh_lb: boolean;
    signal EX_MEM_mem_byte_we: std_logic_vector(3 downto 0);
    signal EX_MEM_op_major: std_logic_vector(1 downto 0);
    signal EX_MEM_instruction: std_logic_vector(31 downto 0); -- debugging only
    signal EX_MEM_PC: std_logic_vector(31 downto 2); -- debugging only
	
    -- pipeline stage 4: memory access
    signal MEM_running, MEM_take_branch: boolean;
    signal MEM_cancel_EX: boolean;
    signal MEM_bpredict_score: std_logic_vector(1 downto 0);
    signal MEM_bpredict_we: std_logic;
    signal MEM_eff_data: std_logic_vector(31 downto 0);
    signal MEM_data_in, MEM_from_shift: std_logic_vector(31 downto 0);
    -- boundary to stage 5
    signal MEM_WB_mem_cycle: std_logic;
    signal MEM_WB_mem_read_sign_extend: std_logic;
    signal MEM_WB_mem_size: std_logic_vector(1 downto 0);
    signal MEM_WB_writeback_addr: std_logic_vector(4 downto 0);
    signal MEM_WB_write_enable: std_logic;
    signal MEM_WB_ex_data, MEM_WB_mem_data: std_logic_vector(31 downto 0);
    signal MEM_WB_multicycle_lh_lb: boolean;
    signal MEM_WB_mem_addr_offset: std_logic_vector(1 downto 0);
    signal MEM_WB_instruction: std_logic_vector(31 downto 0); -- debugging only
	
    -- pipeline stage 5: register writeback
    signal WB_eff_data: std_logic_vector(31 downto 0);
    signal WB_writeback_data: std_logic_vector(31 downto 0);
    signal WB_mem_data_aligned: std_logic_vector(31 downto 0);
    signal WB_clk: std_logic;

    -- multiplication unit
    signal mul_res: std_logic_vector(65 downto 0);
    signal R_mul_a, R_mul_b: std_logic_vector(32 downto 0);
    signal R_hi_lo: std_logic_vector(63 downto 0);

    -- signals used for debugging only
    signal reg_trace_data: std_logic_vector(31 downto 0);
    signal D_tsc, D_instr, D_b_instr, D_b_taken: std_logic_vector(31 downto 0);

begin

    --
    -- Five stage pipeline with result forwarding and hazard detection:
    --
    -- IF:  instruction fetch
    -- ID:  instruction decode and register fetch
    -- EX:  execute
    -- MEM: memory access
    -- WB:  register writeback
    --
    -- Each pipeline stage must consist of purely combinatorial logic terminated
    -- by a single registered section.  Only signals prefixed by
    -- IF_ID_, ID_EX_, EX_MEM_ or MEM_WB_ may be affected by the clk.
    -- Combinatiorial signals used locally in each stage must be prefixed by
    -- IF_, ID_, EX_, MEM_ or WB_.  XXX update / fix this convention!!!
    --
    -- Memory organization, regardless of endianess config:
    -- imem_data_in / dmem_data_in / dmem_data_out (31 downto 0):
    --             10987654321098765432109876543210
    -- 0x00000000: |byte 3||byte 2||byte 1||byte 0|
    -- 0x00000004: |byte 7||byte 6||byte 5||byte 4|
    -- 0x00000008: |byte b||byte a||byte 9||byte 8|
    -- ...
    --
    -- Little endian (C_big_endian = false; gcc -EL):
    --   register: |byte A||byte B||byte C||byte D|
    --   memory:   |byte A||byte B||byte C||byte D|
    -- Big endian (C_big_endian = true; gcc -EB):
    --   register: |byte A||byte B||byte C||byte D|
    --   memory:   |byte D||byte C||byte B||byte A|
    --

    -- XXX TODO:
    --	revisit MULT / MFHI / MFLO decoding (now done in EX stage!!!)
    --  commit MULT result in MEM stage (branch likely must cancel commit)!
    --  reintroduce area-optimized branch likely support as an option
    --	sort out the endianess story
    --	unaligned load / store instructions?
    --	revisit movz / movn: use ALU (and / or) instead of (slow) shifter!
    --	revisit target_addr computation in idecode.vhd
    --	don't branch until branch delay slot fetched!!!
    --	reset?
    --	MTHI/MTLO/MFC0/MTC0?
    --	division? - block on MFHI/MFLO if result not ready
    --	result forwarding: muxes instead of priority encoders?
    --	exceptions/interrupts


    --
    -- Pipeline stage 1: instruction fetch
    -- ===================================
    --

    -- compute current and next program counter
    -- XXX revisit: make IF_PC a register, not an output from a mux.
    IF_PC <= EX_MEM_branch_target when MEM_take_branch else IF_ID_PC_next;

    G_fast_ID:
    if C_fast_ID generate
    IF_PC_next <= IF_PC + 1 when ID_running else IF_PC;
    end generate;

    G_not_fast_ID:
    if not C_fast_ID generate
    IF_PC_incr <= '1' when ID_running else '0';
    IF_PC_next <= IF_PC + IF_PC_incr;
    end generate;

    imem_addr <= IF_PC;
    imem_addr_strobe <= '1';

    process(clk)
    begin
	if rising_edge(clk) then
	    if MEM_take_branch then
		IF_ID_PC_next <= IF_PC_next;
	    elsif ID_running then
		if (ID_jump_cycle or ID_jump_register or ID_predict_taken)
		  and not ID_EX_cancel_next then
		    IF_ID_PC_next <= ID_jump_target;
		else
		    IF_ID_PC_next <= IF_PC_next;
		end if;
	    end if;
	    if ID_running then
		IF_ID_PC <= IF_PC;
		IF_ID_PC_4 <= IF_PC_next;
		IF_ID_branch_delay_slot <=
		  ID_branch_cycle or ID_jump_cycle or ID_jump_register;
		IF_ID_bpredict_index <= IF_bpredict_index;
		if C_big_endian then
		    IF_ID_instruction <=
		      imem_data_in(7 downto 0) & imem_data_in(15 downto 8) &
		      imem_data_in(23 downto 16) & imem_data_in(31 downto 24);
		else
		    IF_ID_instruction <= imem_data_in;
		end if;
	    end if;
	end if;
    end process;
	
    G_bp_scoretable:
    if C_branch_prediction generate
    IF_bpredict_index <= EX_MEM_branch_hist xor IF_PC(14 downto 2);
    IF_bpredict_re <= '1' when ID_running else '0';

    bptrace: entity bptrace
    port map (
	din => MEM_bpredict_score, dout => IF_ID_bpredict_score,
	rdaddr => IF_bpredict_index, wraddr => EX_MEM_bpredict_index,
	re => IF_bpredict_re, we => MEM_bpredict_we, clk => clk
    );
    end generate;

    --
    -- Pipeline stage 2: instruction decode and register fetch
    -- =======================================================
    --
	
    -- instruction decoder
    idecode: entity idecode
    generic map (
	C_branch_likely => C_branch_likely,
	C_movn_movz => C_movn_movz,
	C_mips32_movn_movz => C_mips32_movn_movz
    )
    port map (
	instruction => IF_ID_instruction,
	reg1_addr => ID_reg1_addr, reg2_addr => ID_reg2_addr,
	reg1_zero => ID_reg1_zero, reg2_zero => ID_reg2_zero,
	immediate_value => ID_immediate, use_immediate => ID_use_immediate,
	cmov_cycle => ID_cmov_cycle, cmov_condition => ID_cmov_condition,
	sign_extension => ID_sign_extension,
	target_addr => ID_writeback_addr, op_major => ID_op_major,
	op_minor => ID_op_minor, mem_cycle => ID_mem_cycle,
	branch_cycle => ID_branch_cycle, branch_likely => ID_branch_likely,
	jump_cycle => ID_jump_cycle, jump_register => ID_jump_register,
	branch_condition => ID_branch_condition, sign_extend => ID_sign_extend,
	mem_write => ID_mem_write, mem_size => ID_mem_size,
	mem_read_sign_extend => ID_mem_read_sign_extend,
	latency => ID_latency, ignore_reg2 => ID_ignore_reg2,
	seb_cycle => ID_seb_cycle
    );

    -- three- or four-ported register file: 2(3) async reads, 1 sync write
    regfile: entity reg1w2r
    generic map (
	C_register_technology => C_register_technology,
	C_debug => C_debug
    )
    port map (
	rd1_addr => ID_reg1_addr, rd2_addr => ID_reg2_addr,
	rdd_addr => trace_addr(4 downto 0), wr_addr => MEM_WB_writeback_addr,
	rd1_data => ID_reg1_data, rd2_data => ID_reg2_data,
	rdd_data => reg_trace_data, wr_data => WB_writeback_data,
	wr_enable => MEM_WB_write_enable, clk => WB_clk
    );
	
    --
    -- WB_writeback_data overrides register reads with pipelined load aligner.
    -- With multicycle aligner WB_writeback_data is written to the regfile
    -- at the half of the clk cycle, in which case no bypass logic is required.
    --
    WB_clk <= clk when C_load_aligner else not clk;
    ID_reg1_eff_data <= ID_reg1_data when not C_load_aligner or
      ID_reg1_zero or ID_reg1_addr /= MEM_WB_writeback_addr else
      WB_writeback_data;
    ID_reg2_eff_data <= ID_reg2_data when not C_load_aligner or
      ID_reg2_zero or ID_reg2_addr /= MEM_WB_writeback_addr else
      WB_writeback_data;

    -- stall the IF and ID stages if any of the following conditions hold:
    --
    --	A) EX stage is stalled;
    --	B) execute-use or load-use data hazard is detected;
    --
    ID_load_align_hazard <= C_load_aligner and EX_MEM_latency = '1'
      and ((not ID_reg1_zero and ID_reg1_addr = EX_MEM_writeback_addr) or
      (not ID_ignore_reg2 and ID_reg2_addr = EX_MEM_writeback_addr));
    ID_jump_register_hazard <= ID_jump_register and not ID_reg1_zero and
      (ID_reg1_addr = ID_EX_writeback_addr or
      ID_reg1_addr = EX_MEM_writeback_addr or
      (C_load_aligner and ID_reg1_addr = MEM_WB_writeback_addr));

    G_ID_forwarding:
    if C_result_forwarding generate
    ID_running <= ID_EX_cancel_next or
      (EX_running and not ID_EX_multicycle_lh_lb and
      not ID_load_align_hazard and not ID_jump_register_hazard and
      (ID_reg1_zero or ID_reg1_addr /= ID_EX_writeback_addr or
      ID_EX_latency(0) = '0') and (ID_ignore_reg2 or
      ID_reg2_addr /= ID_EX_writeback_addr or ID_EX_latency(0) = '0'));
    end generate;

    G_ID_no_forwarding:
    if not C_result_forwarding generate
    ID_running <= ID_EX_cancel_next or
      (EX_running and not ID_EX_multicycle_lh_lb and
      not ID_load_align_hazard and not ID_jump_register_hazard and
      not (ID_fwd_ex_reg1 or ID_fwd_mem_reg1)
      and (ID_ignore_reg2 or not (ID_fwd_ex_reg2 or ID_fwd_mem_reg2)));
    end generate;
	
    ID_alu_op2 <= ID_immediate when ID_use_immediate else ID_reg2_eff_data;
	
    -- schedule forwarding of results from the EX stage
    ID_fwd_ex_reg1 <= not MEM_cancel_EX and
      not ID_reg1_zero and ID_reg1_addr = ID_EX_writeback_addr;
    ID_fwd_ex_reg2 <= not MEM_cancel_EX and
      not ID_reg2_zero and ID_reg2_addr = ID_EX_writeback_addr;
    ID_fwd_ex_alu_op2 <= not MEM_cancel_EX and
      ID_fwd_ex_reg2 and not ID_use_immediate;
    -- schedule forwarding of results from the MEM stage
    ID_fwd_mem_reg1 <=
      not ID_reg1_zero and ID_reg1_addr = EX_MEM_writeback_addr;
    ID_fwd_mem_reg2 <=
      not ID_reg2_zero and ID_reg2_addr = EX_MEM_writeback_addr;
    ID_fwd_mem_alu_op2 <= ID_fwd_mem_reg2 and not ID_use_immediate;

    -- compute branch target - XXX revisit: perhaps use ID_immediate here?
    ID_branch_target <= IF_ID_PC_4 +
      (ID_sign_extension(13 downto 0) & IF_ID_instruction(15 downto 0));

    -- branch prediction
    ID_predict_taken <= C_branch_prediction and
      ID_branch_cycle and IF_ID_bpredict_score(1) = '1';

    -- compute jump target
    ID_jump_target <=
      ID_reg1_data(31 downto 2) when ID_jump_register else
      ID_branch_target when ID_predict_taken else
      IF_ID_PC(29 downto 24) & IF_ID_instruction(23 downto 0);

    process(clk)
    begin
	if rising_edge(clk) then
	    if EX_running then
		if not C_load_aligner and ID_EX_multicycle_lh_lb then
		    -- multicycle load aligner
		    -- byte / half word load, insert an arithm shift right cycle
		    -- XXX must stall the ID stage - revisit!!!
		    ID_EX_multicycle_lh_lb <= not EX_MEM_multicycle_lh_lb;
		    ID_EX_mem_cycle <= '0';
		    ID_EX_op_major <= "10"; -- shift
		    ID_EX_immediate(2) <= '0'; -- shift immediate
		    ID_EX_immediate(1 downto 0) <= "10"; -- shift right logical
		    if not EX_MEM_multicycle_lh_lb then
			-- shift amount
			ID_EX_immediate(10 downto 6) <= EX_2bit_add & "000";
		    end if;
		    if MEM_take_branch and not ID_running then
			ID_EX_cancel_next <= true;
		    end if;
		    if ID_running then
			ID_EX_cancel_next <= false;
		    end if;
		    if true or C_debug then -- XXX mult depends on C_debug!!!
			ID_EX_instruction <= x"00000001"; -- debugging only
		    end if;
		    -- schedule forwarding of memory read
		    ID_EX_fwd_ex_reg1 <= false;
		    ID_EX_fwd_ex_reg2 <= false;
		    ID_EX_fwd_ex_alu_op2 <= false;
		    ID_EX_fwd_mem_reg1 <= false;
		    ID_EX_fwd_mem_reg2 <= true;
		    ID_EX_fwd_mem_alu_op2 <= false;
		elsif not ID_running or (not IF_ID_branch_delay_slot and
		  (MEM_take_branch or ID_EX_cancel_next)) then
		    -- insert a bubble if branching or ID stage is stalled
		    ID_EX_writeback_addr <= "00000"; -- NOP
		    ID_EX_mem_cycle <= '0';
		    ID_EX_mem_write <= '0'; -- XXX do we need this?
		    ID_EX_branch_cycle <= false;
		    ID_EX_branch_likely <= false;
		    ID_EX_jump_cycle <= false;
		    ID_EX_jump_register <= false;
		    ID_EX_predict_taken <= false;
		    if MEM_take_branch and not ID_running then
			ID_EX_cancel_next <= true;
		    end if;
		    if ID_running then
			ID_EX_cancel_next <= false;
		    end if;
		    if true or C_debug then -- XXX mult depends on C_debug!!!
			ID_EX_instruction <= x"00000000"; -- debugging only
		    end if;
		else
		    -- propagate next instruction from ID to EX stage
		    ID_EX_reg1_data <= ID_reg1_eff_data;
		    ID_EX_reg2_data <= ID_reg2_eff_data;
		    ID_EX_alu_op2 <= ID_alu_op2;
		    ID_EX_immediate <= ID_immediate;
		    ID_EX_sign_extend <= ID_sign_extend;
		    ID_EX_op_minor <= ID_op_minor;
		    ID_EX_cmov_cycle <= C_movn_movz and ID_cmov_cycle;
		    ID_EX_cmov_condition <= C_movn_movz and ID_cmov_condition;
		    ID_EX_mem_write <= ID_mem_write;
		    ID_EX_mem_size <= ID_mem_size;
		    ID_EX_multicycle_lh_lb <=
		      not C_load_aligner and ID_mem_cycle = '1' and
		      ID_mem_write = '0' and ID_mem_size(1) = '0';
		    ID_EX_mem_read_sign_extend <= ID_mem_read_sign_extend;
		    ID_EX_branch_condition <= ID_branch_condition;
		    ID_EX_PC_8 <= IF_ID_PC_4 + 1;
		    ID_EX_branch_target <= ID_branch_target;
		    ID_EX_seb_cycle <= ID_seb_cycle;
		    ID_EX_writeback_addr <= ID_writeback_addr;
		    ID_EX_mem_cycle <= ID_mem_cycle;
		    ID_EX_branch_cycle <= ID_branch_cycle;
		    ID_EX_branch_likely <= ID_branch_likely;
		    ID_EX_jump_cycle <= ID_jump_cycle;
		    ID_EX_jump_register <= ID_jump_register;
		    ID_EX_predict_taken <= ID_predict_taken;
		    ID_EX_bpredict_score <= IF_ID_bpredict_score;
		    ID_EX_bpredict_index <= IF_ID_bpredict_index;
		    ID_EX_op_major <= ID_op_major;
		    ID_EX_latency <= ID_latency;
		    -- schedule result forwarding
		    ID_EX_fwd_ex_reg1 <= ID_fwd_ex_reg1;
		    ID_EX_fwd_ex_reg2 <= ID_fwd_ex_reg2;
		    ID_EX_fwd_ex_alu_op2 <= ID_fwd_ex_alu_op2;
		    ID_EX_fwd_mem_reg1 <= ID_fwd_mem_reg1;
		    ID_EX_fwd_mem_reg2 <= ID_fwd_mem_reg2;
		    ID_EX_fwd_mem_alu_op2 <= ID_fwd_mem_alu_op2;
		    -- debugging only
		    if C_debug then
			ID_EX_instruction <= IF_ID_instruction;
			ID_EX_PC <= IF_ID_PC;
			if (IF_ID_instruction /= x"00000000") then
			    D_instr <= D_instr + 1;
		        end if;
		    else
			ID_EX_instruction <= IF_ID_instruction; -- XXX MULT!!!
		    end if;
		end if;
	    else
		if ID_running then
		    ID_EX_cancel_next <= false;
		end if;
	    end if;
	end if;
    end process;

			
    --
    -- Pipeline stage 3: execute
    -- =========================
    --

    EX_running <= MEM_running; -- XXX revisit

    -- forward the results from later stages
    G_EX_forwarding:
    if C_result_forwarding generate
    EX_eff_reg1 <= MEM_eff_data when ID_EX_fwd_ex_reg1 else
      WB_eff_data when ID_EX_fwd_mem_reg1 else ID_EX_reg1_data;
    EX_eff_reg2 <= MEM_eff_data when ID_EX_fwd_ex_reg2 else
      WB_eff_data when ID_EX_fwd_mem_reg2 else ID_EX_reg2_data;
    EX_eff_alu_op2 <= MEM_eff_data when ID_EX_fwd_ex_alu_op2 else
      WB_eff_data when ID_EX_fwd_mem_alu_op2 else ID_EX_alu_op2;
    end generate; -- result_forwarding

    G_EX_no_forwarding:
    if not C_result_forwarding generate
    EX_eff_reg1 <= ID_EX_reg1_data;
    EX_eff_reg2 <= WB_eff_data when -- XXX revisit for C_load_aligner = false!
      not C_load_aligner and ID_EX_fwd_mem_reg2 else ID_EX_reg2_data;
    EX_eff_alu_op2 <= ID_EX_alu_op2;
    end generate; -- no result_forwarding

    -- instantiate the ALU
    alu: entity alu
    port map (
	x => EX_eff_reg1, y => EX_eff_alu_op2, seb => ID_EX_seb_cycle,
	addsubx => EX_from_alu_addsubx, logic => EX_from_alu_logic,
	funct => ID_EX_op_minor(1 downto 0), equal => EX_from_alu_equal
    );

    -- compute shift amount and function
    EX_2bit_add <= EX_eff_reg1(1 downto 0) + ID_EX_immediate(1 downto 0);
    EX_shamt <= EX_2bit_add & "000" when ID_EX_mem_cycle = '1' else
      EX_eff_reg1(4 downto 0) when ID_EX_immediate(2) = '1' -- shift variable
      else ID_EX_immediate(10 downto 6); -- shift immediate

    EX_shift_funct_8_16 <= "00" -- shift left logical
      when ID_EX_mem_cycle = '1' else ID_EX_immediate(1 downto 0);

    -- instantiate the barrel shifter
    shift: entity shift
    generic map (
	C_load_aligner => C_load_aligner
    )
    port map (
	shamt_8_16 => EX_shamt(4 downto 3), funct_8_16 => EX_shift_funct_8_16,
	shamt_1_2_4 => EX_MEM_shamt_1_2_4, funct_1_2_4 => EX_MEM_shift_funct,
	stage1_in => EX_MEM_mem_data_out, stage4_out => MEM_from_shift,
	stage8_in => EX_eff_reg2, stage16_out => EX_from_shift,
	mem_multicycle_lh_lb => MEM_WB_multicycle_lh_lb,
	mem_read_sign_extend_multicycle => EX_MEM_mem_read_sign_extend,
	mem_size_multicycle => EX_MEM_mem_size(0)
    );

    -- compute byte select lines for memory writes
    EX_mem_byte_we(0) <= ID_EX_mem_write when
      EX_2bit_add = "00" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '0') else '0';
    EX_mem_byte_we(1) <= ID_EX_mem_write when
      EX_2bit_add = "01" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '0') else '0';
    EX_mem_byte_we(2) <= ID_EX_mem_write when
      EX_2bit_add = "10" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '1') else '0';
    EX_mem_byte_we(3) <= ID_EX_mem_write when
      EX_2bit_add = "11" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '1') else '0';		

    -- MFHI, MFLO, link PC + 8 -- XXX what about MFC0 / MFC1?
    EX_from_alt <=
      R_hi_lo(63 downto 32) when C_mult_enable and
      ID_EX_op_major = "11" and ID_EX_op_minor(1) = '0' else
      R_hi_lo(31 downto 0) when C_mult_enable and ID_EX_op_major = "11"
      and ID_EX_op_minor(1) = '1' else ID_EX_PC_8 & "00";

    -- branch or not?
    process(ID_EX_branch_condition, EX_from_alu_equal, EX_eff_reg1)
    begin
	case ID_EX_branch_condition is
	when "010"  => -- bltz
	    EX_take_branch <= EX_eff_reg1(31) = '1';
	when "011"  => -- bgez
	    EX_take_branch <= EX_eff_reg1(31) = '0';
	when "100"  => -- beq
	    EX_take_branch <= EX_from_alu_equal;
	when "101"  => -- bne
	    EX_take_branch <= not EX_from_alu_equal;
	when "110"  => -- blez
	    EX_take_branch <= EX_eff_reg1(31) = '1' or EX_from_alu_equal;
	when "111"  => -- bgtz
	    EX_take_branch <= EX_eff_reg1(31) = '0' and not EX_from_alu_equal;
	when others =>
	    EX_take_branch <= false;
	end case;
    end process;

    process(clk)
    begin
	if rising_edge(clk) then
	    if MEM_running and EX_running and not MEM_cancel_EX then
		EX_MEM_mem_data_out <= EX_from_shift;
		EX_MEM_addsub_data <= EX_from_alu_addsubx(31 downto 0);
		EX_MEM_mem_size <= ID_EX_mem_size;
		EX_MEM_multicycle_lh_lb <= not C_load_aligner
		  and ID_EX_multicycle_lh_lb;
		EX_MEM_mem_byte_we <= EX_mem_byte_we;
		EX_MEM_shamt_1_2_4 <= EX_shamt(2 downto 0);
		EX_MEM_shift_funct <= ID_EX_immediate(1 downto 0);
		EX_MEM_op_major <= ID_EX_op_major;
		EX_MEM_branch_cycle <= ID_EX_branch_cycle;
		EX_MEM_branch_likely <= ID_EX_branch_likely;
		EX_MEM_bpredict_score <= ID_EX_bpredict_score;
		EX_MEM_bpredict_index <= ID_EX_bpredict_index;
		if ID_EX_branch_cycle then
		    EX_MEM_take_branch <= EX_take_branch;
		    if ID_EX_predict_taken then
			EX_MEM_branch_target <= ID_EX_PC_8;
		    else
			EX_MEM_branch_target <= ID_EX_branch_target;
		    end if;
		else
		    EX_MEM_take_branch <= false;
		end if;
		if ID_EX_op_major = "01" then
		    EX_MEM_logic_cycle <= '1';
		    -- SLT / SLTU / SLTI / SLTIU
		    EX_MEM_logic_data(31 downto 1) <= x"0000000" & "000";
		    if ID_EX_sign_extend then
			EX_MEM_logic_data(0) <= EX_from_alu_addsubx(32)
			  xor (EX_eff_reg1(31) xor EX_eff_alu_op2(31));
		    else
			EX_MEM_logic_data(0) <= EX_from_alu_addsubx(32);
		    end if;
		elsif ID_EX_jump_cycle or ID_EX_jump_register or
		  ID_EX_branch_cycle or ID_EX_op_major = "11" then
		    -- Store (link) PC + 8 address
		    EX_MEM_logic_cycle <= '1';
		    EX_MEM_logic_data <= EX_from_alt;
		else
		    EX_MEM_logic_data <= EX_from_alu_logic;
		    EX_MEM_logic_cycle <= ID_EX_op_minor(2);
		end if;
		if (C_movn_movz and ID_EX_cmov_cycle) then
		    if EX_from_alu_equal = ID_EX_cmov_condition then
			EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		    else
			EX_MEM_writeback_addr <= "00000";
		    end if;
		else
		    EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		end if;
		EX_MEM_mem_cycle <= ID_EX_mem_cycle;
		EX_MEM_latency <= ID_EX_latency(1);
		EX_MEM_mem_read_sign_extend <= ID_EX_mem_read_sign_extend;
		EX_MEM_branch_taken <= ID_EX_predict_taken;
		-- debugging only
		if C_debug then
		    EX_MEM_instruction <= ID_EX_instruction;
		    EX_MEM_PC <= ID_EX_PC;
		end if;
	    elsif MEM_running and (MEM_cancel_EX or not EX_running) then
		-- insert a bubble in the MEM stage
		EX_MEM_take_branch <= false;
		EX_MEM_branch_taken <= false;
		EX_MEM_branch_likely <= false;
		EX_MEM_writeback_addr <= "00000";
		EX_MEM_mem_cycle <= '0';
		EX_MEM_latency <= '0';
		-- debugging only
		if C_debug then
		    EX_MEM_instruction <= x"00000000";
		end if;
	    end if;
	end if;
    end process;


    --
    -- Pipeline stage 4: memory access
    -- ===============================
    --

    MEM_running <= EX_MEM_mem_cycle = '0' or dmem_data_ready = '1';

    MEM_eff_data <= EX_MEM_logic_data when EX_MEM_logic_cycle = '1'
      else EX_MEM_addsub_data;

    MEM_take_branch <= EX_MEM_take_branch xor EX_MEM_branch_taken;
    MEM_cancel_EX <= C_branch_likely and EX_MEM_branch_likely and
      not EX_MEM_take_branch;

    -- branch prediction
    G_bp_update_score:
    if C_branch_prediction generate
    MEM_bpredict_score <=
      "01" when EX_MEM_bpredict_score = "00" and EX_MEM_take_branch else
      "00" when EX_MEM_bpredict_score = "00" and not EX_MEM_take_branch else
      "10" when EX_MEM_bpredict_score = "01" and EX_MEM_take_branch else
      "00" when EX_MEM_bpredict_score = "01" and not EX_MEM_take_branch else
      "11" when EX_MEM_bpredict_score = "10" and EX_MEM_take_branch else
      "01" when EX_MEM_bpredict_score = "10" and not EX_MEM_take_branch else
      "11" when EX_MEM_bpredict_score = "11" and EX_MEM_take_branch else
      "10" when EX_MEM_bpredict_score = "11" and not EX_MEM_take_branch;
    MEM_bpredict_we <= '1' when EX_MEM_branch_cycle else '0';

    process(clk)
    begin
	if rising_edge(clk) then
	    if EX_MEM_branch_cycle then
		EX_MEM_branch_hist(11 downto 0) <=
		  EX_MEM_branch_hist(12 downto 1);
		if EX_MEM_take_branch then
		    EX_MEM_branch_hist(12) <= '1';
		else
		    EX_MEM_branch_hist(12) <= '0';
		end if;
	    end if;
	end if;
    end process;
    end generate;

    -- connect outbound signals for memory access
    dmem_addr <= EX_MEM_addsub_data(31 downto 2);
    dmem_data_out <= EX_MEM_mem_data_out;
    dmem_addr_strobe <= EX_MEM_mem_cycle;
    dmem_byte_we <= EX_MEM_mem_byte_we;

    -- memory output must be externally registered (it is with internal BRAM)
    -- i.e. dmem_data_in??? XXX what is the meaning of this - revisit!

    process(clk)
    begin
	if rising_edge(clk) then
	    MEM_WB_mem_data <= dmem_data_in;
	    if MEM_running then
		MEM_WB_mem_cycle <= EX_MEM_mem_cycle;
		MEM_WB_mem_read_sign_extend <= EX_MEM_mem_read_sign_extend;
		MEM_WB_mem_addr_offset <= EX_MEM_addsub_data(1 downto 0);
		MEM_WB_mem_size <= EX_MEM_mem_size;
		MEM_WB_writeback_addr <= EX_MEM_writeback_addr;
		MEM_WB_multicycle_lh_lb <= not C_load_aligner
		  and EX_MEM_multicycle_lh_lb;
		if EX_MEM_writeback_addr = "00000" then
		    MEM_WB_write_enable <= '0';
		else
		    MEM_WB_write_enable <= '1';
		end if;
		if EX_MEM_op_major = "10" then -- shift
		    MEM_WB_ex_data <= MEM_from_shift;
		else
		    MEM_WB_ex_data <= MEM_eff_data;
		end if;
		if C_debug then
		    MEM_WB_instruction <= EX_MEM_instruction; -- debugging only
		end if;
	    end if;
	end if;
    end process;

    --
    -- Pipeline stage 5: register writeback
    -- ====================================
    --

    -- WB_eff_data goes into bypass / forwarding muxes back to the EX stage
    WB_eff_data <= MEM_WB_mem_data when MEM_WB_mem_cycle = '1'
      else MEM_WB_ex_data;

    -- WB_writeback_data goes directly into register file's write port
    WB_writeback_data <= WB_eff_data when not C_load_aligner
      else WB_mem_data_aligned when MEM_WB_mem_cycle = '1'
      else MEM_WB_ex_data;

    -- instantiate memory load aligner
    G_pipelined_load_aligner:
    if C_load_aligner generate
    loadalign: entity loadalign
    port map (
	mem_read_sign_extend_pipelined => MEM_WB_mem_read_sign_extend,
	mem_size_pipelined => MEM_WB_mem_size,
	mem_addr_offset => MEM_WB_mem_addr_offset,
	mem_align_in => MEM_WB_mem_data, mem_align_out => WB_mem_data_aligned
    );
    end generate;


    --
    -- Multiplier unit, as a separate pipeline
    --
    G_multiplier:
    if C_mult_enable generate
    mul_res <= R_mul_a * R_mul_b; -- infer asynchronous signed multiplier
    process (clk)
    begin
	if falling_edge(clk) then
	    -- XXX revisit instruction decoding
	    if (ID_EX_op_major = "11" and
	      ID_EX_instruction(5 downto 1) = "01100") then
		if (ID_EX_instruction(0) = '0') then
		    -- signed
		    R_mul_a <= EX_eff_reg1(31) & EX_eff_reg1;
		    R_mul_b <= EX_eff_reg2(31) & EX_eff_reg2;
		else
		    -- unsigned
		    R_mul_a <= '0' & EX_eff_reg1;
		    R_mul_b <= '0' & EX_eff_reg2;
		end if;
	    end if;
	    -- XXX revisit R_hi_lo write enable
	    -- XXX don't update R_hi_lo if exception pending
	    R_hi_lo(63 downto 32) <= mul_res(63 downto 32);
	    R_hi_lo(31 downto 0) <= mul_res(31 downto 0);
	end if;
    end process;
    end generate; -- multiplier

    -- XXX performance counters
    G_perf_cnt:
    if C_debug generate
    process(clk)
    begin
	if rising_edge(clk) then
	    D_tsc <= D_tsc + 1;
	    if EX_MEM_branch_cycle then
		D_b_instr <= D_b_instr + 1;
	    end if;
	    if MEM_take_branch then
		D_b_taken <= D_b_taken + 1;
	    end if;
	end if;
    end process;
    end generate;

    -- mux for debugging probes
    G_with_trace_mux:
    if C_debug generate
    ID_EX_sign_extend_debug <= '1' when ID_EX_sign_extend else '0';

    debug_XXX(31 downto 29) <= "000";
    debug_XXX(28) <= '1' when ID_running else '0';
    debug_XXX(27 downto 25) <= "000";
    debug_XXX(24) <= '1' when EX_running else '0';
    debug_XXX(23 downto 21) <= "000";
    debug_XXX(20) <= '1' when MEM_running else '0';
    debug_XXX(19 downto 17) <= "000";
    debug_XXX(16) <= '1' when ID_EX_multicycle_lh_lb else '0';
    debug_XXX(15 downto 13) <= "000";
    debug_XXX(12) <= '1' when EX_MEM_multicycle_lh_lb else '0';
    debug_XXX(11 downto 9) <= "000";
    debug_XXX(8) <= '1' when ID_EX_cancel_next else '0';
    debug_XXX(7 downto 5) <= "000";
    debug_XXX(4) <= '1' when IF_ID_branch_delay_slot else '0';
    debug_XXX(3 downto 1) <= "000";
    debug_XXX(0) <= '1' when MEM_take_branch else '0';

    process(trace_addr)
    begin
	if trace_addr(5) = '0' then
	    trace_data <= reg_trace_data;
	else
	    case "000" & trace_addr(4 downto 0) is
	    when x"00" => trace_data <= IF_PC & "00";
	    when x"01" => trace_data <= IF_ID_PC & "00";
	    when x"02" => trace_data <= ID_EX_PC & "00";
	    when x"03" => trace_data <= EX_MEM_PC & "00";
	    when x"04" => trace_data <= imem_data_in;
	    when x"05" => trace_data <= IF_ID_instruction;
	    when x"06" => trace_data <= ID_EX_instruction;
	    when x"07" => trace_data <= EX_MEM_instruction;
	    when x"08" => trace_data <= ID_reg1_eff_data;
	    when x"09" => trace_data <= ID_reg2_eff_data;
	    when x"0a" => trace_data <= EX_eff_reg1;
	    when x"0b" => trace_data <= EX_eff_reg2;
	    when x"0c" => trace_data <= EX_eff_alu_op2;
	    when x"0d" => trace_data <= EX_MEM_addsub_data;
	    when x"0e" => trace_data <= EX_MEM_logic_data;
	    when x"10" => trace_data <= D_tsc;
	    when x"11" => trace_data <= D_instr;
	    when x"12" => trace_data <= D_b_instr;
	    when x"13" => trace_data <= D_b_taken;
	    --
	    when x"1a" => trace_data <= R_hi_lo(63 downto 32);
	    when x"1b" => trace_data <= R_hi_lo(31 downto 0);
	    -- when x"1b" => trace_data <= debug_XXX;
	    -- when x"1c" => trace_data <= BadVAddr;
	    -- when x"1d" => trace_data <= EPC;
	    -- when x"1e" => trace_data <= Status;
	    -- when x"1f" => trace_data <= Cause;
	    when others => trace_data <= x"00000000";
	    end case;
	end if;
    end process;
    end generate;

end Behavioral;

