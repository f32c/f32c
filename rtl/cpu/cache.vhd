--
-- Copyright (c) 2013 - 2016 Marko Zec, University of Zagreb
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
-- Modifications
-- Davor Jadrijevic: instantiation of generic bram modules
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity cache is
    generic (
	-- ISA options
	C_arch: integer;
	C_big_endian: boolean;		-- MI32 only
	C_mult_enable: boolean;		-- MI32 only
        C_mul_acc: boolean := false;    -- MI32 only
        C_mul_reg: boolean := false;    -- MI32 only
	C_branch_likely: boolean;	-- MI32 only
	C_sign_extend: boolean;		-- MI32 only
	C_movn_movz: boolean := false;	-- MI32 only
	C_ll_sc: boolean := false;
	C_exceptions: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"ffffffff";
	C_init_PC: std_logic_vector(31 downto 0) := x"00000000";

	-- COP0 options
	C_clk_freq: integer;
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
	C_regfile_synchronous_read: boolean := false;

	-- cache options
	C_icache_size: integer := 4;
	C_dcache_size: integer := 4;
	C_cached_addr_bits: integer := 25; -- 32 MB
	C_xram_base: std_logic_vector(31 downto 28) := x"8";
	C_cache_bursts: boolean := false;

	-- debugging options
	C_debug: boolean
    );
    port (
	clk, reset: in std_logic;
	imem_addr_strobe: out std_logic;
	imem_addr: out std_logic_vector(31 downto 2);
	imem_burst_len: out std_logic_vector(2 downto 0);
	imem_data_in: in std_logic_vector(31 downto 0);
	imem_data_ready: in std_logic;
	dmem_addr_strobe: out std_logic;
	dmem_write: out std_logic;
	dmem_byte_sel: out std_logic_vector(3 downto 0);
	dmem_addr: out std_logic_vector(31 downto 2);
	dmem_burst_len: out std_logic_vector(2 downto 0);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_data_ready: in std_logic;
	snoop_cycle: in std_logic;
	snoop_addr: in std_logic_vector(31 downto 2);
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
end cache;

architecture x of cache is
    function F_kb_to_addrlen(k: integer) return integer is
	variable bits, tmp: integer;
    begin
	bits := 0;
	while (2 ** bits < 1024 * k) loop
	    bits := bits + 1;
	end loop;
	return bits;
    end F_kb_to_addrlen;

    constant C_i_addr_bits: integer := F_kb_to_addrlen(C_icache_size);
    constant C_i_tag_bits: integer := C_cached_addr_bits - C_i_addr_bits + 2;
    type T_icache_bram is array(0 to (C_icache_size * 256 - 1))
      of std_logic_vector(C_i_tag_bits + 32 - 1 downto 0);

    signal M_i_bram: T_icache_bram;

    signal i_addr: std_logic_vector(31 downto 2);
    signal i_data: std_logic_vector(31 downto 0);
    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out:
      std_logic_vector(C_i_tag_bits - 1 downto 0);
    signal to_i_bram, from_i_bram:
      std_logic_vector(C_i_tag_bits + 32 - 1 downto 0);
    signal iaddr_cacheable, icache_line_valid: boolean;
    signal iaddr_in_xram: std_logic;
    signal icache_write, instr_ready: std_logic;
    signal flush_i_line, flush_d_line: std_logic;

    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);
    signal R_i_burst_len: std_logic_vector(2 downto 0);

    --
    -- Old I-cache declarations end here, new D-cache stuff below
    --

    -- Data-side CPU interface
    signal cpu_d_addr: std_logic_vector(31 downto 2);
    signal cpu_d_data_in, cpu_d_data_out: std_logic_vector(31 downto 0);
    signal cpu_d_strobe, cpu_d_write, cpu_d_ready: std_logic;
    signal cpu_d_byte_sel: std_logic_vector(3 downto 0);

    -- Data cache
    constant C_d_addr_bits: integer := F_kb_to_addrlen(C_dcache_size);
    constant C_d_tag_bits: integer := C_cached_addr_bits - C_d_addr_bits + 1;
    type T_dcache_bram is array(0 to (C_dcache_size * 256 - 1))
      of std_logic_vector(C_d_tag_bits + 32 - 1 downto 0);

    signal M_d_bram: T_dcache_bram;
    signal R_d_tag_from_bram: std_logic_vector(C_d_tag_bits - 1 downto 0);
    signal R_d_data_from_bram: std_logic_vector(31 downto 0);
    signal R_d_cacheable_cycle, R_d_fetch_done: boolean;
    signal R_d_rd_addr: std_logic_vector(31 downto 2);

    signal d_rd_addr, d_wr_addr: std_logic_vector(C_d_addr_bits - 1 downto 2);
    signal d_from_bram, d_to_bram:
      std_logic_vector(C_d_tag_bits + 32 - 1 downto 0);
    signal d_bram_wr_enable: boolean;
    signal d_cacheable, d_miss_cycle: boolean;
    signal cpu_d_wait: std_logic;

    -- debugging
    signal clk_enable: std_logic;

begin
    assert (C_icache_size = 0 or C_icache_size * 1024 = 2 ** C_i_addr_bits)
      report "C_icache_size must be a power of two" severity failure;
    assert (C_icache_size <= 64)
      report "C_icache_size bigger than 64 KB not supported" severity failure;
    assert (C_i_addr_bits < C_cached_addr_bits)
      report "C_icache_size must be smaller than memory size" severity failure;

    assert (C_dcache_size = 0 or C_dcache_size * 1024 = 2 ** C_d_addr_bits)
      report "C_dcache_size must be a power of two" severity failure;
    assert (C_dcache_size <= 64)
      report "C_dcache_size bigger than 64 KB not supported" severity failure;
    assert (C_d_addr_bits < C_cached_addr_bits)
      report "C_dcache_size must be smaller than memory size" severity failure;

    debug_clk_ena <= clk_enable when C_debug else '1';

    --
    -- data cache FSM
    --
    G_dcache_logic:
    if C_dcache_size > 0 generate

    process(clk)
    begin
	if falling_edge(clk) and (not C_debug or clk_enable = '1') then
	    d_from_bram <= M_d_bram(conv_integer(d_rd_addr));
	end if;
	if rising_edge(clk) and (not C_debug or clk_enable = '1') then
	    if d_bram_wr_enable then
		M_d_bram(conv_integer(d_wr_addr)) <= d_to_bram;
	    end if;
	end if;
    end process;

    process(clk)
    begin
    if rising_edge(clk) and (not C_debug or clk_enable = '1') then
	R_d_tag_from_bram <= d_from_bram(d_from_bram'high downto 32);
	R_d_data_from_bram <= d_from_bram(31 downto 0);
	R_d_fetch_done <= d_miss_cycle and dmem_data_ready = '1';
	if not d_miss_cycle then
	    R_d_rd_addr <= cpu_d_addr;
	    R_d_cacheable_cycle <= d_cacheable and cpu_d_strobe = '1'
	      and cpu_d_write = '0';
	end if;
    end if;
    end process;

    d_wr_mux_iter: for b in 0 to 3 generate
    begin
    d_to_bram(b * 8 + 7 downto b * 8) <=
      dmem_data_in(b * 8 + 7 downto b * 8) when d_miss_cycle
      else cpu_d_data_out(b * 8 + 7 downto b * 8) when cpu_d_byte_sel(b) = '1'
      else R_d_data_from_bram(b * 8 + 7 downto b * 8);
    end generate;

    d_to_bram(d_to_bram'high downto 32) <=
      '0' & cpu_d_addr(C_cached_addr_bits - 1 downto C_d_addr_bits)
      when flush_d_line = '1'
      else '1' & R_d_rd_addr(C_cached_addr_bits - 1 downto C_d_addr_bits)
      when d_miss_cycle
      else '1' & cpu_d_addr(C_cached_addr_bits - 1 downto C_d_addr_bits)
      when cpu_d_byte_sel = x"f" or (R_d_tag_from_bram =
      '1' & R_d_rd_addr(C_cached_addr_bits - 1 downto C_d_addr_bits)
      and cpu_d_addr = R_d_rd_addr)
      else '0' & cpu_d_addr(C_cached_addr_bits - 1 downto C_d_addr_bits);

    d_cacheable <= cpu_d_addr(31 downto 28) = C_xram_base;
    d_rd_addr <= R_d_rd_addr(d_rd_addr'range) when d_miss_cycle
      else cpu_d_addr(d_rd_addr'range);
    d_wr_addr <= R_d_rd_addr(d_wr_addr'range) when d_miss_cycle
      else cpu_d_addr(d_rd_addr'range);
    d_bram_wr_enable <= (d_miss_cycle and dmem_data_ready = '1')
      or (not d_miss_cycle and d_cacheable and cpu_d_write = '1'
      and cpu_d_strobe = '1') or flush_d_line = '1';
    d_miss_cycle <= R_d_cacheable_cycle and not R_d_fetch_done
      and R_d_tag_from_bram /=
      '1' & R_d_rd_addr(C_cached_addr_bits - 1 downto C_d_addr_bits);

    end generate; -- G_dcache_logic

    dmem_addr <= R_d_rd_addr when d_miss_cycle else cpu_d_addr;
    dmem_addr_strobe <= '1' when d_miss_cycle
      else '0' when d_cacheable and cpu_d_write = '0'
      else cpu_d_strobe;
    dmem_write <= '0' when d_miss_cycle else cpu_d_write or flush_d_line;
    dmem_burst_len <= (others => '0');
    dmem_byte_sel <= cpu_d_byte_sel;
    dmem_data_out <= cpu_d_data_out;

    cpu_d_data_in <= dmem_data_in when d_miss_cycle
      else d_from_bram(31 downto 0) when d_cacheable else dmem_data_in;
    cpu_d_ready <= '1' when d_cacheable and cpu_d_write = '0'
      else dmem_data_ready;
    cpu_d_wait <= '1' when d_miss_cycle else '0';

    --
    -- Old I-cache stuff starts here
    --
    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_cache => true, C_reg_IF_PC => true,
	C_cpuid => C_cpuid, C_clk_freq => C_clk_freq, C_ll_sc => C_ll_sc,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_mul_acc => C_mul_acc, C_mul_reg => C_mul_reg,
	C_PC_mask => C_PC_mask,
	C_init_PC => C_init_PC, C_branch_prediction => C_branch_prediction,
	C_bp_global_depth => C_bp_global_depth,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_cop0_count => C_cop0_count, C_cop0_compare => C_cop0_compare,
	C_cop0_config => C_cop0_config, C_exceptions => C_exceptions,
	C_regfile_synchronous_read => C_regfile_synchronous_read,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => reset, intr => intr,
	imem_addr => i_addr, imem_data_in => i_data,
	imem_addr_strobe => open,
	imem_data_ready => instr_ready,
	dmem_addr_strobe => cpu_d_strobe,
	dmem_addr => cpu_d_addr,
	dmem_write => cpu_d_write, dmem_byte_sel => cpu_d_byte_sel,
	dmem_data_in => cpu_d_data_in, dmem_data_out => cpu_d_data_out,
	dmem_data_ready => cpu_d_ready, dmem_cache_wait => cpu_d_wait,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	flush_i_line => flush_i_line, flush_d_line => flush_d_line,
	-- debugging
	debug_in_data => debug_in_data,
	debug_in_strobe => debug_in_strobe,
	debug_in_busy => debug_in_busy,
	debug_out_data => debug_out_data,
	debug_out_strobe => debug_out_strobe,
	debug_out_busy => debug_out_busy,
	debug_clk_ena => clk_enable,
	debug_debug => debug_debug,
	debug_active => debug_active
    );

    icache_data_out <= from_i_bram(31 downto 0);
    icache_tag_out <= from_i_bram(from_i_bram'high downto 32);
    to_i_bram(31 downto 0) <= imem_data_in;
    to_i_bram(to_i_bram'high downto 32) <= icache_tag_in;

    G_icache_2k:
    if C_icache_size = 2 generate
    tag_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => True,
	data_width => C_i_tag_bits - 4,
	addr_width => C_i_addr_bits - 2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(C_i_addr_bits - 1 downto 2),
	addr_b => cpu_d_addr(C_i_addr_bits - 1 downto 2),
	data_in_a => to_i_bram(to_i_bram'high downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(from_i_bram'high downto 36),
	data_out_b => open
    );
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => True,
	data_width => 18,
	addr_width => C_i_addr_bits - 1
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => icache_write,
	addr_a(C_i_addr_bits - 2) => '0',
	addr_a(C_i_addr_bits - 3 downto 0) =>
	  i_addr(C_i_addr_bits - 1 downto 2),
	addr_b(C_i_addr_bits - 2) => '1',
	addr_b(C_i_addr_bits - 3 downto 0) =>
	  i_addr(C_i_addr_bits - 1 downto 2),
	data_in_a => to_i_bram(0 * 18 + 17 downto 0 * 18),
	data_in_b => to_i_bram(1 * 18 + 17 downto 1 * 18),
	data_out_a => from_i_bram(0 * 18 + 17 downto 0 * 18),
	data_out_b => from_i_bram(1 * 18 + 17 downto 1 * 18)
    );
    end generate; -- icache_2k

    G_icache_4k:
    if C_icache_size = 4 generate
    tag_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => True,
	data_width => C_i_tag_bits - 4,
	addr_width => C_i_addr_bits - 2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(C_i_addr_bits - 1 downto 2),
	addr_b => cpu_d_addr(C_i_addr_bits - 1 downto 2),
	data_in_a => to_i_bram(to_i_bram'high downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(from_i_bram'high downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 1 generate
    begin
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => False,
	data_width => 18,
	addr_width => C_i_addr_bits - 2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(C_i_addr_bits - 1 downto 2),
	addr_b => (others => '-'),
	data_in_a => to_i_bram(b * 18 + 17 downto b * 18),
	data_in_b => (others => '-'),
	data_out_a => from_i_bram(b * 18 + 17 downto b * 18),
	data_out_b => open
    );
    end generate i_block_iter;
    end generate; -- icache_4k

    G_icache_big:
    if C_icache_size >= 8 generate
    tag_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => True,
	data_width => C_i_tag_bits - 4,
	addr_width => C_i_addr_bits - 2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(C_i_addr_bits - 1 downto 2),
	addr_b => cpu_d_addr(C_i_addr_bits - 1 downto 2),
	data_in_a => to_i_bram(to_i_bram'high downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(from_i_bram'high downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 3 generate
    begin
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
	dual_port => False,
	data_width => 9,
	addr_width => C_i_addr_bits - 2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(C_i_addr_bits - 1 downto 2),
	addr_b => (others => '-'),
	data_in_a => to_i_bram(b * 9 + 8 downto b * 9),
	data_in_b => (others => '-'),
	data_out_a => from_i_bram(b * 9 + 8 downto b * 9),
	data_out_b => open
    );
    end generate i_block_iter;
    end generate; -- icache_big

    imem_addr <= R_i_addr;
    imem_burst_len <= R_i_burst_len when iaddr_cacheable else (others => '0');
    imem_addr_strobe <= '1' when not iaddr_cacheable else R_i_strobe;
    i_data <= icache_data_out when iaddr_cacheable else imem_data_in;
    instr_ready <= imem_data_ready when not iaddr_cacheable else
      '1' when icache_line_valid else '0';

    iaddr_cacheable <= C_icache_size /= 0;
    icache_write <= imem_data_ready when R_i_strobe = '1' else '0';
    iaddr_in_xram <= '1' when R_i_addr(31 downto 28) = C_xram_base else '0';
    icache_tag_in <= '1' & iaddr_in_xram
      & R_i_addr(C_cached_addr_bits - 1 downto C_i_addr_bits)
      when C_icache_size /= 0;
    icache_line_valid <= iaddr_cacheable and icache_tag_in = icache_tag_out;

    --
    -- instruction cache FSM
    --
    process(clk)
    begin
    if rising_edge(clk) then
	R_i_addr <= i_addr;
	R_i_burst_len <= (others => '0');
	if iaddr_cacheable and (not icache_line_valid)
	  and (imem_data_ready and R_i_strobe) = '0' then
	    R_i_strobe <= '1';
	else
	    R_i_strobe <= '0';
	end if;
    end if;
    end process;
end x;
