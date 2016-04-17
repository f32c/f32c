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
use IEEE.MATH_REAL.ALL;

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;

entity glue is
  generic
  (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 50/81/100/112
    C_clk_freq: integer := 100;

    -- SoC configuration options
    C_mem_size: integer := 32; -- KB
    C_vgahdmi: boolean := false;
      C_vgahdmi_mem_kb: integer := 38; -- KB 38K full mono 640x480

    C_vgatext: boolean := true;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: miniSpartan6+ MIPS compatible soft-core 100MHz 32KB BRAM";	-- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480                   
      C_vgatext_bits: integer := 2;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 8;   -- 8KB text+font  memory
      C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
      C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
      C_vgatext_palette: boolean := false;  -- no color palette
      C_vgatext_text: boolean := true;    -- enable optional text generation
        C_vgatext_char_height: integer := 16;   -- character cell height
        C_vgatext_font_height: integer := 16;    -- font height
        C_vgatext_font_depth: integer := 7;			-- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)        
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)       
        C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character             
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo             
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor                 
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
        C_vgatext_reg_read: boolean := true; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
        C_vgatext_text_fifo: boolean := false;  -- disable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 1;
          C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; 	-- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := false;     -- true for optional bitmap generation                 
        C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := false;  -- disable bitmap FIFO
          C_vgatext_bitmap_fifo_step: integer := 0;	-- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
          C_vgatext_bitmap_fifo_width: integer := 8;	-- bitmap width of FIFO address space length = 2^width * 4 byte

    C_fmrds: boolean := true;
      C_rds_msg_len: integer := 260; -- bytes of RAM for RDS binary message
      C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
      C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
      C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic

    -- warning long compile time on ISE 14.7
    -- C_pids = 2: 1 hour
    -- C_pids = 4: 4 hours
    C_pids: integer := 0;
      C_pid_simulator: std_logic_vector(7 downto 0) := ext("1111", 8);
      C_pid_prescaler: integer := 18;
      C_pid_precision: integer := 1;
      C_pid_pwm_bits: integer := 12;

    C_sio: integer := 1;
    C_spi: integer := 2;
    C_gpio: integer := 32;
    C_simple_io: boolean := true
  );

  port
  (
    clk_50MHz: in std_logic;
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
    TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
    TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
    sw: in std_logic_vector(4 downto 1)
  );
end glue;

architecture Behavioral of glue is
  signal clk, rs232_break: std_logic;
  signal btns: std_logic_vector(1 downto 0);
  signal clk_25MHz, clk_250MHz: std_logic := '0';
  signal tmds_out_rgb: std_logic_vector(2 downto 0);
begin
  -- clock synthesizer: Xilinx Spartan-6 specific
	
  clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
    port map
    (
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
  end generate;

  clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M_25M_250M
    port map
    (
      clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz
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

  -- generic BRAM glue
  glue_bram: entity work.glue_bram
    generic map
    (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_mem_size => C_mem_size,
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mem_kb => C_vgahdmi_mem_kb,
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
      C_vgatext_bitmap_fifo_width => C_vgatext_bitmap_fifo_width,
      C_fmrds => C_fmrds,
      C_fmdds_hz => C_fmdds_hz,
      C_rds_msg_len => C_rds_msg_len,
      C_rds_clock_multiply => C_rds_clock_multiply,
      C_rds_clock_divide => C_rds_clock_divide,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      C_pids => C_pids,
      C_pid_simulator => C_pid_simulator,
      C_pid_prescaler => C_pid_prescaler, -- set control loop frequency
      C_pid_fp => integer(floor((log2(real(C_clk_freq)*1.0E6))+0.5))-C_pid_prescaler, -- control loop approx freq in 2^n Hz for math, 26-C_pid_prescaler = 8
      C_pid_precision => C_pid_precision, -- fixed point PID precision
      C_pid_pwm_bits => C_pid_pwm_bits, -- clock divider bits define PWM output frequency
      C_debug => C_debug
    )
    port map
    (
      clk => clk,
      clk_25MHz => clk_25MHz, -- pixel clock
      clk_250MHz => clk_250MHz, -- tmds clock
      clk_fmdds => clk_250MHz, -- FM/RDS clock
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => rs232_break,
      spi_sck(0)  => flash_cclk,  spi_sck(1)  => sd_clk,
      spi_ss(0)   => flash_cs,    spi_ss(1)   => sd_cd_dat3,
      spi_mosi(0) => flash_mosi,  spi_mosi(1) => sd_cmd,
      spi_miso(0) => flash_miso,  spi_miso(1) => sd_dat0,
      gpio(11 downto 0) => porta(11 downto 0),
      gpio(23 downto 12) => portb(11 downto 0),
      gpio(31 downto 24) => portc(7 downto 0),
      gpio(127 downto 32) => open,
      simple_out(7 downto 0) => leds(7 downto 0),
      simple_out(31 downto 8) => open,
      simple_in(15 downto 0) => open,
      simple_in(19 downto 16) => sw(4 downto 1),
      simple_in(31 downto 20) => open,
      fm_antenna => portd(0),
      tmds_out_rgb => tmds_out_rgb
    );

    -- differential output buffering for HDMI clock and video
    hdmi_output: entity work.hdmi_out
      port map
      (
        tmds_in_clk => clk_25MHz,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb => tmds_out_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );

end Behavioral;
