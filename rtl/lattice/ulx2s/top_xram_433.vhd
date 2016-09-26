--
-- Copyright (c) 2016 Emard
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

-- minimum features example of glue_xram used as bram-only
-- it can be even more reduced by removing gpio and timer

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.numeric_std.all; -- we need signed type
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;
use work.sram_pack.all;

-- vendor specific libs (lattice)
library xp2;
use xp2.components.all;

entity toplevel is
  generic (
    C_clk_freq: integer := 56; -- MHz (72.321429)

    -- ISA options
    C_arch: integer := ARCH_MI32;
    C_big_endian: boolean := false;
    -- C_boot_spi = true: bootloader will try to chainboot SPI flash ROM, fallback to serial
    -- C_boot_spi = false: -- serial bootloader only
    C_boot_spi: boolean := true;
    C_mult_enable: boolean := true;
    C_branch_likely: boolean := true;
    C_sign_extend: boolean := true;
    C_ll_sc: boolean := false;
    C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff"; -- 1MB limit from 0x80000000

    -- COP0 options
    C_exceptions: boolean := true;
    C_cop0_count: boolean := true;
    C_cop0_compare: boolean := true;
    C_cop0_config: boolean := true;

    -- CPU core configuration options
    C_branch_prediction: boolean := true;
    C_full_shifter: boolean := true;
    C_result_forwarding: boolean := true;
    C_load_aligner: boolean := true;

    -- This may negatively influence timing closure:
    C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

    -- Debugging / testing options (should be turned off)
    C_debug: boolean := false;

    -- SoC configuration options
    C_bram_size: integer := 8; -- KB
    C_i_rom_only: boolean := true; -- protect bootloader
    C_icache_size: integer := 2; -- 0, 2, 4 or 8 KBytes
    C_dcache_size: integer := 2; -- 0, 2, 4 or 8 KBytes

    C_sram: boolean := true;
      C_sram_refresh: boolean := true; -- RED ULX2S need it, others don't (exclusive: textmode or refresh)
      C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz

    C_sio: integer := 1; -- number of rs232 serial ports (min 1, leave unconnected to disable)

    C_simple_out: integer := 32; -- LEDs (only 8 used but quantized to 32)
    C_simple_in: integer := 32; -- buttons and switches (not all used)
    C_gpio: integer := 32; -- number of GPIO pins
    C_spi: integer := 2; -- number of SPI interfaces (min 1, leave unconnected to disable)

    C_cw_simple_out: integer := 7; -- simple_out (default 7) bit for 433MHz modulator. -1 to disable. set (C_framebuffer := false, C_dds := false) for 433MHz transmitter

    C_pcm: boolean := true;
    C_timer: boolean := true
  );
  port (
    clk_25m: in std_logic;
    rs232_tx: out std_logic;
    rs232_rx: in std_logic;
    flash_so: in std_logic;
    flash_cen, flash_sck, flash_si: out std_logic;
    sdcard_so: in std_logic;
    sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
    p_ring: out std_logic;
    p_tip: out std_logic_vector(3 downto 0);
    led: out std_logic_vector(7 downto 0);
    btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
    sw: in std_logic_vector(3 downto 0);
    j1_2, j1_3, j1_4, j1_8, j1_9, j1_13, j1_14, j1_15: inout std_logic;
    j1_16, j1_17, j1_18, j1_19, j1_20, j1_21, j1_22, j1_23: inout std_logic;
    j2_2, j2_3, j2_4, j2_5, j2_6, j2_7, j2_8, j2_9: inout std_logic;
    j2_10, j2_11, j2_12, j2_13, j2_16: inout std_logic;
    sram_a: out std_logic_vector(18 downto 0);
    sram_d: inout std_logic_vector(15 downto 0);
    sram_wel, sram_lbl, sram_ubl: out std_logic
  );
end toplevel;

architecture Behavioral of toplevel is
  constant C_sram_pipelined_read: boolean := C_clk_freq = 81; -- works only at 81.25 MHz !!!
  signal clk: std_logic;
  signal clk_56M25, clk_72M32, clk_112M5, clk_433M92: std_logic;
  signal pll_lock, reset_when_clock_stable: std_logic;
  signal cw_antenna: std_logic;
  signal rs232_break: std_logic;
  signal btn: std_logic_vector(4 downto 0);
begin
  clk <= clk_56M25; -- CPU clock

  inst_clk_25M_112M5: entity pll_25m_112m5_56m25
  port map
  (
    clk => clk_25M,
    clkop => clk_112M5,
    clkok => clk_56M25,
    lock => pll_lock
  );

  inst_clk_112M5_433M92: entity pll_112m5_433m92_72m32
  port map
  (
    clk => clk_112M5,
    clkop => clk_433M92,
    clkok => clk_72M32,
    lock => open
  );

  reset_when_clock_stable <= pll_lock;
  -- reset assures clean start at power up
  -- not only after upload of bitstream
  gsr_inst: GSR
  port map
  (
    gsr => reset_when_clock_stable
  );

  btn <= btn_left & btn_right & btn_up & btn_down & btn_center;

  inst_glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_big_endian => C_big_endian,
      C_boot_spi => C_boot_spi,
      C_mult_enable => C_mult_enable,
      C_branch_likely => C_branch_likely,
      C_sign_extend => C_sign_extend,
      C_ll_sc => C_ll_sc,
      C_PC_mask => C_PC_mask,
      C_exceptions => C_exceptions,
      C_cop0_count => C_cop0_count,
      C_cop0_compare => C_cop0_compare,
      C_cop0_config => C_cop0_config,
      C_branch_prediction => C_branch_prediction,
      C_full_shifter => C_full_shifter,
      C_result_forwarding => C_result_forwarding,
      C_load_aligner => C_load_aligner,
      C_movn_movz => C_movn_movz,
      C_debug => C_debug,
      C_bram_size => C_bram_size,
      C_icache_size => C_icache_size,	-- 0, 2, 4 or 8 KBytes
      C_dcache_size => C_dcache_size,	-- 0, 2, 4 or 8 KBytes
      C_sram => C_sram,
      C_sram_refresh => C_sram_refresh,
      C_sram_wait_cycles => C_sram_wait_cycles, -- ISSI, OK do 87.5 MHz
      C_sram_pipelined_read => C_sram_pipelined_read, -- works only at 81.25 MHz !!!
      C_sio => C_sio,
      C_spi => C_spi,
      C_cw_simple_out => C_cw_simple_out, -- CW is for 433 MHz. -1 to disable. set (C_framebuffer => false, C_dds => false) for 433MHz transmitter
      C_simple_out => C_simple_out,
      C_simple_in => C_simple_in,
      C_gpio => C_gpio,
      C_timer => C_timer
    )
    port map
    (
      clk => clk,
      clk_cw => clk_433M92,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx, sio_break(0) => rs232_break,
      spi_sck(0) => flash_sck, spi_ss(0) => flash_cen,
      spi_mosi(0) => flash_si, spi_miso(0) => flash_so,
      spi_sck(1) => sdcard_sck, spi_ss(1) => sdcard_cen,
      spi_mosi(1) => sdcard_si, spi_miso(1) => sdcard_so,
      simple_out(7 downto 0) => led(7 downto 0),
      simple_in(4 downto 0) => btn,
      simple_in(19 downto 16) => sw,
      gpio(0)  => j1_2,  gpio(1)  => j1_3,  gpio(2)  => j1_4,   gpio(3)  => j1_8,
      gpio(4)  => j1_9,  gpio(5)  => j1_4,  gpio(6)  => j1_14,  gpio(7)  => j1_15,
      gpio(8)  => j1_16, gpio(9)  => j1_17, gpio(10) => j1_18,  gpio(11) => j1_19,
      gpio(12) => j1_20, gpio(13) => j1_21, gpio(14) => j1_22,  gpio(15) => j1_23,
      gpio(16) => j2_2,  gpio(17) => j2_3,  gpio(18) => j2_4,   gpio(19) => j2_5,
      gpio(20) => j2_6,  gpio(21) => j2_7,  gpio(22) => j2_8,   gpio(23) => j2_9,
      gpio(24) => j2_10, gpio(25) => j2_11, gpio(26) => j2_12,  gpio(27) => j2_13,
      -- gpio(28) => j2_16,
      cw_antenna => cw_antenna, -- output 433MHz
      sram_a(18 downto 0) => sram_a, sram_d => sram_d,
      sram_lbl => sram_lbl, sram_ubl => sram_ubl,
      sram_wel => sram_wel
    );
  j2_16 <= cw_antenna; -- 433 MHz output
end Behavioral;
