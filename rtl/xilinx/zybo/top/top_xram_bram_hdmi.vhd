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

	-- Main clock: 81/100/125 MHz
	-- vivado at 81MHz: screen flickers, fetch 1 byte late?
	-- ise at 81MHz: no flicker
	-- at 100MHz both ISE and Vivado don't flicker 
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 128;
	C_vgahdmi: boolean := false;
	C_vgahdmi_mem_kb: integer := 38; -- KB 38K full mono 640x480
	C_vgahdmi_test_picture: integer := 1; -- enable test picture

        -- hard startup for xc7 series doesn't work on some boards
        -- reason unknown, disabled by default
        C_hard_startup: boolean := false;

    C_vgatext: boolean := true; -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string :=  "f32c: ZYBO xc7z010 MIPS compatible soft-core 100MHz 128KB BRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0; -- 0=640x480, 1=640x400, 2=800x600 (you must still provide proper pixel clock [25MHz or 40Mhz])
      C_vgatext_bits: integer := 4; -- bits of VGA color per red, green, blue gun (e.g., 1=8, 2=64 and 4=4096 total colors possible)
      C_vgatext_bram_mem: integer := 16; -- BRAM size 1, 2, 4, 8 or 16 depending on font and screen size/memory
      C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
      C_vgatext_palette: boolean := false; -- true for run-time color look-up table, else 16 fixed VGA color palette
      C_vgatext_text: boolean := true; -- enable text generation
        C_vgatext_font_bram8: boolean := false; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_monochrome: boolean := false;	-- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_font_height: integer := 8; -- font data height 8 or 16 for 8x8 or 8x16 font
        C_vgatext_char_height: integer := 8; -- font cell height (text lines will be C_visible_height / C_CHAR_HEIGHT rounded down, 19=25 lines on 480p)
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_depth: integer := 8; -- font char bits 7 for 128 characters or 8 for 256 characters
        C_vgatext_bus_read: boolean := false; -- true: enable reading of the font (ant text). false: write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_text_fifo: boolean := false; -- true to use videofifo for text+color, else BRAM for text+color memory
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the fifo refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) len = 2^width * 4 byte
        C_vgatext_bitmap: boolean := false; -- true to enable bitmap generation
          C_vgatext_bitmap_depth: integer := 8;	-- bitmap bits per pixel (1, 2, 4, 8)
          C_vgatext_bitmap_fifo: boolean := false; -- true to use videofifo, else SRAM port for bitmap memory
          -- 8 bpp compositing
          -- step=horizontal width in pixels
          C_vgatext_bitmap_fifo_step: integer := 640;
          -- height=vertical height in pixels
          C_vgatext_bitmap_fifo_height: integer := 480;
          -- output data width 8bpp
          C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_addr_width: integer := 11;

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
	hdmi_out_en : out std_logic;
	hdmi_clk_p, hdmi_clk_n: out std_logic;
	hdmi_d_p, hdmi_d_n: out std_logic_vector(2 downto 0);
	vga_g: out std_logic_vector(5 downto 0);
	vga_r, vga_b: out std_logic_vector(4 downto 0);
	vga_hs, vga_vs: out std_logic;
	btn: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, clk_250MHz, clk_25MHz: std_logic;
    signal sio_break: std_logic;
    signal rs232_break: std_logic;
    signal tmds_rgb: std_logic_vector(2 downto 0);
begin

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

    hard_startup: if C_hard_startup generate
        reset: startupe2
        generic map (
          prog_usr => "FALSE"
        )
        port map (
          clk => clk,
          gsr => sio_break,
          gts => '0',
          keyclearb => '0',
          pack => '1',
          usrcclko => clk,
          usrcclkts => '0',
          usrdoneo => '1',
          usrdonets => '0'
        );
   end generate;

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_bram_size => C_bram_size,
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_test_picture => C_vgahdmi_test_picture,
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
      C_vgatext_font_bram8 => C_vgatext_font_bram8,
      C_vgatext_monochrome => C_vgatext_monochrome,
      C_vgatext_font_height => C_vgatext_font_height,
      C_vgatext_char_height => C_vgatext_char_height,
      C_vgatext_font_linedouble => C_vgatext_font_linedouble,
      C_vgatext_font_depth => C_vgatext_font_depth,
      C_vgatext_bus_read => C_vgatext_bus_read,
      C_vgatext_reg_read => C_vgatext_reg_read,
      C_vgatext_finescroll => C_vgatext_finescroll,
      C_vgatext_text_fifo => C_vgatext_text_fifo,
      C_vgatext_text_fifo_step => C_vgatext_text_fifo_step,
      C_vgatext_text_fifo_width => C_vgatext_text_fifo_width,
      C_vgatext_bitmap => C_vgatext_bitmap,
      C_vgatext_bitmap_depth => C_vgatext_bitmap_depth,
      C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo,
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_25MHz, -- pixel clock
      clk_pixel_shift => clk_250MHz, -- tmds clock
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => sio_break,
      spi_sck(0)  => open,  spi_sck(1)  => open,
      spi_ss(0)   => open,  spi_ss(1)   => open,
      spi_mosi(0) => open,  spi_mosi(1) => open,
      spi_miso(0) => '-',   spi_miso(1) => '-',
      gpio(3 downto 0) => ja_u(3 downto 0),
      gpio(7 downto 4) => ja_d(3 downto 0),
      gpio(11 downto 8) => jb_u(3 downto 0),
      gpio(15 downto 12) => jb_d(3 downto 0),
      gpio(19 downto 16) => jc_u(3 downto 0),
      gpio(23 downto 20) => jc_d(3 downto 0),
      gpio(27 downto 24) => jd_u(3 downto 0),
      gpio(31 downto 28) => jd_d(3 downto 0),
      gpio(127 downto 32) => open,
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      vga_vsync => vga_vs,
      vga_hsync => vga_hs,
      vga_r(7 downto 3) => vga_r(4 downto 0),
      vga_r(2 downto 0) => open,
      vga_g(7 downto 2) => vga_g(5 downto 0),
      vga_g(1 downto 0) => open,
      vga_b(7 downto 3) => vga_b(4 downto 0),
      vga_b(2 downto 0) => open,
      simple_out(3 downto 0) => led(3 downto 0),
      simple_out(31 downto 4) => open,
      simple_in(3 downto 0) => btn(3 downto 0),
      simple_in(15 downto 4) => open,
      simple_in(19 downto 16) => sw(3 downto 0),
      simple_in(31 downto 20) => open
    );

    -- differential output buffering for HDMI clock and video
    hdmi_out_en <= '1';
    hdmi_output: entity work.hdmi_out
    port map (
      tmds_in_clk => clk_25MHz,
      tmds_out_clk_p => hdmi_clk_p,
      tmds_out_clk_n => hdmi_clk_n,
      tmds_in_rgb => tmds_rgb,
      tmds_out_rgb_p => hdmi_d_p,
      tmds_out_rgb_n => hdmi_d_n
    );

end Behavioral;
