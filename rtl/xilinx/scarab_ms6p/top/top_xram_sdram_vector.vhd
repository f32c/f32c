--
-- Copyright (c) 2016 Davor Jadrijevic
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
use IEEE.MATH_REAL.ALL; -- floor(), log2()

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;

entity scarab_xram_sdram_vector is
  generic
  (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;
    C_exceptions: boolean := true; -- false:disable interrupts allows vector to work

    -- Main clock: 25/50/75/81/83/96/100/111/112/125
    C_clk_freq: integer := 100;
    C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)
    -- SoC configuration options
    C_bram_size: integer := 8; -- bootloader area
    C_icache_size: integer := 2; -- 0, 2, 4, 8, 16, 32 KBytes
    C_dcache_size: integer := 2; -- 0, 2, 4, 8, 16, 32 KBytes
    C_cached_addr_bits: integer := 25; -- number of lower RAM address bits 2^25 -> 32MB to be cached
    C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- RAM start address e.g. x"8" -> 0x80000000
    C_sdram: boolean := true;

    C_vector: boolean := true; -- vector processor unit (wip)
    C_vector_axi: boolean := false; -- vector processor bus type (false: normal f32c)
    C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
    C_vector_vaddr_bits: integer := 11;
    C_vector_vdata_bits: integer := 32;
    C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
    C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
    C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

    -- C_dvid_ddr = false: clk_pixel_shift = 250MHz
    -- C_dvid_ddr = true: clk_pixel_shift = 125MHz
    -- (fixme: DDR video output mode doesn't work on scarab)
    C_dvid_ddr: boolean := true;
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024
    C_shift_clock_synchronizer: boolean := false; -- some hardware may need this enabled

    C_vgahdmi: boolean := true;
    -- insert cache between RAM and compositing2 video fifo
    C_vgahdmi_cache_size: integer := 8; -- KB size 0:disable 2,4,8,16,32:enable
    C_vgahdmi_cache_use_i: boolean := true; -- use I-data caching style, faster
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8; -- bpp (currently 8/16/32 supported)

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: miniSpartan6+ MIPS compatible soft-core 100MHz 32MB SDRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480                   
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 0;   -- 4KB text+font  memory
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
        C_vgatext_bus_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
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
    -- number of pixels for line step 144
    C_ledstrip_fifo_width: integer := 144;
    -- number of scan lines: 480
    C_ledstrip_fifo_height: integer := 480;
    -- normally this should be  actual bits per pixel
    C_ledstrip_fifo_data_width: integer range 8 to 32 := 8;
    -- width of FIFO address space -> size of fifo
    -- for 8bpp compositing use 11 -> 2^11 = 2048 bytes
    C_ledstrip_fifo_addr_width: integer := 11;

    C_cw_simple_out: integer := -1; -- simple_out (default 7) bit for 433MHz modulator. -1 to disable.

      C_pcm: boolean := false;
      C_fmrds: boolean := false;
        C_fm_stereo: boolean := true;
        C_fm_filter: boolean := true;
        C_fm_downsample: boolean := false;
        C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
        C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
        C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
        --C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
        --C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
      C_sio: integer := 1;
      C_spi: integer := 2;

      -- warning long compile time on ISE 14.7
      -- C_pids = 2: 1 hour
      -- C_pids = 4: 4 hours
      C_pids: integer := 0;
        C_pid_simulator: std_logic_vector(7 downto 0) := ext("1111", 8);
        C_pid_prescaler: integer := 18;
        C_pid_precision: integer := 1;
        C_pid_pwm_bits: integer := 12;
        
      C_timer: boolean := true; -- false: disable timer allows vector to work

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
    sd_dat0, sd_dat1, sd_dat2: in std_logic;
    leds: out std_logic_vector(7 downto 0);
    porta, portb, portc: inout std_logic_vector(11 downto 0);
    portd: inout std_logic_vector(3 downto 0); -- fm and cw antennas are here
    porte, portf: inout std_logic_vector(11 downto 0);
    audio1, audio2: out std_logic; -- 3.5mm audio jack
    -- warning TMDS_in is used as output
    TMDS_in_P, TMDS_in_N: out std_logic_vector(2 downto 0);
    TMDS_in_CLK_P, TMDS_in_CLK_N: out std_logic;
    FPGA_SDA, FPGA_SCL: inout std_logic; -- i2c on TMDS_in
    TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
    TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
    sw: in std_logic_vector(4 downto 1)
  );
end;

architecture Behavioral of scarab_xram_sdram_vector is
  signal clk, sdram_clk_internal: std_logic;
  signal clk_pixel, clk_pixel_shift_p, clk_pixel_shift_n: std_logic := '0';
  signal clk_25MHz, clk_30MHz, clk_40MHz, clk_50MHz_p, clk_65MHz, clk_75MHz, clk_93M75, clk_97M5Hz,
         clk_100MHz, clk_125MHz_p, clk_125MHz_n, clk_150MHz_p, clk_150MHz_n, 
         clk_200MHz_p, clk_200MHz_n, clk_250MHz_p, clk_250MHz_n,
         clk_325MHz_p, clk_325MHz_n, clk_375MHz_p, clk_375MHz_n,
         clk_433M92Hz: std_logic := '0';
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal tmds_in_rgb, tmds_out_rgb: std_logic_vector(2 downto 0);
  signal tmds_in_clk, tmds_out_clk: std_logic;
  signal rs232_break: std_logic;
  signal cw_antenna, fm_antenna: std_logic := '0';
  signal btns: std_logic_vector(1 downto 0);
begin
  -- clock synthesizer: Xilinx Spartan-6 specific
  clk125: if C_clk_freq = 125 generate
    clkgen125: entity work.pll_50M_250M_125M_25M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_250MHz_p, clk_out2 => clk, clk_out3 => clk_25MHz
      );
    clk_pixel_shift_p <= clk_250MHz_p;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk
      );
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk111: if C_clk_freq = 111 generate
    clkgen111: entity work.pll_50M_250M_111M11_25M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_250MHz_p, clk_out2 => clk, clk_out3 => clk_25MHz
      );
    clk_pixel_shift_p <= clk_250MHz_p;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk96: if C_clk_freq = 96 generate
    clkgen96: entity work.pll_50M_96M43
      port map
      (
        clk_in_50M => clk_50MHz, clk_out_96M43 => clk
      );
    clkgen433: entity work.pll_96M43_433M9_289M3_28M93
      port map
      (
        clk_in_96M43 => clk, clk_out_433M9 => clk_433M92Hz, clk_out_289M3 => clk_250MHz_p, clk_out_28M93 => clk_25MHz
      );
    clk_pixel_shift_p <= clk_250MHz_p;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk83: if C_clk_freq = 83 generate
    clkgen83: entity work.pll_50M_25M_83M33_250M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk_25MHz, clk_out2 => clk, clk_out3 => clk_250MHz_p
      );
    clk_pixel_shift_p <= clk_250MHz_p;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_50M_81M25
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk
      );
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk50: if C_clk_freq = 50 generate
    clk <= clk_50MHz;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk100M_sdr_640x480: if C_clk_freq = 100 and not C_dvid_ddr and C_video_mode=1 generate
    clkgen100_250_25: entity work.pll_50M_100M_25M_250M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz_p
      );
    clk_pixel <= clk_25MHz;
    clk_pixel_shift_p <= clk_250MHz_p;
    portd(0) <= fm_antenna;
    portd(1) <= cw_antenna;
  end generate;

  clk100M_ddr_640x480: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode<=1 generate
    clkgen100_125_25: entity work.clk_50M_100M_125Mp_125Mn_25M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_100M => clk, clk_25M => clk_25MHz, 
        clk_125Mp => clk_125MHz_p, clk_125Mn => clk_125MHz_n
      );
    clk_pixel <= clk_25MHz;
    clk_pixel_shift_p <= clk_125MHz_p;
    clk_pixel_shift_n <= clk_125MHz_n;
  end generate;

  clk100M_ddr_800x480: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=2 generate
    clkgen100_150_30: entity work.clk_50M_100M_150Mp_150Mn_30M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_100M => clk, clk_30M => clk_30MHz, 
        clk_150Mp => clk_150MHz_p, clk_150Mn => clk_150MHz_n
      );
    clk_pixel <= clk_30MHz;
    clk_pixel_shift_p <= clk_150MHz_p;
    clk_pixel_shift_n <= clk_150MHz_n;
  end generate;

  clk100M_ddr_800x600: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=3 generate
    clkgen100_200_40: entity work.clk_50M_100M_200Mp_200Mn_40M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_100M => clk, clk_40M => clk_40MHz, 
        clk_200Mp => clk_200MHz_p, clk_200Mn => clk_200MHz_n
      );
    clk_pixel <= clk_40MHz;
    clk_pixel_shift_p <= clk_200MHz_p;
    clk_pixel_shift_n <= clk_200MHz_n;
  end generate;

  clk100M_ddr_1024x576: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=4 generate
    clkgen100_250_50: entity work.clk_50M_100M_250Mp_250Mn_50M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_100M => clk, clk_50M => clk_50MHz_p,
        clk_250Mp => clk_250MHz_p, clk_250Mn => clk_250MHz_n
      );
    clk_pixel <= clk_50MHz_p;
    clk_pixel_shift_p <= clk_250MHz_p;
    clk_pixel_shift_n <= clk_250MHz_n;
  end generate;

  clk97M5_ddr_1024x768: if C_clk_freq = 98 and C_dvid_ddr and C_video_mode=5 generate
    clkgen98_325_65: entity work.clk_50M_97M5_325Mp_325Mn_65M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_97M5 => clk, clk_65M => clk_65MHz, 
        clk_325Mp => clk_325MHz_p, clk_325Mn => clk_325MHz_n
      );
    clk_pixel <= clk_65MHz;
    clk_pixel_shift_p <= clk_325MHz_p;
    clk_pixel_shift_n <= clk_325MHz_n;
  end generate;

  clk93M75_ddr_1280x768: if C_clk_freq = 94 and C_dvid_ddr and C_video_mode=6 generate
    clkgen93_375_75: entity work.clk_50M_93M75_375Mp_375Mn_75M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_93M75 => clk, clk_75M => clk_75MHz, 
        clk_375Mp => clk_375MHz_p, clk_375Mn => clk_375MHz_n
      );
    clk_pixel <= clk_75MHz;
    clk_pixel_shift_p <= clk_375MHz_p;
    clk_pixel_shift_n <= clk_375MHz_n;
  end generate;

  G_vendor_specific_startup: if C_vendor_specific_startup generate
  -- reset hard-block: Xilinx Spartan-6 specific
  reset: startup_spartan6
    port map
    (
      clk => clk, gsr => rs232_break, gts => rs232_break,
      keyclearb => '0'
    );
  end generate; -- G_vendor_specific_startup

  -- generic SDRAM glue
  glue_xram: entity work.glue_xram
    generic map
    (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_exceptions => C_exceptions,
      C_bram_size => C_bram_size,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_gpio => C_gpio,
      C_timer => C_timer,
      C_sio => C_sio,
      C_spi => C_spi,
      C_xram_base => C_xram_base,
      C_sdram => C_sdram,
      C_sdram_address_width => 24,
      C_sdram_column_bits => 9,
      C_sdram_startup_cycles => 10100,
      C_sdram_cycles_per_refresh => 1524,

      -- HDMI/DVI-D output SDR or DDR
      C_dvid_ddr => C_dvid_ddr,
      C_shift_clock_synchronizer => C_shift_clock_synchronizer,
      -- vga simple compositing bitmap only graphics
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      -- led strip simple compositing bitmap only graphics
      C_ledstrip => C_ledstrip,
      C_ledstrip_fifo_width => C_ledstrip_fifo_width,
      C_ledstrip_fifo_height => C_ledstrip_fifo_height,
      C_ledstrip_fifo_data_width => C_ledstrip_fifo_data_width,
      C_ledstrip_fifo_addr_width => C_ledstrip_fifo_addr_width,
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
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
      C_cw_simple_out => C_cw_simple_out, -- CW is for 433 MHz. -1 to disable. set (C_framebuffer => false, C_dds => false) for 433MHz transmitter
      C_pcm => C_pcm,
      C_fmrds => C_fmrds,
      C_fm_stereo => C_fm_stereo,
      C_fm_filter => C_fm_filter,
      C_fm_downsample => C_fm_downsample,
      C_rds_msg_len => C_rds_msg_len, -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
      C_fmdds_hz => C_fmdds_hz, -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz)
      C_rds_clock_multiply => C_rds_clock_multiply, -- multiply and divide from cpu clk 100 MHz
      C_rds_clock_divide => C_rds_clock_divide, -- to get 1.824 MHz for RDS logic
      C_pids => C_pids,
      C_pid_simulator => C_pid_simulator,
      C_pid_prescaler => C_pid_prescaler, -- set control loop frequency
      C_pid_fp => integer(floor((log2(real(C_clk_freq)*1.0E6))+0.5))-C_pid_prescaler, -- control loop approx freq in 2^n Hz for math, 26-C_pid_prescaler = 8
      C_pid_precision => C_pid_precision, -- fixed point PID precision
      C_pid_pwm_bits => C_pid_pwm_bits, -- clock divider bits define PWM output frequency
      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_registers => C_vector_registers,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,
      -- CPU debugging with serial port
      C_debug => C_debug
    )
    port map
    (
      clk => clk,
      clk_pixel => clk_pixel, -- pixel clock
      clk_pixel_shift => clk_pixel_shift_p, -- tmds clock 10x pixel clock for SDR or 5x for DDR
      clk_cw => clk_433M92Hz, -- CW clock for 433.92MHz transmitter
      clk_fmdds => clk_250MHz_p, -- FM/RDS clock
      -- external SDRAM interface
      sdram_addr => sdram_a, sdram_data(31 downto 16) => open, sdram_data(15 downto 0) => sdram_d,
      sdram_ba => sdram_ba, sdram_dqm(3 downto 2) => open, sdram_dqm(1 downto 0) => sdram_dqm,
      sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk_internal,
      sdram_we => sdram_wen, sdram_cs => sdram_csn,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => rs232_break,
      spi_sck(0)  => flash_cclk,  spi_sck(1)  => sd_clk,
      spi_ss(0)   => flash_cs,    spi_ss(1)   => sd_cd_dat3,
      spi_mosi(0) => flash_mosi,  spi_mosi(1) => sd_cmd,
      spi_miso(0) => flash_miso,  spi_miso(1) => sd_dat0,
      dvid_red   => dvid_red,
      dvid_green => dvid_green,
      dvid_blue  => dvid_blue,
      dvid_clock => dvid_clock,
      audio_r(3)  => audio1, audio_r(2 downto 0) => open,
      audio_l(3)  => audio2, audio_l(2 downto 0)  => open,
      cw_antenna => cw_antenna,
      fm_antenna => fm_antenna,
      gpio(11 downto  0) => porta(11 downto 0),
      gpio(23 downto 12) => portb(11 downto 0),
      gpio(35 downto 24) => portc(11 downto 0),
      gpio(37 downto 36) => open, -- because cw/fm antennas on portd(1 downto 0)
      gpio(39 downto 38) => portd( 3 downto 2), -- tx antennas
      gpio(51 downto 40) => porte(11 downto 0), 
      -- portf: GPIO
      -- gpio(63 downto 52) => portf(11 downto 0),
      gpio(63 downto 52) => open,
      gpio(127 downto 64) => open,
      -- portf: PID
      --              PID0                           PID1                           PID2
      --pid_encoder_a(0) => portf(0),  pid_encoder_a(1) => portf(4), -- pid_encoder_a(2) => portf(8),
      --pid_encoder_b(0) => portf(1),  pid_encoder_b(1) => portf(5), -- pid_encoder_b(2) => portf(9),
      --pid_bridge_f(0)  => portf(2),  pid_bridge_f(1)  => portf(6), -- pid_bridge_f(2)  => portf(10),
      --pid_bridge_r(0)  => portf(3),  pid_bridge_r(1)  => portf(7), -- pid_bridge_r(2)  => portf(11),
      --
      -- portf: LEDSTRIP and POV ball motor
      ledstrip_out(1 downto 0) => portf(1 downto 0),

      simple_out(7 downto 0) => leds(7 downto 0),
      simple_out(31 downto 8) => open,
      simple_in(15 downto 0) => open,
      simple_in(19 downto 16) => sw(4 downto 1),
      simple_in(31 downto 20) => open
    );
    -- unused pins
    FPGA_SDA <= 'Z';
    FPGA_SCL <= 'Z';

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

    G_dvi_sdr: if not C_dvid_ddr generate
      tmds_out_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_out_clk <= dvid_clock(0);
      -- hdmi "in" port can be used as second output
      -- so user don't need to think which one works :)
      tmds_in_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_in_clk <= dvid_clock(0);
    end generate;

    G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout0: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift_p,
      clk_n     => clk_pixel_shift_n,
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_out_rgb(2),
      out_green => tmds_out_rgb(1),
      out_blue  => tmds_out_rgb(0),
      out_clock => tmds_out_clk
    );
    -- hdmi "in" port can be used as second output
    -- so user don't need to think which one works :)
    G_vga_ddrout1: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift_p,
      clk_n     => clk_pixel_shift_n,
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_in_rgb(2),
      out_green => tmds_in_rgb(1),
      out_blue  => tmds_in_rgb(0),
      out_clock => tmds_in_clk
    );
    end generate;

    -- differential output buffering for HDMI clock and video
    hdmi_output0: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_out_clk,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb    => tmds_out_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );
    -- hdmi "in" port can be used as second output
    -- so user don't need to think which one works :)
    hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_in_clk,
        tmds_out_clk_p => tmds_in_clk_p,
        tmds_out_clk_n => tmds_in_clk_n,
        tmds_in_rgb    => tmds_in_rgb,
        tmds_out_rgb_p => tmds_in_p,
        tmds_out_rgb_n => tmds_in_n
      );

end Behavioral;
