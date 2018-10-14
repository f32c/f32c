--
-- Copyright (c) 2015 Davor Jadrijevic
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity glue is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
        C_regfile_synchronous_read: boolean := true;
	C_debug: boolean := false;

	-- Main clock: 81/100
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 2;
	C_acram: boolean := true;
	C_acram_wait_cycles: integer := 3; -- 3 or more
        C_acram_emu_kb: integer := 32; -- KB axi_cache emulation (power of 2, MAX 32)
        C_icache_size: integer := 2;	-- 0, 2, 4, 8, 16 or 32 KBytes
        C_dcache_size: integer := 2;	-- 0, 2, 4, 8, 16 or 32 KBytes
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	Led: out std_logic_vector(7 downto 0);
	gpio: inout std_logic_vector(39 downto 0);
	icp: in std_logic_vector(1 downto 0);
	ocp: out std_logic_vector(1 downto 0);
        flash_csn, flash_clk, flash_mosi: out std_logic;
        flash_miso: in std_logic;
	btn_k2, btn_k3: in std_logic
    );
end glue;

architecture Behavioral of glue is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
  signal clk, rs232_break: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic := '1';
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_25M_112M5
    port map(
      clk_in1 => clk_25m, clk_out1 => clk
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.clk_25_100_125_25
    port map(
      clk_25M_in => clk_25m, clk_100M => clk,
      clk_125Mp => open, clk_125Mn => open, clk_25M => open,
      reset => '0', locked => open
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_25M_81M25
    port map(
      clk_in1 => clk_25m, clk_out1 => clk
    );
    end generate;

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
    );

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
        C_regfile_synchronous_read => C_regfile_synchronous_read,
	C_bram_size => C_bram_size,
	C_acram => C_acram,
        C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_dce_txd, sio_rxd(0) => rs232_dce_rxd,
	sio_break(0) => rs232_break,
        acram_en => ram_en,
        acram_addr(29 downto 2) => ram_address(29 downto 2),
        acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
        acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
        acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
        acram_ready => ram_ready,
	spi_sck(0)  => flash_clk,  spi_sck(1)  => open,
	spi_ss(0)   => flash_csn,  spi_ss(1)   => open,
	spi_mosi(0) => flash_mosi, spi_mosi(1) => open,
	spi_miso(0) => flash_miso, spi_miso(1) => '-',
	gpio(31 downto 0) => gpio(31 downto 0),
	gpio(127 downto 32) => open,
	icp => icp, ocp => ocp,
	simple_out(7 downto 0) => Led(7 downto 0),
	simple_out(31 downto 8) => open,
	simple_in(0) => btn_k2,
	simple_in(1) => btn_k3,
	simple_in(31 downto 2) => open
    );

    G_acram: if C_acram generate
    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 8 + ceil_log2(C_acram_emu_kb)
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(9 + ceil_log2(C_acram_emu_kb) downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_en => ram_en
    );
    end generate;

end Behavioral;
