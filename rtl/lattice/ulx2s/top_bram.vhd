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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


entity glue is
    generic (
	C_arch: integer := ARCH_MI32; -- either ARCH_MI32 or ARCH_RV32
	C_big_endian: boolean := false;
	C_debug: boolean := false;

	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- SoC configuration options
	C_bram_size: integer := 16;
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 29;
	C_simple_io: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_so: in std_logic;
	flash_cen, flash_sck, flash_si: out std_logic;
	sdcard_so: in std_logic;
	sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
	j1_2, j1_3, j1_4, j1_8, j1_9, j1_13, j1_14, j1_15: inout std_logic;
	j1_16, j1_17, j1_18, j1_19, j1_20, j1_21, j1_22, j1_23: inout std_logic;
	j2_2, j2_3, j2_4, j2_5, j2_6, j2_7, j2_8, j2_9: inout std_logic;
	j2_10, j2_11, j2_12, j2_13, j2_16: inout std_logic;
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
	sw: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
    signal btns: std_logic_vector(4 downto 0);
begin
    -- clock synthesizer: Lattice XP2 specific
    clkgen: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_25m => clk_25m, clk => clk, clk_325m => open,
	ena_325m => '0', res => rs232_break
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_bram_size,
	C_debug => C_debug,
	C_sio => C_sio,
	C_spi => C_spi,
	C_gpio => C_gpio
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_tx,
	sio_rxd(0) => rs232_rx,
	sio_break(0) => rs232_break,
	spi_sck(0) => flash_sck, spi_ss(0) => flash_cen,
	spi_mosi(0) => flash_si, spi_miso(0) => flash_so,
	spi_sck(1) => sdcard_sck, spi_ss(1) => sdcard_cen,
	spi_mosi(1) => sdcard_si, spi_miso(1) => sdcard_so,
	gpio(0) => j1_2, gpio(1) => j1_3,
	gpio(2) => j1_4, gpio(3) => j1_8,
	gpio(4) => j1_9, gpio(5) => j1_13,
	gpio(6) => j1_14, gpio(7) => j1_15,
	gpio(8) => j1_16, gpio(9) => j1_17,
	gpio(10) => j1_18, gpio(11) => j1_19,
	gpio(12) => j1_20, gpio(13) => j1_21,
	gpio(14) => j1_22, gpio(15) => j1_23,
	gpio(16) => j2_2, gpio(17) => j2_3,
	gpio(18) => j2_4, gpio(19) => j2_5,
	gpio(20) => j2_6, gpio(21) => j2_7,
	gpio(22) => j2_8, gpio(23) => j2_9,
	gpio(24) => j2_10, gpio(25) => j2_11,
	gpio(26) => j2_12, gpio(27) => j2_13,
	gpio(28) => j2_16,
	simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
	simple_in(4 downto 0) => btns, simple_in(15 downto 5) => open,
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open
    );
    btns <= btn_center & btn_up & btn_down & btn_left & btn_right;
end Behavioral;
