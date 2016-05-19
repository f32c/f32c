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
-- master should hold i_addr until ready, if this is not the
-- case then arrived data from external RAM will be written
-- in wrong place in the cache
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- to calculate log2 bit size

entity video_cache_i is
    generic (
	-- cache options
	C_icache_size: integer;

	-- bit widths
	C_cached_addr_bits: integer := 20; -- address bits of cached RAM (size=2^n) 20=1MB 25=32MB

	-- debugging options
	C_icache_expire: boolean := false -- true: i-cache will immediately expire every cached data
    );
    port (
        clk: in std_logic;
        -- video_fifo side read-only port
        -- i_cacheable allows selective cacheing for each read cycle
        -- '1'-read from cache if found valid data or read from RAM with storing in cache for later read
        -- '0'-directly read from RAM, bypassing cache
        i_cacheable: in std_logic := '1';
        i_addr: in std_logic_vector(31 downto 2) := (others => '0');
        i_addr_strobe: in std_logic := '0';
        i_data: out std_logic_vector(31 downto 0);
        i_ready: out std_logic;
        i_flush: in std_logic := '0'; -- disabled if unconnected
        i_addr_flush: in std_logic_vector(31 downto 2) := (others => '0');
        -- RAM port side
        imem_addr_strobe: out std_logic;
        imem_addr: out std_logic_vector(31 downto 2);
        imem_data_in: in std_logic_vector(31 downto 0);
        imem_data_ready: in std_logic
    );
end video_cache_i;

architecture x of video_cache_i is
    -- 1.0E-6 is small delta to prevent floating point errors
    -- aborting compilation when C_icache_size = 0
    -- delta value is insignificant for the result converted to integer
    constant C_icache_addr_bits: integer := integer(ceil((log2(real(1024*C_icache_size)+1.0E-6))-1.0E-6));

    -- bit widths of cache tags
    constant C_itag_bits: integer := C_cached_addr_bits-C_icache_addr_bits+1;  -- +1 = 1 extra bit for data valid

    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out: std_logic_vector(C_itag_bits-1 downto 0);
    signal iaddr_cacheable, icache_line_valid: std_logic;
    signal icache_write: std_logic;
    signal flush_i_line: std_logic;
    signal flush_i_addr: std_logic_vector(31 downto 2);

    signal to_i_bram, from_i_bram: std_logic_vector(C_itag_bits+31 downto 0);
    --signal R_iaddr_cacheable: std_logic := '0';
    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);
begin
    assert (C_icache_size = 0 or C_icache_size = 2 or C_icache_size = 4
      or C_icache_size = 8 or C_icache_size = 16 or C_icache_size = 32)
      report "Invalid instruction cache size" severity failure;

    icache_data_out <= from_i_bram(31 downto 0);
    icache_tag_out <= from_i_bram(C_itag_bits+31 downto 32);
    to_i_bram(31 downto 0) <= imem_data_in;
    to_i_bram(C_itag_bits+31 downto 32) <= icache_tag_in;

    normal_icache: if not C_icache_expire generate
      flush_i_line <= i_flush;
      flush_i_addr <= i_addr_flush;
    end generate;

    debug_icache: if C_icache_expire generate
      process(clk)
      begin
        if rising_edge(clk) then
          -- once used i_addr cache line immediately discarded on the next clock
          -- pass i-data from SDRAM thru cache and expire
          flush_i_line <= icache_write;
          flush_i_addr <= i_addr;
        end if;
      end process;
    end generate;

    G_icache: if C_icache_size > 0 generate
    icache_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => True,
        data_width => C_itag_bits+32,
        addr_width => C_icache_addr_bits-2
    )
    port map (
	clk => clk,
	we_a => icache_write, we_b => flush_i_line,
	addr_a(C_icache_addr_bits-3 downto 0) => i_addr(C_icache_addr_bits-1 downto 2),
	addr_b(C_icache_addr_bits-3 downto 0) => flush_i_addr(C_icache_addr_bits-1 downto 2),
	data_in_a => to_i_bram,
	data_in_b => (others => '0'),
	data_out_a => from_i_bram,
	data_out_b => open
    );
    end generate;

    iaddr_cacheable <= i_cacheable when C_icache_size > 0 else '0';
    imem_addr <= i_addr;
    imem_addr_strobe <= R_i_strobe when iaddr_cacheable='1' else i_addr_strobe;
    i_data <= icache_data_out when iaddr_cacheable='1' else imem_data_in;
    i_ready <= icache_line_valid when iaddr_cacheable='1' else imem_data_ready;

    icache_write <= iaddr_cacheable and imem_data_ready and not icache_line_valid;
    itag_valid: if C_icache_size > 0 generate
    icache_tag_in(C_cached_addr_bits-C_icache_addr_bits downto 0)
          <= '1' & R_i_addr(C_cached_addr_bits-1 downto C_icache_addr_bits);
    icache_line_valid <= '1' when
              icache_tag_in(C_cached_addr_bits-C_icache_addr_bits downto 0)
           = icache_tag_out(C_cached_addr_bits-C_icache_addr_bits downto 0)
           else '0';
    end generate;

    G_no_fsm: if false generate
      -- this almost works but has problems
      -- (first word incorrect, following OK)
      R_i_addr <= i_addr;
      R_i_strobe <= iaddr_cacheable and not icache_line_valid;
    end generate;

    G_yes_fsm: if true generate
      -- it uses register to stabilize data
      -- also more response delay than above
      -- but this works
      process(clk)
      begin
        if rising_edge(clk) then
          -- cache FSM
          --if R_i_strobe = '0'
          --then
          R_i_addr <= i_addr;
          --R_iaddr_cacheable <= iaddr_cacheable;
          --end if;
          if iaddr_cacheable = '1'
          and icache_line_valid = '0'
          --and R_i_strobe = '0'
          --and imem_data_ready = '0'
          and (imem_data_ready = '0' or R_i_strobe = '0')
          then
            R_i_strobe <= '1';
          else
            R_i_strobe <= '0';
          end if;
        end if;
      end process;
    end generate;

end x;
