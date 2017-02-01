--
-- Copyright (c) 2011-2015 Marko Zec, University of Zagreb
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

-- this is new and potentially buggy
-- variant of standard ULX2S SRAM
-- with most features
--
-- MIPS CPU 81.25 MHz
-- 1MB SDRAM
-- TV framebuffer (tip of 3.5 mm jack)
-- PCM audio (ring of 3.5 mm jack)
-- 2 SPI ports (flash and SD card)
-- FM/RDS transmitter 87-108 MHz
-- PID controller (3 HW channels + 1 SW simulation)

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

-- this is new and potentially buggy
-- variant of feature-rich ULX2S SRAM
--
-- 1MB SRAM
-- TV framebuffer
-- 16 GPIO with interrupts
-- 1 timer (2xPWM, 2xICP)
-- 1 channel PCM audio out
-- 2 SPI ports (flash and SD card)
-- PCM audio with DMA
-- FM RDS transmitter 87-108MHz (FM plays PCM audio)
-- 4 PID controllers (3 hardware, 1 simulation)
-- 8 LEDs, 5 buttons, 4 switches

entity toplevel is
  generic (
    -- Main clock: 25, 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
    C_clk_freq: integer := 50;

    -- ISA options
    C_arch: integer := ARCH_MI32;
    C_big_endian: boolean := false;
    -- C_boot_spi = true: bootloader will try to chainboot SPI flash ROM, fallback to serial
    -- C_boot_spi = false: -- serial bootloader only
    C_boot_spi: boolean := true;
    C_mult_enable: boolean := true;
    C_mul_acc: boolean := true;    -- MI32 only
    C_mul_reg: boolean := true;    -- MI32 only
    C_branch_likely: boolean := true;
    C_sign_extend: boolean := true;
    C_ll_sc: boolean := false;
    C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff"; -- 1MB limit from 0x80000000
    -- C_PC_mask: std_logic_vector(31 downto 0) := x"100fffff"; -- 1MB limit from 0x10000000

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
    C_bram_size: integer := 8;	-- 8 or 16 KBytes
      C_i_rom_only: boolean := true;
      C_icache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
      C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes

    C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- RAM start address x"8" -> 0x80000000 (need C_PC_mask := x"800fffff")
    -- C_xram_base: std_logic_vector(31 downto 28) := x"1"; -- RAM start address x"1" -> 0x10000000 (need C_PC_mask := x"100fffff")
    C_cached_addr_bits: integer := 20; -- number of lower RAM address bits 2^20 -> 1MB to be cached

    C_sram: boolean := true;
      C_sram_refresh: boolean := false; -- RED ULX2S need it, others don't (exclusive: textmode or refresh)
      C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
      -- C_sram_pipelined_read: boolean := true; -- works only at 81.25 MHz !!! defined below as constant

    C_sio: integer := 1; -- number of rs232 serial ports

    C_simple_out: integer := 32; -- LEDs (only 8 used but quantized to 32)
    C_simple_in: integer := 32; -- buttons and switches (not all used)
    C_gpio: integer := 32; -- number of GPIO pins
    C_spi: integer := 2; -- number of SPI interfaces

    C_hdmi_out: boolean := true;

    C_vgahdmi: boolean := true; -- simple VGA bitmap with compositing
      C_vgahdmi_cache_size: integer := 0; -- KB (0 to disable, 2,4,8,16,32 to enable)
      -- normally this should be  actual bits per pixel
      C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
      -- width of FIFO address space -> size of fifo
      -- for 8bpp compositing use 11 -> 2048 bytes

    C_vgatext: boolean := false; -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: Lattice FX2 MIPS compatible soft-core 50MHz 1MB SRAM"; -- default banner in screen memory
      C_vgatext_mode: integer := 1; -- 640x480
      C_vgatext_bits: integer := 4; -- 16 possible colors
      C_vgatext_bram_mem: integer := 0; -- 4KB text+font  memory
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 1024; -- 1MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- yes, color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true; -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true; -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
        C_vgatext_bus_write: boolean := true; -- true to allow writing vgatext BRAM from CPU bus. false: no writing
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true; -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          -- 8 bpp compositing
          -- step=horizontal width in pixels
          C_vgatext_bitmap_fifo_step: integer := 640;
          -- height=vertical height in pixels
          C_vgatext_bitmap_fifo_height: integer := 480;
          -- output data width 8bpp
          C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_addr_width: integer := 11;

    C_ledstrip: boolean := false;
    -- input number of counts per full circle
    C_ledstrip_full_circle: integer := 200; -- counts
    -- number of pixels in each channel: 72
    C_ledstrip_fifo_width: integer := 72;
    -- number of scan lines: 50
    C_ledstrip_fifo_height: integer := 50;
    -- normally this should be  actual bits per pixel
    C_ledstrip_fifo_data_width: integer range 8 to 32 := 8;
    -- width of FIFO address space -> size of fifo
    -- for 8bpp compositing use 11 -> 2^11 = 2048 bytes
    C_ledstrip_fifo_addr_width: integer := 11;


    C_pcm: boolean := true;
    C_timer: boolean := true;
      C_timer_ocp_mux: boolean := true; -- true: fade example will work, false: real use, no LED muxing, direct output
      C_timer_ocps: integer := 2; -- # output compare units
      C_timer_icps: integer := 2; -- # input capture units
    C_cw_simple_out: integer := -1; -- simple_out (default 7) bit for 433MHz modulator. -1 to disable. set (C_framebuffer := false, C_dds := false) for 433MHz transmitter
    C_fmrds: boolean := false; -- either FM or tx433
    C_fm_stereo: boolean := true;
    C_fm_filter: boolean := true;
    C_fm_downsample: boolean := false;
    C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
    C_fmdds_hz: integer := 325000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
    --C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
    --C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
    C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
    C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
    C_pids: integer := 0; -- 4 PIDs can fit but with other modules like video
    -- can pose routing/timing problems in lattice XP2 so enable them as needed
    -- manifestation of timing problems is that f32c CPU erraticaly slows down
    -- or speeds up while executing arduino delay(1000);
    C_pid_simulator: std_logic_vector(7 downto 0) := ext("1000", 8); -- for each pid choose simulator/real
    C_dds: boolean := false
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
    -- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
  );
end toplevel;

architecture Behavioral of toplevel is
  constant C_sram_pipelined_read: boolean := C_clk_freq = 81; -- works only at 81.25 MHz !!!
  signal clk, clk_325m, ena_325m: std_logic;
  signal clk_112m5, clk_433m, clk_250m: std_logic;
  signal pll_lock: std_logic;
  signal reset_when_clock_stable: std_logic;
  signal rs232_break: std_logic;
  signal btn: std_logic_vector(4 downto 0);
  signal tmds_rgb: std_logic_vector(2 downto 0);
  signal tmds_clk: std_logic;
  signal icp: std_logic_vector(C_timer_icps-1 downto 0); -- timer PWM in
  signal ocp: std_logic_vector(C_timer_ocps-1 downto 0); -- timer PWM out
  signal gpio_28, fm_antenna, cw_antenna: std_logic;
  signal motor_bridge, motor_encoder: std_logic_vector(1 downto 0);
begin
  --
  -- Clock synthesizer
  --
  clk_x_250: if C_hdmi_out generate
    clkgen_x: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_25m => clk_25m, ena_325m => '0',
	clk => clk, clk_325m => open, res => '0'
    );
    ena_325m <= '0';
    clk250Mgen: entity work.pll_25M_250M
    port map (
      CLK => clk_25m, CLKOP => clk_250m
    );
  end generate;

  btn <= btn_left & btn_right & btn_up & btn_down & btn_center;
  inst_glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_big_endian => C_big_endian,
      C_boot_spi => C_boot_spi,
      C_mult_enable => C_mult_enable,
      C_mul_acc => C_mul_acc,
      C_mul_reg => C_mul_reg,
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
      -- C_i_rom_only => C_i_rom_only,
      C_icache_size => C_icache_size,	-- 0, 2, 4 or 8 KBytes
      C_dcache_size => C_dcache_size,	-- 0, 2, 4 or 8 KBytes
      C_xram_base => C_xram_base,
      C_cached_addr_bits => C_cached_addr_bits,
      C_sram => C_sram,
      C_sram_refresh => C_sram_refresh,
      C_sram_wait_cycles => C_sram_wait_cycles, -- ISSI, OK do 87.5 MHz
      C_sram_pipelined_read => C_sram_pipelined_read, -- works only at 81.25 MHz !!!
      C_sio => C_sio,
      C_spi => C_spi,
      C_simple_out => C_simple_out,
      C_simple_in => C_simple_in,
      C_gpio => C_gpio,

      -- vga simple bitmap
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      -- led strip simple compositing bitmap only graphics
      C_ledstrip => C_ledstrip,
      C_ledstrip_full_circle => C_ledstrip_full_circle,
      C_ledstrip_fifo_width => C_ledstrip_fifo_width,
      C_ledstrip_fifo_height => C_ledstrip_fifo_height,
      C_ledstrip_fifo_data_width => C_ledstrip_fifo_data_width,
      C_ledstrip_fifo_addr_width => C_ledstrip_fifo_addr_width,
      -- vga textmode
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_bram_base => C_vgatext_bram_base,
      C_vgatext_external_mem => C_vgatext_external_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
      C_vgatext_font_bram8 => C_vgatext_font_bram8,
      -- C_vgatext_bus_write => C_vgatext_bus_write,
      C_vgatext_bus_read => C_vgatext_bus_read,
      C_vgatext_reg_read => C_vgatext_reg_read,
      C_vgatext_text_fifo => C_vgatext_text_fifo,
      C_vgatext_text_fifo_step => C_vgatext_text_fifo_step,
      C_vgatext_text_fifo_width => C_vgatext_text_fifo_width,
      C_vgatext_char_height => C_vgatext_char_height,
      C_vgatext_font_height => C_vgatext_font_height,
      C_vgatext_font_depth => C_vgatext_font_depth,
      C_vgatext_font_linedouble => C_vgatext_font_linedouble,
      C_vgatext_font_widthdouble => C_vgatext_font_widthdouble,
      C_vgatext_monochrome => C_vgatext_monochrome,
      C_vgatext_finescroll => C_vgatext_finescroll,
      C_vgatext_cursor => C_vgatext_cursor,
      C_vgatext_cursor_blink => C_vgatext_cursor_blink,
      C_vgatext_bitmap => C_vgatext_bitmap,
      C_vgatext_bitmap_depth => C_vgatext_bitmap_depth,
      C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo,
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
      C_pcm => C_pcm,
      C_timer => C_timer,
        C_timer_ocp_mux => C_timer_ocp_mux,
        C_timer_ocps => C_timer_ocps,
        C_timer_icps => C_timer_icps,
      C_pids => C_pids,
      C_pid_simulator => C_pid_simulator, -- for each pid choose simulator/real
      C_cw_simple_out => C_cw_simple_out, -- CW is for 433 MHz. -1 to disable. set (C_framebuffer => false, C_dds => false) for 433MHz transmitter
      C_fmrds => C_fmrds, -- either FM or tx433
      C_fm_stereo => C_fm_stereo,
      C_fm_filter => C_fm_filter,
      C_fm_downsample => C_fm_downsample,
      C_rds_msg_len => C_rds_msg_len, -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
      C_fmdds_hz => C_fmdds_hz, -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
      C_rds_clock_multiply => C_rds_clock_multiply, -- multiply and divide from cpu clk 81.25 MHz
      C_rds_clock_divide => C_rds_clock_divide  -- to get 1.824 MHz for RDS logic
      --C_dds => C_dds
    )
    port map (
      clk => clk,
      clk_pixel => clk_25m,
      clk_pixel_shift => clk_250m,
      clk_fmdds => clk_325m,
      clk_cw => clk_433m,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx, sio_break(0) => rs232_break,
      spi_sck(0) => flash_sck, spi_ss(0) => flash_cen,
      spi_mosi(0) => flash_si, spi_miso(0) => flash_so,
      spi_sck(1) => sdcard_sck, spi_ss(1) => sdcard_cen,
      spi_mosi(1) => sdcard_si, spi_miso(1) => sdcard_so,
      jack_ring(3) => p_ring,
      jack_tip => p_tip,
      simple_out(7 downto 0) => led(7 downto 0),
      simple_in(4 downto 0) => btn,
      simple_in(19 downto 16) => sw,
      -- gpio
      gpio(0)  => j1_2,  gpio(1)  => j1_3,  gpio(2)  => j1_4,   gpio(3)  => j1_8,
      gpio(4)  => j1_9,  gpio(5)  => j1_4,  gpio(6)  => j1_14,  gpio(7)  => j1_15,
      --gpio(8)  => j1_16, gpio(9)  => j1_17, gpio(10) => j1_18,  gpio(11) => j1_19,
      --gpio(12) => j1_20, gpio(13) => j1_21, gpio(14) => j1_22,  gpio(15) => j1_23,
      -- timer hardware pins
      icp(0) => j2_4, icp(1) => j2_11,
      ocp(0) => j2_3, ocp(1) => j2_10,
      -- gpio(27 downto 16) multifuncition GPIO/VGA/PID
      -- **** GPIO **** gpio(27 downto 16)
      --gpio(16) => j2_2,  gpio(17) => j2_3,  gpio(18) => j2_4,   gpio(19) => j2_5,  -- PID0
      --gpio(20) => j2_6,  gpio(21) => j2_7,  gpio(22) => j2_8,   gpio(23) => j2_9,  -- PID1
      --gpio(24) => j2_10, gpio(25) => j2_11, gpio(26) => j2_12,  gpio(27) => j2_13, -- PID2
      --  **** PID **** gpio(27 downto 16)
      --pid_encoder_a(0) => j2_2,  pid_encoder_b(0) => j2_3,  pid_bridge_f(0) => j2_4,  pid_bridge_r(0) => j2_5,  -- PID0
      --pid_encoder_a(1) => j2_6,  pid_encoder_b(1) => j2_7,  pid_bridge_f(1) => j2_8,  pid_bridge_r(1) => j2_9,  -- PID1
      --pid_encoder_a(2) => j2_10, pid_encoder_b(2) => j2_11, pid_bridge_f(2) => j2_12, pid_bridge_r(2) => j2_13, -- PID2
      --  **** LEDSTRIP ****, gpio the rest
      --ledstrip_rotation => j2_2, -- motor provides only a single channel pulse for the counter
      --ledstrip_out(0) => j2_6, ledstrip_out(1) => j2_7, -- ws2812b outputs
      --gpio(16) => open,  gpio(17) => open,  gpio(18) => j2_4,   gpio(19) => j2_5,
      --gpio(20) => open,  gpio(21) => open,  gpio(22) => j2_8,   gpio(23) => j2_9,
      --gpio(24) => j2_10, gpio(25) => j2_11, gpio(26) => j2_12,  gpio(27) => j2_13,
      --  **** VGA **** gpio(27 downto 16)
      --vga_vsync => j2_3,
      --vga_hsync => j2_4,
      --vga_b(5) => j2_5,  vga_b(6) => j2_6,  vga_b(7) => j2_7,
      --vga_g(5) => j2_8,  vga_g(6) => j2_9,  vga_g(7) => j2_10,
      --vga_r(5) => j2_11, vga_r(6) => j2_12, vga_r(7) => j2_13,
      -- ***** HDMI *****
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
      --  gpio(28) multifunction: antenna
      gpio(28) => gpio_28, -- j2_16
      cw_antenna => cw_antenna, -- output 433MHz
      fm_antenna => fm_antenna, -- output 87-108MHz
      sram_a(18 downto 0) => sram_a, sram_d => sram_d,
      sram_lbl => sram_lbl, sram_ubl => sram_ubl,
      sram_wel => sram_wel
    );

    -- differential output buffering for HDMI clock and video
    hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_rgb    => tmds_rgb,
        tmds_out_rgb_p(2) => j1_22,  -- D2+ red    JB2
        tmds_out_rgb_n(2) => j2_9,   -- D2- red    JB6
        tmds_out_rgb_p(1) => j1_21,  -- D1+ green  JB3
        tmds_out_rgb_n(1) => j2_8,   -- D1- green  JB7
        tmds_out_rgb_p(0) => j1_20,  -- D0+ blue   JB4
        tmds_out_rgb_n(0) => j2_7,   -- D0- blue   JB8
        tmds_in_clk    => tmds_clk,
        tmds_out_clk_p => j1_23, -- CLK+ clock     JB1
        tmds_out_clk_n => j2_16  -- CLK- clock     JB5
      );

    -- simulation for the ledstrip motor (forward-only motor)
    ledstrip_motor_simulation: if false generate
    motor_bridge <= '0' & led(1); -- led(1) is PWM out (arduino pin 9 in Fade example)
    motor: entity work.simotor
    generic map
    (
      prescaler => 4,
      motor_power => 4, -- acceleration
      motor_speed => 20,  -- inverse log2 friction proportional to speed
      -- larger motor_speed values allow higher motor top speed
      motor_friction => 1   -- static friction
    )
    port map
    (
      clock => clk,
      bridge => motor_bridge,
      encoder => motor_encoder
    );
    end generate; -- ledstrip_motor_simulation

end Behavioral;
