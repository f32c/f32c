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


entity video_cache is
    generic (
	-- cache options
	C_icache_size: integer;
	C_dcache_size: integer;

	-- bit widths
	C_cached_addr_bits: integer := 20; -- address bits of cached RAM (size=2^n) 20=1MB 25=32MB

	-- debugging options
	C_icache_expire: boolean := false -- true: i-cache will immediately expire every cached data
    );
    port (
        clk: in std_logic;
        -- video_fifo side read-only port
        i_addr: in std_logic_vector(31 downto 2) := (others => '0');
        i_data: out std_logic_vector(31 downto 0);
        instr_ready: out std_logic;
        cpu_flush_i_line: in std_logic := '0'; -- disabled if unconnected
        -- video_fifo side, read-write port
        d_addr: in std_logic_vector(31 downto 2) := (others => '0');
        cpu_d_data_in: out std_logic_vector(31 downto 0);
        cpu_d_data_out: in std_logic_vector(31 downto 0) := (others => '0');
        cpu_d_strobe, cpu_d_write: in std_logic := '0'; -- disabled if unconnected
        cpu_d_byte_sel: in std_logic_vector(3 downto 0) := "1111";
        cpu_d_ready: out std_logic;
        cpu_flush_d_line: in std_logic := '0';
        -- RAM port side
        imem_addr_strobe: out std_logic;
        imem_addr: out std_logic_vector(31 downto 2);
        imem_data_in: in std_logic_vector(31 downto 0) := (others => '0');
        imem_data_ready: in std_logic := '1';
        dmem_addr_strobe: out std_logic;
        dmem_write: out std_logic;
        dmem_byte_sel: out std_logic_vector(3 downto 0);
        dmem_addr: out std_logic_vector(31 downto 2);
        dmem_data_in: in std_logic_vector(31 downto 0) := (others => '0');
        dmem_data_out: out std_logic_vector(31 downto 0);
        dmem_data_ready: in std_logic := '1'; -- eveready
        --snoop_cycle: in std_logic;
        --snoop_addr: in std_logic_vector(31 downto 2);
        -- debugging only
        icache_write_enable: in std_logic := '1'; -- icache write enable
        icache_flush_enable: in std_logic := '1' -- icache flush enable
    );
end video_cache;

architecture x of video_cache is
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

    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal dcache_data_in: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out: std_logic_vector(C_itag_bits-1 downto 0);
    signal dcache_tag_in, dcache_tag_out: std_logic_vector(C_dtag_bits-1 downto 0);
    signal iaddr_cacheable, icache_line_valid: boolean;
    signal daddr_cacheable, dcache_line_valid: boolean;
    signal icache_write: std_logic;
    signal dcache_write, data_ready: std_logic;
    signal flush_i_line, flush_d_line: std_logic;
    signal flush_i_addr: std_logic_vector(31 downto 2);

    signal to_i_bram, from_i_bram: std_logic_vector(C_itag_bits+31 downto 0);
    signal to_d_bram, from_d_bram: std_logic_vector(C_dtag_bits+31 downto 0);

    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);
    signal R_i_addr_in_xram: std_logic; -- hacky distinguish XRAM/BRAM
    signal R_dcache_wbuf: std_logic_vector(31 downto 0);
    signal R_d_state: std_logic_vector(1 downto 0);
    signal dcache_data_out: std_logic_vector(31 downto 0);

    signal d_tag_valid_bit: std_logic;
begin
    assert (C_icache_size = 0 or C_icache_size = 2 or C_icache_size = 4
      or C_icache_size = 8 or C_icache_size = 16 or C_icache_size = 32)
      report "Invalid instruction cache size" severity failure;
    assert (C_dcache_size = 0 or C_dcache_size = 2 or C_dcache_size = 4
      or C_dcache_size = 8 or C_dcache_size = 16 or C_dcache_size = 32)
      report "Invalid data cache size" severity failure;

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
    R_i_addr_in_xram <= '1';
    icache_tag_in(1+C_cached_addr_bits-C_icache_addr_bits downto 0) 
      <= '1'
      & R_i_addr_in_xram -- dirty address decoding: external RAM or internal BRAM
      & R_i_addr(C_cached_addr_bits-1 downto C_icache_addr_bits);
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

    daddr_cacheable <= C_dcache_size > 0;
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
