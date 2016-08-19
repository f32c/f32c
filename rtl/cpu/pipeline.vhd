--
-- Copyright (c) 2008 - 2016 Marko Zec, University of Zagreb
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
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
use work.mi32_pack.all;
use work.rv32_pack.all;


entity pipeline is
    generic (
	-- ISA options
	C_arch: integer;
	C_big_endian: boolean;		-- MI32 only
	C_mult_enable: boolean;		-- MI32 only
	C_mul_acc: boolean := false;	-- MI32 only
	C_mul_reg: boolean := false;	-- MI32 only
	C_branch_likely: boolean;	-- MI32 only
	C_sign_extend: boolean;		-- MI32 only
	C_movn_movz: boolean := false;	-- MI32 only
	C_ll_sc: boolean := false;
	C_exceptions: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"ffffffff";
	C_init_PC: std_logic_vector(31 downto 0) := x"00000000";

	-- COP0 options
	C_clk_freq: integer;
	C_cache: boolean := false;
	C_cpuid: integer := 0;
	C_cop0_count: boolean := false;
	C_cop0_compare: boolean := false;
	C_cop0_config: boolean := false;

	-- optimization options
	C_result_forwarding: boolean := true;
	C_branch_prediction: boolean := true;
	C_bp_global_depth: integer := 6; -- range 2 to 12
	C_load_aligner: boolean := true;
	C_full_shifter: boolean := true;
	C_reg_IF_PC: boolean := false;
	C_regfile_synchronous_read: boolean := false;

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
	dmem_cache_wait: in std_logic := '0';
	snoop_cycle: in std_logic;
	snoop_addr: in std_logic_vector(31 downto 2);
	flush_i_line, flush_d_line: out std_logic;
	intr: in std_logic_vector(5 downto 0);
	-- debugging only
	debug_in_data: in std_logic_vector(7 downto 0);
	debug_in_strobe: in std_logic;
	debug_in_busy: out std_logic;
	debug_out_data: out std_logic_vector(7 downto 0);
	debug_out_strobe: out std_logic;
	debug_out_busy: in std_logic;
	debug_clk_ena: out std_logic;
	debug_debug: out std_logic_vector(7 downto 0);
	debug_active: out std_logic
    );
end pipeline;

architecture Behavioral of pipeline is

    constant C_eff_init_PC: std_logic_vector(31 downto 0)
      := C_init_PC and C_PC_mask;

    constant REG_ZERO: std_logic_vector(4 downto 0) := ARCH_REG_ZERO(C_arch);

    -- pipeline stage 1: instruction fetch
    signal IF_PC, IF_PC_next, IF_PC_ext_next: std_logic_vector(31 downto 2);
    signal IF_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_bpredict_re: std_logic;
    signal IF_instruction: std_logic_vector(31 downto 0);
    signal IF_data_ready, IF_fetch_complete, IF_need_refetch: boolean;
    -- boundary to stage 2
    signal IF_ID_fetch_in_progress, IF_ID_incomplete_branch: boolean;
    signal IF_ID_instruction: std_logic_vector(31 downto 0);
    signal IF_ID_bpredict_score: std_logic_vector(1 downto 0);
    signal IF_ID_bpredict_index: std_logic_vector(12 downto 0);
    signal IF_ID_PC, IF_ID_PC_4, IF_ID_PC_next: std_logic_vector(31 downto 2);
    signal IF_ID_EPC: std_logic_vector(31 downto 2);
    signal IF_ID_EIP, IF_ID_bubble: boolean;
	
    -- pipeline stage 2: instruction decode and register fetch
    signal ID_running: boolean;
    signal ID_reg1_zero, ID_reg2_zero, ID_reg1_pc: boolean;
    signal ID_branch_cycle, ID_branch_likely, ID_jump_cycle: boolean;
    signal ID_branch_offset: std_logic_vector(31 downto 2);
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
    signal ID_shift_funct: std_logic_vector(1 downto 0);
    signal ID_shift_variable: boolean;
    signal ID_shift_amount: std_logic_vector(4 downto 0);
    signal ID_immediate: std_logic_vector(31 downto 0);
    signal ID_slt_signed: boolean;
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
    signal ID_mult, ID_mult_signed, ID_madd, ID_mul_compound: boolean;
    signal ID_mthi, ID_mtlo: boolean;
    signal ID_ll, ID_sc: boolean;
    signal ID_flush_i_line, ID_flush_d_line: std_logic;
    signal ID_wait, ID_cop0_write, ID_exception, ID_di, ID_ei: boolean;
    -- boundary to stage 3
    signal ID_EX_bpredict_score: std_logic_vector(1 downto 0);
    signal ID_EX_writeback_addr, ID_EX_cop0_addr: std_logic_vector(4 downto 0);
    signal ID_EX_reg1_data, ID_EX_reg2_data: std_logic_vector(31 downto 0);
    signal ID_EX_alu_op2: std_logic_vector(31 downto 0);
    signal ID_EX_fwd_ex_reg1, ID_EX_fwd_ex_reg2, ID_EX_fwd_ex_alu_op2: boolean;
    signal ID_EX_fwd_mem_reg1, ID_EX_fwd_mem_reg2: boolean;
    signal ID_EX_fwd_mem_alu_op2, ID_EX_slt_signed: boolean;
    signal ID_EX_cmov_cycle, ID_EX_cmov_condition: boolean;
    signal ID_EX_branch_cycle, ID_EX_branch_likely: boolean;
    signal ID_EX_jump_register: boolean;
    signal ID_EX_cancel_next, ID_EX_predict_taken: boolean;
    signal ID_EX_bpredict_index: std_logic_vector(12 downto 0);
    signal ID_EX_branch_target: std_logic_vector(31 downto 2);
    signal ID_EX_branch_condition: std_logic_vector(2 downto 0);
    signal ID_EX_op_major: std_logic_vector(1 downto 0);
    signal ID_EX_op_minor: std_logic_vector(2 downto 0);
    signal ID_EX_read_alt: boolean;
    signal ID_EX_alt_sel: std_logic_vector(2 downto 0);
    signal ID_EX_shift_funct: std_logic_vector(1 downto 0);
    signal ID_EX_shift_variable: boolean;
    signal ID_EX_shift_amount: std_logic_vector(4 downto 0);
    signal ID_EX_mem_cycle, ID_EX_mem_write: std_logic;
    signal ID_EX_mem_size: std_logic_vector(1 downto 0);
    signal ID_EX_mem_read_sign_extend: std_logic;
    signal ID_EX_multicycle_lh_lb: boolean;
    signal ID_EX_latency: std_logic_vector(1 downto 0);
    signal ID_EX_seb_seh_cycle: boolean;
    signal ID_EX_seb_seh_select: std_logic;
    signal ID_EX_mult, ID_EX_mult_signed, ID_EX_madd: boolean;
    signal ID_EX_mul_compound, ID_EX_mthi, ID_EX_mtlo: boolean;
    signal ID_EX_ll, ID_EX_sc: boolean;
    signal ID_EX_flush_i_line, ID_EX_flush_d_line: std_logic;
    signal ID_EX_branch_delay_follows, ID_EX_branch_delay_slot: boolean;
    signal ID_EX_cop0_write, ID_EX_wait: boolean;
    signal ID_EX_exception, ID_EX_ei, ID_EX_di: boolean;
    signal ID_EX_EPC: std_logic_vector(31 downto 2);
    signal ID_EX_EIP, ID_EX_bubble: boolean;
    signal ID_EX_instruction: std_logic_vector(31 downto 0); -- debugging only
	
    -- pipeline stage 3: execute
    signal EX_running: boolean;
    signal EX_eff_reg1, EX_eff_reg2: std_logic_vector(31 downto 0);
    signal EX_eff_alu_op2: std_logic_vector(31 downto 0);
    signal EX_shamt: std_logic_vector(4 downto 0);
    signal EX_from_shift: std_logic_vector(31 downto 0);
    signal EX_from_alu_addsubx: std_logic_vector(32 downto 0);
    signal EX_from_alu_logic, EX_from_alt: std_logic_vector(31 downto 0);
    signal EX_from_cop0: std_logic_vector(31 downto 0);
    signal EX_equal: boolean;
    signal EX_2bit_add: std_logic_vector(1 downto 0);
    signal EX_mem_align_shamt: std_logic_vector(1 downto 0);
    signal EX_mem_byte_sel: std_logic_vector(3 downto 0);
    signal EX_take_branch: boolean;
    signal EX_branch_target: std_logic_vector(31 downto 2);
    signal EX_PC_RET: std_logic_vector(31 downto 2);
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
    signal EX_MEM_shift_blocked: boolean;
    signal EX_MEM_mem_size: std_logic_vector(1 downto 0);
    signal EX_MEM_multicycle_lh_lb: boolean;
    signal EX_MEM_mem_write: std_logic;
    signal EX_MEM_mem_byte_sel: std_logic_vector(3 downto 0);
    signal EX_MEM_op_major: std_logic_vector(1 downto 0);
    signal EX_MEM_flush_i_line, EX_MEM_flush_d_line: std_logic;
    signal EX_MEM_ll_bit: std_logic;
    signal EX_MEM_ll_addr: std_logic_vector(31 downto 2);
    signal EX_MEM_sc: boolean;
    signal EX_MEM_EIP: boolean;
    signal EX_MEM_instruction: std_logic_vector(31 downto 0);
    signal EX_MEM_PC: std_logic_vector(31 downto 2);
	
    -- pipeline stage 4: memory access
    signal MEM_running, MEM_take_branch: boolean;
    signal MEM_cancel_EX: boolean;
    signal MEM_bpredict_score: std_logic_vector(1 downto 0);
    signal MEM_bpredict_we: std_logic;
    signal MEM_eff_data: std_logic_vector(31 downto 0);
    signal MEM_shamt_1_2_4: std_logic_vector(2 downto 0);
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
    signal MEM_WB_instruction: std_logic_vector(31 downto 0);
    signal MEM_WB_PC: std_logic_vector(31 downto 2);
	
    -- pipeline stage 5: register writeback
    signal WB_eff_data: std_logic_vector(31 downto 0);
    signal WB_writeback_data: std_logic_vector(31 downto 0);
    signal WB_mem_data_aligned: std_logic_vector(31 downto 0);
    signal WB_clk: std_logic;

    -- multiplication unit
    signal EX_mul_start, R_mul_commit, R_mul_done, mul_done: boolean;
    signal R_we_hi, R_we_lo, R_clr_hi, R_clr_lo: boolean;
    signal R_hi_lo, R_hi_lo_target: std_logic_vector(63 downto 0);
    signal hi_lo_from_mul: std_logic_vector(63 downto 0);

    -- COP0 registers
    signal R_reset: std_logic; -- registered reset input
    signal R_cop0_count, R_cop0_compare: std_logic_vector(31 downto 0);
    signal R_cop0_config: std_logic_vector(31 downto 0);
    signal R_cop0_EPC: std_logic_vector(31 downto 2);
    signal R_cop0_EBASE: std_logic_vector(31 downto 2);
    signal R_cop0_EI, R_cop0_BD: std_logic;
    signal R_cop0_intr, R_cop0_intr_mask: std_logic_vector(7 downto 0);
    signal R_cop0_EX_code: std_logic_vector(4 downto 0);
    signal R_cop0_timer_intr: std_logic;
    signal sr, cause: std_logic_vector(31 downto 0);

    -- signals used for debugging only
    signal clk_enable: std_logic;
    signal trace_addr: std_logic_vector(31 downto 0);
    signal reg_trace_data, misc_trace_data: std_logic_vector(31 downto 0);
    signal final_trace_data: std_logic_vector(31 downto 0);
    signal R_d_imem_data_in: std_logic_vector(31 downto 0);
    signal D_instr, D_b_instr, D_b_mispredict: std_logic_vector(31 downto 0);

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
    --  reintroduce area-optimized branch likely support as an option
    --	sort out the endianess story
    --	unaligned load / store instructions?
    --	revisit target_addr computation in idecode.vhd
    --	division?
    --	result forwarding: muxes instead of priority encoders?
    --
    -- Believed to have been fixed already:
    --  cancel and restart an incomplete instruction fetch on branch!
    --	don't branch until branch delay slot fetched!!!
    --  MFC0/MTC0
    --	MTHI/MTLO
    --  block on MFHI/MFLO if result not ready
    --	revisit MULT / MFHI / MFLO decoding (now done in EX stage!!!)
    --  commit MULT result in MEM stage (branch likely must cancel commit)!
    --	exceptions/interrupts


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
	C_reg_IF_PC and EX_running and (EX_take_branch xor ID_EX_predict_taken)
      else IF_PC + 1 when
	MEM_take_branch and not IF_need_refetch and ID_running
      else IF_PC when
	MEM_take_branch and not IF_need_refetch
      else EX_MEM_branch_target when
	IF_need_refetch or IF_ID_incomplete_branch
      else ID_jump_target when
	ID_running and not ID_EX_cancel_next and not IF_ID_bubble and
	(ID_jump_cycle or ID_predict_taken)
      else IF_PC + 1 when
	ID_running
      else IF_ID_PC_next; -- i.e. do not change
    IF_PC_ext_next <=
      IF_PC_next and C_PC_mask(31 downto 2) when IF_data_ready
      else IF_ID_PC; -- i.e. do not change

    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
	    R_reset <= reset;
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
		IF_ID_bubble <= true;
	    elsif ID_running then
		IF_ID_instruction <= IF_instruction;
		IF_ID_bubble <= false;
		IF_ID_PC_4 <= IF_PC + 1 and C_PC_mask(31 downto 2);
		IF_ID_bpredict_index <= IF_bpredict_index;
		if C_debug or C_arch = ARCH_RV32 or C_exceptions then
		    IF_ID_EPC <= IF_PC;
		end if;
		if C_exceptions then
		    if EX_MEM_EIP and not IF_ID_EIP and not ID_EX_EIP then
			IF_ID_EIP <= true;
			IF_ID_instruction <= x"03400008"; -- jr k0
		    end if;
		    if IF_ID_EIP then
			IF_ID_EIP <= false;
			IF_ID_bubble <= true; -- delay slot
		    end if;
		end if;
	    elsif (C_arch = ARCH_MI32
	      and (ID_EX_branch_likely and not EX_take_branch))
	      or (C_arch = ARCH_RV32 and EX_take_branch) then
		IF_ID_bubble <= false; -- XXX should be true?
		IF_ID_instruction <= x"00000000"; -- NOP, XXX, revisit!!!
	    end if;
	    -- crude reset hack for RV32 in absence of proper exception support
	    if C_arch = ARCH_RV32 and R_reset = '1' then
		IF_ID_PC <= R_cop0_EBASE and C_PC_mask(31 downto 2);
		IF_ID_bubble <= true;
	    end if;
	end if;
    end process;

    G_bp_scoretable:
    if C_branch_prediction and C_arch /= ARCH_RV32 generate
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

    -- MI32 instruction decoder
    G_idecode_mi32:
    if C_arch = ARCH_MI32 generate
    idecode: entity work.idecode_mi32
    generic map (
	C_cache => C_cache, C_ll_sc => C_ll_sc,
	C_branch_likely => C_branch_likely, C_sign_extend => C_sign_extend,
	C_mul_acc => C_mul_acc, C_mul_reg => C_mul_reg,
	C_movn_movz => C_movn_movz, C_exceptions => C_exceptions
    )
    port map (
	instruction => IF_ID_instruction,
	reg1_addr => ID_reg1_addr, reg2_addr => ID_reg2_addr,
	reg1_zero => ID_reg1_zero, reg2_zero => ID_reg2_zero,
	immediate_value => ID_immediate, use_immediate => ID_use_immediate,
	cmov_cycle => ID_cmov_cycle, cmov_condition => ID_cmov_condition,
	branch_offset => ID_branch_offset, shift_fn => ID_shift_funct,
	shift_variable => ID_shift_variable, shift_amount => ID_shift_amount,
	read_alt => ID_read_alt, alt_sel => ID_alt_sel,
	target_addr => ID_writeback_addr, op_major => ID_op_major,
	op_minor => ID_op_minor, mem_cycle => ID_mem_cycle,
	branch_cycle => ID_branch_cycle, branch_likely => ID_branch_likely,
	jump_cycle => ID_jump_cycle, jump_register => ID_jump_register,
	branch_condition => ID_branch_condition, slt_signed => ID_slt_signed,
	mem_write => ID_mem_write, mem_size => ID_mem_size,
	mem_read_sign_extend => ID_mem_read_sign_extend,
	latency => ID_latency, ignore_reg2 => ID_ignore_reg2,
	seb_seh_cycle => ID_seb_seh_cycle, seb_seh_select => ID_seb_seh_select,
	mult => ID_mult, mult_signed => ID_mult_signed, madd => ID_madd,
	mul_compound => ID_mul_compound, mthi => ID_mthi, mtlo => ID_mtlo,
	ll => ID_ll, sc => ID_sc,
	cop0_wait => ID_wait, cop0_write => ID_cop0_write,
	exception => ID_exception, di => ID_di, ei => ID_ei,
	flush_i_line => ID_flush_i_line, flush_d_line => ID_flush_d_line
    );
    end generate;

    -- RV32 instruction decoder
    G_idecode_rv32:
    if C_arch = ARCH_RV32 generate
    idecode: entity work.idecode_rv32
    generic map (
	C_cache => C_cache, C_ll_sc => C_ll_sc, C_mul_reg => C_mul_reg,
	C_exceptions => C_exceptions
    )
    port map (
	instruction => IF_ID_instruction,
	reg1_addr => ID_reg1_addr, reg2_addr => ID_reg2_addr,
	reg1_zero => ID_reg1_zero, reg2_zero => ID_reg2_zero,
	reg1_pc => ID_reg1_pc,
	immediate_value => ID_immediate, use_immediate => ID_use_immediate,
	branch_offset => ID_branch_offset, shift_fn => ID_shift_funct,
	shift_variable => ID_shift_variable, shift_amount => ID_shift_amount,
	read_alt => ID_read_alt, alt_sel => ID_alt_sel,
	target_addr => ID_writeback_addr, op_major => ID_op_major,
	op_minor => ID_op_minor, mem_cycle => ID_mem_cycle,
	branch_cycle => ID_branch_cycle, jump_register => ID_jump_register,
	branch_condition => ID_branch_condition, slt_signed => ID_slt_signed,
	mem_write => ID_mem_write, mem_size => ID_mem_size,
	mem_read_sign_extend => ID_mem_read_sign_extend,
	latency => ID_latency, ignore_reg2 => ID_ignore_reg2,
	mult => ID_mult, mult_signed => ID_mult_signed, madd => ID_madd,
	mul_compound => ID_mul_compound, mthi => ID_mthi, mtlo => ID_mtlo,
	ll => ID_ll, sc => ID_sc,
	cop0_wait => ID_wait, cop0_write => ID_cop0_write,
	exception => ID_exception, di => ID_di, ei => ID_ei,
	flush_i_line => ID_flush_i_line, flush_d_line => ID_flush_d_line
    );
    end generate;

    -- three- or four-ported register file: 2(3) async reads, 1 sync write
    regfile: entity work.reg1w2r
    generic map (
	C_synchronous_read => C_regfile_synchronous_read,
	C_debug => C_debug
    )
    port map (
	rd1_addr => ID_reg1_addr, rd2_addr => ID_reg2_addr,
	rdd_addr => trace_addr(4 downto 0), wr_addr => MEM_WB_writeback_addr,
	rd1_data => ID_reg1_data, rd2_data => ID_reg2_data,
	rdd_data => reg_trace_data, wr_data => WB_writeback_data,
	wr_enable => MEM_WB_write_enable, rd_clk => clk, wr_clk => WB_clk
    );

    --
    -- WB_writeback_data overrides register reads with pipelined load aligner.
    -- With multicycle aligner WB_writeback_data is written to the regfile
    -- at the half of the clk cycle, in which case no bypass logic is required.
    --
    WB_clk <= clk when C_load_aligner else not clk;
    ID_reg1_eff_data <= IF_ID_EPC & "00" when C_arch = ARCH_RV32 and ID_reg1_pc
      else ID_reg1_data when (not C_load_aligner and
      (not C_regfile_synchronous_read or
      ID_reg1_zero or ID_reg1_addr /= MEM_WB_writeback_addr)) or
      ID_reg1_zero or ID_reg1_addr /= MEM_WB_writeback_addr
      else WB_writeback_data;
    ID_reg2_eff_data <= ID_reg2_data when (not C_load_aligner and
      (not C_regfile_synchronous_read or
      ID_reg2_zero or ID_reg2_addr /= MEM_WB_writeback_addr)) or
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
    ID_jump_register_hazard <= C_arch = ARCH_MI32
      and ID_jump_register and not ID_reg1_zero and
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

    -- compute branch target
    ID_branch_target <= C_PC_mask(31 downto 2) and
      (IF_ID_PC_4 + ID_branch_offset) when C_arch = ARCH_MI32
      else C_PC_mask(31 downto 2) and (IF_ID_EPC + ID_branch_offset);

    -- branch prediction
    ID_predict_taken <= C_branch_prediction and C_arch /= ARCH_RV32
      and ID_branch_cycle and IF_ID_bpredict_score(1) = '1';

    -- compute jump target
    ID_jump_target <=
      ID_reg1_eff_data(31 downto 2) when not C_load_aligner and
      C_regfile_synchronous_read and C_arch = ARCH_MI32 and ID_jump_register
      else ID_reg1_data(31 downto 2) when C_arch = ARCH_MI32
      and ID_jump_register
      else ID_branch_target when C_branch_prediction and C_arch /= ARCH_RV32
      and not ID_jump_cycle
      else IF_ID_PC_4(31 downto 28) & IF_ID_instruction(25 downto 0);

    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
	    if MEM_take_branch and not ID_running and IF_fetch_complete then
		ID_EX_cancel_next <= true;
	    end if;
	    if C_mult_enable then
		ID_EX_mul_compound <= false;
	    end if;
	    if EX_running then
		if not C_load_aligner and ID_EX_multicycle_lh_lb and
		  not MEM_cancel_EX and not EX_MEM_EIP then
		    -- multicycle load aligner
		    -- byte / half word load, insert an arithm shift right cycle
		    -- XXX must stall the ID stage - revisit!!!
		    ID_EX_multicycle_lh_lb <= not EX_MEM_multicycle_lh_lb;
		    ID_EX_mem_cycle <= '0';
		    ID_EX_op_major <= OP_MAJOR_SHIFT;
		    ID_EX_shift_variable <= false;
		    ID_EX_shift_funct <= OP_SHIFT_RL;
		    if not EX_MEM_multicycle_lh_lb then
			ID_EX_shift_amount <=  EX_mem_align_shamt & "000";
		    end if;
		    if ID_running or EX_MEM_EIP then
			ID_EX_cancel_next <= false;
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= '0';
			ID_EX_flush_d_line <= '0';
		    end if;
		    if C_debug then
			ID_EX_instruction <= x"00000001"; -- debugging only
		    end if;
		    -- schedule forwarding of memory read
		    ID_EX_fwd_ex_reg1 <= false;
		    ID_EX_fwd_ex_reg2 <= false;
		    ID_EX_fwd_ex_alu_op2 <= false;
		    ID_EX_fwd_mem_reg1 <= false;
		    ID_EX_fwd_mem_reg2 <= true;
		    ID_EX_fwd_mem_alu_op2 <= false;
		elsif not ID_running or (not ID_EX_branch_delay_follows and
		  (MEM_take_branch or ID_EX_cancel_next)) or
		  IF_ID_bubble or (C_exceptions and EX_MEM_EIP) then
		    -- insert a bubble if branching or ID stage is stalled
		    ID_EX_writeback_addr <= REG_ZERO; -- NOP
		    ID_EX_mem_cycle <= '0';
		    ID_EX_mem_write <= '0';
		    ID_EX_multicycle_lh_lb <= false;
		    ID_EX_jump_register <= false;
		    ID_EX_branch_cycle <= false;
		    ID_EX_branch_likely <= false;
		    ID_EX_predict_taken <= false;
		    if ID_running or EX_MEM_EIP then
			ID_EX_cancel_next <= false;
		    end if;
		    if C_mult_enable then
			ID_EX_mult <= false;
			ID_EX_mult_signed <= false;
			ID_EX_madd <= false;
		    end if;
		    if C_ll_sc then
		        ID_EX_ll <= false;
		        ID_EX_sc <= false;
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= '0';
			ID_EX_flush_d_line <= '0';
		    end if;
		    if C_exceptions then
			ID_EX_wait <= false;
			ID_EX_bubble <= true;
			ID_EX_cop0_write <= false;
			ID_EX_exception <= false;
			ID_EX_ei <= false;
			ID_EX_di <= false;
			if ID_running then
			    ID_EX_EIP <= IF_ID_EIP;
			end if;
			if EX_MEM_EIP then
			    ID_EX_branch_delay_slot <= false;
			    ID_EX_branch_delay_follows <= false;
			end if;
		    end if;
		    if C_debug then
			ID_EX_instruction <= x"00000000"; -- debugging only
		    end if;
		    -- Don't care bits (optimization hints)
		    ID_EX_reg1_data <= (others => '-');
		    ID_EX_reg2_data <= (others => '-');
		    ID_EX_alu_op2 <= (others => '-');
		    ID_EX_cop0_addr <= (others => '-');
		    ID_EX_op_major <= OP_MAJOR_ALU;
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
		    ID_EX_cop0_addr <= IF_ID_instruction(15 downto 11);
		    ID_EX_slt_signed <= ID_slt_signed;
		    ID_EX_op_major <= ID_op_major;
		    ID_EX_op_minor <= ID_op_minor;
		    ID_EX_cmov_cycle <= C_movn_movz and ID_cmov_cycle;
		    ID_EX_cmov_condition <= C_movn_movz and ID_cmov_condition;
		    ID_EX_mem_write <= ID_mem_write;
		    ID_EX_mem_size <= ID_mem_size;
		    ID_EX_multicycle_lh_lb <= not (C_exceptions and EX_MEM_EIP)
		      and not C_load_aligner and ID_mem_cycle = '1' and
		      ID_mem_write = '0' and ID_mem_size(1) = '0';
		    ID_EX_mem_read_sign_extend <= ID_mem_read_sign_extend;
		    ID_EX_branch_condition <= ID_branch_condition;
		    ID_EX_branch_target <= ID_branch_target;
		    ID_EX_seb_seh_cycle <= ID_seb_seh_cycle;
		    ID_EX_seb_seh_select <= ID_seb_seh_select;
		    ID_EX_alt_sel <= ID_alt_sel;
		    ID_EX_read_alt <= ID_read_alt;
		    ID_EX_shift_funct <= ID_shift_funct;
		    ID_EX_shift_variable <= ID_shift_variable;
		    ID_EX_shift_amount <= ID_shift_amount;
		    ID_EX_writeback_addr <= ID_writeback_addr;
		    ID_EX_mem_cycle <= ID_mem_cycle;
		    ID_EX_jump_register <=
		      C_arch = ARCH_RV32 and ID_jump_register;
		    ID_EX_branch_cycle <= ID_branch_cycle;
		    ID_EX_branch_likely <= C_branch_likely and
		      ID_branch_likely and ID_branch_cycle;
		    ID_EX_branch_delay_follows <= C_arch = ARCH_MI32
		      and (ID_branch_cycle or ID_jump_cycle);
		    ID_EX_predict_taken <= ID_predict_taken;
		    ID_EX_bpredict_score <= IF_ID_bpredict_score;
		    ID_EX_bpredict_index <= IF_ID_bpredict_index;
		    ID_EX_latency <= ID_latency;
		    if C_mult_enable then
			ID_EX_mult <= ID_mult;
			ID_EX_mult_signed <= ID_mult_signed;
			ID_EX_madd <= C_mul_acc and ID_madd;
			ID_EX_mul_compound <= ID_mul_compound;
			ID_EX_mthi <= ID_mthi;
			ID_EX_mtlo <= ID_mtlo;
			if ID_mtlo then
			    ID_EX_reg2_data(0) <= '1';
			end if;
		    end if;
		    if C_ll_sc then
		        ID_EX_ll <= ID_ll;
		        ID_EX_sc <= ID_sc;
		    end if;
		    if C_cache then
			ID_EX_flush_i_line <= ID_flush_i_line;
			ID_EX_flush_d_line <= ID_flush_d_line;
		    end if;
		    if (C_exceptions or C_debug)
		      and not ID_EX_branch_delay_follows then
			ID_EX_EPC <= IF_ID_EPC;
		    end if;
		    if C_exceptions then
			ID_EX_wait <= ID_wait;
			ID_EX_bubble <= IF_ID_bubble;
			ID_EX_cop0_write <= ID_cop0_write;
			ID_EX_exception <= ID_exception;
			if ID_running then
			    ID_EX_EIP <= IF_ID_EIP;
			end if;
			ID_EX_ei <= ID_ei;
			ID_EX_di <= ID_di;
			ID_EX_branch_delay_slot <= ID_EX_branch_delay_follows;
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
		    end if;
		end if;
	    else
		if C_exceptions and ID_EX_wait and (R_cop0_EI = '0' or
		  (R_cop0_intr and R_cop0_intr_mask) /= x"00") then
		    ID_EX_bubble <= true;
		    ID_EX_wait <= false;
		end if;
		if ID_running or EX_MEM_EIP then
		    ID_EX_cancel_next <= false;
		end if;
	    end if;
	    if R_reset = '1' then
		ID_EX_exception <= true;
	    end if;
	end if;
    end process;


    --
    -- Pipeline stage 3: execute
    -- =========================
    --

    EX_running <= MEM_running and not (C_exceptions and ID_EX_wait)
      and (not C_mult_enable or MEM_cancel_EX
      or (R_mul_done and not ID_EX_mul_compound) or
      (ID_EX_alt_sel /= ALT_HI and ID_EX_alt_sel /= ALT_LO));

    -- forward the results from later stages
    EX_eff_reg1 <=
      MEM_eff_data when ID_EX_fwd_ex_reg1 and C_result_forwarding else
      WB_eff_data when ID_EX_fwd_mem_reg1 and C_result_forwarding else
      ID_EX_reg1_data;
    EX_eff_reg2 <=
      MEM_eff_data when ID_EX_fwd_ex_reg2 and C_result_forwarding else
      WB_eff_data when ID_EX_fwd_mem_reg2 and
     (C_result_forwarding or not C_load_aligner) else
      ID_EX_reg2_data;
    EX_eff_alu_op2 <=
      MEM_eff_data when ID_EX_fwd_ex_alu_op2 and C_result_forwarding else
      WB_eff_data when ID_EX_fwd_mem_alu_op2 and C_result_forwarding else
      ID_EX_alu_op2;

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
	funct => ID_EX_op_minor(1 downto 0)
    );

    -- compute shift amount and function
    EX_2bit_add <= EX_eff_reg1(1 downto 0) + ID_EX_alu_op2(1 downto 0);
    EX_mem_align_shamt <= "00" when ID_EX_mem_size(1) = '1' else
      EX_2bit_add when not C_big_endian else
      not(EX_2bit_add(1)) & '0' when ID_EX_mem_size = "01" else
      "00" when EX_2bit_add = "11" else
      "01" when EX_2bit_add = "10" else
      "10" when EX_2bit_add = "01" else
      "11" when EX_2bit_add = "00";
    EX_shamt <= EX_mem_align_shamt & "---" when ID_EX_mem_cycle = '1'
      else EX_eff_reg1(4 downto 0) when ID_EX_shift_variable
      else ID_EX_shift_amount;

    -- instantiate the barrel shifter
    shift: entity work.shift
    generic map (
	C_load_aligner => C_load_aligner
    )
    port map (
	shamt_8_16 => EX_shamt(4 downto 3), funct_8_16 => ID_EX_shift_funct,
	shamt_1_2_4 => MEM_shamt_1_2_4, funct_1_2_4 => EX_MEM_shift_funct,
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

    -- link return address, MFHI, MFLO, MFC0
    EX_PC_RET <= IF_ID_PC_4 when C_arch = ARCH_MI32 else IF_ID_EPC;
    with ID_EX_alt_sel select
    EX_from_alt <=
      R_hi_lo(63 downto 32) when ALT_HI,
      R_hi_lo(31 downto 0) when ALT_LO,
      EX_from_cop0 when ALT_COP0,
      EX_PC_RET & "00" when others;

    -- COP0 outbound mux
    G_MI32_COP0_mux:
    if C_arch = ARCH_MI32 generate
    sr <=  x"0000" & R_cop0_intr_mask & x"0" & "000" & R_cop0_EI;
    cause <=  R_cop0_BD & "000" & x"000"
      & R_cop0_intr & "0" & R_cop0_EX_code & "00";
    with ID_EX_cop0_addr select
    EX_from_cop0 <=
      R_cop0_count when MI32_COP0_COUNT,
      R_cop0_compare when MI32_COP0_COMPARE,
      sr when MI32_COP0_STATUS,
      cause when MI32_COP0_CAUSE,
      R_cop0_EPC & "00" when MI32_COP0_EXC_PC,
      R_cop0_config when MI32_COP0_CONFIG,
      (others => '-') when others;
    end generate;
    G_RV32_COP0_mux:
    if C_arch = ARCH_RV32 generate
    EX_from_cop0 <= R_cop0_count;
    end generate;

    -- branch or not?
    EX_equal <= EX_eff_reg1 = EX_eff_reg2;
    process(ID_EX_branch_cycle, ID_EX_branch_condition, EX_equal,
      EX_eff_reg1)
    begin
	if C_arch = ARCH_MI32 and ID_EX_branch_cycle then
	    case ID_EX_branch_condition is
	    when MI32_TEST_LTZ => EX_take_branch <= EX_eff_reg1(31) = '1';
	    when MI32_TEST_GEZ => EX_take_branch <= EX_eff_reg1(31) = '0';
	    when MI32_TEST_EQ  => EX_take_branch <= EX_equal;
	    when MI32_TEST_NE  => EX_take_branch <= not EX_equal;
	    when MI32_TEST_LEZ =>
	      EX_take_branch <= EX_eff_reg1(31) = '1' or EX_equal;
	    when MI32_TEST_GTZ =>
	      EX_take_branch <= EX_eff_reg1(31) = '0' and not EX_equal;
	    when others =>
	      EX_take_branch <= false;
	    end case;
	elsif C_arch = ARCH_RV32 and ID_EX_branch_cycle then
	    case ID_EX_branch_condition is
	    when RV32_TEST_ALWAYS => EX_take_branch <= true;
	    when RV32_TEST_EQ  => EX_take_branch <= EX_equal;
	    when RV32_TEST_NE  => EX_take_branch <= not EX_equal;
	    when RV32_TEST_LT  =>
	      EX_take_branch <= (EX_eff_reg1(31) xor EX_eff_alu_op2(31)
	        xor EX_from_alu_addsubx(32)) = '1';
	    when RV32_TEST_GE  =>
	      EX_take_branch <= (EX_eff_reg1(31) xor EX_eff_alu_op2(31)
	        xor EX_from_alu_addsubx(32)) = '0';
	    when RV32_TEST_LTU =>
	      EX_take_branch <= EX_from_alu_addsubx(32) = '1';
	    when RV32_TEST_GEU =>
	      EX_take_branch <= EX_from_alu_addsubx(32) = '0';
	    when others =>
	      EX_take_branch <= false;
	    end case;
	else
	    EX_take_branch <= false;
	end if;
    end process;

    EX_branch_target <= IF_ID_PC_4 when ID_EX_predict_taken
      else ID_EX_branch_target;

    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
	    if C_ll_sc then
		if ID_EX_ll then
		    EX_MEM_ll_bit <= '1';
		    EX_MEM_ll_addr <= EX_from_alu_addsubx(31 downto 2)
		      and C_PC_mask(31 downto 2);
		else
		    if snoop_cycle = '1' and EX_MEM_ll_addr = snoop_addr then
			EX_MEM_ll_bit <= '0';
		    end if;
		end if;
	    end if;

	    if C_exceptions and ID_EX_EIP and ID_running then
		EX_MEM_EIP <= false;
	    end if;

	    if C_exceptions then
		R_cop0_intr(6 downto 2) <= intr(4 downto 0);
		R_cop0_intr(7) <= intr(5) or R_cop0_timer_intr;
	    end if;

	    if not C_full_shifter and EX_MEM_shift_blocked then
		if EX_MEM_shamt_1_2_4 = "010" then
		    EX_MEM_shift_blocked <= false;
		end if;
		EX_MEM_mem_data_out <= MEM_from_shift;
		EX_MEM_shamt_1_2_4 <= EX_MEM_shamt_1_2_4 - 1;
	    end if;

	    if MEM_running and (MEM_cancel_EX or not EX_running or
	      (C_exceptions and EX_MEM_EIP)) then
		-- insert a bubble in the MEM stage
		EX_MEM_take_branch <= false;
		EX_MEM_branch_taken <= false;
		EX_MEM_branch_cycle <= false;
		EX_MEM_branch_likely <= false;
		EX_MEM_writeback_addr <= REG_ZERO;
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
	    elsif MEM_running and EX_running then
		EX_MEM_mem_data_out <= EX_from_shift;
		EX_MEM_addsub_data <= EX_from_alu_addsubx(31 downto 0);
		EX_MEM_mem_size <= ID_EX_mem_size;
		EX_MEM_multicycle_lh_lb <= not C_load_aligner
		  and ID_EX_multicycle_lh_lb;
		EX_MEM_mem_cycle <= ID_EX_mem_cycle;
		EX_MEM_mem_write <= ID_EX_mem_write;
		EX_MEM_mem_byte_sel <= EX_mem_byte_sel;
		EX_MEM_shamt_1_2_4 <= EX_shamt(2 downto 0);
		EX_MEM_shift_funct <= ID_EX_shift_funct;
		EX_MEM_shift_blocked <= not C_full_shifter
		  and ID_EX_op_major = OP_MAJOR_SHIFT
		  and EX_shamt(2 downto 1) /= "00";
		EX_MEM_op_major <= ID_EX_op_major;
		EX_MEM_branch_cycle <= ID_EX_branch_cycle;
		EX_MEM_branch_likely <= ID_EX_branch_likely;
		EX_MEM_bpredict_score <= ID_EX_bpredict_score;
		EX_MEM_bpredict_index <= ID_EX_bpredict_index;
		EX_MEM_take_branch <= EX_take_branch;
		EX_MEM_branch_taken <= ID_EX_predict_taken;
		if ID_EX_branch_cycle then
		    if C_arch = ARCH_RV32 and ID_EX_jump_register then
			EX_MEM_branch_target <= C_PC_mask(31 downto 2)
			  and EX_from_alu_addsubx(31 downto 2);
		    else
			EX_MEM_branch_target <= EX_branch_target;
		    end if;
		end if;
		if C_movn_movz and ID_EX_cmov_cycle then
		    if (EX_eff_reg2 = x"00000000") = ID_EX_cmov_condition then
			EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		    else
			EX_MEM_writeback_addr <= REG_ZERO;
		    end if;
		else
		    EX_MEM_writeback_addr <= ID_EX_writeback_addr;
		end if;
	        if C_exceptions and not EX_MEM_EIP then
		    if ID_EX_ei then
			R_cop0_EI <= '1';
		    end if;
		    if ID_EX_di then
			R_cop0_EI <= '0';
		    end if;
		    if ID_EX_cop0_write then
			if ID_EX_cop0_addr = MI32_COP0_STATUS then
			    R_cop0_intr_mask <= EX_eff_reg2(15 downto 8);
			    R_cop0_EI <= EX_eff_reg2(0);
			end if;
			if ID_EX_cop0_addr = MI32_COP0_CAUSE then
			    R_cop0_BD <= EX_eff_reg2(31);
			    R_cop0_intr(1 downto 0) <= EX_eff_reg2(9 downto 8);
			    R_cop0_EX_code <= EX_eff_reg2(6 downto 2);
			end if;
			if ID_EX_cop0_addr = MI32_COP0_EXC_PC then
			    R_cop0_EPC <= EX_eff_reg2(31 downto 2)
			      and C_PC_mask(31 downto 2);
			end if;
			if ID_EX_cop0_addr = MI32_COP0_EBASE then
			    R_cop0_EBASE <= EX_eff_reg2(31 downto 2)
			      and C_PC_mask(31 downto 2);
			end if;
			if ID_EX_cop0_addr = MI32_COP0_COMPARE and
			  C_cop0_count and C_cop0_compare then
			    R_cop0_compare <= EX_eff_reg2;
			    R_cop0_timer_intr <= '0';
			end if;
		    end if;
		end if;
		if C_exceptions and R_cop0_EI = '1' and not ID_EX_bubble and
		  ((R_cop0_intr and R_cop0_intr_mask) /= x"00"
		  or ID_EX_exception) and not (ID_EX_multicycle_lh_lb
		  or EX_MEM_multicycle_lh_lb or MEM_WB_multicycle_lh_lb) then
		    R_cop0_EI <= '0'; -- disable all exceptions
		    EX_MEM_EIP <= true; -- signal exception in progress
		    R_cop0_EPC <= ID_EX_EPC and C_PC_mask(31 downto 2);
		    if ID_EX_branch_delay_slot then
			R_cop0_BD <= '1';
		    else
			R_cop0_BD <= '0';
		    end if;
		    -- copy EBASE to k0
		    EX_MEM_op_major <= OP_MAJOR_ALT;
		    EX_MEM_logic_cycle <= '1';
		    EX_MEM_logic_data <= R_cop0_EBASE & "00";
		    EX_MEM_writeback_addr <= MI32_REG_K0;
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
		    if ID_EX_slt_signed then
			EX_MEM_logic_data(0) <= EX_from_alu_addsubx(32)
			  xor EX_eff_reg1(31) xor EX_eff_alu_op2(31);
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
		    EX_MEM_PC <= ID_EX_EPC;
		    EX_MEM_instruction <= ID_EX_instruction;
		end if;
	    elsif C_ll_sc and EX_MEM_sc and EX_MEM_ll_bit = '0' then
		EX_MEM_mem_cycle <= '0';
	    end if;
	    if C_exceptions and C_cop0_count and C_cop0_compare then
		if R_cop0_count = R_cop0_compare then
		    R_cop0_timer_intr <= '1';
		end if;
	    else
		R_cop0_timer_intr <= '0';
	    end if;
	    if R_reset = '1' then
		EX_MEM_mem_cycle <= '0';
		EX_MEM_mem_write <= '0';
		if C_exceptions then
		    R_cop0_EBASE <= C_eff_init_PC(31 downto 2);
		    R_cop0_EI <= '1';
		    R_cop0_intr_mask <= (others => '0');
		end if;
	    end if;
	end if;
    end process;


    --
    -- Pipeline stage 4: memory access
    -- ===============================
    --

    MEM_running <= (dmem_cache_wait = '0' or not C_cache)
      and (EX_MEM_mem_cycle = '0' or dmem_data_ready = '1')
      and not (not C_full_shifter and EX_MEM_shift_blocked);

    MEM_eff_data <= EX_MEM_logic_data when EX_MEM_logic_cycle = '1'
      else EX_MEM_addsub_data;

    MEM_take_branch <= EX_MEM_take_branch xor EX_MEM_branch_taken;
    MEM_cancel_EX <= (C_arch = ARCH_MI32 and C_branch_likely
      and EX_MEM_branch_likely and not EX_MEM_take_branch) or
      (C_arch = ARCH_RV32 and EX_MEM_take_branch);

    MEM_shamt_1_2_4 <= "001" when not C_full_shifter and EX_MEM_shift_blocked
      else "00" & EX_MEM_shamt_1_2_4(0) when not C_full_shifter
      else EX_MEM_shamt_1_2_4;

    -- branch prediction
    G_bp_update_score:
    if C_branch_prediction and C_arch /= ARCH_RV32 generate
    MEM_bpredict_we <= '1' when EX_MEM_branch_cycle else '0';
    process(clk, clk_enable)
    begin
	if falling_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
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
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
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

    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1'
	  and (MEM_running or (C_cache and dmem_cache_wait = '1')) then
	    MEM_WB_mem_data <= MEM_data_in;
	end if;
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
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
		if EX_MEM_writeback_addr = REG_ZERO then
		    MEM_WB_write_enable <= '0';
		else
		    MEM_WB_write_enable <= '1';
		end if;
		if EX_MEM_op_major = OP_MAJOR_SHIFT then
		    MEM_WB_ex_data <= MEM_from_shift;
		elsif C_ll_sc and EX_MEM_sc then
		    MEM_WB_ex_data <= x"0000000" & "000" & EX_MEM_mem_cycle;
		else
		    MEM_WB_ex_data <= MEM_eff_data;
		end if;
		if C_debug then
		    MEM_WB_PC <= EX_MEM_PC;
		    MEM_WB_instruction <= EX_MEM_instruction;
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


    -- Multiplier unit, as a separate pipeline
    EX_mul_start <= (not C_cache or dmem_cache_wait = '0')
      and ID_EX_mult and not MEM_cancel_EX and not EX_MEM_EIP
      and (not C_mul_acc or not ID_EX_madd or R_mul_done)
      and (ID_EX_alt_sel /= ALT_LO or ID_EX_mul_compound or ID_EX_madd);
    multiplier: entity work.mul
    port map (
	clk => clk, clk_enable => clk_enable, start => EX_mul_start,
	mult_signed => ID_EX_mult_signed, mthi => ID_EX_mthi,
	x => EX_eff_reg1, y => EX_eff_reg2,
	hi_lo => hi_lo_from_mul, done => mul_done
    );

    G_simple_mul:
    if C_mult_enable and not C_mul_acc and not C_exceptions generate
    R_hi_lo <= hi_lo_from_mul;
    R_mul_done <= mul_done;
    end generate; -- G_simple_mul

    G_staged_mul:
    if C_mult_enable and (C_mul_acc or C_exceptions) generate
    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1' then
	    R_mul_commit <= false;
	    R_clr_hi <= false;
	    R_clr_lo <= false;
	    if C_mul_acc then
		R_hi_lo_target <= R_hi_lo + hi_lo_from_mul;
	    else
		R_hi_lo_target <= hi_lo_from_mul;
	    end if;
	    if EX_mul_start then
		R_mul_done <= false;
		R_we_hi <= not ID_EX_mtlo;
		R_we_lo <= not ID_EX_mthi;
		if C_mul_acc and not ID_EX_madd then
		    R_clr_hi <= not ID_EX_mtlo;
		    R_clr_lo <= not ID_EX_mthi;
		end if;
	    elsif mul_done then
		if not R_mul_done then
		    R_mul_commit <= true;
		end if;
		R_mul_done <= true;
	    end if;
	end if;
	if falling_edge(clk) and clk_enable = '1' then
	    if R_mul_commit then
		if R_we_hi then
		    R_hi_lo(63 downto 32) <= R_hi_lo_target(63 downto 32);
		end if;
		if R_we_lo then
		    R_hi_lo(31 downto 0) <= R_hi_lo_target(31 downto 0);
		end if;
	    end if;
	    if C_mul_acc and R_clr_hi then
		R_hi_lo(63 downto 32) <= (others => '0');
	    end if;
	    if C_mul_acc and R_clr_lo then
		R_hi_lo(31 downto 0) <= (others => '0');
	    end if;
	end if;
    end process;
    end generate; -- G_staged_mul


    -- COP0
    G_cop0_count:
    if C_cop0_count generate
    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1' then
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
    if C_cop0_config or C_debug generate
    R_cop0_config(31) <= '0'; -- no config1 register
    with C_clk_freq select R_cop0_config(30 downto 16) <=
	"10" & conv_std_logic_vector(100, 13) when 33,
	"01" & conv_std_logic_vector(125, 13) when 62,
	"10" & conv_std_logic_vector(200, 13) when 66,
	"10" & conv_std_logic_vector(200, 13) when 67,
	"11" & conv_std_logic_vector(325, 13) when 81,
	"01" & conv_std_logic_vector(175, 13) when 87,
	"01" & conv_std_logic_vector(225, 13) when 112,
	"10" & conv_std_logic_vector(400, 13) when 133,
	"01" & conv_std_logic_vector(275, 13) when 137,
	"10" & conv_std_logic_vector(500, 13) when 166,
	"10" & conv_std_logic_vector(500, 13) when 167,
	"10" & conv_std_logic_vector(700, 13) when 233,
	"10" & conv_std_logic_vector(800, 13) when 266,
	"10" & conv_std_logic_vector(800, 13) when 267,
	"00" & conv_std_logic_vector(C_clk_freq, 13) when others;
    R_cop0_config(15) <= '1' when C_big_endian else '0';
    R_cop0_config(14) <= '1' when C_arch = ARCH_RV32 else '0';
    R_cop0_config(13 downto 4) <= (others => '-');
    R_cop0_config(3 downto 0) <= conv_std_logic_vector(C_cpuid, 4);
    end generate;
    G_not_cop0_config:
    if not C_cop0_config and not C_debug generate
    R_cop0_config <= (others => '-');
    end generate;

    --
    -- Debug module
    --
    G_debug:
    if C_debug generate
    debug: entity work.debug
    port map (
	clk => clk,
	ctrl_in_data => debug_in_data,
	ctrl_in_strobe => debug_in_strobe,
	ctrl_in_busy => debug_in_busy,
	ctrl_out_data => debug_out_data,
	ctrl_out_strobe => debug_out_strobe,
	ctrl_out_busy => debug_out_busy,
	clk_enable => clk_enable,
	trace_active => debug_active,
	trace_break_pc => IF_PC,
	trace_op => open,
	trace_addr => trace_addr,
	trace_data_out => open,
	trace_data_in => final_trace_data
    );

    final_trace_data <= reg_trace_data when trace_addr(5) = '0'
      else misc_trace_data;

    with trace_addr(4 downto 0) select
    misc_trace_data <=
	R_hi_lo(63 downto 32)	when "00000",
	R_hi_lo(31 downto 0)	when "00001",
	sr			when "00010",
	cause			when "00011",
	R_cop0_EPC & "00"	when "00100",
	R_cop0_EBASE & "00"	when "00101",
	R_cop0_count		when "00110",
	R_cop0_compare		when "00111",

	-- IF
	IF_PC & "00"		when "01000",
	R_d_imem_data_in	when "01001",

	-- ID
	IF_ID_EPC & "00"	when "01010",
	IF_ID_instruction	when "01011",

	-- EX
	ID_EX_EPC & "00"	when "01100",
	ID_EX_instruction	when "01101",

	-- MEM
	EX_MEM_PC & "00"	when "01110",
	EX_MEM_instruction	when "01111",

	-- WB
	MEM_WB_PC & "00"	when "10000",
	MEM_WB_instruction	when "10001",

	-- Performance counters
	D_instr			when "10100",
	D_b_instr		when "10101",
	D_b_mispredict		when "10110",
	R_cop0_config		when "10111",
	(others => '-')		when others;

    -- performance counters
    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1'
	  and (not C_cache or dmem_cache_wait = '0') then
	    if EX_MEM_branch_cycle then
		D_b_instr <= D_b_instr + 1;
	    end if;
	    if MEM_take_branch then
		D_b_mispredict <= D_b_mispredict + 1;
	    end if;
	end if;
    end process;

    -- extra registers for reducing timing pressure on debug mux
    process(clk, clk_enable)
    begin
	if rising_edge(clk) and clk_enable = '1' then
	    R_d_imem_data_in <= imem_data_in;
	end if;
    end process;
    end generate;

    G_no_debug:
    if not C_debug generate
	clk_enable <= '1';
    end generate;

    debug_clk_ena <= clk_enable;

end Behavioral;

