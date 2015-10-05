--
-- Copyright (c) 2013 - 2014 Marko Zec, University of Zagreb
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
-- Davor Jadrijevic: instantiation of generic bram modules, parametrization
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- to calculate log2 bit size
use work.f32c_pack.all;


entity cache is
    generic (
	-- ISA options
	C_arch: integer;
	C_big_endian: boolean;
	C_mult_enable: boolean;
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_ll_sc: boolean;
	C_movn_movz: boolean;
	C_exceptions: boolean;
	C_PC_mask: std_logic_vector(31 downto 0);

	-- COP0 options
	C_clk_freq: integer;
	C_cpuid: integer;
	C_cop0_count: boolean;
	C_cop0_compare: boolean;
	C_cop0_config: boolean;

	-- optimization options
	C_result_forwarding: boolean;
	C_full_shifter: boolean;
	C_branch_prediction: boolean;
	C_load_aligner: boolean;
	C_register_technology: string;

	-- cache options
	C_icache_size: integer;
	C_dcache_size: integer;

	-- bit widths
	C_cached_addr_bits: integer := 20; -- address bits of cached RAM (size=2^n) 20=1MB 25=32MB

	-- debugging options
	C_icache_expire: boolean := false; -- true: i-cache will immediately expire every cached data
	C_debug: boolean
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
	intr: in std_logic_vector(5 downto 0);
	-- debugging only
	icache_write_enable: in std_logic := '1'; -- icache write enable
	icache_flush_enable: in std_logic := '1'; -- icache flush enable

	debug_in_data: in std_logic_vector(7 downto 0);
	debug_in_strobe: in std_logic;
	debug_in_busy: out std_logic;
	debug_out_data: out std_logic_vector(7 downto 0);
	debug_out_strobe: out std_logic;
	debug_out_busy: in std_logic;
	debug_debug: out std_logic_vector(7 downto 0);
	debug_active: out std_logic
    );
end cache;

architecture x of cache is
    constant C_D_IDLE: std_logic_vector := "00";
    constant C_D_WRITE: std_logic_vector := "01";
    constant C_D_READ: std_logic_vector := "10";
    constant C_D_FETCH: std_logic_vector := "11";

    -- 1.0E-6 is small delta to prevent floating point errors
    -- aborting compilation when C_icache_size = 0
    -- delta value is insignificant for the result converted to integer
    constant C_icache_addr_bits: integer := integer(ceil((log2(real(1024*C_icache_size)+1.0E-6))-1.0E-6));
    constant C_dcache_addr_bits: integer := integer(ceil((log2(real(1024*C_dcache_size)+1.0E-6))-1.0E-6));

    -- bit widths of cache tags
    constant C_itag_bits: integer := C_cached_addr_bits-C_icache_addr_bits+2;  -- +2 = 1 extra bit for data valid + 1 extra bit for addr(31)
    constant C_dtag_bits: integer := C_cached_addr_bits-C_dcache_addr_bits+1;  -- +1 = 1 extra bit for data valid

    signal i_addr, d_addr: std_logic_vector(31 downto 2);
    signal i_data: std_logic_vector(31 downto 0);
    signal cpu_d_data_in, cpu_d_data_out: std_logic_vector(31 downto 0);
    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal dcache_data_in: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out: std_logic_vector(C_itag_bits-1 downto 0);
    signal dcache_tag_in, dcache_tag_out: std_logic_vector(C_dtag_bits-1 downto 0);
    signal iaddr_cacheable, icache_line_valid: boolean;
    signal daddr_cacheable, dcache_line_valid: boolean;
    signal icache_write, instr_ready: std_logic;
    signal dcache_write, data_ready: std_logic;
    signal cpu_flush_i_line, cpu_flush_d_line: std_logic;
    signal flush_i_line, flush_d_line: std_logic;
    signal flush_i_addr: std_logic_vector(31 downto 2);
    signal to_i_bram, from_i_bram: std_logic_vector(C_itag_bits+31 downto 0);
    signal to_d_bram, from_d_bram: std_logic_vector(C_dtag_bits+31 downto 0);

    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);
    signal R_dcache_wbuf: std_logic_vector(31 downto 0);
    signal R_d_state: std_logic_vector(1 downto 0);
    signal dcache_data_out: std_logic_vector(31 downto 0);

    signal cpu_d_strobe, cpu_d_write, cpu_d_ready: std_logic;
    signal cpu_d_byte_sel: std_logic_vector(3 downto 0);
    signal d_tag_valid_bit: std_logic;
begin

    assert (C_icache_size = 0 or C_icache_size = 2 or C_icache_size = 4
      or C_icache_size = 8 or C_icache_size = 16 or C_icache_size = 32)
      report "Invalid instruction cache size" severity failure;
    assert (C_dcache_size = 0 or C_dcache_size = 2 or C_dcache_size = 4
      or C_dcache_size = 8 or C_dcache_size = 16 or C_dcache_size = 32)
      report "Invalid data cache size" severity failure;

    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_cache => true, C_reg_IF_PC => true,
	C_cpuid => C_cpuid, C_clk_freq => C_clk_freq, C_ll_sc => C_ll_sc,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_register_technology => C_register_technology,
	C_cop0_count => C_cop0_count, C_cop0_compare => C_cop0_compare,
	C_cop0_config => C_cop0_config, C_exceptions => C_exceptions,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => reset, intr => intr,
	imem_addr => i_addr, imem_data_in => i_data,
	imem_addr_strobe => open,
	imem_data_ready => instr_ready,
	dmem_addr_strobe => cpu_d_strobe,
	dmem_addr => d_addr,
	dmem_write => cpu_d_write, dmem_byte_sel => cpu_d_byte_sel,
	dmem_data_in => cpu_d_data_in, dmem_data_out => cpu_d_data_out,
	dmem_data_ready => cpu_d_ready,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	flush_i_line => cpu_flush_i_line, flush_d_line => cpu_flush_d_line,
	-- debugging
	debug_in_data => debug_in_data,
	debug_in_strobe => debug_in_strobe,
	debug_in_busy => debug_in_busy,
	debug_out_data => debug_out_data,
	debug_out_strobe => debug_out_strobe,
	debug_out_busy => debug_out_busy,
	debug_debug => debug_debug,
	debug_active => debug_active
    );

    icache_data_out <= from_i_bram(31 downto 0);
    icache_tag_out <= from_i_bram(C_itag_bits+31 downto 32);
    to_i_bram(31 downto 0) <= imem_data_in;
    to_i_bram(C_itag_bits+31 downto 32) <= icache_tag_in;

    normal_icache: if not C_icache_expire generate
      flush_i_line <= cpu_flush_i_line and icache_flush_enable;
      flush_i_addr <= d_addr;
    end generate;

    debug_icache: if C_icache_expire generate
      process(clk)
      begin
        if rising_edge(clk) then
          -- once used i_addr cache line immediately discarded on the next clock
          -- pass i-data from SDRAM thru cache and expire
          flush_i_line <= icache_write and icache_flush_enable;
          flush_i_addr <= i_addr;
        end if;
      end process;
    end generate;

    G_icache_2k:
    if C_icache_size = 2 generate
    tag_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => True,
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_itag_bits-(36-32), 
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a(C_icache_addr_bits-3 downto 0) => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b(C_icache_addr_bits-3 downto 0) => flush_i_addr(C_icache_addr_bits-1 downto 2),
	data_in_a => to_i_bram(C_itag_bits+31 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(C_itag_bits+31 downto 36),
	data_out_b => open
    );
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => True,
        data_width => 18, -- double size: 2-port 18-bit bram used as 1-port 36-bit
        addr_width => C_icache_addr_bits-1
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => icache_write,
	addr_a(C_icache_addr_bits-2) => '0',
	addr_a(C_icache_addr_bits-3 downto 0) => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b(C_icache_addr_bits-2) => '1',
	addr_b(C_icache_addr_bits-3 downto 0) => i_addr(C_icache_addr_bits-1 downto 2),
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
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_itag_bits-(36-32), 
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b => flush_i_addr(C_icache_addr_bits-1 downto 2),
	data_in_a => to_i_bram(C_itag_bits+31 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(C_itag_bits+31 downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 1 generate
    begin
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        data_width => 18,
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(C_icache_addr_bits-1 downto 2),
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
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_itag_bits-(36-32), 
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b => flush_i_addr(C_icache_addr_bits-1 downto 2),
	data_in_a => to_i_bram(C_itag_bits+31 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(C_itag_bits+31 downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 3 generate
    begin
    i_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        data_width => 9,
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b => (others => '-'),
	data_in_a => to_i_bram(b * 9 + 8 downto b * 9),
	data_in_b => (others => '-'),
	data_out_a => from_i_bram(b * 9 + 8 downto b * 9),
	data_out_b => open
    );
    end generate i_block_iter;
    end generate; -- icache_big

    imem_addr <= R_i_addr;
    imem_addr_strobe <= '1' when not iaddr_cacheable else R_i_strobe;
    i_data <= icache_data_out when iaddr_cacheable else imem_data_in;
    instr_ready <= imem_data_ready when not iaddr_cacheable else
      '1' when icache_line_valid else '0';

    iaddr_cacheable <= C_icache_size > 0; -- XXX kseg0: R_i_addr(31 downto 29) = "100";
    icache_write <= imem_data_ready and R_i_strobe and icache_write_enable;
    itag_valid: if C_icache_size > 0 generate
    icache_tag_in(1+C_cached_addr_bits-C_icache_addr_bits downto 0) 
      <= '1' & R_i_addr(31) & R_i_addr(C_cached_addr_bits-1 downto C_icache_addr_bits);
    icache_line_valid <= iaddr_cacheable
      and '1' & icache_tag_in(C_cached_addr_bits-C_icache_addr_bits downto 0) 
           = icache_tag_out(1+C_cached_addr_bits-C_icache_addr_bits downto 0);
    end generate;

    process(clk)
    begin
    if rising_edge(clk) then
	--
	-- instruction cache FSM
	--
	R_i_addr <= i_addr;
	if iaddr_cacheable
	  and (not icache_line_valid) and imem_data_ready = '0' then
	    R_i_strobe <= '1';
	else
	    R_i_strobe <= '0';
	end if;

	--
	-- data cache FSM
	--
	if cpu_d_strobe = '0' or dmem_data_ready = '1' then
	    R_d_state <= C_D_IDLE;
	elsif R_d_state = C_D_READ and dcache_line_valid then
	    R_d_state <= C_D_IDLE;
	elsif cpu_d_strobe = '1' and daddr_cacheable then
	    if cpu_d_write = '1' then
		R_d_state <= C_D_WRITE;
	    elsif R_d_state = C_D_IDLE then
		R_d_state <= C_D_READ;
	    else
		R_d_state <= C_D_FETCH;
	    end if;
	else
	    R_d_state <= C_D_IDLE;
	end if;
    end if;
    end process;

    dmem_addr <= d_addr;
    dmem_write <= cpu_d_write;
    dmem_byte_sel <= cpu_d_byte_sel;
    dmem_data_out <= cpu_d_data_out;

    dmem_addr_strobe <=
      cpu_d_strobe when (not daddr_cacheable) or cpu_d_write = '1'
      else '0' when R_d_state = C_D_READ and dcache_line_valid
      else '0' when R_d_state = C_D_IDLE else cpu_d_strobe;
    cpu_d_data_in <= dcache_data_out when R_d_state = C_D_READ
      else dmem_data_in;
    cpu_d_ready <= '1' when R_d_state = C_D_READ and dcache_line_valid
      else dmem_data_ready;

    daddr_cacheable <= C_dcache_size > 0 and d_addr(31 downto 29) = "100";
    dcache_write <= dmem_data_ready when
      (R_d_state = C_D_WRITE or R_d_state = C_D_FETCH) else '0';
    d_tag_valid_bit <= '0' when cpu_d_write = '1' and cpu_d_byte_sel /= "1111"
      and not dcache_line_valid else '1';
    dtag_valid: if C_dcache_size > 0 generate
    dcache_tag_in(C_dtag_bits-1) <= d_tag_valid_bit;
    dcache_tag_in(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0) <= d_addr(C_cached_addr_bits-1 downto C_dcache_addr_bits);
    dcache_line_valid <= dcache_tag_out(C_dtag_bits-1) = '1' 
      and dcache_tag_in(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0) = dcache_tag_out(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0);
    end generate;

    dcache_tag_out <= from_d_bram(C_dtag_bits+31 downto 32);
    dcache_data_out <= from_d_bram(31 downto 0);
    to_d_bram(C_dtag_bits+31 downto 32) <= dcache_tag_in;
    to_d_bram(31 downto 0) <= R_dcache_wbuf when R_d_state = C_D_WRITE
      else dmem_data_in;

    each_byte: for i in 0 to 3 generate
    process(clk)
    begin
    if falling_edge(clk) then
	if cpu_d_byte_sel(i) = '1' then
	    R_dcache_wbuf(8*i+7 downto 8*i) <= cpu_d_data_out(8*i+7 downto 8*i);
	else
	    R_dcache_wbuf(8*i+7 downto 8*i) <= dcache_data_out(8*i+7 downto 8*i);
	end if;
    end if;
    end process;
    end generate;

    G_dcache_2k:
    if C_dcache_size = 2 generate
    tag_dp_bram_d: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_dtag_bits-(36-32), 
        addr_width => C_dcache_addr_bits-2
    )
    port map (
	clk => clk,
	we_b => '0', we_a => dcache_write,
	addr_b => (others => '0'),
	addr_a => d_addr(C_dcache_addr_bits-1 downto 2),
	data_in_b => (others => '0'),
	data_in_a => to_d_bram(C_dtag_bits+31 downto 36),
	data_out_b => open,
	data_out_a => from_d_bram(C_dtag_bits+31 downto 36)
    );
    d_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => True,
        data_width => 18,
        addr_width => C_dcache_addr_bits-1
    )
    port map (
	clk => clk,
	we_a => dcache_write, we_b => dcache_write,
	addr_a => '0' & d_addr(C_dcache_addr_bits-1 downto 2),
	addr_b => '1' & d_addr(C_dcache_addr_bits-1 downto 2),
	data_in_a => to_d_bram(0 * 18 + 17 downto 0 * 18),
	data_in_b => to_d_bram(1 * 18 + 17 downto 1 * 18),
	data_out_a => from_d_bram(0 * 18 + 17 downto 0 * 18),
	data_out_b => from_d_bram(1 * 18 + 17 downto 1 * 18)
    );
    end generate; -- dcache_2k

    G_dcache_4k:
    if C_dcache_size = 4 generate
    tag_dp_bram_d: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_dtag_bits-(36-32), 
        addr_width => C_dcache_addr_bits-2
    )
    port map (
	clk => clk,
	we_b => '0', we_a => dcache_write,
	addr_b => (others => '0'),
	addr_a => d_addr(C_dcache_addr_bits-1 downto 2),
	data_in_b => (others => '0'),
	data_in_a => to_d_bram(C_dtag_bits+31 downto 36),
	data_out_b => open,
	data_out_a => from_d_bram(C_dtag_bits+31 downto 36)
    );
    d_block_iter: for b in 0 to 1 generate
    begin
    d_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        data_width => 18,
        addr_width => C_dcache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => dcache_write, we_b => '0',
	addr_a => d_addr(C_dcache_addr_bits-1 downto 2),
	addr_b => (others => '0'),
	data_in_a => to_d_bram(b * 18 + 17 downto b * 18),
	data_in_b => (others => '0'),
	data_out_a => from_d_bram(b * 18 + 17 downto b * 18),
	data_out_b => open
    );
    end generate d_block_iter;
    end generate; -- dcache_4k

    G_dcache_big:
    if C_dcache_size >= 8 generate
    tag_dp_bram_d: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        -- 36: bram consists of 4 9-bit blocks
        -- 32: CPU data bus width
        -- 36-32=4: we have 4 extra bits of other BRAM to use for tag
        data_width => C_dtag_bits-(36-32), 
        addr_width => C_dcache_addr_bits-2
    )
    port map (
	clk => clk,
	we_b => '0', we_a => dcache_write,
	addr_b => (others => '0'),
	addr_a => d_addr(C_dcache_addr_bits-1 downto 2),
	data_in_b => (others => '0'),
	data_in_a => to_d_bram(C_dtag_bits+31 downto 36),
	data_out_b => open,
	data_out_a => from_d_bram(C_dtag_bits+31 downto 36)
    );
    d_block_iter: for b in 0 to 3 generate
    begin
    d_dp_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => False,
        data_width => 9,
        addr_width => C_dcache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => dcache_write, we_b => '0',
	addr_a => d_addr(C_dcache_addr_bits-1 downto 2),
	addr_b => (others => '0'),
	data_in_a => to_d_bram(b * 9 + 8 downto b * 9),
	data_in_b => (others => '0'),
	data_out_a => from_d_bram(b * 9 + 8 downto b * 9),
	data_out_b => open
    );
    end generate d_block_iter;
    end generate; -- dcache_big
end x;
