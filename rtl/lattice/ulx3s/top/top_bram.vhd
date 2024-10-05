--
-- Copyright (c) 2015, 2016 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library ecp5u;
use ecp5u.components.all;

use work.f32c_pack.all;

entity glue is
    generic (
	C_arch: integer := ARCH_MI32; -- either ARCH_MI32 or ARCH_RV32
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_mul_reg: boolean := false;
	C_debug: boolean := false;

	C_clk_freq: integer := 84;

	-- SoC configuration options
	C_bram_size: integer := 32;
	C_sio: integer := 1;
	C_spi: integer := 3;
	C_gpio: integer := 0;
	C_simple_io: boolean := true;
	C_timer: boolean := false
    );
    port (
	clk_25m: in std_logic;

	-- SIO0 (FTDI)
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;

	-- On-board simple IO
	led: out std_logic_vector(7 downto 0);
	btn_pwr, btn_f1, btn_f2: in std_logic;
	btn_up, btn_down, btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0);

	-- SPI flash (SPI #0)
	flash_so: in std_logic;
	flash_si: out std_logic;
	flash_cen: out std_logic;
	--flash_sck: out std_logic; -- accessed via special ECP5 primitive
	flash_holdn, flash_wpn: out std_logic := '1';

	-- SD card (SPI #1)
	sd_cmd: inout std_logic;
	sd_clk: out std_logic;
	sd_d: inout std_logic_vector(3 downto 0);
	sd_cdn: in std_logic;
	sd_wp: in std_logic;

	-- ADC MAX11123 (SPI #2)
	adc_csn: out std_logic;
	adc_sclk: out std_logic;
	adc_mosi: out std_logic;
	adc_miso: in std_logic;

	-- PCB antenna
	ant: out std_logic;

	-- '1' = power off
	shutdown: out std_logic := '0'
    );
end glue;

architecture x of glue is
    signal clk, pll_lock: std_logic;
    signal clk_112m5, clk_96m43, clk_84m34: std_logic;
    signal reset: std_logic;
    signal sio_break: std_logic;
    signal flash_sck: std_logic;
    signal flash_csn: std_logic;

    signal R_simple_in: std_logic_vector(19 downto 0);
    signal open_out: std_logic_vector(31 downto 8);

begin
    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_mult_enable => C_mult_enable,
	C_mul_reg => C_mul_reg,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_bram_size,
	C_debug => C_debug,
	C_sio => C_sio,
	C_spi => C_spi,
	C_gpio => C_gpio,
	C_timer => C_timer
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_tx,
	sio_rxd(0) => rs232_rx,
	sio_break(0) => sio_break,
	simple_out(31 downto 8) => open_out,
	simple_out(7 downto 0) => led,
	simple_in(31 downto 20) => (others => '-'),
	simple_in(19 downto 0) => R_simple_in,
	spi_ss(0) => flash_csn,
	spi_ss(1) => sd_d(3),
	spi_ss(2) => adc_csn,
	spi_sck(0) => flash_sck,
	spi_sck(1) => sd_clk,
	spi_sck(2) => adc_sclk,
	spi_mosi(0) => flash_si,
	spi_mosi(1) => sd_cmd,
	spi_mosi(2) => adc_mosi,
	spi_miso(0) => flash_so,
	spi_miso(1) => sd_d(0),
	spi_miso(2) => adc_miso
    );
    R_simple_in <= sw & x"00" & '0' & not btn_pwr & btn_f2 & btn_f1
      & btn_up & btn_down & btn_left & btn_right when rising_edge(clk);

    -- SPI flash clock has to be routed through a ECP5-specific primitive
    I_flash_mux: USRMCLK
    port map (
	USRMCLKTS => flash_csn,
	USRMCLKI => flash_sck
    );
    flash_cen <= flash_csn;

    I_pll: entity work.pll_25m
    port map (
	clk_25m => clk_25m,
	clk_168m75 => open,
	clk_112m5 => clk_112m5,
	clk_96m43 => clk_96m43,
	clk_84m34 => clk_84m34,
	lock => pll_lock
    );

    clk <= clk_112m5 when C_clk_freq = 112
      else clk_96m43 when C_clk_freq = 96
      else clk_84m34 when C_clk_freq = 84
      else '0';
    reset <= not pll_lock or sio_break;

end x;
