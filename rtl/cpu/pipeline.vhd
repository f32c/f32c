--
-- Copyright 2008 - 2014 Marko Zec, University of Zagreb.        
--
-- Neither this file nor any parts of it may be used unless an explicit 
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id$

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;


entity pipeline is
    generic (
	-- ISA options
	C_big_endian: boolean;
	C_mult_enable: boolean;
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_ll_sc: boolean;
	C_movn_movz: boolean;
	C_exceptions: boolean := true;
	C_PC_mask: std_logic_vector(31 downto 0) := x"ffffffff";
	C_init_PC: std_logic_vector(31 downto 0) := x"00000000";

	-- COP0 options
	C_clk_freq: integer;
	C_cache: boolean := false;
	C_cpuid: integer := 0;
	C_cop0_count: boolean;
	C_cop0_config: boolean;

	-- optimization options
	C_result_forwarding: boolean := true;
	C_branch_prediction: boolean := true;
	C_bp_global_depth: integer := 6; -- range 2 to 12
	C_load_aligner: boolean := true;
	C_reg_IF_PC: boolean := false;
	C_register_technology: string := "unknown";

	-- debugging options
	C_debug: boolean := false
    );
    port (
	clk, reset: in std_logic;
	imem_addr_strobe: out std_logic;
	imem_addr: out std_logic_vector(31 downto 2);
	imem_data_in: in std_logic_vector(31 downto 0);
	imem_data_ready: in std_logic;
	dmem_addr_strobe: out std_logic;
	dmem_write: out std_logic;
	dmem_byte_sel: out std_logic_vector(3 downto 0);
	dmem_addr: out std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_data_ready: in std_logic;
	snoop_cycle: in std_logic;
	snoop_addr: in std_logic_vector(31 downto 2);
	flush_i_line, flush_d_line: out std_logic;
	intr: in std_logic;
	-- debugging only
	trace_addr: in std_logic_vector(5 downto 0);
	trace_data: out std_logic_vector(31 downto 0)
    );
end pipeline;

architecture Behavioral of pipeline is

    constant C_eff_init_PC: std_logic_vector(31 downto 0)
      := C_init_PC and C_PC_mask;

    signal debug_XXX: std_logic_vector(31 downto 0) := x"00000000";

    -- pipeline stage 1: instruction fetch
    signal IF_PC, IF_PC_next, IF_PC_ext_next: std_logic_vector(31 downto 2);
    signal IF_PC_incr: std_logic;
    signal IF_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_bpredict_re: std_logic;
    signal IF_instruction: std_logic_vector(31 downto 0);
    signal IF_data_ready, IF_fetch_complete, IF_need_refetch: boolean;
    -- boundary to stage 2
    signal IF_ID_fetch_in_progress, IF_ID_incomplete_branch: boolean;
    signal IF_ID_instruction: std_logic_vector(31 downto 0);
    signal IF_ID_bpredict_score: std_logic_vector(1 downto 0);
    signal IF_ID_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_ID_branch_delay_slot: boolean;
    signal IF_ID_PC, IF_ID_PC_4, IF_ID_PC_next: std_logic_vector(31 downto 2);
    signal IF_ID_EPC: std_logic_vector(31 downto 2);
    signal IF_ID_EIP: boolean;
	
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
    signal ID_read_alt: boolean;
    signal ID_alt_sel: std_logic_vector(2 downto 0);
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
    signal ID_seb_seh_cycle: boolean;
    signal ID_seb_seh_select: std_logic;
    signal ID_ll, ID_sc: boolean;
    signal ID_flush_i_line, ID_flush_d_line: std_logic;
    signal ID_wait, ID_cop0_write, ID_exception, ID_di, ID_ei: boolean;
    -- boundary to stage 3
    signal ID_EX_bpredict_score: std_logic_vector(1 downto 0);
    signal ID_EX_writeback_addr, ID_EX_cop0_addr: std_logic_vector(4 downto 0);
    signal ID_EX_reg1_data, ID_EX_reg2_data: std_logic_vector(31 downto 0);
    signal ID_EX_immediate, ID_EX_alu_op2: std_logic_vector(31 downto 0);
    signal ID_EX_fwd_ex_reg1, ID_EX_fwd_ex_reg2, ID_EX_fwd_ex_alu_op2: boolean;
    signal ID_EX_fwd_mem_reg1, ID_EX_fwd_mem_reg2: boolean;
    signal ID_EX_fwd_mem_alu_op2, ID_EX_sign_extend: boolean;
    signal ID_EX_cmov_cycle, ID_EX_cmov_condition: boolean;
    signal ID_EX_branch_cycle, ID_EX_branch_likely: boolean;
    signal ID_EX_cancel_next, ID_EX_predict_taken: boolean;
    signal ID_EX_bpredict_index: std_logic_vector(12 downto 0);
    signal ID_EX_branch_target: std_logic_vector(31 downto 2);
    signal ID_EX_branch_condition: std_logic_vector(2 downto 0);
    signal ID_EX_op_major: std_logic_vector(1 downto 0);
    signal ID_EX_op_minor: std_logic_vector(2 downto 0);
    signal ID_EX_read_alt: boolean;
    signal ID_EX_alt_sel: std_logic_vector(2 downto 0);
    signal ID_EX_mem_cycle, ID_EX_mem_write: std_logic;
    signal ID_EX_mem_size: std_logic_vector(1 downto 0);
    signal ID_EX_mem_read_sign_extend: std_logic;
    signal ID_EX_multicycle_lh_lb: boolean;
    signal ID_EX_latency: std_logic_vector(1 downto 0);
    signal ID_EX_seb_seh_cycle: boolean;
    signal ID_EX_seb_seh_select: std_logic;
    signal ID_EX_ll, ID_EX_sc: boolean;
    signal ID_EX_flush_i_line, ID_EX_flush_d_line: std_logic;
    signal ID_EX_branch_delay_slot: boolean;
    signal ID_EX_cop0_write, ID_EX_wait: boolean;
    signal ID_EX_exception, ID_EX_ei, ID_EX_di: boolean;
    signal ID_EX_EPC: std_logic_vector(31 downto 2);
    signal ID_EX_EIP, ID_EX_bubble: boolean;
    signal ID_EX_instruction: std_logic_vector(31 downto 0); -- debugging only
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
    signal EX_from_cop0: std_logic_vector(31 downto 0);
    signal EX_from_alu_equal: boolean;
    signal EX_2bit_add: std_logic_vector(1 downto 0);
    signal EX_mem_align_shamt: std_logic_vector(1 downto 0);
    signal EX_mem_byte_sel: std_logic_vector(3 downto 0);
    signal EX_take_branch: boolean;
    signal EX_branch_target: std_logic_vector(31 downto 2);
    -- boundary to stage 4
    signal EX_MEM_writeback_addr: std_logic_vector(4 downto 0);
    signal EX_MEM_addsub_data: std_logic_vector(31 downto 0);
    signal EX_MEM_logic_data: std_logic_vector(31 downto 0);
    signal EX_MEM_mem_data_out: std_logic_vector(31 downto 0);
    signal EX_MEM_branch_target: std_logic_vector(29 downto 0);
    signal EX_MEM_take_branch: boolean;
    signal EX_MEM_branch_cycle, EX_MEM_branch_taken: boolean;
    signal EX_MEM_branch_likely: boolean;
    signal EX_MEM_bpredict_score: std_logic_vector(1 downto 0);
    signal EX_MEM_branch_hist:
      std_logic_vector((C_bp_global_depth - 1) downto 0);
    signal EX_MEM_bpredict_index: std_logic_vector(12 downto 0);
    signal EX_MEM_latency: std_logic;
    signal EX_MEM_mem_cycle, EX_MEM_logic_cycle: std_logic;
    signal EX_MEM_mem_read_sign_extend: std_logic;
    signal EX_MEM_shamt_1_2_4: std_logic_vector(2 downto 0);
    signal EX_MEM_shift_funct: std_logic_vector(1 downto 0);
    signal EX_MEM_mem_size: std_logic_vector(1 downto 0);
    signal EX_MEM_multicycle_lh_lb: boolean;
    signal EX_MEM_mem_write: std_logic;
    signal EX_MEM_mem_byte_sel: std_logic_vector(3 downto 0);
    signal EX_MEM_op_major: std_logic_vector(1 downto 0);
    signal EX_MEM_flush_i_line, EX_MEM_flush_d_line: std_logic;
    signal EX_MEM_ll_bit: std_logic;
    signal EX_MEM_ll_addr: std_logic_vector(31 downto 2);
    signal EX_MEM_sc: boolean;
    signal EX_MEM_instruction: std_logic_vector(31 downto 0); -- debugging only
    signal EX_MEM_EIP: boolean;
	
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
    signal mul_res: signed(65 downto 0);
    signal R_mul_a, R_mul_b: signed(32 downto 0);
    signal R_hi_lo: std_logic_vector(63 downto 0);

    -- COP0
    signal R_reset: std_logic; -- registered reset input
    signal R_cop0_count: std_logic_vector(31 downto 0);
    signal R_cop0_config: std_logic_vector(31 downto 0);
    signal R_cop0_EPC: std_logic_vector(31 downto 0);
    signal R_cop0_EBASE: std_logic_vector(31 downto 2);
    signal R_cop0_EI: boolean := false;
    signal R_intr: std_logic;

    -- signals used for debugging only
    signal reg_trace_data: std_logic_vector(31 downto 0);
    signal D_instr, D_b_instr, D_b_taken: std_logic_vector(31 downto 0);

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
    --  revisit / simplify register file write-enable setting
    --	revisit MULT / MFHI / MFLO decoding (now done in EX stage!!!)
    --  commit MULT result in MEM stage (branch likely must cancel commit)!
    --  reintroduce area-optimized branch likely support as an option
    --	sort out the endianess story
    --	unaligned load / store instructions?
    --	revisit target_addr computation in idecode.vhd
    --	MTHI/MTLO
    --	division? - block on MFHI/MFLO if result not ready
    --	result forwarding: muxes instead of priority encoders?
    --	exceptions/interrupts
    --
    -- Believed to have been fixed already:
    --  cancel and restart an incomplete instruction fetch on branch!
    --	don't branch until branch delay slot fetched!!!
    --  MFC0/MTC0


    --
    -- Pipeline stage 1: instruction fetch
    -- ===================================
    --

    -- compute current and next program counter

    -- instruction word fetch: big / little endian
    IF_instruction <=
      imem_data_in(7 downto 0) & imem_data_in(15 downto 8) &
      imem_data_in(23 downto 16) & imem_data_in(31 downto 24) when C_big_endian
      else imem_data_in;

    imem_addr <= IF_PC_ext_next when C_cache else IF_PC;
    imem_addr_strobe <= not R_reset; -- XXX revisit!!!

    IF_data_ready <= imem_data_ready = '1';

    IF_fetch_complete <= MEM_take_branch or IF_data_ready;
    IF_need_refetch <= MEM_take_branch and
      (not IF_data_ready or IF_ID_fetch_in_progress);

    IF_PC <= EX_MEM_branch_target when not C_reg_IF_PC and MEM_take_branch
      else IF_ID_PC;

    IF_PC_next <=
      EX_branch_target when
	C_reg_IF_PC and (MEM_running and EX_running) and
	(EX_take_branch xor ID_EX_predict_taken)
      else IF_PC + 1 when
	MEM_take_branch and not IF_need_refetch and ID_running
      else IF_PC when
	MEM_take_branch and not IF_need_refetch
      else EX_MEM_branch_target when
	IF_need_refetch or IF_ID_incomplete_branch
      else ID_jump_target when
	ID_running and not ID_EX_cancel_next and
	(ID_jump_cycle or ID_jump_register or ID_predict_taken)
      else IF_PC + 1 when
	ID_running
      else IF_ID_PC_next; -- i.e. do not change
    IF_PC_ext_next <=
      IF_PC_next and C_PC_mask(31 downto 2) when IF_data_ready
      else IF_ID_PC; -- i.e. do not change

    process(clk)
    begin
	if rising_edge(clk) then
	    IF_ID_PC_next <= IF_PC_next and C_PC_mask(31 downto 2);
	    IF_ID_PC <= IF_PC_ext_next;
	    if not IF_data_ready then
		IF_ID_fetch_in_progress <= true;
	    else
		IF_ID_fetch_in_progress <= false;
	    end if;
	    if IF_need_refetch then
		IF_ID_incomplete_branch <= true;
	    elsif IF_data_ready then
		IF_ID_incomplete_branch <= false;
	    end if;
	    if IF_need_refetch or IF_ID_incomplete_branch then
		IF_ID_instruction <= x"00000000";
	    elsif ID_running then
		IF_ID_instruction <= IF_instruction;
		IF_ID_PC_4 <= IF_PC + 1 and C_PC_mask(31 downto 2);
		IF_ID_bpredict_index <= IF_bpredict_index;
		IF_ID_branch_delay_slot <=
		  ID_branch_cycle or ID_jump_cycle or ID_jump_register;
		if C_exceptions and EX_MEM_EIP then
		    if not IF_ID_EIP and not ID_EX_EIP then
			if not (ID_branch_cycle or ID_jump_cycle or
			  ID_jump_register or IF_ID_branch_delay_slot or
			  ID_EX_branch_delay_slot) then
			    IF_ID_EIP <= true;
			    IF_ID_instruction <= x"03400008"; -- jr k0
			else
			    IF_ID_instruction <= x"00000000";
			end if;
		    end if;
		    IF_ID_branch_delay_slot <= false;
		end if;
		if C_exceptions then
		    if IF_ID_EIP then
			IF_ID_EIP <= false;
			IF_ID_instruction <= x"00000000";
		    end if;
		    IF_ID_EPC <= IF_PC;
		end if;
	    elsif ID_EX_branch_likely and not EX_take_branch then
		IF_ID_instruction <= x"00000000";
	    end if;
	end if;
    end process;
	
    G_bp_scoretable:
    if C_branch_prediction generate
    IF_bpredict_index(12 downto (13 - C_bp_global_depth)) <=
      EX_MEM_branch_hist xor IF_PC(14 downto (15 - C_bp_global_depth));
    IF_bpredict_index((12 - C_bp_global_depth) downto 0) <=
      IF_PC((14 - C_bp_global_depth) downto 2);
    IF_bpredict_re <= '1' when ID_running else '0';

    bptrace: entity work.bptrace
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
    idecode: entity work.idecode
    generic map (
	C_cache => C_cache,
	C_ll_sc => C_ll_sc,
	C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend,
	C_movn_movz => C_movn_movz,
	C_exceptions => C_exceptions
    )
    port map (
	instruction => IF_ID_instruction,
	reg1_addr => ID_reg1_addr, reg2_addr => ID_reg2_addr,
	reg1_zero => ID_reg1_zero, reg2_zero => ID_reg2_zero,
	immediate_value => ID_immediate, use_immediate => ID_use_immediate,
	cmov_cycle => ID_cmov_cycle, cmov_condition => ID_cmov_condition,
	sign_extension => ID_sign_extension,
	read_alt => ID_read_alt, alt_sel => ID_alt_sel,
	target_addr => ID_writeback_addr, op_major => ID_op_major,
	op_minor => ID_op_minor, mem_cycle => ID_mem_cycle,
	branch_cycle => ID_branch_cycle, branch_likely => ID_branch_likely,
	jump_cycle => ID_jump_cycle, jump_register => ID_jump_register,
	branch_condition => ID_branch_condition, sign_extend => ID_sign_extend,
	mem_write => ID_mem_write, mem_size => ID_mem_size,
	mem_read_sign_extend => ID_mem_read_sign_extend,
	latency => ID_latency, ignore_reg2 => ID_ignore_reg2,
	seb_seh_cycle => ID_seb_seh_cycle, seb_seh_select => ID_seb_seh_select,
	ll => ID_ll, sc => ID_sc,
	cop0_wait => ID_wait, cop0_write => ID_cop0_write,
	exception => ID_exception, di => ID_di, ei => ID_ei,
	flush_i_line => ID_flush_i_line, flush_d_line => ID_flush_d_line
    );

    -- three- or four-ported register file: 2(3) async reads, 1 sync write
    regfile: entity work.reg1w2r
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
    ID_running <= IF_fetch_complete and (ID_EX_cancel_next or
      (EX_running and not ID_EX_multicycle_lh_lb and
      not ID_load_align_hazard and not ID_jump_register_hazard and
      (ID_reg1_zero or ID_reg1_addr /= ID_EX_writeback_addr or
      ID_EX_latency(0) = '0') and (ID_ignore_reg2 or
      ID_reg2_addr /= ID_EX_writeback_addr or ID_EX_latency(0) = '0')));
    end generate;

    G_ID_no_forwarding:
    if not C_result_forwarding generate
    ID_running <= IF_fetch_complete and (ID_EX_cancel_next or
      (EX_running and not ID_EX_multicycle_lh_lb and
      not ID_load_align_hazard and not ID_jump_register_hazard and
      not (ID_fwd_ex_reg1 or ID_fwd_mem_reg1)
      and (ID_ignore_reg2 or not (ID_fwd_ex_reg2 or ID_fwd_mem_reg2))));
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
    ID_branch_target <= C_PC_mask(31 downto 2) and (IF_ID_PC_4 +
      (ID_sign_extension(13 downto 0) & IF_ID_instruction(15 downto 0)));

    -- branch prediction
    ID_predict_taken <= C_branch_prediction
      and ID_branch_cycle and IF_ID_bpredict_score(1) = '1';

    -- compute jump target
    ID_jump_target <= ID_reg1_data(31 downto 2) when ID_jump_register
      else ID_branch_target when ID_predict_taken
      else IF_ID_PC_4(31 downto 28) & IF_ID_instruction(25 downto 0);

    process(clk)
    begin
	if rising_edge(clk) then
	    if EX_running then
		if not C_load_aligner and ID_EX_multicycle_lh_lb and
		  not MEM_cancel_EX then
		    -- multicycle load aligner
		    -- byte / half word load, insert an arithm shift right cycle
		    -- XXX must stall the ID stage - revisit!!!
		    ID_EX_multicycle_lh_lb <= not EX_MEM_multicycle_lh_lb;
		    ID_EX_mem_cycle <= '0';
		    ID_EX_op_major <= OP_MAJOR_SHIFT;
		    ID_EX_immediate(2) <= '0'; -- shift immediate
		    ID_EX_immediate(1 downto 0) <= "10"; -- shift right logical
		    if not EX_MEM_multicycle_lh_lb then
			-- shift amount
			ID_EX_immediate(10 downto 6) <=
			  EX_mem_align_shamt & "000";
		    end if;
		    if MEM_take_branch and not ID_running and
		      IF_fetch_complete then
			ID_EX_cancel_next <= true;
		    end if;
		    if ID_running then
			ID_EX_cancel_next <= false;
		    end if;
		    if true or C_debug then -- XXX mult depends on C_debug!!!
			ID_EX_instruction <= x"00000001"; -- debugging only
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= '0';
			ID_EX_flush_d_line <= '0';
		    end if;
		    -- schedule forwarding of memory read
		    ID_EX_fwd_ex_reg1 <= false;
		    ID_EX_fwd_ex_reg2 <= false;
		    ID_EX_fwd_ex_alu_op2 <= false;
		    ID_EX_fwd_mem_reg1 <= false;
		    ID_EX_fwd_mem_reg2 <= true;
		    ID_EX_fwd_mem_alu_op2 <= false;
		elsif not ID_running or (not IF_ID_branch_delay_slot and
		  (MEM_take_branch or ID_EX_cancel_next)) or
		  (C_exceptions and EX_MEM_EIP) then
		    -- insert a bubble if branching or ID stage is stalled
		    ID_EX_writeback_addr <= MIPS32_REG_ZERO; -- NOP
		    ID_EX_mem_cycle <= '0';
		    ID_EX_mem_write <= '0';
		    ID_EX_multicycle_lh_lb <= false;
		    ID_EX_branch_cycle <= false;
		    ID_EX_branch_likely <= false;
		    ID_EX_predict_taken <= false;
		    if MEM_take_branch and not ID_running and
		      IF_fetch_complete then
			ID_EX_cancel_next <= true;
		    end if;
		    if ID_running then
			ID_EX_cancel_next <= false;
		    end if;
		    if true or C_debug then -- XXX mult depends on C_debug!!!
			ID_EX_instruction <= x"00000000"; -- debugging only
		    end if;
		    if C_ll_sc then
		        ID_EX_ll <= false;
		        ID_EX_sc <= false;
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= '0';
			ID_EX_flush_d_line <= '0';
		    end if;
		    ID_EX_wait <= false; -- XXX move under C_exceptions
		    if C_exceptions then
			ID_EX_bubble <= true;
			ID_EX_cop0_write <= false;
			ID_EX_exception <= false;
			ID_EX_ei <= false;
			ID_EX_di <= false;
			ID_EX_EIP <= IF_ID_EIP;
			if EX_MEM_EIP then
			    ID_EX_branch_delay_slot <= false;
			end if;
		    end if;
		    -- Don't care bits (optimization hints)
		    ID_EX_reg1_data <= (others => '-');
		    ID_EX_reg2_data <= (others => '-');
		    ID_EX_alu_op2 <= (others => '-');
		    ID_EX_immediate <= (others => '-');
		    ID_EX_cop0_addr <= (others => '-');
		    ID_EX_op_major <= (others => '-');
		    ID_EX_op_minor <= (others => '-');
		    ID_EX_mem_size <= (others => '-');
		    ID_EX_branch_condition <= (others => '-');
		    ID_EX_bpredict_score <= (others => '-');
		    ID_EX_bpredict_index <= (others => '-');
		    ID_EX_latency <= (others => '-');
		else
		    -- propagate the next instruction from ID to EX stage
		    ID_EX_reg1_data <= ID_reg1_eff_data;
		    ID_EX_reg2_data <= ID_reg2_eff_data;
		    ID_EX_alu_op2 <= ID_alu_op2;
		    ID_EX_immediate <= ID_immediate;
		    ID_EX_cop0_addr <= IF_ID_instruction(15 downto 11);
		    ID_EX_sign_extend <= ID_sign_extend;
		    ID_EX_op_major <= ID_op_major;
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
		    ID_EX_branch_target <= ID_branch_target;
		    ID_EX_seb_seh_cycle <= ID_seb_seh_cycle;
		    ID_EX_seb_seh_select <= ID_seb_seh_select;
		    ID_EX_alt_sel <= ID_alt_sel;
		    ID_EX_read_alt <= ID_read_alt;
		    ID_EX_writeback_addr <= ID_writeback_addr;
		    ID_EX_mem_cycle <= ID_mem_cycle;
		    ID_EX_branch_cycle <= ID_branch_cycle;
		    ID_EX_branch_likely <= ID_branch_likely;
		    ID_EX_predict_taken <= ID_predict_taken;
		    ID_EX_bpredict_score <= IF_ID_bpredict_score;
		    ID_EX_bpredict_index <= IF_ID_bpredict_index;
		    ID_EX_latency <= ID_latency;
		    ID_EX_wait <= ID_wait; -- XXX move under C_exceptions
		    if C_ll_sc then
		        ID_EX_ll <= ID_ll;
		        ID_EX_sc <= ID_sc;
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= ID_flush_i_line;
			ID_EX_flush_d_line <= ID_flush_d_line;
		    end if;
		    if C_exceptions then
			ID_EX_bubble <= false;
			ID_EX_cop0_write <= ID_cop0_write;
			ID_EX_exception <= ID_exception;
			ID_EX_EIP <= IF_ID_EIP;
			ID_EX_ei <= ID_ei;
			ID_EX_di <= ID_di;
			ID_EX_EPC <= IF_ID_EPC;
			ID_EX_branch_delay_slot <= IF_ID_branch_delay_slot;
		    end if;
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
			D_instr <= D_instr + 1;
		    else
			ID_EX_instruction <= IF_ID_instruction; -- XXX MULT!!!
		    end if;
		end if;
	    else
		if C_cop0_count then
		    ID_EX_wait <= ID_EX_wait and R_cop0_count(9 downto 2) /= 0;
		    if R_intr = '1' then
			ID_EX_wait <= false;
		    end if;
		end if;
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

    -- When result forwarding muxes are not configured, stall the pipeline
    -- until the results from all instructions preceding a branch instruction
    -- are flushed or stored in the register file.
    -- XXX revisit!  jump cycles?
    EX_running <= MEM_running and not ID_EX_wait and
      (C_result_forwarding or not ID_EX_branch_cycle
      or EX_MEM_writeback_addr = MIPS32_REG_ZERO);

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
    alu: entity work.alu
    generic map (
	C_sign_extend => C_sign_extend
    )
    port map (
	x => EX_eff_reg1, y => EX_eff_alu_op2,
	seb_seh_cycle => ID_EX_seb_seh_cycle,
	seb_seh_select => ID_EX_seb_seh_select,
	addsubx => EX_from_alu_addsubx, logic => EX_from_alu_logic,
	funct => ID_EX_op_minor(1 downto 0), equal => EX_from_alu_equal
    );

    -- compute shift amount and function
    EX_2bit_add <= EX_eff_reg1(1 downto 0) + ID_EX_immediate(1 downto 0);
    EX_mem_align_shamt <= "00" when ID_EX_mem_size(1) = '1' else
      EX_2bit_add when not C_big_endian else
      not(EX_2bit_add(1)) & '0' when ID_EX_mem_size = "01" else
      "00" when EX_2bit_add = "11" else
      "01" when EX_2bit_add = "10" else
      "10" when EX_2bit_add = "01" else
      "11" when EX_2bit_add = "00";
    EX_shamt <= EX_mem_align_shamt & "---" when ID_EX_mem_cycle = '1' else
      EX_eff_reg1(4 downto 0) when ID_EX_immediate(2) = '1' -- shift variable
      else ID_EX_immediate(10 downto 6); -- shift immediate

    EX_shift_funct_8_16 <= "00" when ID_EX_mem_cycle = '1' -- sll
      else ID_EX_immediate(1 downto 0);

    -- instantiate the barrel shifter
    shift: entity work.shift
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

    -- compute byte select lines
    EX_mem_byte_sel(0) <= '1' when
      EX_2bit_add = "00" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '0') else '0';
    EX_mem_byte_sel(1) <= '1' when
      EX_2bit_add = "01" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '0') else '0';
    EX_mem_byte_sel(2) <= '1' when
      EX_2bit_add = "10" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '1') else '0';
    EX_mem_byte_sel(3) <= '1' when
      EX_2bit_add = "11" or ID_EX_mem_size(1) = '1' or
      (ID_EX_mem_size(0) = '1' and EX_2bit_add(1) = '1') else '0';		

    -- MFHI, MFLO, MFC0, link PC + 8
    with ID_EX_alt_sel select
    EX_from_alt <=
      R_hi_lo(63 downto 32) when ALT_HI,
      R_hi_lo(31 downto 0) when ALT_LO,
      EX_from_cop0 when ALT_COP0,
      IF_ID_PC_4 & "00" when others;

    -- COP0 outbound mux
    with ID_EX_cop0_addr select
    EX_from_cop0 <=
      R_cop0_count when MIPS_COP0_COUNT,
      R_cop0_config when MIPS_COP0_CONFIG,
      R_cop0_EPC when MIPS_COP0_EXC_PC,
      R_cop0_EBASE & "00" when MIPS_COP0_EBASE, -- XXX testing, remove this!
      (others => '-') when others;

    -- branch or not?
    process(ID_EX_branch_cycle, ID_EX_branch_condition, EX_from_alu_equal,
      EX_eff_reg1)
    begin
	if ID_EX_branch_cycle then
	    case ID_EX_branch_condition is
	    when TEST_LTZ => EX_take_branch <= EX_eff_reg1(31) = '1';
	    when TEST_GEZ => EX_take_branch <= EX_eff_reg1(31) = '0';
	    when TEST_EQ  => EX_take_branch <= EX_from_alu_equal;
	    when TEST_NE  => EX_take_branch <= not EX_from_alu_equal;
	    when TEST_LEZ =>
	      EX_take_branch <= EX_eff_reg1(31) = '1' or EX_from_alu_equal;
	    when TEST_GTZ =>
	      EX_take_branch <= EX_eff_reg1(31) = '0' and not EX_from_alu_equal;
	    when others =>
	      EX_take_branch <= false;
	    end case;
	else
	    EX_take_branch <= false;
	end if;
    end process;

    EX_branch_target <= IF_ID_PC_4 when ID_EX_predict_taken
      else ID_EX_branch_target;

    process(clk)
    begin
	if rising_edge(clk) then
	    if C_ll_sc then
		if ID_EX_ll then
		    EX_MEM_ll_bit <= '1';
		    EX_MEM_ll_addr(19 downto 2) <=
		      EX_from_alu_addsubx(19 downto 2); -- XXX
		else
		    if snoop_cycle = '1' and EX_MEM_ll_addr = snoop_addr then
			EX_MEM_ll_bit <= '0';
		    end if;
		end if;
	    end if;

	    if C_exceptions and ID_EX_EIP then
		EX_MEM_EIP <= false;
	    end if;

	    R_intr <= intr;

	    if MEM_running and (MEM_cancel_EX or not EX_running) then
		-- insert a bubble in the MEM stage
		EX_MEM_take_branch <= false;
		EX_MEM_branch_taken <= false;
		EX_MEM_branch_cycle <= false;
		EX_MEM_branch_likely <= false;
		EX_MEM_writeback_addr <= MIPS32_REG_ZERO;
		EX_MEM_mem_cycle <= '0';
		EX_MEM_latency <= '0';
		if C_ll_sc then
		    EX_MEM_sc <= false;
		end if;
		if C_cache then
		    EX_MEM_flush_i_line <= '0';
		    EX_MEM_flush_d_line <= '0';
		end if;
		-- debugging only
		if C_debug then
		    EX_MEM_instruction <= x"00000000";
		end if;
	    elsif MEM_running and EX_running and not MEM_cancel_EX then
		EX_MEM_mem_data_out <= EX_from_shift;
		EX_MEM_addsub_data <= EX_from_alu_addsubx(31 downto 0);
		EX_MEM_mem_size <= ID_EX_mem_size;
		EX_MEM_multicycle_lh_lb <= not C_load_aligner
		  and ID_EX_multicycle_lh_lb;
		EX_MEM_mem_cycle <= ID_EX_mem_cycle;
		EX_MEM_mem_write <= ID_EX_mem_write;
		EX_MEM_mem_byte_sel <= EX_mem_byte_sel;
		EX_MEM_shamt_1_2_4 <= EX_shamt(2 downto 0);
		EX_MEM_shift_funct <= ID_EX_immediate(1 downto 0);
		EX_MEM_op_major <= ID_EX_op_major;
		EX_MEM_branch_cycle <= ID_EX_branch_cycle;
		EX_MEM_branch_likely <= ID_EX_branch_likely;
		EX_MEM_bpredict_score <= ID_EX_bpredict_score;
		EX_MEM_bpredict_index <= ID_EX_bpredict_index;
		EX_MEM_take_branch <= EX_take_branch;
		EX_MEM_branch_taken <= ID_EX_predict_taken;
		if ID_EX_branch_cycle then
		    EX_MEM_branch_target <= EX_branch_target;
		end if;
		if C_movn_movz and ID_EX_cmov_cycle then
		    if (EX_eff_reg2 = x"00000000") = ID_EX_cmov_condition then
			EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		    else
			EX_MEM_writeback_addr <= MIPS32_REG_ZERO;
		    end if;
		else
		    EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		end if;
	        if C_exceptions and not EX_MEM_EIP then
		    if ID_EX_ei then
			R_cop0_EI <= true;
		    end if;
		    if ID_EX_di then
			R_cop0_EI <= false;
		    end if;
		    if ID_EX_cop0_write then
			if ID_EX_cop0_addr = MIPS_COP0_EXC_PC then
			    R_cop0_EPC <= EX_eff_reg2 and C_PC_mask;
			end if;
			if ID_EX_cop0_addr = MIPS_COP0_EBASE then
			    R_cop0_EBASE <= EX_eff_reg2(31 downto 2)
			      and C_PC_mask(31 downto 2);
			end if;
		    end if;
		end if;
		if C_exceptions and R_cop0_EI and
--		  not ID_EX_branch_delay_slot and
		  not ID_EX_bubble and
		  (ID_EX_exception or R_intr = '1') then
		    R_cop0_EI <= false; -- disable all exceptions
		    EX_MEM_EIP <= true; -- signal exception in progress
		    R_cop0_EPC(31 downto 2) <=
		      ID_EX_EPC and C_PC_mask(31 downto 2);
		    if ID_EX_branch_delay_slot then
			R_cop0_EPC(1 downto 0) <= "01";
		    else
			R_cop0_EPC(1 downto 0) <= "00";
		    end if;
		    -- copy EBASE to k0
		    EX_MEM_op_major <= OP_MAJOR_ALT;
		    EX_MEM_logic_cycle <= '1';
		    EX_MEM_logic_data <= R_cop0_EBASE & "00";
		    EX_MEM_writeback_addr <= MIPS32_REG_K0;
		    -- nullify the rest of the interrupted instruction
		    EX_MEM_take_branch <= false;
		    EX_MEM_branch_taken <= false;
		    EX_MEM_branch_cycle <= false;
		    EX_MEM_branch_likely <= false;
		    EX_MEM_mem_cycle <= '0';
		    if C_ll_sc then
			EX_MEM_sc <= false;
		    end if;
		    if C_cache then
			EX_MEM_flush_i_line <= '0';
			EX_MEM_flush_d_line <= '0';
		    end if;
		elsif ID_EX_op_major = OP_MAJOR_SLT then
		    EX_MEM_logic_cycle <= '1';
		    EX_MEM_logic_data(31 downto 1) <= x"0000000" & "000";
		    if ID_EX_sign_extend then
			EX_MEM_logic_data(0) <= EX_from_alu_addsubx(32)
			  xor (EX_eff_reg1(31) xor EX_eff_alu_op2(31));
		    else
			EX_MEM_logic_data(0) <= EX_from_alu_addsubx(32);
		    end if;
		elsif ID_EX_read_alt then
		    -- PC + 8, MFHI, MFLO, MTC0
		    EX_MEM_logic_cycle <= '1';
		    EX_MEM_logic_data <= EX_from_alt;
		else
		    EX_MEM_logic_data <= EX_from_alu_logic;
		    EX_MEM_logic_cycle <= ID_EX_op_minor(2);
		end if;
		EX_MEM_latency <= ID_EX_latency(1);
		EX_MEM_mem_read_sign_extend <= ID_EX_mem_read_sign_extend;
		if C_ll_sc then
		    EX_MEM_sc <= ID_EX_sc;
		    if ID_EX_sc and EX_MEM_ll_bit = '0' then
			EX_MEM_mem_cycle <= '0';
		    end if;
		end if;
		if C_cache then
		    EX_MEM_flush_i_line <= ID_EX_flush_i_line;
		    EX_MEM_flush_d_line <= ID_EX_flush_d_line;
		end if;
		-- debugging only
		if C_debug then
		    EX_MEM_instruction <= ID_EX_instruction;
		end if;
	    elsif C_ll_sc and EX_MEM_sc and EX_MEM_ll_bit = '0' then
		EX_MEM_mem_cycle <= '0';
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
    MEM_cancel_EX <= (C_branch_likely and EX_MEM_branch_likely and
      not EX_MEM_take_branch); -- or (C_exceptions and EX_MEM_EIP);

    -- branch prediction
    G_bp_update_score:
    if C_branch_prediction generate
    MEM_bpredict_we <= '1' when EX_MEM_branch_cycle else '0';
    process(clk)
    begin
	if falling_edge(clk) then
	    if EX_MEM_take_branch then
		case EX_MEM_bpredict_score is
		    when BP_STRONG_NOT_TAKEN =>
			MEM_bpredict_score <= BP_WEAK_NOT_TAKEN;
		    when BP_WEAK_NOT_TAKEN =>
			MEM_bpredict_score <= BP_WEAK_TAKEN;
		    when BP_WEAK_TAKEN =>
			MEM_bpredict_score <= BP_STRONG_TAKEN;
		    when BP_STRONG_TAKEN =>
			MEM_bpredict_score <= BP_STRONG_TAKEN;
		    when others =>
			-- do nothing: appease Xilinx synthesizer
		end case;
	    else
		case EX_MEM_bpredict_score is
		    when BP_STRONG_NOT_TAKEN =>
			MEM_bpredict_score <= BP_STRONG_NOT_TAKEN;
		    when BP_WEAK_NOT_TAKEN =>
			MEM_bpredict_score <= BP_STRONG_NOT_TAKEN;
		    when BP_WEAK_TAKEN =>
			MEM_bpredict_score <= BP_WEAK_NOT_TAKEN;
		    when BP_STRONG_TAKEN =>
			MEM_bpredict_score <= BP_WEAK_TAKEN;
		    when others =>
			-- do nothing: appease Xilinx synthesizer
		end case;
	    end if;
	end if;
	if rising_edge(clk) then
	    if EX_MEM_branch_cycle then
		EX_MEM_branch_hist((C_bp_global_depth - 2) downto 0) <=
		  EX_MEM_branch_hist((C_bp_global_depth - 1) downto 1);
		if EX_MEM_take_branch then
		    EX_MEM_branch_hist(C_bp_global_depth - 1) <= '1';
		else
		    EX_MEM_branch_hist(C_bp_global_depth - 1) <= '0';
		end if;
	    end if;
	end if;
    end process;
    end generate;

    -- connect outbound signals for memory access
    dmem_addr_strobe <= EX_MEM_mem_cycle;
    dmem_write <= EX_MEM_mem_write;
    dmem_byte_sel <= EX_MEM_mem_byte_sel;
    dmem_addr <= EX_MEM_addsub_data(31 downto 2);
    dmem_data_out <= EX_MEM_mem_data_out(7 downto 0) &
      EX_MEM_mem_data_out(15 downto 8) & EX_MEM_mem_data_out(23 downto 16) &
      EX_MEM_mem_data_out(31 downto 24) when C_big_endian
      else EX_MEM_mem_data_out;
    flush_i_line <= EX_MEM_flush_i_line;
    flush_d_line <= EX_MEM_flush_d_line;

    -- memory output must be externally registered (it is with internal BRAM)
    -- inbound data word: big / little endian
    MEM_data_in <= dmem_data_in(7 downto 0) & dmem_data_in(15 downto 8) &
      dmem_data_in(23 downto 16) & dmem_data_in(31 downto 24) when C_big_endian
      else dmem_data_in;

    process(clk)
    begin
	if rising_edge(clk) then
	    if MEM_running then
		if C_ll_sc and EX_MEM_sc then
		    MEM_WB_mem_cycle <= '0';
		else
		    MEM_WB_mem_cycle <= EX_MEM_mem_cycle;
		end if;
		MEM_WB_mem_read_sign_extend <= EX_MEM_mem_read_sign_extend;
		MEM_WB_mem_addr_offset <= EX_MEM_addsub_data(1 downto 0);
		MEM_WB_mem_size <= EX_MEM_mem_size;
		MEM_WB_writeback_addr <= EX_MEM_writeback_addr;
		MEM_WB_multicycle_lh_lb <= not C_load_aligner
		  and EX_MEM_multicycle_lh_lb;
		if EX_MEM_writeback_addr = MIPS32_REG_ZERO then
		    MEM_WB_write_enable <= '0';
		else
		    MEM_WB_write_enable <= '1';
		end if;
		MEM_WB_mem_data <= MEM_data_in;
		if EX_MEM_op_major = OP_MAJOR_SHIFT then
		    MEM_WB_ex_data <= MEM_from_shift;
		elsif C_ll_sc and EX_MEM_sc then
		    MEM_WB_ex_data <= x"0000000" & "000" & EX_MEM_mem_cycle;
		else
		    MEM_WB_ex_data <= MEM_eff_data;
		end if;
		if C_debug then
		    MEM_WB_instruction <= EX_MEM_instruction; -- debugging only
		end if;
	    else
		MEM_WB_write_enable <= '0';
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
    loadalign: entity work.loadalign
    generic map (
	C_big_endian => C_big_endian
    )
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
	    if (ID_EX_op_major = OP_MAJOR_ALT and
	      ID_EX_instruction(5 downto 1) = "01100") then
		R_mul_a(31 downto 0) <= CONV_SIGNED(UNSIGNED(EX_eff_reg1), 32);
		R_mul_b(31 downto 0) <= CONV_SIGNED(UNSIGNED(EX_eff_reg2), 32);
		if (ID_EX_instruction(0) = '0') then
		    -- signed
		    R_mul_a(32) <= EX_eff_reg1(31);
		    R_mul_b(32) <= EX_eff_reg2(31);
		else
		    -- unsigned
		    R_mul_a(32) <= '0';
		    R_mul_b(32) <= '0';
		end if;
	    end if;
	    -- XXX revisit R_hi_lo write enable
	    -- XXX don't update R_hi_lo if exception pending?
	    R_hi_lo(63 downto 32) <=
	      conv_std_logic_vector(mul_res(63 downto 32), 32);
	    R_hi_lo(31 downto 0) <=
	      conv_std_logic_vector(mul_res(31 downto 0), 32);
	end if;
    end process;
    end generate; -- multiplier

    -- COP0
    G_cop0_count:
    if C_cop0_count generate
    process(clk)
    begin
	if rising_edge(clk) then
	    R_reset <= reset;
	    R_cop0_count <= R_cop0_count + 1;
	end if;
    end process;
    end generate;
    G_not_cop0_count:
    if not C_cop0_count generate
    R_cop0_count <= (others => '-'); 
    end generate;

    -- R_cop0_config
    G_cop0_config:
    if C_cop0_config generate
    R_cop0_config(31) <= '0'; -- no config1 register
    with C_clk_freq select R_cop0_config(30 downto 16) <=
	"10" & conv_std_logic_vector(100, 13) when 33,
	"10" & conv_std_logic_vector(200, 13) when 66,
	"11" & conv_std_logic_vector(325, 13) when 81,
	"10" & conv_std_logic_vector(400, 13) when 133,
	"10" & conv_std_logic_vector(500, 13) when 166,
	"00" & conv_std_logic_vector(C_clk_freq, 13) when others;
    R_cop0_config(15) <= '1' when C_big_endian else '0';
    R_cop0_config(14 downto 4) <= (others => '-');
    R_cop0_config(3 downto 0) <= conv_std_logic_vector(C_cpuid, 4);
    end generate;
    G_not_cop0_config:
    if not C_cop0_config generate
    R_cop0_config <= (others => '-');
    end generate;

    -- XXX performance counters
    G_perf_cnt:
    if C_debug generate
    process(clk)
    begin
	if rising_edge(clk) then
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

    debug_XXX(28) <= '1' when R_cop0_EI else '0';
    debug_XXX(24) <= '1' when IF_ID_EIP else '0';
    debug_XXX(20) <= '1' when ID_EX_EIP else '0';
    debug_XXX(16) <= '1' when EX_MEM_EIP else '0';
    debug_XXX(12) <= '1' when ID_running else '0';
    debug_XXX(8) <= '1' when EX_running else '0';
    debug_XXX(4) <= '1' when IF_ID_branch_delay_slot else '0';
    debug_XXX(0) <= '1' when ID_EX_branch_delay_slot else '0';


    with ("00" & trace_addr) select
    trace_data <=
	IF_PC & "00"		when x"20",
	IF_ID_EPC & "00"	when x"21",
	ID_EX_EPC & "00"	when x"22",
	imem_data_in		when x"24",
	IF_ID_instruction	when x"25",
	ID_EX_instruction	when x"26",
	EX_MEM_instruction	when x"27",
	ID_reg1_eff_data	when x"28",
	ID_reg2_eff_data	when x"29",
	EX_eff_reg1		when x"2a",
	EX_eff_reg2		when x"2b",
	EX_eff_alu_op2		when x"2c",
	EX_MEM_addsub_data	when x"2d",
	EX_MEM_logic_data	when x"2e",
	-- dmem_data_out	when x"2f",
	dmem_data_in		when x"30",
	--
	R_cop0_count		when x"34",
	D_instr			when x"35",
	D_b_instr		when x"36",
	D_b_taken		when x"37",
	--
	debug_XXX		when x"39",
	R_hi_lo(31 downto 0)	when x"3a",
	R_hi_lo(63 downto 32)	when x"3b",
	--
	R_cop0_EBASE & "00"	when x"3c",
	R_cop0_EPC 	 	when x"3d",
	--
	reg_trace_data		when others;

    end generate;

    G_without_trace_mux:
    if not C_debug generate
	--trace_data <= x"00000000";
	trace_data(7 downto 4) <= x"f";
	trace_data(0) <= '1' when R_cop0_EI else '0';
	trace_data(1) <= '1' when IF_ID_EIP else '0';
	trace_data(2) <= '1' when EX_MEM_EIP else '0';
	trace_data(3) <= '1' when ID_EX_wait else '0';

    end generate;
end Behavioral;

