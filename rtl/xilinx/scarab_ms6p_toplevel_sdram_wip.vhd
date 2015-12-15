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
  generic
  (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 50/81/83/100/111/112/125
    C_clk_freq: integer := 100;
    -- SoC configuration options
    C_mem_size: integer := 8; -- bootloader area
    C_icache_expire: boolean := false; -- false: normal i-cache, true: passthru buggy i-cache
    C_icache_size: integer := 2; -- 0, 2, 4, 8, 16, 32 KBytes
    C_dcache_size: integer := 2; -- 0, 2, 4, 8, 16, 32 KBytes
    C_sdram_separate_arbiter: boolean := false;
    C_ram_emu_addr_width: integer := 0; -- RAM emulation (0:disable, 11:8K, 12:16K ...)
    C_ram_emu_wait_states: integer := 2; -- 0 doesn't work, 1 and more works

    C_vgahdmi: boolean := true;
    C_vgahdmi_test_picture: integer := 0;
    -- number of pixels for line step 640 for no compositing
    -- 680 for comositing
    C_vgahdmi_fifo_step: integer := 680;
    -- number of pixels to postpone step
    -- postpone step as much as possible to avoid flickering of a left sprite moved right
    C_vgahdmi_fifo_postpone_step: integer := 672;
    -- number of 32 bit words used for H-compositing dual thin sprite,
    -- first 32-bit word contains 2 offsets and the rest is bitmap
    -- usual value for this is 17
    -- (tiny sprites are one pixel high)
    C_vgahdmi_fifo_compositing_length: integer := 17;
    -- output data width select: 8 bits = 3
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
    -- width of FIFO address space -> size of fifo
    -- for 8bpp compositing use 9 -> 512 bytes
    C_vgahdmi_fifo_addr_width: integer := 9;

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: miniSpartan6+ MIPS compatible soft-core 100MHz 32MB SDRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480                   
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 4;   -- 4KB text+font  memory
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
      C_vgatext_palette: boolean := true;  -- no color palette
      C_vgatext_text: boolean := true;    -- enable optional text generation
        C_vgatext_char_height: integer := 16;   -- character cell height
        C_vgatext_font_height: integer := 16;    -- font height
        C_vgatext_font_depth: integer := 8;			-- font char depth, 7=128 characters or 8=256 characters
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
          --C_vgatext_bitmap_fifo_step: integer := 0; -- disabled
          --C_vgatext_bitmap_fifo_postpone_step: integer := 0; -- disabled
          --C_vgatext_bitmap_fifo_compositing_length: integer := 0; -- disabled
          --C_vgatext_bitmap_fifo_width: integer := 8; -- bitmap width of FIFO address space length = 2^width * 4 byte

          -- step=10*length make 680 bytes, contains 640 pixels and 20 16-bit offsets for compositing
          C_vgatext_bitmap_fifo_step: integer := 10*17;
          -- postpone step as much as possible to avoid flickering of a left sprite moved right
          C_vgatext_bitmap_fifo_postpone_step: integer := 10*17-4;
          -- word length for H-compositing thin sprite, including offset word (tiny sprites one pixel high)
          C_vgatext_bitmap_fifo_compositing_length: integer := 17;
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_width: integer := 10;

      C_fmrds: boolean := true;
      C_sio: integer := 1;
      C_spi: integer := 2;
      C_gpio: integer := 32
  );
  port
  (
    clk_50MHz: in std_logic;
    sdram_clk: out std_logic;
    sdram_cke: out std_logic;
    sdram_csn: out std_logic;
    sdram_rasn: out std_logic;
    sdram_casn: out std_logic;
    sdram_wen: out std_logic;
    sdram_a: out std_logic_vector (12 downto 0);
    sdram_ba: out std_logic_vector(1 downto 0);
    sdram_dqm: out std_logic_vector(1 downto 0);
    sdram_d: inout std_logic_vector (15 downto 0);
    rs232_tx: out std_logic;
    rs232_rx: in std_logic;
    flash_cs, flash_cclk, flash_mosi: out std_logic;
    flash_miso: in std_logic;
    sd_clk, sd_cd_dat3, sd_cmd: out std_logic;
    sd_dat0: in std_logic;
    leds: out std_logic_vector(7 downto 0);
    porta, portb: inout std_logic_vector(11 downto 0);
    portc: inout std_logic_vector(7 downto 0);
    portd: out std_logic_vector(0 downto 0); -- fm antenna is here
    TMDS_in_P, TMDS_in_N: out std_logic_vector(2 downto 0);
    TMDS_in_CLK_P, TMDS_in_CLK_N: out std_logic;
    TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
    TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
    sw: in std_logic_vector(4 downto 1)
  );
end glue;

architecture Behavioral of glue is
  signal clk, sdram_clk_internal: std_logic;
  signal clk_25MHz, clk_250MHz: std_logic := '0';
  signal rs232_break: std_logic;
  signal btns: std_logic_vector(1 downto 0);
  signal tmds_out_rgb: std_logic_vector(2 downto 0);
begin
  -- clock synthesizer: Xilinx Spartan-6 specific

  clk125: if C_clk_freq = 125 generate
    clkgen125: entity work.pll_50M_250M_125M_25M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_250MHz, clk_out2 => clk, clk_out3 => clk_25MHz
      );
  end generate;

  clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk
      );
  end generate;

  clk111: if C_clk_freq = 111 generate
    clkgen111: entity work.pll_50M_250M_111M11_25M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_250MHz, clk_out2 => clk, clk_out3 => clk_25MHz
      );
  end generate;

  clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M_25M_250M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz
      );
  end generate;

  clk83: if C_clk_freq = 83 generate
    clkgen83: entity work.pll_50M_25M_83M33_250M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_25MHz, clk_out2 => clk, clk_out3 => clk_250MHz
      );
  end generate;

  clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_50M_81M25
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk
      );
  end generate;

  clk50: if C_clk_freq = 50 generate
    clk <= clk_50MHz;
  end generate;

  -- reset hard-block: Xilinx Spartan-6 specific
  reset: startup_spartan6
    port map
    (
      clk => clk, gsr => rs232_break, gts => rs232_break,
      keyclearb => '0'
    );

  -- generic SDRAM glue
  glue_sdram: entity work.glue_sdram
    generic map
    (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_mem_size => C_mem_size,
      C_icache_expire => C_icache_expire,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      C_sdram_address_width => 24,
      C_sdram_column_bits => 9,
      C_sdram_startup_cycles => 10100,
      C_sdram_cycles_per_refresh => 1524,
      C_sdram_separate_arbiter => C_sdram_separate_arbiter,
      C_ram_emu_addr_width => C_ram_emu_addr_width,
      C_ram_emu_wait_states => C_ram_emu_wait_states,
      -- vga simple compositing bitmap only graphics
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_test_picture => C_vgahdmi_test_picture,
      C_vgahdmi_fifo_step => C_vgahdmi_fifo_step,
      C_vgahdmi_fifo_postpone_step => C_vgahdmi_fifo_postpone_step,
      C_vgahdmi_fifo_compositing_length => C_vgahdmi_fifo_compositing_length,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_vgahdmi_fifo_addr_width => C_vgahdmi_fifo_addr_width,
      -- vga advanced graphics text+compositing bitmap
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
      C_vgatext_bitmap_fifo_postpone_step => C_vgatext_bitmap_fifo_postpone_step,
      C_vgatext_bitmap_fifo_compositing_length => C_vgatext_bitmap_fifo_compositing_length,
      C_vgatext_bitmap_fifo_width => C_vgatext_bitmap_fifo_width,
      C_fmrds => C_fmrds,
      C_debug => C_debug
    )
    port map
    (
      clk => clk,
      clk_25MHz => clk_25MHz, -- pixel clock
      clk_250MHz => clk_250MHz, -- tmds clock
      clk_fmdds => clk_250MHz, -- FM/RDS clock
      -- external SDRAM interface
      sdram_addr => sdram_a, sdram_data => sdram_d,
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
      sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk_internal,
      sdram_we => sdram_wen, sdram_cs => sdram_csn,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => rs232_break,
      spi_sck(0)  => flash_cclk,  spi_sck(1)  => sd_clk,
      spi_ss(0)   => flash_cs,    spi_ss(1)   => sd_cd_dat3,
      spi_mosi(0) => flash_mosi,  spi_mosi(1) => sd_cmd,
      spi_miso(0) => flash_miso,  spi_miso(1) => sd_dat0,
      tmds_out_rgb => tmds_out_rgb,
      fm_antenna => portd(0),
      gpio(11 downto 0) => porta(11 downto 0),
      gpio(23 downto 12) => portb(11 downto 0),
      gpio(31 downto 24) => portc(7 downto 0),
      gpio(127 downto 32) => open,
      simple_out(7 downto 0) => leds(7 downto 0),
      simple_out(31 downto 8) => open,
      simple_in(15 downto 0) => open,
      simple_in(19 downto 16) => sw(4 downto 1),
      simple_in(31 downto 20) => open
    );

    -- SDRAM clock output needs special routing on Spartan-6
    sdram_clk_forward : ODDR2
      generic map
      (
        DDR_ALIGNMENT => "NONE", INIT => '0', SRTYPE => "SYNC"
      )
      port map
      (
        Q => sdram_clk, C0 => clk, C1 => sdram_clk_internal, CE => '1',
        R => '0', S => '0', D0 => '0', D1 => '1'
      );

    -- differential output buffering for HDMI clock and video
    hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => clk_25MHz,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb    => tmds_out_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );

    hdmi_output2: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => clk_25MHz,
        tmds_out_clk_p => tmds_in_clk_p,
        tmds_out_clk_n => tmds_in_clk_n,
        tmds_in_rgb    => tmds_out_rgb,
        tmds_out_rgb_p => tmds_in_p,
        tmds_out_rgb_n => tmds_in_n
      );

end Behavioral;
