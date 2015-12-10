--
-- Copyright (c) 2015 Marko Zec, University of Zagreb
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
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- SoC configuration options
	C_mem_size: integer := 16;
	C_vgahdmi: boolean := false;
	C_vgahdmi_mem_kb: integer := 4; -- KB, very little BRAM available on lattice

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: Lattice FX2 MIPS compatible soft-core 81.25MHz 8KB BRAM"; -- default banner in screen memory
      C_vgatext_mode: integer := 0; -- 640x480
      C_vgatext_bits: integer := 4; -- 64 possible colors
      C_vgatext_bram_mem: integer := 8; -- 8KB text+font  memory
      C_vgatext_external_mem: integer := 0; -- no external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true;  -- enable optional text generation
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 7; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)        
        C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)       
        C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character             
        C_vgatext_finescroll: boolean := true; -- true for pixel level character scrolling and line length modulo             
        C_vgatext_cursor: boolean := true; -- true for optional text cursor                 
        C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := false;  -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := false; -- true for optional bitmap generation                 
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := false; -- enable bitmap FIFO
          --C_vgatext_bitmap_fifo_step: integer := 640/4; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
          --C_vgatext_bitmap_compositing_length: integer := 17; -- word length for H-compositing slice, including offset word (tiny sprites one pixel high)
          --C_vgatext_bitmap_fifo_width: integer := 9; -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_step: integer := 0; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
          C_vgatext_bitmap_compositing_length: integer := 0; -- word length for H-compositing slice, including offset word (tiny sprites one pixel high)
          C_vgatext_bitmap_fifo_width: integer := 4; -- bitmap width of FIFO address space length = 2^width * 4 byte

	C_fmrds: boolean := true;
	C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
        C_fmdds_hz: integer := 325000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        --C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
        --C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
        C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
        C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
	C_sio: integer := 1;
	C_sio_break_detect_delay_ms: integer := 200; -- ms (milliseconds) serial break
	C_spi: integer := 2;
	C_gpio: integer := 16;
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
    signal clk_325m: std_logic;
    signal btns: std_logic_vector(4 downto 0);
begin
    -- clock synthesizer: Lattice XP2 specific
    clkgen: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_25m => clk_25m, clk => clk, clk_325m => clk_325m,
	ena_325m => '1', res => rs232_break
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_mem_size => C_mem_size,
	C_debug => C_debug,
	C_vgahdmi => C_vgahdmi,
	C_vgahdmi_mem_kb => C_vgahdmi_mem_kb,
	-- vga textmode
        C_vgatext => C_vgatext,
        C_vgatext_label => C_vgatext_label,
        C_vgatext_mode => C_vgatext_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_text => C_vgatext_text,
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
        --C_vgatext_bitmap_compositing_length => C_vgatext_bitmap_compositing_length,
        C_vgatext_bitmap_fifo_width => C_vgatext_bitmap_fifo_width,
	C_fmrds => C_fmrds,
	C_fmdds_hz => C_fmdds_hz,
	C_rds_msg_len => C_rds_msg_len,
        C_rds_clock_multiply => C_rds_clock_multiply,
        C_rds_clock_divide => C_rds_clock_divide,
	C_sio => C_sio, C_sio_break_detect_delay_ms => C_sio_break_detect_delay_ms,
	C_spi => C_spi,
	C_gpio => C_gpio
    )
    port map (
	clk => clk,
	clk_25MHz => clk_25m,
	clk_fmdds => clk_325m,
	sio_txd(0) => rs232_tx,
	sio_rxd(0) => rs232_rx,
	sio_break(0) => rs232_break,
	spi_sck(0) => flash_sck, spi_ss(0) => flash_cen,
	spi_mosi(0) => flash_si, spi_miso(0) => flash_so,
	spi_sck(1) => sdcard_sck, spi_ss(1) => sdcard_cen,
	spi_mosi(1) => sdcard_si, spi_miso(1) => sdcard_so,
	gpio(0) => j1_2,
	gpio(1) => j1_3,
	gpio(2) => j1_4,
	gpio(3) => j1_8,
	gpio(4) => j1_9,
	gpio(5) => j1_13,
	gpio(6) => j1_14,
	gpio(7) => j1_15,
	gpio(8) => j1_16,
	gpio(9) => j1_17,
	gpio(10) => j1_18,
	gpio(11) => j1_19,
	gpio(12) => j1_20,
	gpio(13) => j1_21,
	gpio(14) => j1_22,
	gpio(15) => j1_23,
	vga_vsync => j2_3,
	vga_hsync => j2_4,
	vga_b(5) => j2_5,  vga_b(6) => j2_6,  vga_b(7) => j2_7,
	vga_g(5) => j2_8,  vga_g(6) => j2_9,  vga_g(7) => j2_10,
	vga_r(5) => j2_11, vga_r(6) => j2_12, vga_r(7) => j2_13,
	fm_antenna => j2_16,
	simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
	simple_in(4 downto 0) => btns, simple_in(15 downto 5) => open,
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open
    );
    btns <= btn_center & btn_up & btn_down & btn_left & btn_right;
end Behavioral;
