--
-- Copyright (c) 2015 Emanuel Stiebler
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
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/100 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 128;

	C_vgahdmi: boolean := false;
	C_vgahdmi_mem_kb: integer := 38; -- KB 38K full mono 640x480
	C_vgahdmi_test_picture: integer := 1; -- enable test picture

    C_vgatext: boolean := true; -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string :=  "f32c: ESA11-7a35i MIPS compatible soft-core 100MHz 128KB BRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0; -- 0=640x480, 1=640x400, 2=800x600 (you must still provide proper pixel clock [25MHz or 40Mhz])
      C_vgatext_bits: integer := 2; -- bits of VGA color per red, green, blue gun (e.g., 1=8, 2=64 and 4=4096 total colors possible)
      C_vgatext_bram_mem: integer := 8; -- BRAM size 1, 2, 4, 8 or 16 depending on font and screen size/memory
      C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
      C_vgatext_palette: boolean := false; -- true for run-time color look-up table, else 16 fixed VGA color palette
      C_vgatext_text: boolean := true; -- enable text generation
        C_vgatext_monochrome: boolean := false;	-- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_font_height: integer := 16; -- font data height 8 or 16 for 8x8 or 8x16 font
        C_vgatext_char_height: integer := 16; -- font cell height (text lines will be C_visible_height / C_CHAR_HEIGHT rounded down, 19=25 lines on 480p)
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_depth: integer := 7; -- font char bits 7 for 128 characters or 8 for 256 characters
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
            C_vgatext_bitmap_fifo_step: integer := 0; -- bitmap step for the fifo refill and rewind (0 unless repeating lines)
            C_vgatext_bitmap_fifo_width: integer := 8; -- bitmap width of FIFO address space len = 2^width * 4 byte

	C_sio: integer := 1;   -- 1 UART channel
	C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
	C_gpio: integer := 32; -- 32 GPIO bits
	C_ps2: boolean := true; -- PS/2 keyboard
        C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
    );
    port (
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic;
	FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
	FPGA_SD_D0: in std_logic;
	M_EXPMOD0, M_EXPMOD1, M_EXPMOD2, M_EXPMOD3: inout std_logic_vector(7 downto 0); -- EXPMODs
	M_7SEG_A, M_7SEG_B, M_7SEG_C, M_7SEG_D, M_7SEG_E, M_7SEG_F, M_7SEG_G, M_7SEG_DP: out std_logic;
	M_7SEG_DIGIT: out std_logic_vector(3 downto 0);
--	seg: out std_logic_vector(7 downto 0); -- 7-segment display
--	an: out std_logic_vector(3 downto 0); -- 7-segment display
	M_LED: out std_logic_vector(7 downto 0);
	-- PS/2 keyboard
	PS2_A_DATA, PS2_A_CLK, PS2_B_DATA, PS2_B_CLK: inout std_logic;
        -- HDMI
	VID_D_P, VID_D_N: out std_logic_vector(2 downto 0);
	VID_CLK_P, VID_CLK_N: out std_logic;
        -- VGA
        VGA_RED, VGA_GREEN, VGA_BLUE: out std_logic_vector(7 downto 0);
        VGA_SYNC_N, VGA_BLANK_N, VGA_CLOCK_P: out std_logic;
        VGA_HSYNC, VGA_VSYNC: out std_logic;
	M_BTN: in std_logic_vector(4 downto 0);
	M_HEX: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_100MHz, clk_250MHz: std_logic;
    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal tmds_out_rgb: std_logic_vector(2 downto 0);
    signal vga_vsync_n, vga_hsync_n: std_logic;
    signal ps2_clk_in : std_logic;
    signal ps2_clk_out : std_logic;
    signal ps2_dat_in : std_logic;
    signal ps2_dat_out : std_logic;
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin
    -- make single ended clock
    --clk100in: entity work.inp_ds_port
    --port map(i_in_p => i_100MHz_P,
    --       i_in_n => i_100MHz_N,
    --       o_out  => clk);

    -- PLL with differential input: 100MHz
    -- single-ended outputs 81.25MHz, 250MHz, 25MHz
    cpu_81MHz: if C_clk_freq = 81 generate
    pll100in_out81_250_25: entity work.mmcm_d100M_81M25_250M521_25M052
    port map(clk_in1_p => i_100MHz_P,
             clk_in1_n => i_100MHz_N,
             clk_out1  => clk, -- 81.25 MHz
             clk_out2  => clk_250MHz,
             clk_out3  => clk_25MHz
             );
    end generate;

    -- PLL with differential input: 100MHz
    -- single-ended outputs 250MHz, 100MHz, 25MHz
    cpu100MHz: if C_clk_freq = 100 generate
    pll100in_out250_100_25: entity work.pll_d100M_250M_100M_25M
    port map(clk_in1_p => i_100MHz_P,
             clk_in1_n => i_100MHz_N,
             clk_out1  => clk_250MHz,
             clk_out2  => clk, -- 100 MHz
             clk_out3  => clk_25MHz
             );
    end generate;

    -- reset hard-block: Xilinx Artix-7 specific
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

    ps2_dat_in	<= PS2_A_DATA;
    PS2_A_DATA	<= '0' when ps2_dat_out='0' else 'Z';
    ps2_clk_in	<= PS2_A_CLK;
    PS2_A_CLK	<= '0' when ps2_clk_out='0' else 'Z';

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
        C_mem_size => C_mem_size,
        C_gpio => C_gpio,
        C_sio => C_sio,
        C_spi => C_spi,
        C_ps2 => C_ps2,

	C_vgahdmi => C_vgahdmi,
	C_vgahdmi_mem_kb => C_vgahdmi_mem_kb,
	C_vgahdmi_test_picture => C_vgahdmi_test_picture,

      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
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
      C_vgatext_bitmap_fifo_width => C_vgatext_bitmap_fifo_width,

        C_debug => C_debug
    )
    port map (
	clk => clk,
	clk_25MHz => clk_25MHz,
	clk_250MHz => clk_250MHz,
	sio_txd(0) => UART1_TXD, 
	sio_rxd(0) => UART1_RXD,
	sio_break(0) => sio_break,
        spi_sck(0)  => open,  spi_sck(1)  => FPGA_SD_SCLK,
        spi_ss(0)   => open,  spi_ss(1)   => FPGA_SD_D3,
        spi_mosi(0) => open,  spi_mosi(1) => FPGA_SD_CMD,
        spi_miso(0) => '-',   spi_miso(1) => FPGA_SD_D0,
	gpio(7 downto 0) => M_EXPMOD0, gpio(15 downto 8) => M_EXPMOD1,
	gpio(23 downto 16) => M_EXPMOD2, gpio(31 downto 24) => M_EXPMOD3,
	gpio(127 downto 32) => open,
        -- PS/2 Keyboard
        ps2_clk_in   => ps2_clk_in,
        ps2_dat_in   => ps2_dat_in,
        ps2_clk_out  => ps2_clk_out,
        ps2_dat_out  => ps2_dat_out,
        -- VGA/HDMI
	tmds_out_rgb => tmds_out_rgb,
	vga_vsync => vga_vsync_n,
	vga_hsync => vga_hsync_n,
	vga_r => VGA_RED,
	vga_g => VGA_GREEN,
	vga_b => VGA_BLUE,
	-- simple I/O
	simple_out(7 downto 0) => M_LED, simple_out(15 downto 8) => disp_7seg_segment,
	simple_out(19 downto 16) => M_7SEG_DIGIT, simple_out(31 downto 20) => open,
	simple_in(4 downto 0) => M_BTN,
        simple_in(8 downto 5) => M_HEX,
        simple_in(31 downto 9) => (others => '-')
    );

    m_7seg_a  <= disp_7seg_segment(0);
    m_7seg_b  <= disp_7seg_segment(1);
    m_7seg_c  <= disp_7seg_segment(2);
    m_7seg_d  <= disp_7seg_segment(3);
    m_7seg_e  <= disp_7seg_segment(4);
    m_7seg_f  <= disp_7seg_segment(5);
    m_7seg_g  <= disp_7seg_segment(6);
    m_7seg_dp <= disp_7seg_segment(7);

    -- differential output buffering for HDMI clock and video
    hdmi_output: entity work.hdmi_out
      port map (
        tmds_in_clk => clk_25MHz,
        tmds_out_clk_p => VID_CLK_P,
        tmds_out_clk_n => VID_CLK_N,
        tmds_in_rgb => tmds_out_rgb,
        tmds_out_rgb_p => VID_D_P,
        tmds_out_rgb_n => VID_D_N
      );
    VGA_SYNC_N <= '1';
    VGA_BLANK_N <= '1';
    VGA_CLOCK_P <= clk_25MHz;
    VGA_VSYNC <= vga_vsync_n;
    VGA_HSYNC <= vga_hsync_n;

end Behavioral;
