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

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity glue is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 25/81/100/125 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 8;
	C_i_rom_only: boolean := false;
        C_icache_expire: boolean := false; -- false: normal i-cache, true: passthru buggy i-cache
        C_icache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 25bits -> 2^25 -> 32MB to be cached
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_125m: in std_logic;
        rs232_tx: out std_logic;
        rs232_rx: in std_logic;
	led: out std_logic_vector(3 downto 0);
	sw: in std_logic_vector(3 downto 0);
	ja_u: inout std_logic_vector(3 downto 0);
	ja_d: inout std_logic_vector(3 downto 0);
	jb_u: inout std_logic_vector(3 downto 0);
	jb_d: inout std_logic_vector(3 downto 0);
	jc_u: inout std_logic_vector(3 downto 0);
	jc_d: inout std_logic_vector(3 downto 0);
	jd_u: inout std_logic_vector(3 downto 0);
	jd_d: inout std_logic_vector(3 downto 0);
--	hdmi_clk_p, hdmi_clk_n: out std_logic;
--	hdmi_d_p, hdmi_d_n: out std_logic_vector(2 downto 0);
--	vga_g: out std_logic_vector(5 downto 0);
--	vga_r, vga_b: out std_logic_vector(4 downto 0);
--	vga_hs, vga_vs: out std_logic;
	btn: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, clk_250MHz, clk_25MHz: std_logic;
    signal rs232_break: std_logic;
    signal tmds_out_rgb: std_logic_vector(2 downto 0);
    signal sram_a: std_logic_vector(18 downto 0);
    signal sram_d: std_logic_vector(15 downto 0);
    signal sram_wel, sram_lbl, sram_ubl: std_logic;
begin

    clk25: if C_clk_freq = 25 generate
    clkgen25: entity work.pll_125M_250M_100M_25M
    port map(
      clk_in1 => clk_125m, clk_out1 => clk_250MHz, clk_out2 => open, clk_out3 => clk_25MHz
    );
    clk <= clk_25MHz;
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen100: entity work.mmcm_125M_81M25_250M521_25M052
    port map(
      clk_in1 => clk_125m, clk_out1 => clk, clk_out2 => clk_250MHz, clk_out3 => clk_25MHz
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_125M_250M_100M_25M
    port map(
      clk_in1 => clk_125m, clk_out1 => clk_250MHz, clk_out2 => clk, clk_out3 => clk_25MHz
    );
    end generate;

    clk125: if C_clk_freq = 125 generate
    clk <= clk_125m;
    end generate;

    -- generic BRAM glue
    glue_bram: entity work.glue_sram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,
	C_i_rom_only => C_i_rom_only
    )
    port map (
	clk => clk,
	sio_tx => rs232_tx, sio_rx => rs232_rx,
	sio_break => open,
--	spi_sck(0)  => open,  spi_sck(1)  => open,
--	spi_ss(0)   => open,  spi_ss(1)   => open,
--	spi_mosi(0) => open,  spi_mosi(1) => open,
--	spi_miso(0) => '-',   spi_miso(1) => '-',
--	gpio(3 downto 0) => ja_u(3 downto 0),
--	gpio(7 downto 4) => ja_d(3 downto 0),
--	gpio(11 downto 8) => jb_u(3 downto 0),
--	gpio(15 downto 12) => jb_d(3 downto 0),
--	gpio(19 downto 16) => jc_u(3 downto 0),
--	gpio(23 downto 20) => jc_d(3 downto 0),
--	gpio(27 downto 24) => jd_u(3 downto 0),
--	gpio(31 downto 28) => jd_d(3 downto 0),
--	gpio(127 downto 32) => open,
	simple_out(3 downto 0) => led(3 downto 0),
	simple_out(31 downto 4) => open,
	simple_in(3 downto 0) => btn(3 downto 0),
	simple_in(15 downto 4) => open,
	simple_in(19 downto 16) => sw(3 downto 0),
	simple_in(31 downto 20) => open,
	sram_a => sram_a, sram_d => sram_d, sram_wel => sram_wel,
	sram_lbl => sram_lbl, sram_ubl => sram_ubl
    );

    sram_chip_emulation: entity work.sram_emu
    generic map
    (
      C_addr_width => 12
    )
    port map
    (
      clk => clk,
      sram_a => sram_a(11 downto 0), sram_d => sram_d,
      sram_wel => sram_wel,
      sram_lbl => sram_lbl, sram_ubl => sram_ubl
    );

end Behavioral;
