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


entity zybo_xram_acram_emu_hdmi is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/100/125 MHz
	-- vivado at 81MHz: screen flickers, fetch 1 byte late?
	-- ise at 81MHz: no flicker
	-- at 100MHz both ISE and Vivado don't flicker 
	C_clk_freq: integer := 100;

        -- hard startup for xc7 series doesn't work on some boards
        -- reason unknown, disabled by default
        C_hard_startup: boolean := false;

	-- SoC configuration options
	C_bram_size: integer := 16;

        -- axi cache ram
	C_acram: boolean := true;

        C_icache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 25bits -> 2^25 -> 32MB to be cached

        C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)

	C_vgahdmi: boolean := false;
	C_video_cache_size: integer := 0; -- enable test picture


    C_vgatext: boolean := true;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string :=  "f32c: ZYBO xc7z010 MIPS compatible soft-core 100MHz 128KB BRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 0;   -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          C_vgatext_bitmap_fifo_timeout: integer := 48; -- abort compositing 48 pixels before end of line
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
end zybo_xram_acram_emu_hdmi;

architecture Behavioral of zybo_xram_acram_emu_hdmi is
    signal clk, clk_250MHz, clk_125MHz, clk_25MHz: std_logic;
    signal clk_pixel_shift: std_logic;
    signal sio_break: std_logic;
    signal rs232_break: std_logic;
    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
    signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_ready          : std_logic;
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);
    signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
begin

    clk81: if C_clk_freq = 81 generate
    clkgen100: entity work.mmcm_125M_81M25_250M521_25M052
    port map(
      clk_in1 => clk_125m, clk_out1 => clk, clk_out2 => clk_250MHz, clk_out3 => clk_25MHz
    );
    end generate;

    clk100_sdr: if C_clk_freq = 100 and not C_dvid_ddr generate
    clkgen100_sdr: entity work.pll_125M_250M_100M_25M
    port map(
      clk_in1 => clk_125m, clk_out1 => clk_250MHz, clk_out2 => clk, clk_out3 => clk_25MHz
    );
    clk_pixel_shift <= clk_250MHz;
    end generate;

    clk100_ddr: if C_clk_freq = 100 and C_dvid_ddr generate
    clkgen100_ddr: entity work.clk_125M_100M_125M_25M
    port map(
      reset => '0', locked => open,
      clk_125M_in => clk_125m, clk_125M => clk_125MHz, clk_100M => clk, clk_25M => clk_25MHz
    );
    clk_pixel_shift <= clk_125MHz;
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
      C_acram => C_acram,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_dvid_ddr => C_dvid_ddr,
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_cache_size => C_video_cache_size,
      -- vga advanced graphics text+compositing bitmap
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
      C_vgatext_bitmap_fifo_timeout => C_vgatext_bitmap_fifo_timeout,
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
      clk_pixel_shift => clk_pixel_shift, -- tmds clock
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
      dvid_red   => dvid_red,
      dvid_green => dvid_green,
      dvid_blue  => dvid_blue,
      dvid_clock => dvid_clock,
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
      simple_in(31 downto 20) => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready
    );

    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 15
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(16 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
    );

    G_dvi_sdr: if not C_dvid_ddr generate
      tmds_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_clk <= dvid_clock(0);
    end generate;

    G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift,
      clk_n     => '0', -- inverted shift clock not needed on xilinx
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_rgb(2),
      out_green => tmds_rgb(1),
      out_blue  => tmds_rgb(0),
      out_clock => tmds_clk
    );
    end generate;

    -- differential output buffering for HDMI clock and video
    hdmi_out_en <= '1';
    hdmi_output: entity work.hdmi_out
    port map (
      tmds_in_clk => tmds_clk,
      tmds_out_clk_p => hdmi_clk_p,
      tmds_out_clk_n => hdmi_clk_n,
      tmds_in_rgb => tmds_rgb,
      tmds_out_rgb_p => hdmi_d_p,
      tmds_out_rgb_n => hdmi_d_n
    );

end Behavioral;
