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
-- Modifications by Davor Jadrijevic:
-- instantiation of generic bram modules
-- parametrization
-- separated d-cache from pipeline and i-cache
-- replaced address decoder with cpu_d_cacheable signal
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- to calculate log2 bit size

entity video_cache_d is
    generic (
	-- cache options
	C_dcache_size: integer := 0;
	C_cached_addr_bits: integer := 20; -- 1 MB
	C_cache_bursts: boolean := false;

	-- debugging options
	C_debug: boolean := false
    );
    port (
	clk: in std_logic;
        -- video_fifo side, read-write port
        cpu_d_cacheable: in std_logic := '1';
        cpu_d_addr: in std_logic_vector(31 downto 2);
        cpu_d_data_in: out std_logic_vector(31 downto 0);
        cpu_d_data_out: in std_logic_vector(31 downto 0);
        cpu_d_strobe, cpu_d_write: in std_logic; -- disabled if unconnected
        cpu_d_byte_sel: in std_logic_vector(3 downto 0);
        cpu_d_ready: out std_logic;
        -- RAM port side
	dmem_addr_strobe: out std_logic;
	dmem_write: out std_logic;
	dmem_byte_sel: out std_logic_vector(3 downto 0);
	dmem_addr: out std_logic_vector(31 downto 2);
	dmem_burst_len: out std_logic_vector(2 downto 0);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_data_ready: in std_logic
    );
end video_cache_d;

architecture x of video_cache_d is
    -- one-hot state encoding
    constant C_D_IDLE: integer := 0;
    constant C_D_WRITE: integer := 1;
    constant C_D_READ: integer := 2;
    constant C_D_FETCH: integer := 3;
    constant C_D_BURST: integer := 4;

    -- 1.0E-6 is small delta to prevent floating point errors
    -- aborting compilation when C_icache_size = 0
    -- delta value is insignificant for the result converted to integer
    constant C_dcache_addr_bits: integer := integer(ceil((log2(real(1024*C_dcache_size)+1.0E-6))-1.0E-6));

    -- bit widths of cache tags
    constant C_dtag_bits: integer := C_cached_addr_bits-C_dcache_addr_bits+1;  -- +1 = 1 extra bit for data valid

    signal dcache_addr: std_logic_vector(31 downto 2);
    signal dcache_data_in: std_logic_vector(31 downto 0);
    signal dcache_tag_in, dcache_tag_out: std_logic_vector(C_dtag_bits-1 downto 0);
    signal daddr_cacheable, dcache_line_valid: boolean;
    signal dcache_write, data_ready: std_logic;
    signal to_d_bram, from_d_bram: std_logic_vector(C_dtag_bits+31 downto 0);

    signal R_d_addr: std_logic_vector(31 downto 2);
    signal R_d_burst_len: std_logic_vector(2 downto 0);
    signal R_dcache_wbuf: std_logic_vector(31 downto 0);
    signal R_d_state: std_logic_vector(4 downto 0);
    signal dcache_data_out: std_logic_vector(31 downto 0);

    signal d_tag_valid_bit: std_logic;
begin
    assert (C_dcache_size = 0 or C_dcache_size = 2 or C_dcache_size = 4
      or C_dcache_size = 8 or C_dcache_size = 16 or C_dcache_size = 32)
      report "Invalid data cache size" severity failure;

    process(clk)
    begin
    if rising_edge(clk) then
	--
	-- data cache FSM
	--
	if R_d_state(C_D_IDLE) = '1' then
	    if cpu_d_strobe = '1' and daddr_cacheable then
		R_d_addr <= cpu_d_addr;
		R_d_state <= (others => '0');
		if cpu_d_write = '1' then
		    R_d_state(C_D_WRITE) <= '1';
		else
		    R_d_state(C_D_READ) <= '1';
		end if;
	    end if;
	elsif R_d_state(C_D_WRITE) = '1' then
	    if dmem_data_ready = '1' then
		R_d_state <= (others => '0');
		R_d_state(C_D_IDLE) <= '1';
	    end if;
	elsif R_d_state(C_D_READ) = '1' then
	    R_d_state <= (others => '0');
	    if dcache_line_valid then
		R_d_state(C_D_IDLE) <= '1';
	    else
		R_d_state(C_D_FETCH) <= '1';
		if C_cache_bursts then
		    R_d_burst_len <= "111" - R_d_addr(4 downto 2);
		end if;
	    end if;
	elsif R_d_state(C_D_FETCH) = '1'
	  or (C_cache_bursts and R_d_state(C_D_BURST) = '1') then
	    if dmem_data_ready = '1' then
		R_d_state <= (others => '0');
		if C_cache_bursts and R_d_burst_len /= 0 then
		    R_d_state(C_D_BURST) <= '1';
		    R_d_burst_len <= R_d_burst_len - 1;
		    R_d_addr(4 downto 2) <= R_d_addr(4 downto 2) + 1;
		else
		    R_d_state(C_D_IDLE) <= '1';
		end if;
	    end if;
	else
	    R_d_state <= (others => '0');
	    R_d_state(C_D_IDLE) <= '1';
	end if;
    end if;
    end process;

    dmem_addr <= R_d_addr when R_d_state(C_D_IDLE) = '0' else cpu_d_addr;
    dmem_burst_len <= R_d_burst_len;
    dmem_write <=
      cpu_d_write when not C_cache_bursts or R_d_state(C_D_IDLE) = '1'
      else '1' when R_d_state(C_D_WRITE) = '1' else '0';
    dmem_byte_sel <= cpu_d_byte_sel;
    dmem_data_out <= cpu_d_data_out;

    dmem_addr_strobe <= '1' when C_cache_bursts and R_d_state(C_D_BURST) = '1'
      else cpu_d_strobe when (not daddr_cacheable) or cpu_d_write = '1'
      else '0' when R_d_state(C_D_READ) = '1' and dcache_line_valid
      else '0' when R_d_state(C_D_IDLE) = '1' else cpu_d_strobe;
    cpu_d_data_in <= dcache_data_out when R_d_state(C_D_READ) = '1'
      else dmem_data_in;
    cpu_d_ready <= '1' when R_d_state(C_D_READ) = '1' and dcache_line_valid
      else dmem_data_ready
	when (not daddr_cacheable and R_d_state(C_D_IDLE) = '1')
      or R_d_state(C_D_FETCH) = '1' or R_d_state(C_D_WRITE) = '1' else '0';

    daddr_cacheable <= C_dcache_size > 0 and cpu_d_cacheable = '1';
    dcache_addr <= cpu_d_addr when not C_cache_bursts or
      R_d_state(C_D_IDLE) = '1' else R_d_addr;
    dcache_write <= dmem_data_ready when (R_d_state(C_D_WRITE) = '1'
      or R_d_state(C_D_FETCH) = '1' or R_d_state(C_D_BURST) = '1') else '0';
    d_tag_valid_bit <= '0' when R_d_state(C_D_WRITE) = '1'
      and cpu_d_byte_sel /= "1111" and not dcache_line_valid else '1';
    dtag_valid: if C_dcache_size > 0 generate
    dcache_tag_in(C_dtag_bits-1) <= d_tag_valid_bit;
    dcache_tag_in(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0) <= dcache_addr(C_cached_addr_bits-1 downto C_dcache_addr_bits);
    dcache_line_valid <= dcache_tag_out(C_dtag_bits-1) = '1' 
      and dcache_tag_in(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0) = dcache_tag_out(C_cached_addr_bits-C_dcache_addr_bits-1 downto 0);
    end generate;

    dcache_tag_out <= from_d_bram(C_dtag_bits+31 downto 32);
    dcache_data_out <= from_d_bram(31 downto 0);
    to_d_bram(C_dtag_bits+31 downto 32) <= dcache_tag_in;
    to_d_bram(31 downto 0) <= R_dcache_wbuf when R_d_state(C_D_WRITE) = '1'
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
	addr_a => dcache_addr(C_dcache_addr_bits-1 downto 2),
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
	addr_a => '0' & dcache_addr(C_dcache_addr_bits-1 downto 2),
	addr_b => '1' & dcache_addr(C_dcache_addr_bits-1 downto 2),
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
	addr_a => dcache_addr(C_dcache_addr_bits-1 downto 2),
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
	addr_a => dcache_addr(C_dcache_addr_bits-1 downto 2),
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
	addr_a => dcache_addr(C_dcache_addr_bits-1 downto 2),
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
	addr_a => dcache_addr(C_dcache_addr_bits-1 downto 2),
	addr_b => (others => '0'),
	data_in_a => to_d_bram(b * 9 + 8 downto b * 9),
	data_in_b => (others => '0'),
	data_out_a => from_d_bram(b * 9 + 8 downto b * 9),
	data_out_b => open
    );
    end generate d_block_iter;
    end generate; -- dcache_big
end x;
