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

use work.f32c_pack.all;

entity glue is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81 or 112
	C_clk_freq: integer := 81;

	-- SoC configuration options
	C_bram_size: integer := 2;
        C_icache_size: integer := 2;
        C_dcache_size: integer := 2;
        C_acram: boolean := true;
	C_sio: integer := 1;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_txd: out std_logic;
	rs232_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	gpio: inout std_logic_vector(31 downto 0);
	btn_left, btn_right: in std_logic
    );
end glue;

architecture Behavioral of glue is
  signal clk: std_logic;
  signal btns: std_logic_vector(1 downto 0);
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_read_busy      : std_logic := '0';
begin
    -- clock synthesizer: Altera specific
    clk112: if C_clk_freq = 112 generate
    clkgen: entity work.pll_25M_112M5
    port map(
      inclk0 => clk_25m, c0 => clk
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen: entity work.pll_25M_81M25
    port map(
      inclk0 => clk_25m, c0 => clk
    );
    end generate;

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_bram_size => C_bram_size,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_acram => C_acram,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      sio_txd(0) => rs232_txd, sio_rxd(0) => rs232_rxd,
      spi_sck => open, spi_ss => open, spi_mosi => open, spi_miso => "",
      gpio(31 downto 0) => gpio(31 downto 0), gpio(127 downto 32) => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_read_busy => ram_read_busy,
      simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
      simple_in(1 downto 0) => btns, simple_in(31 downto 2) => open
    );
    btns <= btn_left & btn_right;

    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 12
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(13 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_en => ram_en
    );

end Behavioral;
