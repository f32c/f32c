--
-- Copyright (c) 2015 Xark
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


entity glue is
  generic (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
    C_clk_freq: integer := 50;

    -- SoC configuration options
    C_mem_size: integer := 2;
    C_icache_size: integer := 2;
    C_dcache_size: integer := 2;
    C_branch_prediction: boolean := false;
    C_sio: integer := 2;
    C_spi: integer := 2;
    C_simple_io: boolean := true;
    C_gpio: integer := 29;
    C_gpio_pullup: boolean := true;
    C_gpio_adc: integer := 6;       -- number of analog ports for ADC (on A0-A5 pins)
    C_ps2: boolean := true;
    C_vgatext: boolean := true;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FleaFPGA-Uno f32c: 50MHz MIPS-compatible soft-core, 512KB SRAM";
    C_vgatext_mode: integer := 0;   -- 640x480
    C_vgatext_bits: integer := 4;   -- 4096 possible colors
    C_vgatext_bram_mem: integer := 16;   -- 8KB text+font  memory
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := true;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
    C_vgatext_char_height: integer := 16;   -- character cell height
    C_vgatext_font_height: integer := 16;    -- font height
    C_vgatext_font_depth: integer := 7;     -- font char depth, 7=128 characters or 8=256 characters
    C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
    C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
    C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
    C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
    C_vgatext_cursor: boolean := true;    -- true for optional text cursor
    C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
    C_vgatext_bus_read: boolean := true; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_reg_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_text_fifo: boolean := true;  -- disable text memory FIFO
      C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
      C_vgatext_text_fifo_width: integer := 6;  -- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := true;     -- true for optional bitmap generation
    C_vgatext_bitmap_depth: integer := 4;   -- 8-bpp 16-color bitmap
    C_vgatext_bitmap_fifo: boolean := true;  -- disable bitmap FIFO
      C_vgatext_bitmap_fifo_step: integer := 0; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
      C_vgatext_bitmap_fifo_width: integer := 6 -- bitmap width of FIFO address space length = 2^width * 4 byte
  );
  port (
  sys_clock   : in    std_logic;  -- main clock input from 25MHz clock source
  --sys_reset   : in    std_logic;  --

  Shield_reset : inout    std_logic;  -- Buffered reset signal out to GPIO header
  --clk_25m: in std_logic;

  -- SRAM
  SRAM_Addr   : out   std_logic_vector(18 downto 0);  -- SRAM address bus
  SRAM_Data   : inout std_logic_vector(7 downto 0); -- data bus to/from SRAM
  SRAM_n_cs   : out   std_logic;
  SRAM_n_oe   : out   std_logic;
  SRAM_n_we   : out   std_logic;

  -- UART0 (USB slave serial)
  slave_tx_o  : out   std_logic;
  slave_rx_i  : in    std_logic;

  -- UART1 (Optional WiFi interface)
  wifi_rx_i   : out   std_logic;
  wifi_tx_o   : in    std_logic;

  LVDS_Red    : out   std_logic;
  LVDS_Green  : out   std_logic;
  LVDS_Blue   : out   std_logic;
  LVDS_ck     : out   std_logic;

  -- PS2 interface
  PS2_clk1    : inout std_logic;
  PS2_data1   : inout std_logic;

  User_LED1   : inout std_logic;
  User_LED2   : out   std_logic;
  User_n_PB1  : in    std_logic;

  GPIO_wordport : inout std_logic_vector(15 downto 0);
  GPIO_pullup   : inout std_logic_vector(15 downto 0);

  ADC_Comp_in   : inout std_logic_vector(5 downto 0);
  ADC_Error_out : inout std_logic_vector(5 downto 0);

    -- SPI1 to Flash ROM
  spi1_miso   : in      std_logic;
  spi1_mosi   : out     std_logic;
  spi1_clk    : out     std_logic;
  spi1_cs     : out     std_logic

  );
end glue;

architecture Behavioral of glue is
  signal clk, rs232_break, rs232_break2: std_logic;
  signal clk_dvi, clk_dvin, clk_pixel: std_logic;
  signal ps2_clk_in : std_logic;
  signal ps2_clk_out : std_logic;
  signal ps2_dat_in : std_logic;
  signal ps2_dat_out : std_logic;

begin
  ps2_dat_in  <= PS2_data1;
  PS2_data1   <= '0' when ps2_dat_out='0' else 'Z';
  ps2_clk_in  <= PS2_clk1;
  PS2_clk1    <= '0' when ps2_clk_out='0' else 'Z';

  SRAM_n_cs   <= '0';
  SRAM_n_oe   <= '0';
  shield_reset <= 'Z';  -- ignore for now

  -- un-comment following two lines for WiFi option
  gpio_pullup(0) <= '1';  -- Wifi gpio
  User_LED2      <= '1';  -- Wifi reset

  u0 : entity work.clkgen
  port map(
    CLKI        =>  sys_clock,
    CLKOP       =>  clk_dvi,
    CLKOS       =>  clk_dvin,
    CLKOS2      =>  clk_pixel,
    CLKOS3      =>  clk
  );

    -- generic BRAM glue
  glue_bram: entity work.glue_bram_sram8
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_mem_size => C_mem_size,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_debug => C_debug,
    C_sio => C_sio,
    C_spi => C_spi,
    C_gpio => C_gpio,
    C_gpio_pullup => C_gpio_pullup,
    C_gpio_adc => C_gpio_adc,
    C_branch_prediction => C_branch_prediction,
        C_vgatext => C_vgatext,
        C_vgatext_label => C_vgatext_label,
        C_vgatext_mode => C_vgatext_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_bus_read => C_vgatext_bus_read,
        C_vgatext_reg_read => C_vgatext_reg_read,
        C_vgatext_text => C_vgatext_text,
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
        C_vgatext_bitmap_fifo_width => C_vgatext_bitmap_fifo_width
  )
  port map (
    clk => clk,
    clk_dvi => clk_dvi,
    clk_dvin => clk_dvin,
    clk_25MHz => clk_pixel,
    sio_rxd(0) => slave_rx_i,
    sio_rxd(1) => wifi_tx_o,
    sio_txd(0) => slave_tx_o,
    sio_txd(1) => wifi_rx_i,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,
    spi_sck(0) => spi1_clk,
    spi_ss(0) => spi1_cs,
    spi_mosi(0) => spi1_mosi,
    spi_miso(0) => spi1_miso,

    ADC_Error_out => ADC_Error_out,

    gpio(127 downto 32) => open,

    gpio(24) => GPIO_wordport(0), -- PORTD0 pin D0
    gpio(25) => GPIO_wordport(1), -- PORTD1 pin D1
    gpio(26) => GPIO_wordport(2), -- PORTD2 pin D2
    gpio(27) => GPIO_wordport(3), -- PORTD3 pin D3
    gpio(28) => GPIO_wordport(4), -- PORTD4 pin D4
    gpio(29) => GPIO_wordport(5), -- PORTD5 pin D5
    gpio(30) => GPIO_wordport(6), -- PORTD6 pin D6
    gpio(31) => GPIO_wordport(7), -- PORTD7 pin D7


    gpio(21 downto 16) => ADC_Comp_In,

    gpio(23 downto 22) => open,

    gpio(8) => GPIO_wordport(8),  -- PORTB0 pin D8
    gpio(9) => GPIO_wordport(9),  -- PORTB1 pin D9
    gpio(10) => GPIO_wordport(10),  -- PORTB2 pin D10
    gpio(11) => GPIO_wordport(11),  -- PORTB3 pin D11
    gpio(12) => GPIO_wordport(12),  -- PORTB4 pin D12
    gpio(13) => GPIO_wordport(13),  -- PORTB5 pin D13
    gpio(14) => open,
    gpio(15) => open,

    gpio(7 downto 0) => open,

    gpio_pullup(127 downto 32) => open,

-- Wifi    gpio_pullup(24) => gpio_pullup(0), -- PORTD0 pin D0 pullup -- Not available if WiFi option installed
    gpio_pullup(25) => gpio_pullup(1),  -- PORTD1 pin D1 pullup
    gpio_pullup(26) => gpio_pullup(2),  -- PORTD2 pin D2 pullup
    gpio_pullup(27) => gpio_pullup(3),  -- PORTD3 pin D3 pullup
    gpio_pullup(28) => gpio_pullup(4),  -- PORTD4 pin D4 pullup
    gpio_pullup(29) => gpio_pullup(5),  -- PORTD5 pin D5 pullup
    gpio_pullup(30) => gpio_pullup(6),  -- PORTD6 pin D6 pullup
    gpio_pullup(31) => gpio_pullup(7),  -- PORTD7 pin D7 pullup


    gpio_pullup(21 downto 16) => open,

    gpio_pullup(23 downto 22) => open,

    gpio_pullup(8) => gpio_pullup(8),   -- PORTB0 pin D8 pullup
    gpio_pullup(9) => gpio_pullup(9),   -- PORTB1 pin D9 pullup
    gpio_pullup(10) => gpio_pullup(10), -- PORTB2 pin D10 pullup
    gpio_pullup(11) => gpio_pullup(11), -- PORTB3 pin D11 pullup
    gpio_pullup(12) => gpio_pullup(12), -- PORTB4 pin D12 pullup
    gpio_pullup(13) => gpio_pullup(13), -- PORTB5 pin D13 pullup
    gpio_pullup(14) => open,
    gpio_pullup(15) => open,

    gpio_pullup(7 downto 0) => open,

    simple_out(0) => User_LED1,
-- Wifi    simple_out(1) => User_LED2, -- Not available if WiFi option installed
    simple_out(31 downto 2) => open,
    simple_in(0) => NOT User_n_PB1,
    simple_in(31 downto 1) => open,
    sram_addr(18 downto 0) =>   SRAM_Addr,
    sram_data =>  SRAM_Data,
    sram_we => SRAM_n_we,
    -- PS/2 Keyboard
    ps2_clk_in      => ps2_clk_in,
    ps2_dat_in      => ps2_dat_in,
    ps2_clk_out     => ps2_clk_out,
    ps2_dat_out     => ps2_dat_out,
    -- Digital Video out
    LVDS_Red => LVDS_Red,
    LVDS_Green => LVDS_Green,
    LVDS_Blue => LVDS_Blue,
    LVDS_ck => LVDS_ck
  );
end Behavioral;

