
--
-- Copyright (c) 2015 Marko Zec, University of Zagreb
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use ieee.numeric_std.all; -- we need signed type

use work.f32c_pack.all;
use work.sram_pack.all;
use work.axi_pack.all;
use work.video_mode_pack.all;

entity glue_xram is
generic (
  C_clk_freq: integer;

  -- ISA options
  C_arch: integer := ARCH_MI32;
  C_big_endian: boolean := false;
  C_mult_enable: boolean := true;
  C_mul_acc: boolean := false;    -- MI32 only
  C_mul_reg: boolean := false;    -- MI32 only
  C_branch_likely: boolean := true;
  C_sign_extend: boolean := true;
  C_ll_sc: boolean := false;
  C_PC_mask: std_logic_vector(31 downto 0) := x"ffffffff"; -- full 4GB
  C_exceptions: boolean := true;

  -- COP0 options
  C_cop0_count: boolean := true;
  C_cop0_compare: boolean := true;
  C_cop0_config: boolean := true;

  -- CPU core configuration options
  C_branch_prediction: boolean := true;
  C_full_shifter: boolean := true;
  C_result_forwarding: boolean := true;
  C_load_aligner: boolean := true;
  C_regfile_synchronous_read: boolean := false;

  -- Negatively influences timing closure, hence disabled
  C_movn_movz: boolean := false;

  -- CPU debugging
  C_debug: boolean := false;

  -- SDRAM parameters
  C_sdram_clock_range : integer := 2;
  C_sdram_ras : integer := 3;
  C_sdram_cas : integer := 3;
  C_sdram_pre : integer := 3;
  C_sdram_address_width : integer := 24; -- recommended C_cached_addr_bits-1, -- RAM addr is 16-bit based (24 for 32MB), cached addr is 8-bit based (25 for 32MB)
  C_sdram_column_bits : integer := 9; -- recommended C_cached_addr_bits-16, -- 9 for 32MB, 10 for 64MB
  C_sdram_startup_cycles : integer := 10100;
  C_sdram_cycles_per_refresh : integer := 1524;

  -- RAM emulation
  -- 0: normal SDRAM, no emulation
  -- 11:8K, 12:16K, 13:32K ... RAM emulation
  --C_ram_emu_addr_width: integer := 0;
  --C_ram_emu_wait_states: integer := 0;

  -- SoC configuration options
  C_bram_size: integer := 2;	-- in KBytes
  C_bram_const_init: boolean := true; -- preload BRAM with the bootloader content (MAX10 can't, it is different)
  C_boot_write_protect: boolean := true; -- true: write protect bootloader, false: CPU can modify its bootloader
  C_boot_spi: boolean := false;
  C_icache_size: integer := 0;	-- 0, 2, 4, 8, 16 or 32 KBytes
  C_dcache_size: integer := 0;	-- 0, 2, 4, 8, 16 or 32 KBytes
  C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- x"8" maps RAM to 0x80000000
  C_cached_addr_bits: integer := 20; -- number of lower RAM address bits to be cached
  C_xdma: boolean := false; -- used to write bootloader on MAX10 (shared with refresh/textmode port)
  C_sram: boolean := false; -- 16-bit SRAM
  C_sram8: boolean := false; -- 8-bit SRAM (or 16-bit chip connected with 8 lines)
  C_sram_refresh: boolean := false; -- sram refresh workaround (RED ULX2S boards need this)
  C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
  C_sram_pipelined_read: boolean := false; -- works only at 81.25 MHz !!!
  C_sdram: boolean := false; -- 16-bit SDRAM (or 32-bit chip connected with 16 lines)
  C_sdram32: boolean := false; -- 32-bit SDRAM
  C_acram: boolean := false; -- AXI CACHE RAM
  C_acram_wait_cycles: integer := 4; -- wait cycles for acram
  C_axiram: boolean := false; -- AXI Master RAM (connects to AXI Slave)
  C_sio: integer := 1; -- number of serial port interfaces 0-4
  C_sio_init_baudrate: integer := 115200;
  C_sio_fixed_baudrate: boolean := false;
  C_sio_break_detect: boolean := true;
  C_usbsio: std_logic_vector := "0000"; -- 0-standard serial port, 1-usbserial port
  C_spi: integer := 0;
  C_spi_turbo_mode: std_logic_vector := "0000";
  C_spi_fixed_speed: std_logic_vector := "1111";
  C_simple_in: integer range 0 to 128 := 32;
  C_simple_out: integer range 0 to 128 := 32;
  -- video hardware output settings
  C_dvid_ddr: boolean := false; -- false: generate digital video from 250MHz SDR single edge, true: digital video from 125MHz DDR double edge
  -- C_lvds_display:
  -- false: normal monitors, DVI-D/HDMI 10-bit TMDS (25MHz pixel clock, 250MHz shift clock)
  -- true:  bare wired LCD panel, 7-bit LVDS (36MHz pixel clock, 252MHz shift clock and does only SDR, not DDR)
  C_lvds_display: boolean := false; -- false: normal DVI-D/HDMI, true: bare LCD panel
  C_lcd35_display: boolean := false; -- small 3.5" 320x240 LCD takes 8-bit R,G,B each clock cycle
  C_shift_clock_synchronizer: boolean := false; -- some hardware may need this enabled
  -- TV simple 512x512 bitmap
  C_tv: boolean := false; -- enable TV output
  C_tv_fifo_width: integer := 512;
  C_tv_fifo_height: integer := 512;
  C_tv_fifo_data_width: integer range 8 to 32 := 8;
  C_tv_fifo_addr_width: integer := 11;
  -- VGA/HDMI simple 640x480 bitmap only
  C_vgahdmi: boolean := false; -- enable VGA/HDMI output to vga_ and tmds_
  C_vgahdmi_compositing: integer := 2; -- 2: Compositing2 2D acceleration, 0: linear bitmap
  C_compositing2_write_while_reading: boolean := true; -- true for normal function
  C_vgahdmi_mode: integer := 1; -- video mode selection: 0:640x360, 1:640x480, 2:800x450, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024
  C_vgahdmi_axi: boolean := false; -- true: use AXI bus (video_axi_in/out) instead of f32c bus
  C_vgahdmi_cache_size: integer := 0; -- KB enable cache for f32c bus (C_vgahdmi_axi = false)
  C_vgahdmi_cache_use_i: boolean := false; -- true: use instruction cache (faster, maybe buggy), false: use data cache (slower, works)
  C_vgahdmi_fifo_fast_ram: boolean := true;
  C_vgahdmi_fifo_timeout: integer := 0; -- abort compositing at N pixels before end of line (0 disabled)
  C_vgahdmi_fifo_burst_max_bits: integer := 0; -- values >= 1 enable the burst
  C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
  --C_vgahdmi_fifo_addr_width: integer := 11; -- calculated internally
  --
  C_video_base_addr_out: boolean := false; -- dummy video driver, just output base address to toplevel
  -- LED strip ws2812 POV simple 144x480 bitmap only
  C_ledstrip: boolean := false; -- enable dual channel ws2812b output
  C_ledstrip_full_circle: integer := 100; -- count of pulses per full circle of rotation
  C_ledstrip_fifo_width: integer := 72;
  C_ledstrip_fifo_height: integer := 36;
  C_ledstrip_fifo_data_width: integer range 8 to 32 := 8;
  C_ledstrip_fifo_addr_width: integer := 11;
  -- Xark's feature-rich bitmap+textmode VGA
  -- it can mix 8bpp bitmap and tiled graphics on the same screen
  -- choice of many of video modes
  -- minimal mode needs only 4K BRAM
  C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "f32c";    -- default banner in screen memory
    C_vgatext_mode: integer := 1; -- video mode selection: 0:640x360, 1:640x480, 2:800x450, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024
    C_vgatext_bits: integer := 2; -- 4 possible colors
    C_vgatext_bram_mem: integer := 4; -- 4KB text+font  memory
    C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- start address of textmode bram x"4" -> 0x40000000
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true; -- reset registers to default with async reset
    C_vgatext_palette: boolean := false; -- no color palette
    C_vgatext_text: boolean := true; -- enable optional text generation
      C_vgatext_font_bram8: boolean := false; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
      C_vgatext_char_height: integer := 16; -- character cell height
      C_vgatext_font_height: integer := 8; -- font height
      C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
      C_vgatext_font_linedouble: boolean := true; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
      C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
      C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character
      C_vgatext_finescroll: boolean := false; -- true for pixel level character scrolling and line length modulo
      C_vgatext_cursor: boolean := true; -- true for optional text cursor
      C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
      C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_reg_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
      C_vgatext_text_fifo_postpone_step: integer := 0;
      C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
        C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := false; -- true for optional bitmap generation
      C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
      C_vgatext_bitmap_fifo: boolean := false; -- disable bitmap FIFO
        C_vgatext_bitmap_fifo_timeout: integer := 0; -- abort compositing at N pixels before end of line (0 disabled)
        C_vgatext_bitmap_fifo_step: integer := 640; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_height: integer := 480; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_addr_width: integer := 11; -- bitmap width of FIFO address space length = 2^width * 4 byte
        C_vgatext_bitmap_fifo_data_width: integer := 8; -- data width from the fifo

    C_pcm: boolean := false;
    C_synth: boolean := false;
      C_synth_zero_cross: boolean := false; -- volume changes at zero-cross, spend 1 BRAM to remove clicks
      C_synth_amplify: integer := 0; -- 0 is default for digital output. higher values may clip
      C_synth_multiplier_sign_fix: boolean := false; -- some FPGA like ECP5 need such fix
    C_dacpwm: boolean := false; -- combine 4-bit DAC with PWM to enhance resolution
    C_spdif: boolean := false; -- generate SPDIF output
    C_i2s: boolean := false; -- generate I2S output
      C_i2s_Hz: integer := 44100; -- I2S sample rate
    C_cw_simple_out: integer := -1; -- simple out bit used for CW modulation. -1 to disable
    C_fmrds: boolean := false; -- enable FM/RDS output to fm_antenna
      C_fm_stereo: boolean := false;
      C_fm_filter: boolean := false;
      C_fm_downsample: boolean := false;
      C_rds_msg_len: integer := 260; -- bytes of circular sent message, typical 52 for PS or 260 PS+RT
      C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250000000, 325000000)
      C_rds_clock_multiply: integer := 57; -- multiply 57 and divide 3125 from cpu clk 100 MHz
      C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
    C_gpio: integer range 0 to 128 := 32;
    C_gpio_pullup: boolean := false; -- XXX fixme not connected
    C_gpio_adc: integer range 0 to 6 := 6;  -- XXX fixme not connected number of gpio ports setup for ADC (FleaFPGA-Uno)
    C_pids: integer range 0 to 8 := 0; -- number of pids 0:disable, 2-8:enable
      C_pid_simulator: std_logic_vector(7 downto 0) := (others => '0'); -- for each pid choose simulator/real
      C_pid_prescaler: integer range 10 to 26 := 18; -- control loop frequency f_clk/2^prescaler
      C_pid_precision: integer range 0 to 8 := 1; -- fixed point PID precision
      C_pid_pwm_bits: integer range 11 to 32 := 12; -- PWM output frequency f_clk/2^pwmbits (min 11 => 40kHz @ 81.25MHz)
      C_pid_fp: integer range 0 to 26 := 8; -- loop frequency value for pid calculation, use 26-C_pid_prescaler
    C_timer: boolean := true;
      C_timer_ocp_mux: boolean := true; -- true: OCP to simple_out (LED) mux, fade example works, false: output to dedicated PWM ocp pins
      C_timer_ocps: integer := 2;
      C_timer_icps: integer := 2;
    C_vector: boolean := false; -- vector processor
    C_vector_burst_max_bits: integer := 6; -- AXI MIG can do 64x32-bit word burst
    C_vector_vaddr_bits: integer := 11; -- vector size, should match FPGA internal BRAM block
    C_vector_vdata_bits: integer := 32; -- don't touch, vector data bus width
    C_vector_bram_pass_thru: boolean := false; -- "false" is ok for all except altera Cyclone-V which needs "true"
    C_vector_axi: boolean := false; -- vector processor bus: true:AXI, false:f32c RAM
    C_vector_interrupt: boolean := false; -- library can work without it. Enabling interrupt may produce routing and timing problems
    C_vector_registers: integer := 8; -- Number of BRAM based vector registers. One register is 8K
    C_vector_float_addsub: boolean := true; -- true: have float addsub (+,-), false: without this, LUT saving
    C_vector_float_multiply: boolean := true; -- true: have float multiply (*), false: without multiply, LUT and DSP saving
    C_vector_float_divide: boolean := true -- true: have float divider (/), false: without divider, LUT and much DSP saving
);
port (
  clk: in std_logic;
  clk_pixel: in std_logic := '0'; -- VGA pixel clock 25 MHz
  clk_pixel_shift: in std_logic := '0'; -- digital video (DVID/HDMI) bit shift clock, for SDR 10x clk_pixel, for DDR 5x clk_pixel, default 0 if no digital video
  clk_fmdds: in std_logic := '0'; -- FM DDS clock (>216 MHz)
  clk_cw: in std_logic := '0'; -- CW transmitter 433.92 MHz
  clk_usbsio: in std_logic := '0'; -- usb-serial port 48 or 60 MHz
  reset: in std_logic := '0'; -- external RESET (or'd with RS232 BREAK)
  -- xdma: external DMA
  xdma_addr: in std_logic_vector(29 downto 2) := (others => '-');
  xdma_strobe: in std_logic := '0';
  xdma_write: in std_logic := '0';
  xdma_byte_sel: in std_logic_vector(3 downto 0) := (others => '1');
  xdma_data_in: in std_logic_vector(31 downto 0) := (others => '-');
  xdma_data_ready: out std_logic := '0';
  sram_a: out std_logic_vector(19 downto 0);
  sram_d: inout std_logic_vector(15 downto 0);
  sram_wel, sram_lbl, sram_ubl: out std_logic;
  -- sram_oel: out std_logic; -- XXX the old ULXP2 board needs this!
  sdram_addr: out std_logic_vector(12 downto 0);
  sdram_data: inout std_logic_vector(31 downto 0);
  sdram_ba: out std_logic_vector(1 downto 0);
  sdram_dqm: out std_logic_vector(3 downto 0) := (others => '1');
  sdram_ras, sdram_cas: out std_logic;
  sdram_cke, sdram_clk: out std_logic;
  sdram_we, sdram_cs: out std_logic;
  -- axi cache ram (shared signaling with sdram)
  acram_en: out std_logic;
  acram_addr: out std_logic_vector(29 downto 2);
  acram_ready: in std_logic := '1';
  acram_data_rd: in std_logic_vector(31 downto 0) := (others => '0');
  acram_data_wr: out std_logic_vector(31 downto 0);
  acram_byte_we: out std_logic_vector(3 downto 0);
  -- AXI Master for CPU and VIDEO
  cpu_axi_in: in T_axi_miso := C_axi_miso_0;
  cpu_axi_out: out T_axi_mosi;
  -- video axi is currently used only when C_vgahdmi = true and C_vgahdmi_axi = true
  video_axi_aresetn: in std_logic := '1';
  video_axi_aclk: in std_logic := '0';
  video_axi_in: in T_axi_miso := C_axi_miso_0;
  video_axi_out: out T_axi_mosi;
  -- vector processor AXI
  vector_axi_in: in T_axi_miso := C_axi_miso_0;
  vector_axi_out: out T_axi_mosi;
  --
  sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
  sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
  usbsio_diff_dp: inout std_logic_vector(C_sio - 1 downto 0); -- used as IN only, INOUT avoids error when unused
  usbsio_dp, usbsio_dn: inout std_logic_vector(C_sio - 1 downto 0);
  spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
  spi_miso: in std_logic_vector(C_spi - 1 downto 0) := (others => '-');
  simple_in: in std_logic_vector(31 downto 0);
  simple_out: out std_logic_vector(31 downto 0);
  pid_encoder_a, pid_encoder_b: in  std_logic_vector(C_pids-1 downto 0) := (others => '-');
  pid_bridge_f,  pid_bridge_r:  out std_logic_vector(C_pids-1 downto 0);
  vga_hsync, vga_vsync, vga_blank: out std_logic;
  vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0) := (others => '0'); -- parallel VGA
  vga_serial_rgb: out std_logic_vector(7 downto 0) := (others => '0'); -- each 8-bit R,G,B is sent durinig one of 3 clock cycles
  dvi_r, dvi_g, dvi_b: out std_logic_vector(9 downto 0) := (others => '0'); -- parallel DVI
  dvid_red, dvid_green, dvid_blue, dvid_clock: out std_logic_vector(1 downto 0);
  video_base_addr: out std_logic_vector(31 downto 2) := (others => '0'); -- video base address
  ledstrip_rotation: in std_logic := '0'; -- input from motor rotation encoder
  ledstrip_out: out std_logic_vector(1 downto 0); -- 2 channels out
  audio_l, audio_r, video_composite: out std_logic_vector(3 downto 0); -- 3.5mm phone jack, new naming of 4-bit simple DAC
  spdif_out: out std_logic; -- spdif output digital audio
  i2s_din, i2s_bck, i2s_lrck: out std_logic; -- i2s output digital audio
  fm_antenna, cw_antenna: out std_logic;
  gpio: inout std_logic_vector(127 downto 0);
  gpio_pullup: inout std_logic_vector(127 downto 0);  -- XXX fixme not connected optional (set C_gpio_pullup false)
  -- timer PWM input capture and output compare
  ocp: out std_logic_vector(C_timer_ocps-1 downto 0);
  icp: in std_logic_vector(C_timer_icps-1 downto 0) := (others => '0');
  --ADC ports
  ADC_Error_out: inout std_logic_vector(5 downto 0); -- XXX fixme not connected
  -- PS/2 Keyboard
  ps2_clk_in: in std_logic := '0'; -- XXX fixme not connected
  ps2_dat_in: in std_logic := '0';
  ps2_clk_out: out std_logic;
  ps2_dat_out: out std_logic
);
end glue_xram;

architecture Behavioral of glue_xram is
    signal imem_addr: std_logic_vector(31 downto 2);
    signal S_imem_addr_in_xram: std_logic;
    signal imem_addr_strobe, imem_data_ready, dmem_bram_enable: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal S_dmem_addr_in_xram: std_logic;
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal cpu_to_dmem: std_logic_vector(31 downto 0);
    signal final_to_cpu_i, final_to_cpu_d: std_logic_vector(31 downto 0);
    signal bram_d_to_cpu, bram_i_to_cpu: std_logic_vector(31 downto 0);
    signal bram_i_ready, bram_d_ready: std_logic;
    signal io_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);
    signal intr: std_logic_vector(5 downto 0); -- interrupt
    signal S_reset: std_logic;

    -- SDRAM
    signal to_xram: sram_port_array;
    signal xram_ready: sram_ready_array;
    signal from_xram: std_logic_vector(31 downto 0);
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);
    constant instr_port: integer := 0;
    constant data_port: integer := 1;
    constant fb_port: integer := 2;
    constant fb_text_port: integer := 3;
    -- currently either text mode or refresh can be enabled, not both
    -- port number is the same as fb_text port because textmode is
    -- not yet working on ULX2S
    constant refresh_port: integer := 3;
    constant vector_port: integer := 3;
    constant pcm_port: integer := 4;
    constant C_xram_ports: integer := 5;

    -- io base
    type T_iomap_range is array(0 to 1) of std_logic_vector(15 downto 0);
    constant iomap_range: T_iomap_range := (x"F800", x"FFFF"); -- actual range is 0xFFFFF800 .. 0xFFFFFFFF

    function iomap_from(r: T_iomap_range; base: T_iomap_range) return integer is
      variable a, b: std_logic_vector(15 downto 0);
    begin
        a := r(0);
        b := base(0);
        return conv_integer(a(11 downto 4) - b(11 downto 4));
    end iomap_from;

    function iomap_to(r: T_iomap_range; base: T_iomap_range) return integer is
      variable a, b: std_logic_vector(15 downto 0);
    begin
        a := r(1);
        b := base(0);
        return conv_integer(a(11 downto 4) - b(11 downto 4));
    end iomap_to;

    -- calculates compositing2 fifo_addr_width (in bits) suitable
    -- for given horizontal resolution
    function compositing2_line_width(x_resolution: integer) return integer is
    begin
      if x_resolution < 1024 then
        return 11;
      else
        return 12;
      end if;
    end;

    -- Timer
    constant iomap_timer: T_iomap_range := (x"F900", x"F93F");
    signal timer_range: std_logic := '0';
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal S_ocp, ocp_enable, ocp_mux: std_logic_vector(C_timer_ocps-1 downto 0);
    signal icp_enable: std_logic_vector(C_timer_icps-1 downto 0);
    signal timer_intr: std_logic := '0';

    -- TV video
    -- C_fb_base_addr_disabled intializer having
    -- MSB bit different than C_xram_base  because we
    -- want to start with test screen by default for any C_xram_base
    signal R_fb_base_addr: std_logic_vector(31 downto 2) := not C_xram_base(31) &
      "-----------------------------"; -- rest of 29 bits can have any value
    signal R_fb_intr: std_logic;
    signal S_tv_dac: std_logic_vector(3 downto 0);
    signal S_tv_fetch_next: std_logic;
    signal S_tv_vsync: std_logic;
    signal S_tv_mode: std_logic_vector(1 downto 0) := "10";

    -- VGA/HDMI video
    constant iomap_vga: T_iomap_range := (x"FB90", x"FB9F");
    signal vga_ce: std_logic; -- '1' when address is in iomap_vga range
    signal S_video_data_clk: std_logic; -- switched cpu clk or axi clk
    signal S_vga_enable: std_logic;
    signal S_vga_active_enabled: std_logic;
    signal vga_fetch_next, S_vga_fetch_enabled: std_logic; -- video module requests next data from fifo
    signal vga_line_repeat: std_logic;
    signal vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_data_r, vga_data_g, vga_data_b: std_logic_vector(7 downto 0);
    -- VGA RAM port
    signal vga_addr: std_logic_vector(29 downto 2);
    signal vga_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_data_ready: std_logic; -- RAM responds to FIFO
    signal vga_data: std_logic_vector(31 downto 0);
    signal vga_suggest_burst: std_logic_vector(7 downto 0) := (others => '0');
    -- Video FIFO data bus
    signal video_fifo_suggest_cache: std_logic := '0';
    signal video_fifo_suggest_burst: std_logic_vector(7 downto 0) := (others => '0');
    signal video_fifo_addr: std_logic_vector(29 downto 2);
    signal video_fifo_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal video_fifo_data_ready: std_logic; -- RAM responds to FIFO
    signal video_fifo_data: std_logic_vector(31 downto 0);
    signal video_fifo_read_ready: std_logic := '1';

    signal video_bram_write: std_logic;
    signal video_bram_addr_strobe: std_logic;
    signal S_vga_r, S_vga_g, S_vga_b: std_logic_vector(7 downto 0);
    signal S_vga_vsync, S_vga_hsync: std_logic;
    signal S_vga_vblank, S_vga_blank: std_logic;
    signal vga_frame: std_logic; -- fifo outputs signal for frame interrupt


    constant iomap_ledstrip: T_iomap_range := (x"FB90", x"FB9F");
    signal ledstrip_ce: std_logic;
    signal S_ledstrip_active: std_logic;
    signal S_ledstrip_pixel_data: std_logic_vector(23 downto 0) := (others => '0');
    signal S_ledstrip_counter, S_ledstrip_counter2: std_logic_vector(23 downto 0);
    signal S_ledstrip_line, S_ledstrip_bit: std_logic_vector(15 downto 0);
    signal S_ledstrip_out: std_logic;
    signal S_ledstrip_wraparound: std_logic;
    signal R_ledstrip_wraparound_shift: std_logic_vector(2 downto 0);
    signal R_ledstrip_capture: std_logic_vector(31 downto 0);
    signal from_ledstrip: std_logic_vector(31 downto 0);

    -- VGA_textmode VGA/HDMI video (text and font in BRAM, bitmap in sdram)
    constant iomap_vga_textmode: T_iomap_range := (x"FB80", x"FB9F");
    signal vga_textmode_ce: std_logic;
    signal from_vga_textmode: std_logic_vector(31 downto 0);
    signal vga_textmode_red: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_green: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_blue: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_hsync: std_logic;
    signal vga_textmode_vsync: std_logic;
    signal vga_textmode_blank: std_logic;

    -- VGA_textmode BRAM access
    signal vga_textmode_dmem_write: std_logic;
    signal vga_textmode_dmem_to_cpu: std_logic_vector(31 downto 0);
    signal vga_textmode_bram_addr: std_logic_vector(15 downto 2);
    signal vga_textmode_bram_data_in: std_logic_vector(31 downto 0);
    signal vga_textmode_bram_data: std_logic_vector(31 downto 0);
    signal vga_textmode_bram8_data: std_logic_vector(7 downto 0);
    signal vga_textmode_dmem8_write: std_logic;

    -- VGA_textmode SRAM/FIFO text access
    signal vga_textmode_text_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_data: std_logic_vector(31 downto 0);
    signal vga_textmode_text_strobe: std_logic;
    signal vga_textmode_text_rewind: std_logic;
    signal vga_textmode_text_ready: std_logic; -- SDRAM data ready
    signal vga_textmode_text_sdram_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_sdram_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_textmode_text_sdram_ready: std_logic; -- RAM responds to FIFO
    signal vga_textmode_text_active: std_logic; -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_text_frame: std_logic;

    -- VGA_textmode SRAM/FIFO bitmap access
    signal vga_textmode_bitmap_addr: std_logic_vector(29 downto 2); -- FIFO start or SRAM address
    signal vga_textmode_bitmap_data: std_logic_vector(C_vgatext_bitmap_fifo_data_width-1 downto 0); -- data from FIFO or SRAM
    signal vga_textmode_bitmap_strobe: std_logic; -- FIFO fetch next word
    signal vga_textmode_bitmap_rewind: std_logic; -- rewind FIFO
    signal vga_textmode_bitmap_ready: std_logic; -- SRAM data ready
    signal vga_textmode_bitmap_active: std_logic; -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_bitmap_frame: std_logic;

    -- VGA to DVI-D conversion in DDR mode
    signal dvid_red_ddr, dvid_green_ddr, dvid_blue_ddr, dvid_clock_ddr: std_logic_vector(1 downto 0);

    -- PCM audio
    constant iomap_pcm: T_iomap_range := (x"FBA0", x"FBAF");
    signal pcm_ce: std_logic;
    signal pcm_addr_strobe, pcm_data_ready: std_logic;
    signal pcm_addr: std_logic_vector(29 downto 2);
    signal from_pcm: std_logic_vector(31 downto 0);
    signal pwm_l, pwm_r: std_logic;
    signal pcm_bus_l, pcm_bus_r: ieee.numeric_std.signed(15 downto 0);
    signal pwm_filt_l, pwm_filt_r: std_logic;

    -- Polyphonic synth (128 tonewheel voices)
    constant iomap_synth: T_iomap_range := (x"FBB0", x"FBBF");
    signal synth_ce: std_logic;
    signal pcm_synth: ieee.numeric_std.signed(23 downto 0);
    signal dacpwm_synth: std_logic_vector(3 downto 0); -- same size as audio_l audio_r
    signal pwm_synth: std_logic;
    -- signal from_synth: std_logic_vector(31 downto 0); -- write only

    -- Global PCM 24-bit signed mono for digital output (currently only SPDIF)
    signal S_pcm_mono: ieee.numeric_std.signed(23 downto 0);
    -- Global PCM 24-bit signed stereo for digital output (currently only I2S)
    signal S_pcm_l, S_pcm_r: ieee.numeric_std.signed(23 downto 0);

    -- FM/RDS RADIO
    constant iomap_fmrds: T_iomap_range := (x"FC00", x"FC0F");
    signal from_fmrds: std_logic_vector(31 downto 0);
    signal fmrds_ce: std_logic;

    -- Vector processor
    constant iomap_vector: T_iomap_range := (x"FC20", x"FC3F");
    signal from_vector: std_logic_vector(31 downto 0);
    signal vector_ce: std_logic;
    signal vector_intr, S_vector_intr: std_logic := '0';
    signal S_vector_io_store_mode: std_logic;
    signal S_vector_io_addr: std_logic_vector(29 downto 2);
    signal S_vector_io_request: std_logic;
    signal S_vector_io_done: std_logic;
    signal S_vector_io_bram_we: std_logic;
    signal S_vector_io_bram_next: std_logic;
    signal S_vector_io_bram_addr: std_logic_vector(C_vector_vaddr_bits downto 0);
    signal S_vector_io_bram_wdata: std_logic_vector(C_vector_vdata_bits-1 downto 0);
    signal S_vector_io_bram_rdata: std_logic_vector(C_vector_vdata_bits-1 downto 0);

    -- vector to f32c ram bus port interface
    signal S_vector_ram_addr_strobe: std_logic;
    signal S_vector_ram_addr: std_logic_vector(29 downto 2);
    signal S_vector_ram_burst_len: std_logic_vector(7 downto 0) := (others => '0');
    signal S_vector_ram_we: std_logic;
    signal S_vector_ram_data_ready: std_logic;
    signal S_vector_ram_wdata: std_logic_vector(31 downto 0);
    signal S_vector_ram_rdata: std_logic_vector(31 downto 0);

    -- GPIO
    constant iomap_gpio: T_iomap_range := (x"F800", x"F87F");
    signal gpio_range: std_logic := '0';
    constant C_gpios: integer := (C_gpio+31)/32; -- number of gpio units
    type gpios_type is array (C_gpios-1 downto 0) of std_logic_vector(31 downto 0);
    signal from_gpio, gpios: gpios_type;
    signal gpio_ce: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr_joint: std_logic := '0';

    -- PID
    constant iomap_pid: T_iomap_range := (x"FD80", x"FDBF");
    constant C_pid: boolean := C_pids >= 2; -- minimum is 2 PIDs, otherwise no PID
    signal from_pid: std_logic_vector(31 downto 0);
    signal pid_ce: std_logic;
    signal pid_intr: std_logic; -- currently unused
    signal pid_bridge_f_out: std_logic_vector(C_pids-1 downto 0);
    signal pid_bridge_r_out: std_logic_vector(C_pids-1 downto 0);
    signal pid_encoder_a_out: std_logic_vector(C_pids-1 downto 0);
    signal pid_encoder_b_out: std_logic_vector(C_pids-1 downto 0);
    constant C_pids_bits: integer := integer(floor((log2(real(C_pids)+0.001))+0.5));

    -- Serial I/O (RS232)
    constant iomap_sio: T_iomap_range := (x"FB00", x"FB3F");
    signal sio_range: std_logic := '0';
    type from_sio_type is array (0 to C_sio - 1) of
      std_logic_vector(31 downto 0);
    signal from_sio: from_sio_type;
    signal sio_ce, sio_tx, sio_rx: std_logic_vector(C_sio - 1 downto 0);
    signal sio_break_internal: std_logic_vector(C_sio - 1 downto 0);

    -- SPI (on-board Flash, SD card, others...)
    constant iomap_spi: T_iomap_range := (x"FB40", x"FB7F");
    signal spi_range: std_logic := '0';
    type from_spi_type is array (0 to C_spi - 1) of
      std_logic_vector(31 downto 0);
    signal from_spi: from_spi_type;
    signal spi_ce: std_logic_vector(C_spi - 1 downto 0);

    -- Simple I/O: onboard LEDs, buttons and switches
    constant iomap_simple_in: T_iomap_range := (x"FF00", x"FF0F");
    constant iomap_simple_out: T_iomap_range := (x"FF10", x"FF1F");
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);

    -- external RAM signals (currently only used for RAM emulation)
    signal xram_request, xram_write: std_logic;
    signal xram_addr: std_logic_vector(27 downto 0);
    signal xram_byte_sel: std_logic_vector(3 downto 0);
    signal xram_data_in, xram_data_out: std_logic_vector(31 downto 0);
    signal xram_ready_next_cycle: std_logic;

    -- external SRAM refresh workaround
    signal refresh_addr: std_logic_vector(29 downto 2) := (others => '0');
    signal refresh_strobe: std_logic := '0';
    signal refresh_data_ready: std_logic;
    signal refresh_write: std_logic;
    signal refresh_byte_sel: std_logic_vector(3 downto 0) := (others => '1');
    signal refresh_data_in: std_logic_vector(31 downto 0) := (others => '-');

    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_debug: std_logic_vector(7 downto 0);
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin
    S_reset <= reset or sio_break_internal(0);

    -- f32c core
    pipeline: entity work.cache
    generic map (
      C_arch => C_arch, C_cpuid => 0, C_clk_freq => C_clk_freq,
      C_regfile_synchronous_read => C_regfile_synchronous_read,
      C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
      C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
      C_mult_enable => C_mult_enable, C_mul_acc => C_mul_acc, C_mul_reg => C_mul_reg,
      C_PC_mask => C_PC_mask,
      C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
      C_cop0_compare => C_cop0_compare,
      C_branch_prediction => C_branch_prediction,
      C_result_forwarding => C_result_forwarding,
      C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
      C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
      C_xram_base => C_xram_base, -- hacky part of address decoding in the cache
      C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits, -- +1 ? e.g. 20 bits will cache 1MB
      -- debugging only
      C_debug => C_debug
    )
    port map (
      clk => clk, reset => S_reset, intr => intr,
      imem_addr => imem_addr,
      imem_data_in => final_to_cpu_i,
      imem_addr_strobe => imem_addr_strobe,
      imem_data_ready => imem_data_ready,
      dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
      dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
      dmem_data_in => final_to_cpu_d, dmem_data_out => cpu_to_dmem,
      dmem_data_ready => dmem_data_ready,
      snoop_cycle => '0', snoop_addr => "------------------------------",
      -- debugging
      debug_in_data => sio_to_debug_data,
      debug_in_strobe => deb_sio_rx_done,
      debug_in_busy => open,
      debug_out_data => debug_to_sio_data,
      debug_out_strobe => deb_sio_tx_strobe,
      debug_out_busy => deb_sio_tx_busy,
      debug_debug => debug_debug,
      debug_active => debug_active
    );
    -- both internal bram and external RAM are cached
    -- the cache must distinguish between them so
    -- RAM base address must be passed to cache module
    -- it is not enough to only decode them here
    S_imem_addr_in_xram <= '1' when imem_addr(31 downto 28) = C_xram_base else '0';
    S_dmem_addr_in_xram <= '1' when dmem_addr(31 downto 28) = C_xram_base else '0';
    -- f32c 'standard' RAM hardcoded at 0x80000000
    -- using most significant address bit (bit 32), which is
    --S_imem_addr_in_xram <= imem_addr(31);
    --S_dmem_addr_in_xram <= dmem_addr(31);

    G_yes_mux_bram: if C_bram_size > 0 generate
    final_to_cpu_i <= from_xram when S_imem_addr_in_xram = '1' else bram_i_to_cpu;
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1'
      else vga_textmode_dmem_to_cpu when C_vgatext AND C_vgatext_bus_read AND dmem_addr(31 downto 28) = C_vgatext_bram_base -- address 0x40000000
      else from_xram when S_dmem_addr_in_xram = '1'
      else bram_d_to_cpu;
    imem_data_ready <= xram_ready(instr_port) when S_imem_addr_in_xram = '1'
      else bram_i_ready;
    dmem_data_ready <= xram_ready(data_port) when S_dmem_addr_in_xram = '1'
      else io_addr_strobe or video_bram_addr_strobe or bram_d_ready;
    end generate;
    G_no_mux_bram: if C_bram_size <= 0 generate
    final_to_cpu_i <= from_xram;
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1'
      else vga_textmode_dmem_to_cpu when C_vgatext AND C_vgatext_bus_read AND dmem_addr(31 downto 28) = C_vgatext_bram_base -- address 0x40000000
      else from_xram;
    imem_data_ready <= xram_ready(instr_port);
    dmem_data_ready <= xram_ready(data_port) when S_dmem_addr_in_xram = '1'
      else io_addr_strobe or video_bram_addr_strobe;
    end generate;

    intr <= "00" & gpio_intr_joint & (timer_intr or S_vector_intr) & from_sio(0)(8) & R_fb_intr;
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"F" -- iomap at 0xFxxxxxxx
      else '0';
    video_bram_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 28) = C_vgatext_bram_base -- default at 0x4xxxxxxx
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    
    G_xram:
    if C_sdram or C_sdram32 or C_sram or C_sram8 or C_acram or C_axiram generate
    -- port 0: instruction bus
    to_xram(instr_port).addr_strobe <= imem_addr_strobe when
      S_imem_addr_in_xram = '1' else '0';
    to_xram(instr_port).addr <= imem_addr(to_xram(instr_port).addr'high downto 2);
    to_xram(instr_port).data_in <= (others => '-');
    to_xram(instr_port).write <= '0';
    to_xram(instr_port).byte_sel <= "1111";
    -- port 1: data bus
    to_xram(data_port).addr_strobe <= dmem_addr_strobe when
      S_dmem_addr_in_xram = '1' else '0';
    to_xram(data_port).addr <= dmem_addr(to_xram(data_port).addr'high downto 2);
    to_xram(data_port).data_in <= cpu_to_dmem;
    to_xram(data_port).write <= dmem_write;
    to_xram(data_port).byte_sel <= dmem_byte_sel;
    -- port 2: VGA/HDMI video read
    G_bitmap_sram: if C_tv OR (C_vgahdmi and not C_vgahdmi_axi) OR C_ledstrip OR (C_vgatext AND C_vgatext_bitmap) generate
    to_xram(fb_port).addr_strobe <= vga_addr_strobe;
    to_xram(fb_port).addr <= vga_addr(to_xram(fb_port).addr'high downto 2);
    to_xram(fb_port).data_in <= (others => '-');
    to_xram(fb_port).burst_len <= vga_suggest_burst;
    to_xram(fb_port).write <= '0';
    to_xram(fb_port).byte_sel <= "1111"; -- 32 bits read for RGB
    vga_data_ready <= xram_ready(fb_port);
    end generate; -- G_bitmap_sdram
    -- port 3: VGA/HDMI video text+color read
    G_text_sram: if C_vgatext AND C_vgatext_text_fifo generate
    to_xram(fb_text_port).addr_strobe <= vga_textmode_text_sdram_strobe;
    to_xram(fb_text_port).addr <= vga_textmode_text_sdram_addr(to_xram(fb_text_port).addr'high downto 2);
    to_xram(fb_text_port).data_in <= (others => '-');
    to_xram(fb_text_port).write <= '0';
    to_xram(fb_text_port).byte_sel <= "1111"; -- 32 bits read for RGB
    vga_textmode_text_sdram_ready <= xram_ready(fb_text_port);
    end generate;
    G_refresh_port: if C_sram_refresh or C_xdma generate
    to_xram(refresh_port).addr_strobe <= refresh_strobe;
    to_xram(refresh_port).addr <= refresh_addr;
    to_xram(refresh_port).data_in <= refresh_data_in;
    to_xram(refresh_port).write <= refresh_write;
    to_xram(refresh_port).byte_sel <= refresh_byte_sel; -- refresh should set all to 32 bits read
    refresh_data_ready <= xram_ready(refresh_port);
    end generate;
    
    -- port 3: Vector FPU DMA
    G_vector_xram: if C_vector and (not C_vector_axi) generate
        to_xram(vector_port).addr_strobe <= S_vector_ram_addr_strobe;
        to_xram(vector_port).burst_len <= S_vector_ram_burst_len;
        to_xram(vector_port).write <= S_vector_ram_we;
        to_xram(vector_port).byte_sel <= "1111";
        to_xram(vector_port).addr <= S_vector_ram_addr;
        to_xram(vector_port).data_in <= S_vector_ram_wdata;
        S_vector_ram_data_ready <= xram_ready(vector_port);
    end generate;
    -- port 4: PCM audio DMA
    G_pcm_xram: if C_pcm generate
        to_xram(pcm_port).addr_strobe <= pcm_addr_strobe;
        to_xram(pcm_port).write <= '0';
        to_xram(pcm_port).byte_sel <= "1111";
        to_xram(pcm_port).addr <= pcm_addr;
        to_xram(pcm_port).data_in <= (others => '-');
        pcm_data_ready <= xram_ready(pcm_port);
    end generate;
    end generate; -- G_xram

    G_sram16bit:
    if C_sram generate
    sram: entity work.sram
    generic map (
	C_ports => C_xram_ports, -- extra ports: framebuffer, textmode and PCM audio
	C_prio_port => fb_port, -- framebuffer
	C_wait_cycles => C_sram_wait_cycles,
	C_pipelined_read => C_sram_pipelined_read
    )
    port map (
	clk => clk, sram_a => sram_a(18 downto 0), sram_d => sram_d,
	sram_wel => sram_wel, sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	data_out => from_xram,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- Multi-port connections:
	bus_in => to_xram, ready_out => xram_ready
    );
    end generate; -- G_sram16bit

    G_sram_refresh: if C_sram_refresh generate
    sram_refresh: entity work.sram_refresh
    generic map (
        C_clk_freq => C_clk_freq, -- MHz cpu clock frequency
        -- DRAM page size is apparently 512 bytes, our bus width is 4B
        C_addr_bits => 11, -- address range to refresh (pages)
        -- Refresh all 2048 pages every 32 ms, per IS42S16100E specs
        C_refresh_cycle_ms => 32 -- milliseconds
    )
    port map (
      clk => clk,
      refresh_addr => refresh_addr(19 downto 9), -- 1MB paged, 512 bytes per page
      refresh_strobe => refresh_strobe,
      refresh_data_ready => refresh_data_ready
    );
    end generate; -- G_sram_refresh

    G_xdma: if C_xdma generate
    refresh_addr <= xdma_addr;
    refresh_strobe <= xdma_strobe;
    refresh_byte_sel <= xdma_byte_sel;
    refresh_write <= xdma_write;
    refresh_data_in <= xdma_data_in;
    xdma_data_ready <= refresh_data_ready;
    end generate; -- G_xdma

    G_sram8bit:
    if C_sram8 generate
    sram8: entity work.sram8_controller
    generic map (
        C_ports => C_xram_ports, -- extra ports: framebuffer, textmode and PCM audio
        C_prio_port => fb_port, -- framebuffer
        C_wait_cycles => C_sram_wait_cycles,
        C_pipelined_read => C_sram_pipelined_read
    )
    port map (
        clk => clk,
        -- internal connections
        data_out => from_xram, bus_in => to_xram, ready_out => xram_ready,
        sram_wel => sram_wel, sram_addr => sram_a(19 downto 0), sram_data => sram_d(7 downto 0),
        snoop_cycle => snoop_cycle, snoop_addr => snoop_addr
    );
    end generate; -- G_sram8bit

    G_sdram16:
    if C_sdram generate
    -- sdram: entity work.sdram_mz_wrap  -- burst capable sdram driver, but can't cross column boundary
    sdram16: entity work.sdram
    generic map (
      C_ports => C_xram_ports,
      --C_prio_port => 2, -- VGA priority port not yet implemented
      C_ras => C_sdram_ras,
      C_cas => C_sdram_cas,
      C_pre => C_sdram_pre,
      --C_shift_read => true, -- 16->32 bit collection: true: shifter, false: multiplexer
      C_clock_range => C_sdram_clock_range, -- 1 or 2 works at 100 MHz
      sdram_address_width => C_sdram_address_width,
      sdram_column_bits => C_sdram_column_bits,
      sdram_startup_cycles => C_sdram_startup_cycles,
      cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
      clk => clk, reset => sio_break_internal(0), -- SDRAM when preloaded must not be held at reset
      -- internal connections
      data_out => from_xram, bus_in => to_xram, ready_out => xram_ready,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- external SDRAM interface
      sdram_addr => sdram_addr, sdram_data => sdram_data(15 downto 0),
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm(1 downto 0),
      sdram_ras => sdram_ras, sdram_cas => sdram_cas,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk,
      sdram_we => sdram_we, sdram_cs => sdram_cs
    );
    end generate; -- end final G_sdram16

    G_sdram32:
    if C_sdram32 generate
    sdram32: entity work.sdram32
    generic map (
      C_ports => C_xram_ports,
      --C_prio_port => 2, -- VGA priority port not yet implemented
      --C_ras => 3, -- 3 default
      --C_cas => 3, -- 3 default
      --C_pre => 3, -- 3 default
      --C_shift_read => true, -- 16->32 bit collection: true: shifter, false: multiplexer
      C_clock_range => C_sdram_clock_range, -- 1 or 2 works at 100 MHz
      sdram_address_width => C_sdram_address_width,
      sdram_column_bits => C_sdram_column_bits,
      sdram_startup_cycles => C_sdram_startup_cycles,
      cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
      clk => clk, reset => sio_break_internal(0), -- SDRAM when preloaded must not be held at reset
      -- internal connections
      data_out => from_xram, bus_in => to_xram, ready_out => xram_ready,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- external SDRAM interface
      sdram_addr => sdram_addr, sdram_data => sdram_data,
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
      sdram_ras => sdram_ras, sdram_cas => sdram_cas,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk,
      sdram_we => sdram_we, sdram_cs => sdram_cs
    );
    end generate; -- end final G_sdram32

    G_no_sdram: if not C_sdram and not C_sdram32 generate
    -- disable SDRAM, but we need to
    -- use external signals here so
    -- xilinx compiler will be happy
    sdram_addr <= (others => '-');
    sdram_data <= (others => 'Z');
    sdram_ba <= (others => '-');
    sdram_dqm <= (others => '-');
    sdram_ras <= '1';
    sdram_cas <= '1';
    sdram_cke <= '1';
    sdram_clk <= '0';
    sdram_we <= '1';
    sdram_cs <= '1';
    end generate; -- G_no_sdram

    G_acram:
    if C_acram generate
    acram: entity work.acram
    generic map (
	C_ports => C_xram_ports, -- extra ports: framebuffer, textmode and PCM audio
	C_prio_port => fb_port, -- framebuffer
	C_wait_cycles => C_acram_wait_cycles
    )
    port map (
	clk => clk,
	acram_en => acram_en,
	acram_a => acram_addr(29 downto 2),
	acram_data_rd => acram_data_rd,
	acram_data_wr => acram_data_wr,
	acram_byte_we => acram_byte_we,
	acram_ready => acram_ready,
	data_out => from_xram,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- Multi-port connections:
	bus_in => to_xram, ready_out => xram_ready
    );
    end generate; -- G_acram

    G_axiram:
    if C_axiram generate
    acram: entity work.axiram
    generic map (
      C_ports => C_xram_ports, -- extra ports: framebuffer, textmode and PCM audio
      C_prio_port => fb_port -- framebuffer
    )
    port map (
      clk => clk,
      -- axi_aresetn => not sio_break_internal(0),
      axi_in => cpu_axi_in,
      axi_out => cpu_axi_out,
      data_out => from_xram,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- Multi-port connections:
      bus_in => to_xram, ready_out => xram_ready
    );
    end generate; -- G_axiram

    -- RS232 or USB sio
    G_sio: for i in 0 to C_sio - 1 generate
        G_rs232_sio: if C_usbsio(i) = '0' generate
        rs232_sio_instance: entity work.sio
        generic map (
          C_clk_freq => C_clk_freq,
          C_init_baudrate => C_sio_init_baudrate,
          C_fixed_baudrate => C_sio_fixed_baudrate,
          C_break_detect => C_sio_break_detect,
          C_break_resets_baudrate => C_sio_break_detect,
          C_big_endian => C_big_endian
	)
        port map (
          clk => clk, ce => sio_ce(i), txd => sio_tx(i), rxd => sio_rx(i),
          bus_write => dmem_write, byte_sel => dmem_byte_sel,
          bus_in => cpu_to_dmem, bus_out => from_sio(i),
          break => sio_break_internal(i)
        );
        end generate G_rs232_sio;
        G_usb_sio: if C_usbsio(i) = '1' generate
        usb_sio_instance: entity work.usbsio
        generic map (
          C_bypass => false, -- false: normal, true: serial loopback for debug
          C_big_endian => C_big_endian
	)
        port map (
          clk => clk, ce => sio_ce(i),
          reset => '0',
          usb_clk => clk_usbsio,
          usb_diff_dp => usbsio_diff_dp(i), usb_dp => usbsio_dp(i), usb_dn => usbsio_dn(i),
          bus_write => dmem_write, byte_sel => dmem_byte_sel,
          bus_in => cpu_to_dmem, bus_out => from_sio(i),
          break => sio_break_internal(i)
        );
        end generate G_usb_sio;
        sio_ce(i) <= io_addr_strobe when io_addr(11 downto 6) = x"3" & "00" and
          conv_integer(io_addr(5 downto 4)) = i else '0';
	sio_break(i) <= sio_break_internal(i);
    end generate;
    G_sio_decoder: if C_sio > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      sio_range <= '1' when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range),
                   '0' when others;
    end generate;
    sio_rx(0) <= sio_rxd(0);

    -- SPI
    G_spi: for i in 0 to C_spi - 1 generate
        spi_instance: entity work.spi
        generic map (
          C_turbo_mode => C_spi_turbo_mode(i) = '1',
          C_fixed_speed => C_spi_fixed_speed(i) = '1'
        )
        port map (
          clk => clk, ce => spi_ce(i),
          bus_write => dmem_write, byte_sel => dmem_byte_sel,
          bus_in => cpu_to_dmem, bus_out => from_spi(i),
          spi_sck => spi_sck(i), spi_cen => spi_ss(i),
          spi_miso => spi_miso(i), spi_mosi => spi_mosi(i)
        );
        spi_ce(i) <= io_addr_strobe when io_addr(11 downto 6) = x"3" & "01" and
          conv_integer(io_addr(5 downto 4)) = i else '0';
    end generate;
    G_spi_decoder: if C_spi > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      spi_range <= '1' when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range),
                   '0' when others;
    end generate;

    --
    -- Simple I/O
    --
    process(clk)
    begin
        if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then
            -- simple out
            -- currently limted to 32 simple out bits (fixme for more)
            if C_simple_out > 0 and conv_integer(io_addr(11 downto 4)) = iomap_from(iomap_simple_out, iomap_range) then
              for i in 0 to 3 loop
                if dmem_byte_sel(i) = '1' then
                  R_simple_out(i*8+7 downto i*8) <= cpu_to_dmem(i*8+7 downto i*8);
                end if;
              end loop;
            end if;
        end if;
        if rising_edge(clk) then
            R_simple_in(C_simple_in - 1 downto 0) <=
              simple_in(C_simple_in - 1 downto 0);
        end if;
    end process;

    G_simple_out_standard:
    if not (C_timer=true and C_timer_ocp_mux=true) generate
      simple_out(C_simple_out-1 downto 0) <= R_simple_out(C_simple_out-1 downto 0);
    end generate;

    -- muxing simple_io to show PWM of timer on LEDs
    G_simple_out_timer:
    if C_timer=true and C_timer_ocp_mux=true generate
      G_ocp_mux:
      for i in 0 to C_timer_ocps-1 generate
        ocp_mux(i) <= S_ocp(i) when ocp_enable(i)='1' else R_simple_out(i);
      end generate;
      simple_out <= R_simple_out(C_simple_out-1 downto C_timer_ocps) & ocp_mux;
    end generate;

    -- big address decoder when CPU reads IO
    process(io_addr, R_simple_in, R_simple_out, from_sio, from_timer, from_gpio, from_vga_textmode)
        variable i: integer;
    begin
        io_to_cpu <= (others => '-');
        case conv_integer(io_addr(11 downto 4)) is
        when iomap_from(iomap_gpio, iomap_range) to iomap_to(iomap_gpio, iomap_range) =>
            for i in 0 to C_gpios - 1 loop
                if conv_integer(io_addr(6 downto 5)) = i then
                    io_to_cpu <= from_gpio(i);
                end if;
            end loop;
        when iomap_from(iomap_timer, iomap_range) to iomap_to(iomap_timer, iomap_range) =>
	    if C_timer then
                io_to_cpu <= from_timer;
            end if;
        when iomap_from(iomap_vector, iomap_range) to iomap_to(iomap_vector, iomap_range) =>
	    if C_vector then
                io_to_cpu <= from_vector;
            end if;
        when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range) =>
            for i in 0 to C_sio - 1 loop
                if conv_integer(io_addr(5 downto 4)) = i then
                    io_to_cpu <= from_sio(i);
                end if;
            end loop;
        when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range) =>
            for i in 0 to C_spi - 1 loop
                if conv_integer(io_addr(5 downto 4)) = i then
                    io_to_cpu <= from_spi(i);
                end if;
            end loop;
        when iomap_from(iomap_pid, iomap_range) to iomap_to(iomap_pid, iomap_range) =>
            if C_pid then
                io_to_cpu <= from_pid;
            end if;
        when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range) =>
            if C_fmrds then
                io_to_cpu <= from_fmrds;
            end if;
        when iomap_from(iomap_simple_in, iomap_range) to iomap_to(iomap_simple_in, iomap_range) =>
            for i in 0 to (C_simple_in + 31) / 32 - 1 loop
                if conv_integer(io_addr(3 downto 2)) = i then
                  io_to_cpu <= R_simple_in(32*i+31 downto 32*i);
                end if;
            end loop;
        when iomap_from(iomap_simple_out, iomap_range) to iomap_to(iomap_simple_out, iomap_range) =>
            for i in 0 to (C_simple_out + 31) / 32 - 1 loop
                if conv_integer(io_addr(3 downto 2)) = i then
                  io_to_cpu <= R_simple_out(32*i+31 downto 32*i);
                end if;
            end loop;
        -- vgahdmi, ledstrip and textmode share the same iomap addresses
        -- we can specify only one otherwise error confilict will be generated
        --when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range) =>
        --when iomap_from(iomap_ledstrip, iomap_range) to iomap_to(iomap_ledstrip, iomap_range) =>
        when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range) =>
            if C_tv then
                io_to_cpu <= (others => S_vga_vblank); -- XXX fixme sync too short, get correct blank
            end if;
            if C_vgahdmi then
                io_to_cpu <= (others => S_vga_vblank); -- vertical blank: all bits the same
            end if;
            if C_ledstrip then
                io_to_cpu <= from_ledstrip;
            end if;
            if C_vgatext then
                io_to_cpu <= from_vga_textmode;
            end if;
        when iomap_from(iomap_pcm, iomap_range) to iomap_to(iomap_pcm, iomap_range) =>
            if C_pcm then
                io_to_cpu <= from_pcm;
            else
                io_to_cpu <= (others => '-');
            end if;
        when others  =>
            io_to_cpu <= (others => '-');
        end case;
    end process;

    -- GPIO
    G_gpio:
    for i in 0 to C_gpios-1 generate
        gpio_inst: entity work.gpio
        generic map (
          C_bits => 32
        )
        port map (
          clk => clk, ce => gpio_ce(i), addr => dmem_addr(4 downto 2),
          bus_write => dmem_write, byte_sel => dmem_byte_sel,
          bus_in => cpu_to_dmem, bus_out => from_gpio(i),
          gpio_irq => gpio_intr(i),
          gpio_phys => gpio(32*i+31 downto 32*i) -- physical input/output
        );
        gpio_ce(i) <= io_addr_strobe when conv_integer(io_addr(11 downto 5)) = i else '0';
    end generate;
    G_gpio_decoder_intr: if C_gpios > 0 generate
        with conv_integer(io_addr(11 downto 4)) select
          gpio_range <= '1' when iomap_from(iomap_gpio, iomap_range) to iomap_to(iomap_gpio, iomap_range),
                        '0' when others;
        gpio_intr_joint <= gpio_intr(0);
        -- TODO: currently only 32 gpio supported in fpgarduino core
        -- when support for 128 gpio is there we should use this:
        -- gpio_intr_joint <= '0' when conv_integer(gpio_intr) = 0 else '1';
    end generate;

    -- PID
    G_pid:
    if C_pid generate
    pid_inst: entity work.pid
    generic map (
      C_pwm_bits => C_pid_pwm_bits,
      C_prescaler => C_pid_prescaler,
      C_fp => C_pid_fp,
      C_precision => C_pid_precision,
      C_simulator => C_pid_simulator,
      C_pids => C_pids,
      C_addr_unit_bits => C_pids_bits
    )
    port map (
      clk => clk, ce => pid_ce, addr => dmem_addr(C_pids_bits+3 downto 2),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_pid,
      encoder_a_in  => pid_encoder_a,
      encoder_b_in  => pid_encoder_b,
      encoder_a_out => pid_encoder_a_out,
      encoder_b_out => pid_encoder_b_out,
      bridge_f_out => pid_bridge_f_out,
      bridge_r_out => pid_bridge_r_out
    );
    with conv_integer(io_addr(11 downto 4)) select
      pid_ce <= io_addr_strobe when iomap_from(iomap_pid, iomap_range) to iomap_to(iomap_pid, iomap_range),
                           '0' when others;
    pid_bridge_f <= pid_bridge_f_out;
    pid_bridge_r <= pid_bridge_r_out;
    end generate;

    -- Timer
    G_timer:
    if C_timer generate
    -- icp <= R_simple_out(3) & R_simple_out(0); -- during debug period, leds will serve as software-generated ICP
    timer: entity work.timer
    generic map (
      C_ocps => C_timer_ocps,
      C_icps => C_timer_icps,
      C_pres => 10,
      C_bits => 12
    )
    port map (
      clk => clk, ce => timer_ce, addr => dmem_addr(5 downto 2),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_timer,
      timer_irq => timer_intr,
      ocp_enable => ocp_enable, -- enable physical output
      ocp => S_ocp, -- output compare signal
      icp_enable => icp_enable, -- enable physical input
      icp => icp -- input capture signal
    );
    ocp <= S_ocp;
    with conv_integer(io_addr(11 downto 4)) select
      timer_ce <= io_addr_strobe when iomap_from(iomap_timer, iomap_range) to iomap_to(iomap_timer, iomap_range),
                             '0' when others;
    end generate;

    -- Vector processor
    G_vector:
    if C_vector generate
      vector: entity work.vector
      generic map (
        C_vaddr_bits => C_vector_vaddr_bits, -- number of bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
        C_vdata_bits => C_vector_vdata_bits, -- number of data bits
        C_vectors => C_vector_registers,
        C_bram_pass_thru => C_vector_bram_pass_thru,
        C_float_addsub => C_vector_float_addsub,
        C_float_multiply => C_vector_float_multiply,
        C_float_divide => C_vector_float_divide
      )
      port map (
        clk => clk, ce => vector_ce, addr => dmem_addr(4 downto 2),
        -- f32c CPU interface
        bus_write => dmem_write, byte_sel => dmem_byte_sel,
        bus_in => cpu_to_dmem, bus_out => from_vector,
        -- vector I/O module interface
        io_store_mode => S_vector_io_store_mode,
        io_addr => S_vector_io_addr,
        io_request => S_vector_io_request,
        io_done => S_vector_io_done,
        io_bram_we => S_vector_io_bram_we,
        io_bram_next => S_vector_io_bram_next,
        io_bram_addr => S_vector_io_bram_addr,
        io_bram_wdata => S_vector_io_bram_wdata,
        io_bram_rdata => S_vector_io_bram_rdata,
        vector_irq => vector_intr
      );

      -- connecting interrupt will degrate signal routing and timing performance
      -- on spartan-6 LX25. Vector Library currently doesn't need it.
      -- It polls interrupt flag register
      G_connect_vector_interrupt:
      if C_vector_interrupt generate
        S_vector_intr <= vector_intr;
      end generate;

      G_vector_axi:
      if C_vector_axi generate
        I_axi_vector_dma:
        entity work.axi_vector_dma
        generic map
        (
          C_burst_max_bits => C_vector_burst_max_bits, -- number of bits that describe max burst length
          C_vaddr_bits => C_vector_vaddr_bits, -- number of bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
          C_vdata_bits => C_vector_vdata_bits  -- number of data bits
        )
        port map
        (
          clk => clk,

          -- vector processor control from mmio
          store_mode => S_vector_io_store_mode, -- '0' load (read from RAM), '1' store (write to RAM)
          addr => S_vector_io_addr, -- pointer to vector struct in RAM
          request => S_vector_io_request, -- 1-cycle pulse to start a I/O request
          done => S_vector_io_done, -- goes to 0 after accepting I/O request, returns to 1 when done

          -- bram interface
          bram_we => S_vector_io_bram_we, -- I/O module outputs we signal
          bram_next => S_vector_io_bram_next, -- I/O module outputs request to increment vector.vhd internal bram addr
          bram_addr => S_vector_io_bram_addr, -- I/O module outputs addr
          bram_wdata => S_vector_io_bram_wdata, -- I/O module outputs wdata
          bram_rdata => S_vector_io_bram_rdata, -- I/O module inputs rdata

          -- axi interface (external)
          axi_in => vector_axi_in, axi_out => vector_axi_out
        );
      end generate;

      G_vector_xram:
      if not C_vector_axi generate
        I_xram_vector_dma:
        entity work.f32c_vector_dma
        generic map
        (
          C_vaddr_bits => C_vector_vaddr_bits, -- number of bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
          C_vdata_bits => C_vector_vdata_bits  -- number of data bits
        )
        port map
        (
          clk => clk,

          -- vector processor control from mmio
          store_mode => S_vector_io_store_mode, -- '0' load (read from RAM), '1' store (write to RAM)
          addr => S_vector_io_addr, -- pointer to vector struct in RAM
          request => S_vector_io_request, -- 1-cycle pulse to start a I/O request
          done => S_vector_io_done, -- goes to 0 after accepting I/O request, returns to 1 when done

          -- bram interface
          bram_we => S_vector_io_bram_we, -- I/O module outputs we signal
          bram_next => S_vector_io_bram_next, -- I/O module outputs request to increment vector.vhd internal bram addr
          bram_addr => S_vector_io_bram_addr, -- I/O module outputs addr
          bram_wdata => S_vector_io_bram_wdata, -- I/O module outputs wdata
          bram_rdata => S_vector_io_bram_rdata, -- I/O module inputs rdata

          -- f32c interface (external)
          addr_strobe => S_vector_ram_addr_strobe,
          addr_out => S_vector_ram_addr,
          suggest_burst => S_vector_ram_burst_len(2 downto 0),
          data_ready => S_vector_ram_data_ready,
          data_write => S_vector_ram_we,
          data_in => S_vector_ram_rdata,
          data_out => S_vector_ram_wdata
        );
        S_vector_ram_rdata <= from_xram;
      end generate;

      with conv_integer(io_addr(11 downto 4)) select
        vector_ce <= io_addr_strobe when iomap_from(iomap_vector, iomap_range) to iomap_to(iomap_vector, iomap_range),
                               '0' when others;
    end generate;

    -- TV PAL composite signal generation
    G_tv: if C_tv generate
    -- data source (compositing2 fifo)
    -- misnomer warning: we use "vga" signal names although no VGA here but TV
    S_vga_enable <= '1' when R_fb_base_addr(31 downto 28) = C_xram_base else '0';
    S_vga_fetch_enabled <= S_vga_enable and vga_fetch_next; -- drain fifo into display
    S_vga_active_enabled <= S_vga_enable and not S_tv_vsync; -- frame active, pre-fill fifo
    comp_fifo: entity work.compositing2_fifo
    generic map (
      C_write_while_reading => C_compositing2_write_while_reading,
      C_width => C_tv_fifo_width,
      C_height => C_tv_fifo_height,
      C_data_width => C_tv_fifo_data_width,
      C_addr_width => C_tv_fifo_addr_width
    )
    port map (
      clk => clk,
      clk_pixel => clk,
      addr_strobe => vga_addr_strobe,
      addr_out => vga_addr,
      data_ready => vga_data_ready, -- data valid for read acknowledge from RAM
      data_in => from_xram,
      -- data_in => x"00000001", -- test pattern vertical lines
      --data_in(7 downto 0) => vga_addr(9 downto 2), -- test if address is in sync with video frame
      -- data_in(31 downto 8) => (others => '0'),
      base_addr => R_fb_base_addr(29 downto 2),
      active => S_vga_active_enabled,
      frame => vga_frame, -- output, for interrupt, 1 cpu clock pulse wide exactly
      data_out => vga_data_from_fifo(C_tv_fifo_data_width-1 downto 0),
      fetch_next => S_vga_fetch_enabled
      -- dirty hack upper bit of base enables fetching
      -- works if RAM is mapped to 0x80000000 or above
    );
    -- composite video signal generator
    S_tv_mode <= "00" when S_vga_enable='1' else "10";
    tvbitmap: entity work.tv
    port map
    (
      clk => clk,
      clk_dac => clk_pixel_shift,
      fetch_next => vga_fetch_next,
      pixel_data => vga_data_from_fifo(15 downto 0),
      mode => S_tv_mode, -- "00" is 8-bit mode, "01" is 16-bit mode, "10" is test picture
      dac_out => S_tv_dac,
      vblank => S_vga_vblank,
      vsync => S_tv_vsync -- output, 1 short pulse before every new frame
    );
    -- address decoder to set base address and clear interrupts
    with conv_integer(io_addr(11 downto 4)) select
      vga_ce <= io_addr_strobe when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range),
                           '0' when others;
    process(clk)
    begin
        if rising_edge(clk) then
            if S_reset = '1' then
              R_fb_base_addr(31) <= not C_xram_base(31);
            elsif vga_ce = '1' and dmem_write = '1' then
                -- cpu write: writes Framebuffer base
                if C_big_endian then
                   R_fb_base_addr <= -- XXX: revisit, probably wrong;
                      cpu_to_dmem(11 downto 8) &
                      cpu_to_dmem(23 downto 16) &
                      cpu_to_dmem(31 downto 26);
                else
                   R_fb_base_addr <= cpu_to_dmem(31 downto 2);
                end if;
            end if;
            -- interrupt handling: (CPU read or write will clear interrupt)
            if vga_ce = '1' then -- and dmem_write = '0' then
                R_fb_intr <= '0';
            else
                if vga_frame = '1' then -- vga_frame (should last 1 cpu clock exactly)
                    R_fb_intr <= '1';
                end if;
            end if;
        end if; -- end rising edge
    end process;
    end generate; -- C_tv

    -- for external video driver, just obtain output address
    -- this is dummy video driver
    -- todo: frame interrupt not yet supported
    G_video_base_addr_out:
    if C_video_base_addr_out generate
    -- address decoder to set base address and clear interrupts
    with conv_integer(io_addr(11 downto 4)) select
      vga_ce <= io_addr_strobe when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range),
                           '0' when others;
    process(clk)
    begin
        if rising_edge(clk) then
            if S_reset = '1' then
              R_fb_base_addr(31) <= not C_xram_base(31);
            elsif vga_ce = '1' and dmem_write = '1' then
                -- cpu write: writes Framebuffer base
                if C_big_endian then
                   R_fb_base_addr <= -- XXX: revisit, probably wrong;
                      cpu_to_dmem(11 downto 8) &
                      cpu_to_dmem(23 downto 16) &
                      cpu_to_dmem(31 downto 26);
                else
                   R_fb_base_addr <= cpu_to_dmem(31 downto 2);
                end if;
            end if;
            -- interrupt handling: (CPU read or write will clear interrupt)
            if vga_ce = '1' then -- and dmem_write = '0' then
                R_fb_intr <= '0';
            else
                if vga_frame = '1' then
                    R_fb_intr <= '1';
                end if;
            end if;
        end if; -- end rising edge
    end process;
    video_base_addr <= R_fb_base_addr;
    end generate; -- end G_video_base_addr_out

    -- VGA/HDMI
    G_vgahdmi:
    if C_vgahdmi generate
    S_vga_enable <= '1' when R_fb_base_addr(31 downto 28) = C_xram_base else '0';
    S_vga_fetch_enabled <= S_vga_enable and vga_fetch_next; -- drain fifo into display
    S_vga_active_enabled <= S_vga_enable and not S_vga_vsync; -- frame active, pre-fill fifo

    G_no_vgahdmi_axi: if not C_vgahdmi_axi generate
    -- vga_data(7 downto 0) <= vga_addr(12 downto 5);
    -- vga_data(7 downto 0) <= x"0F";
    vga_data <= from_xram;
    S_video_data_clk <= clk; -- compositing fifo must run CPU clock synchronous
    -- data source: cache cpu clock synchronous
    G_no_vgahdmi_cache: if C_vgahdmi_cache_size=0 generate
      -- bypass the cache
      vga_addr_strobe <= video_fifo_addr_strobe;
      vga_addr <= video_fifo_addr;
      vga_suggest_burst <= video_fifo_suggest_burst;
      video_fifo_data_ready <= vga_data_ready; -- data valid for read acknowledge from RAM
      video_fifo_data <= vga_data; -- from XRAM
    end generate; -- end G_no_video_cache

    G_yes_vgahdmi_cache_i: if C_vgahdmi_cache_use_i and C_vgahdmi_cache_size > 0 generate
    -- currently i-cache can't do constant streaming for video
    -- until it is fixed, use d-cache
    vgahdmi_cache_i: entity work.video_cache_i
    generic map
    (
        C_icache_size => C_vgahdmi_cache_size,
        C_cached_addr_bits => C_cached_addr_bits -- address bits of cached RAM (size=2^n) 20=1MB 25=32MB
    )
    port map
    (
      clk => clk,
      -- to external RAM
      imem_addr_strobe => vga_addr_strobe,
      imem_addr(31 downto 30) => open,
      imem_addr(29 downto 2) => vga_addr,
      imem_data_in => vga_data, -- input from XRAM
      imem_data_ready => vga_data_ready, -- input from XRAM
      -- to video FIFO
      i_addr_strobe => video_fifo_addr_strobe,
      i_cacheable => video_fifo_suggest_cache,
      i_addr(31 downto 30) => "10",
      i_addr(29 downto 2) => video_fifo_addr,
      i_ready => video_fifo_data_ready, -- output to fifo
      i_data => video_fifo_data -- output from cache to fifo
    );
    end generate; -- end G_yes_vgahdmi_cache_i

    G_yes_vgahdmi_cache_d: if (not C_vgahdmi_cache_use_i) and C_vgahdmi_cache_size > 0 generate
    vgahdmi_cache_d: entity work.video_cache_d
    generic map
    (
        C_dcache_size => C_vgahdmi_cache_size,
        C_cached_addr_bits => C_cached_addr_bits -- address bits of cached RAM (size=2^n) 20=1MB 25=32MB
    )
    port map
    (
      clk => clk,
      -- to external RAM
      dmem_addr_strobe => vga_addr_strobe,
      dmem_addr(31 downto 30) => open,
      dmem_addr(29 downto 2) => vga_addr,
      dmem_data_in => vga_data, -- input from XRAM
      dmem_data_ready => vga_data_ready, -- input from XRAM
      -- to video FIFO
      cpu_d_cacheable => video_fifo_suggest_cache,
      -- cpu_d_strobe => video_fifo_addr_strobe,
      cpu_d_strobe => '1', -- permanent strobe works better
      cpu_d_addr(31 downto 30) => "--", -- random MSB, ignored
      cpu_d_addr(29 downto 2) => video_fifo_addr,
      cpu_d_ready => video_fifo_data_ready, -- output to fifo
      cpu_d_byte_sel => "1111", -- always 32 bit fetch
      cpu_d_write => '0', -- never write
      cpu_d_data_out => (others => '-'), -- input random data
      cpu_d_data_in => video_fifo_data -- output from cache to fifo
    );
    end generate; -- end G_yes_vgahdmi_cache_d
    end generate; -- end G_no_vgahdmi_axi

    G_yes_vgahdmi_axi: if C_vgahdmi_axi generate
    S_video_data_clk <= video_axi_aclk; -- compositing fifo will run axi clock synchronous
    video_axi_read: entity work.axi_read
    port map
    (
        axi_aresetn => video_axi_aresetn,
        axi_aclk => video_axi_aclk,
        axi_in => video_axi_in,
        axi_out => video_axi_out,

        iaddr => video_fifo_addr,
        iaddr_strobe => video_fifo_addr_strobe,
        iburst => video_fifo_suggest_burst,
        odata => video_fifo_data,
        oready => video_fifo_data_ready,
        iread_ready => video_fifo_read_ready
    );
    end generate; -- end G_yes_vgahdmi_axi

    -- data source: FIFO - cross clock domain cpu-pixel
    G_vgabit_c2: if C_vgahdmi_compositing = 2 generate
    -- compositing2 video accelerator, shows linked list of pixel data
    comp_fifo: entity work.compositing2_fifo
    generic map (
      C_write_while_reading => C_compositing2_write_while_reading,
      C_fast_ram => C_vgahdmi_fifo_fast_ram,
      C_timeout => C_vgahdmi_fifo_timeout,
      C_burst_max_bits => C_vgahdmi_fifo_burst_max_bits,
      C_width => C_video_modes(C_vgahdmi_mode).visible_width,
      C_height => C_video_modes(C_vgahdmi_mode).visible_height,
      C_data_width => C_vgahdmi_fifo_data_width,
      C_addr_width => compositing2_line_width(C_video_modes(C_vgahdmi_mode).visible_width) --C_vgahdmi_fifo_addr_width
    )
    port map (
      clk => S_video_data_clk, -- cpu or axi clock synchronous
      clk_pixel => clk_pixel,
      suggest_cache => video_fifo_suggest_cache,
      suggest_burst => video_fifo_suggest_burst(C_vgahdmi_fifo_burst_max_bits-1 downto 0),
      addr_strobe => video_fifo_addr_strobe,
      addr_out => video_fifo_addr,
      read_ready => video_fifo_read_ready, -- fifo outputs '1' when ready to read data from RAM
      data_ready => video_fifo_data_ready, -- data valid for read acknowledge from RAM
      data_in => video_fifo_data, -- from cache
      -- data_in => x"00AA00AA", -- test pattern gray vertical line over whole screen
      base_addr => R_fb_base_addr(29 downto 2),
      active => S_vga_active_enabled,
      frame => vga_frame,
      data_out => vga_data_from_fifo(C_vgahdmi_fifo_data_width-1 downto 0),
      fetch_next => S_vga_fetch_enabled
    );
    end generate;

    G_vgabit_linear: if C_vgahdmi_compositing < 2 generate
      -- linear bitmap - shows linear memory block
      -- this FIFO always fetches 32-bit data
      -- todo support 8bpp and 16bpp
      video_fifo_suggest_cache <= '1';
      linear_fifo: entity work.videofifo
          generic map (
            C_bram => true,
            C_step => 0,
            C_postpone_step => 0,
            C_width => 10 -- buffer address width, size = 2^C_width x 32-bit
          )
          port map (
            clk => clk,
            clk_pixel => clk_pixel,
            addr_strobe => video_fifo_addr_strobe,
            addr_out => video_fifo_addr,
            data_ready => video_fifo_data_ready, -- data valid for read acknowledge from cache
            data_in => video_fifo_data, -- from cache
            -- data_in => x"00000001", -- test pattern vertical lines
            base_addr => R_fb_base_addr(29 downto 2),
            start => S_vga_active_enabled,
            frame => vga_frame,
            data_out => vga_data_from_fifo(31 downto 0),
            rewind => vga_line_repeat,
            fetch_next => S_vga_fetch_enabled
          );
    end generate;

    -- 8/16/32 bpp conversion into RGB-888 for display.
    -- unspported bpp values produce black screen
    -- LSB bit extended as padding improving max dynamic range
    G_vgabit_RGB_332_888: if C_vgahdmi_fifo_data_width = 8 generate
      vga_data_r <= vga_data_from_fifo(7 downto 5) & vga_data_from_fifo(7 downto 5) & vga_data_from_fifo(7 downto 6); -- red
      vga_data_g <= vga_data_from_fifo(4 downto 2) & vga_data_from_fifo(4 downto 2) & vga_data_from_fifo(4 downto 3); -- green
      vga_data_b <= vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0); -- blue
    end generate;
    G_vgabit_RGB_565_888: if C_vgahdmi_fifo_data_width = 16 generate
      vga_data_r <= vga_data_from_fifo(15 downto 11) & vga_data_from_fifo(15 downto 13); -- red
      vga_data_g <= vga_data_from_fifo(10 downto 5) & vga_data_from_fifo(10 downto 9); -- green
      vga_data_b <= vga_data_from_fifo(4 downto 0) & vga_data_from_fifo(4 downto 2); -- blue
    end generate;
    G_vgabit_RGB_888_888: if C_vgahdmi_fifo_data_width = 32 generate
      -- only 24 from 32 bits are used, 8 bits reserved for alpha channel
      vga_data_r <= vga_data_from_fifo(23 downto 16); -- red
      vga_data_g <= vga_data_from_fifo(15 downto 8); -- green
      vga_data_b <= vga_data_from_fifo(7 downto 0); -- blue
    end generate;

    -- VGA video generator - pixel clock synchronous
    vgabitmap: entity work.vga
    generic map (
      C_resolution_x => C_video_modes(C_vgahdmi_mode).visible_width,
      C_hsync_front_porch => C_video_modes(C_vgahdmi_mode).h_front_porch,
      C_hsync_pulse => C_video_modes(C_vgahdmi_mode).h_sync_pulse,
      C_hsync_back_porch => C_video_modes(C_vgahdmi_mode).h_back_porch,
      C_resolution_y => C_video_modes(C_vgahdmi_mode).visible_height,
      C_vsync_front_porch => C_video_modes(C_vgahdmi_mode).v_front_porch,
      C_vsync_pulse => C_video_modes(C_vgahdmi_mode).v_sync_pulse,
      C_vsync_back_porch => C_video_modes(C_vgahdmi_mode).v_back_porch
    )
    port map (
      clk_pixel => clk_pixel,
      test_picture => not S_vga_enable, -- shows test picture when VGA is disabled (on startup)
      fetch_next => vga_fetch_next,
      line_repeat => vga_line_repeat,
      red_byte    => vga_data_r,
      green_byte  => vga_data_g,
      blue_byte   => vga_data_b,
      vga_r => S_vga_r,
      vga_g => S_vga_g,
      vga_b => S_vga_b,
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync,
      vga_blank => S_vga_blank, -- '1' when outside of horizontal or vertical graphics area
      vga_vblank => S_vga_vblank -- '1' when outside of vertical graphics area (used for vblank interrupt)
    );
    vga_r <= S_vga_r;
    vga_g <= S_vga_g;
    vga_b <= S_vga_b;
    vga_vsync <= S_vga_vsync xor not C_video_modes(C_vgahdmi_mode).v_sync_polarity;
    vga_hsync <= S_vga_hsync xor not C_video_modes(C_vgahdmi_mode).h_sync_polarity;
    vga_blank <= S_vga_blank;

    G_vgahdmi_tmds_display: if not C_lvds_display generate
    -- DVI-D TMDS Encoder Block
    -- XXX Fixme: unify this block with vgatextmode (use same signal names)
    G_vgahdmi_dvid: entity work.vga2dvid
    generic map (
      C_shift_clock_synchronizer => C_shift_clock_synchronizer,
      C_ddr     => C_dvid_ddr,
      C_depth   => 8 -- 8bpp (8 bit per pixel)
    )
    port map (
      clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

      in_red   => S_vga_r,
      in_green => S_vga_g,
      in_blue  => S_vga_b,

      in_blank => S_vga_blank,
      in_hsync => S_vga_hsync,
      in_vsync => S_vga_vsync,

      -- parallel output DVI encoded
      outp_red   => dvi_r,
      outp_green => dvi_g,
      outp_blue  => dvi_b,

      -- single-ended output ready for differential buffers
      out_red   => dvid_red,
      out_green => dvid_green,
      out_blue  => dvid_blue,
      out_clock => dvid_clock
    );
    end generate;

    G_vgahdmi_lvds_display: if C_lvds_display generate
    -- LCD LVDS Encoder Block
    -- XXX Fixme: unify this block with vgatextmode (use same signal names)
    G_vgahdmi_lvds: entity work.vga2lcd
    generic map (
      C_shift_clock_synchronizer => C_shift_clock_synchronizer,
      C_depth => 8 -- 8bpp (8 bit per pixel)
    )
    port map (
      clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

      in_red   => S_vga_r,
      in_green => S_vga_g,
      in_blue  => S_vga_b,

      in_blank => S_vga_blank,
      in_hsync => S_vga_hsync,
      in_vsync => S_vga_vsync,

      -- single-ended output ready for differential buffers
      out_red_green  => dvid_red,
      out_green_blue => dvid_green,
      out_blue_sync  => dvid_blue,
      out_clock      => dvid_clock
    );
    end generate;

    G_vgahdmi_lcd35_display: if C_lcd35_display generate
    -- TODO: unify this block with vgatextmode (use same signal names)
    G_vgahdmi_lcd35: entity work.vga2lcd35
    generic map (
      C_depth => 8 -- 8bpp (8 bit per pixel)
    )
    port map (
      clk_pixel => clk_pixel,
      clk_shift => clk_pixel_shift,
      in_red   => S_vga_r,
      in_green => S_vga_g,
      in_blue  => S_vga_b,
      in_hsync => S_vga_hsync,
      out_rgb  => vga_serial_rgb -- 8-bit output serial R,G,B
    );
    end generate;

    -- address decoder to set base address and clear interrupts
    with conv_integer(io_addr(11 downto 4)) select
      vga_ce <= io_addr_strobe when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range),
                           '0' when others;
    process(clk)
    begin
        if rising_edge(clk) then
            if S_reset = '1' then
              R_fb_base_addr(31) <= not C_xram_base(31);
            elsif vga_ce = '1' and dmem_write = '1' then
                -- cpu write: writes Framebuffer base
                if C_big_endian then
                   R_fb_base_addr <= -- XXX: revisit, probably wrong;
                      cpu_to_dmem(11 downto 8) &
                      cpu_to_dmem(23 downto 16) &
                      cpu_to_dmem(31 downto 26);
                else
                   R_fb_base_addr <= cpu_to_dmem(31 downto 2);
                end if;
            end if;
            -- interrupt handling: (CPU read or write will clear interrupt)
            if vga_ce = '1' then -- and dmem_write = '0' then
                R_fb_intr <= '0';
            else
                if vga_frame = '1' then
                    R_fb_intr <= '1';
                end if;
            end if;
        end if; -- end rising edge
    end process;
    end generate; -- G_vgahdmi

    -- rotating LED strip POV
    G_ledstrip_module:
    if C_ledstrip generate
      -- address decoder to handle mmaped io registers
      with conv_integer(io_addr(11 downto 4)) select
        ledstrip_ce <= io_addr_strobe when iomap_from(iomap_ledstrip, iomap_range) to iomap_to(iomap_ledstrip, iomap_range),
                                  '0' when others;
      ledstrip_driver: entity work.ledstrip
      generic map (
        C_clk_Hz => C_clk_freq*1000000, -- module timing needs to know clk freq in Hz
        C_xram_base => C_xram_base,
        C_ledstrip_full_circle => C_ledstrip_full_circle, -- number of sensor pulses per full rotation
        C_width => C_ledstrip_fifo_width,
        C_height => C_ledstrip_fifo_height,
        C_data_width => C_ledstrip_fifo_data_width,
        C_addr_width => C_ledstrip_fifo_addr_width
      )
      port map (
        clk => clk,
        ce => ledstrip_ce,
        addr => dmem_addr(3 downto 2),
        bus_write => dmem_write, byte_sel => dmem_byte_sel,
        bus_in => cpu_to_dmem, bus_out => from_ledstrip,
      
        video_addr_strobe => vga_addr_strobe,
        video_addr => vga_addr,
        video_data_ready => vga_data_ready,
        from_xram => from_xram,
      
        video_frame => vga_frame,
        rotation_sensor => ledstrip_rotation,
        ledstrip_out => S_ledstrip_out
      );
      ledstrip_out <= (others => S_ledstrip_out);
      process(clk)
      begin
        -- simple interrupt handling: (any CPU read or write will clear interrupt)
        if ledstrip_ce = '1' then
          R_fb_intr <= '0';
        else
          if vga_frame = '1' then
            R_fb_intr <= '1';
          end if;
        end if;
      end process;
    end generate; -- G_ledstrip

    -- VGA textmode
    G_vgatext:
    if C_vgatext generate
      vga_video: entity work.VGA_textmode
      generic map (
        C_vgatext_mode => C_vgatext_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_text => C_vgatext_text,
        C_vgatext_font_bram8 => C_vgatext_font_bram8,
        C_vgatext_reg_read => C_vgatext_reg_read,
        C_vgatext_text_fifo => C_vgatext_text_fifo,
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
        C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
        C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo
      )
      port map (
        reset_i => S_reset,
        clk_i => clk, ce_i => vga_textmode_ce, bus_addr_i => dmem_addr(4 downto 2),
        bus_write_i => dmem_write, byte_sel_i => dmem_byte_sel,
        bus_data_i => cpu_to_dmem, bus_data_o => from_vga_textmode,

        clk_pixel_i => clk_pixel,

        bram_addr_o => vga_textmode_bram_addr,
        bram_data_i => vga_textmode_bram_data_in,
        text_active_o => vga_textmode_text_active,

        textfifo_addr_o => vga_textmode_text_addr,
        textfifo_data_i => vga_textmode_text_data,
        textfifo_strobe_o => vga_textmode_text_strobe,
        textfifo_rewind_o =>vga_textmode_text_rewind,

        bitmap_strobe_o => vga_textmode_bitmap_strobe,
        bitmap_addr_o => vga_textmode_bitmap_addr,
        bitmap_ready_i => vga_textmode_bitmap_ready,
        bitmap_data_i => vga_textmode_bitmap_data,
        bitmap_rewind_o => vga_textmode_bitmap_rewind,
        bitmap_active_o => vga_textmode_bitmap_active,

        red_o => vga_textmode_red,
        green_o => vga_textmode_green,
        blue_o => vga_textmode_blue,
        hsync_o => vga_textmode_hsync,
        vsync_o => vga_textmode_vsync,
        blank_o => vga_textmode_blank
      );

      vga_r(7 downto 8-C_vgatext_bits) <= vga_textmode_red;
      vga_g(7 downto 8-C_vgatext_bits) <= vga_textmode_green;
      vga_b(7 downto 8-C_vgatext_bits) <= vga_textmode_blue;
      vga_vsync <= vga_textmode_vsync;
      vga_hsync <= vga_textmode_hsync;

      -- video FIFO for text+color
      G_vgatext_fifo:
      if C_vgatext_text AND C_vgatext_text_fifo generate
        videofifo: entity work.videofifo
          generic map (
            C_postpone_step => C_vgatext_text_fifo_postpone_step,
            C_step => C_vgatext_text_fifo_step,
            C_width => C_vgatext_text_fifo_width -- length = 4 * 2^width
          )
          port map (
            clk => clk,
            clk_pixel => clk_pixel,
            addr_strobe => vga_textmode_text_sdram_strobe,
            addr_out => vga_textmode_text_sdram_addr,
            data_ready => vga_textmode_text_sdram_ready, -- data valid for read acknowledge from RAM
            data_in => from_xram, -- from SDRAM or BRAM
            -- data_in => x"00000001", -- test pattern vertical lines
            base_addr => vga_textmode_text_addr,
            start => vga_textmode_text_active,
            frame => vga_textmode_text_frame,
            data_out => vga_textmode_text_data,
            fetch_next => vga_textmode_text_strobe,
            rewind => vga_textmode_text_rewind
          );
      end generate; -- G_vgatext_fifo

      S_vga_enable <= '1' when vga_textmode_bitmap_addr /= 0 else '0'; -- XXX fixme apply it like on vghadmi
      S_vga_fetch_enabled <= S_vga_enable and vga_textmode_bitmap_strobe; -- drain fifo into display
      S_vga_active_enabled <= S_vga_enable and vga_textmode_bitmap_active; -- frame active, pre-fill fifo

      -- video FIFO for bitmap
      G_vgatext_bitmap_fifo:
      if C_vgatext_bitmap AND C_vgatext_bitmap_fifo generate
        bitmap_videofifo: entity work.compositing2_fifo
          generic map (
            C_write_while_reading => C_compositing2_write_while_reading,
            C_timeout => C_vgatext_bitmap_fifo_timeout,
            C_width => C_vgatext_bitmap_fifo_step,
            C_height => C_vgatext_bitmap_fifo_height,
            C_data_width => C_vgatext_bitmap_fifo_data_width,
            C_addr_width => C_vgatext_bitmap_fifo_addr_width
          )
          port map (
            clk => clk,
            clk_pixel => clk_pixel,
            addr_strobe => vga_addr_strobe,
            addr_out => vga_addr,
            data_ready => vga_data_ready, -- data valid for read acknowledge from RAM
            data_in => from_xram, -- from SDRAM or BRAM
            -- data_in => x"00000001", -- test pattern vertical lines
            base_addr => vga_textmode_bitmap_addr,
            active => S_vga_active_enabled,
            frame => vga_textmode_bitmap_frame,
            data_out => vga_textmode_bitmap_data,
            fetch_next => S_vga_fetch_enabled -- vga_textmode_bitmap_strobe
          );
      end generate; -- G_vgatext_bitmap_fifo

      -- VGA textmode BRAM (for text+attribute bytes and font)
      G_vga_textmode_bram: if C_vgatext_text and C_vgatext_bram_mem > 0 generate
        G_vgatext_bram: entity work.vga_textmode_bram
          generic map (
            C_mem_size     => C_vgatext_bram_mem,
            C_label        => C_vgatext_label,
            C_monochrome   => C_vgatext_monochrome,
            C_font_height  => C_vgatext_font_height,
            C_font_depth   => C_vgatext_font_depth
          )
          port map (
            clk => clk, imem_addr => vga_textmode_bram_addr, imem_data_out => vga_textmode_bram_data,
            dmem_write => vga_textmode_dmem_write,
            dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
            dmem_data_out => vga_textmode_dmem_to_cpu, dmem_data_in => cpu_to_dmem
          );
      end generate; -- G_vga_textmode_bram

      -- VGA textmode font BRAM (8-bit)
      G_vga_textmode_bram8: if C_vgatext_font_bram8 generate
        G_vgatext_bram8: entity work.VGA_textmode_font_bram8
          generic map (
            C_font_height => C_vgatext_font_height,
            C_font_depth  => C_vgatext_font_depth
          )
          port map (
            clk => clk, imem_addr => vga_textmode_bram_addr, imem_data_out => vga_textmode_bram8_data,
            dmem_write => vga_textmode_dmem8_write,
            dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr(15 downto 2),
            dmem_data_out => open, dmem_data_in => cpu_to_dmem(7 downto 0)
          );
      end generate; -- G_vga_textmode_bram8

      -- DVI-D Encoder Block (Thanks Hamster ;-)
      G_vgatext_tmds_display: if not C_lvds_display generate
      G_vgatext_dvid: entity work.vga2dvid
        generic map (
          C_ddr     => C_dvid_ddr,
          C_depth   => C_vgatext_bits
        )
        port map (
          clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

          in_red   => vga_textmode_red(C_vgatext_bits-1 downto 0),
          in_green => vga_textmode_green(C_vgatext_bits-1 downto 0),
          in_blue  => vga_textmode_blue(C_vgatext_bits-1 downto 0),

          in_blank => vga_textmode_blank,
          in_hsync => vga_textmode_hsync,
          in_vsync => vga_textmode_vsync,

          -- parallel output DVI encoded
          outp_red   => dvi_r,
          outp_green => dvi_g,
          outp_blue  => dvi_b,

          -- single-ended output for differential buffers
          out_red   => dvid_red,
          out_green => dvid_green,
          out_blue  => dvid_blue,
          out_clock => dvid_clock
        );
      end generate;
      G_vgatext_lvds_display: if C_lvds_display generate
      G_vgatext_lcd: entity work.vga2lcd
        generic map (
          C_depth   => C_vgatext_bits
        )
        port map (
          clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

          in_red   => vga_textmode_red(C_vgatext_bits-1 downto 0),
          in_green => vga_textmode_green(C_vgatext_bits-1 downto 0),
          in_blue  => vga_textmode_blue(C_vgatext_bits-1 downto 0),

          in_blank => vga_textmode_blank,
          in_hsync => vga_textmode_hsync,
          in_vsync => vga_textmode_vsync,

          -- single-ended output for differential buffers
          out_red_green  => dvid_red,
          out_green_blue => dvid_green,
          out_blue_sync  => dvid_blue,
          out_clock      => dvid_clock
        );
      end generate;

      vgatext_intr:
      process(clk) begin
        if rising_edge(clk) then
            if vga_textmode_ce = '1' then -- interrupt handling: (CPU read or write will clear interrupt)
              R_fb_intr <= '0';
            else
              if vga_textmode_text_frame = '1' OR vga_textmode_bitmap_frame = '1' then
                R_fb_intr <= '1';
              end if;
            end if;
        end if; -- end rising edge
      end process;

      pass_bram8_data: if C_vgatext_font_bram8 generate
        vga_textmode_bram_data_in <= vga_textmode_bram_data(31 downto 8) & vga_textmode_bram8_data;
      end generate; -- pass_bram8_data
  
      pass_bram32_data: if not C_vgatext_font_bram8 generate
        vga_textmode_bram_data_in <= vga_textmode_bram_data;
      end generate; -- pass_bram32_data

      vga_textmode_dmem_write <= dmem_addr_strobe and dmem_write
                            when dmem_addr(31 downto 28) = C_vgatext_bram_base
                             AND (NOT C_vgatext_font_bram8 OR dmem_addr(15) = '0')
                            else '0';

      G_vgatext_bram8_wr: if C_vgatext_font_bram8 generate
        vga_textmode_dmem8_write <= dmem_addr_strobe and dmem_write
                               when dmem_addr(31 downto 28) = C_vgatext_bram_base AND dmem_addr(15) = '1'
                               else '0';
      end generate; -- G_vgatext_bram8_wr

      with conv_integer(io_addr(11 downto 4)) select
        vga_textmode_ce <= io_addr_strobe when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range),
        '0' when others;

    end generate; -- G_vgatext

    --
    -- PCM audio
    --
    G_pcm:
    if C_pcm generate
    pcm: entity work.pcm
    port map (
      clk => clk, io_ce => pcm_ce, io_addr => io_addr(3 downto 2),
      io_bus_write => dmem_write, io_byte_sel => dmem_byte_sel,
      io_bus_in => cpu_to_dmem, io_bus_out => from_pcm,
      addr_strobe => pcm_addr_strobe, data_ready => pcm_data_ready,
      addr_out => pcm_addr, data_in => from_xram,
      out_pcm_l => pcm_bus_l, out_pcm_r => pcm_bus_r,
      out_r => pwm_r, out_l => pwm_l
    );
    with conv_integer(io_addr(11 downto 4)) select
      pcm_ce <= io_addr_strobe when iomap_from(iomap_pcm, iomap_range) to iomap_to(iomap_pcm, iomap_range),
                           '0' when others;
    G_yes_pcm_dacpwm: if C_dacpwm generate
      pcm_l_dacpwm: entity work.dacpwm
      generic map
      (
        C_pcm_bits => 12,
        C_dac_bits => audio_l'length
      )
      port map
      (
        clk => clk,
        pcm => std_logic_vector(pcm_bus_l(pcm_bus_l'length-1 downto pcm_bus_l'length-12)),
        dac => audio_l
      );
      pcm_r_dacpwm: entity work.dacpwm
      generic map
      (
        C_pcm_bits => 12,
        C_dac_bits => audio_r'length
      )
      port map
      (
        clk => clk,
        pcm => std_logic_vector(pcm_bus_r(pcm_bus_r'length-1 downto pcm_bus_r'length-12)),
        dac => audio_r
      );
    end generate;
    G_not_pcm_dacpwm: if not C_dacpwm generate
      audio_l <= (others => pwm_l);
      audio_r <= (others => pwm_r);
    end generate;
    end generate;
    
    G_tvout: if C_tv generate
    video_composite <= S_tv_dac;
    end generate;

    --
    -- Polyphonic Synth
    --
    G_synth:
    if C_synth generate
    synth: entity work.synth
    generic map
    (
      C_clk_freq => C_clk_freq * 1000000, -- Hz fixme with Hz-precise clock
      C_voice_vol_bits => 11,
      C_wav_data_bits => 12,
      -- C_keyboard => true, -- constant test tone (fixme: it doesn't work)
      C_multiplier_sign_fix => C_synth_multiplier_sign_fix,
      C_zero_cross => C_synth_zero_cross,
      C_amplify => C_synth_amplify
    )
    port map
    (
      clk => clk, io_ce => synth_ce, io_addr => io_addr(2 downto 2),
      io_bus_write => dmem_write, io_byte_sel => dmem_byte_sel,
      io_bus_in => cpu_to_dmem, -- io_bus_out => from_synth,
      pcm_out => pcm_synth
    );
    with conv_integer(io_addr(11 downto 4)) select
      synth_ce <= io_addr_strobe when iomap_from(iomap_synth, iomap_range) to iomap_to(iomap_synth, iomap_range),
                           '0' when others;
    G_yes_synth_dacpwm: if C_dacpwm generate
      synth_dacpwm: entity work.dacpwm
      generic map
      (
        C_pcm_bits => 12,
        C_dac_bits => dacpwm_synth'length
      )
      port map
      (
        clk => clk,
        pcm => std_logic_vector(pcm_synth(pcm_synth'length-1 downto pcm_synth'length-12)),
        dac => dacpwm_synth
      );
      audio_l <= dacpwm_synth;
      audio_r <= dacpwm_synth;
    end generate;
    G_not_synth_dacpwm: if not C_dacpwm generate
      synth_sigmadelta: entity work.sigmadelta
      generic map
      (
        C_bits => 12
      )
      port map
      (
        clk => clk,
        in_pcm => pcm_synth(pcm_synth'length-1 downto pcm_synth'length-12),
        out_pwm => pwm_synth
      );
      audio_l <= (others => pwm_synth);
      audio_r <= (others => pwm_synth);
    end generate;
    end generate;
    

    -- SPDIF digital audio output (1-channel)
    G_spdif:
    if C_spdif generate
    S_pcm_mono <= pcm_synth + pcm_bus_l + pcm_bus_r; -- global PCM mixer, warning synth is 24-bit others are 16-bit
    inst_spdif_tx: entity work.spdif_tx
    generic map
    (
      C_clk_freq => C_clk_freq * 1000000 -- Hz fixme with Hz-precise clock
    )
    port map
    (
      clk => clk,
      data_in => std_logic_vector(S_pcm_mono),
      spdif_out => spdif_out
    );
    end generate;

    -- I2S digital audio output (2-channel)
    G_i2s:
    if C_i2s generate
    S_pcm_l <= pcm_synth + pcm_bus_l; -- global PCM mixer, warning synth is 24-bit PCM is 16-bit
    S_pcm_r <= pcm_synth + pcm_bus_r; -- global PCM mixer, warning synth is 24-bit PCM is 16-bit
    inst_i2s: entity work.i2s
    generic map
    (
      clk_hz => C_clk_freq * 1000000, -- Hz fixme with Hz-precise clock
      lrck_hz => C_i2s_Hz -- Hz i2s PCM sample rate
    )
    port map
    (
      clk => clk,
      l => std_logic_vector(S_pcm_l(23 downto 8)),
      r => std_logic_vector(S_pcm_r(23 downto 8)),
      din => i2s_din, bck => i2s_bck, lrck => i2s_lrck
    );
    end generate;

    -- CW transmitter
    -- one selected simple_out enables carrier wave (CW) modulation
    -- used for carriers of higher frequency than FM DDS
    -- can produce (433 MHz)
    G_cw_antenna:
    if C_cw_simple_out >= 0 and C_simple_out > C_cw_simple_out generate
      cw_antenna <= R_simple_out(C_cw_simple_out) and clk_cw;
    end generate;

    -- FM/RDS
    G_fmrds:
    if C_fmrds generate
    fm_tx: entity work.fm
    generic map (
      c_fmdds_hz => C_fmdds_hz, -- Hz FMDDS clock frequency
      C_rds_msg_len => C_rds_msg_len, -- allocate RAM for RDS message
      C_stereo => C_fm_stereo,
      C_filter => C_fm_filter,
      C_downsample => C_fm_downsample,
      -- multiply/divide CPU clock to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide
    )
    port map (
      clk => clk, -- RDS and PCM processing clock 81.25 MHz
      clk_fmdds => clk_fmdds,
      ce => fmrds_ce, addr => dmem_addr(3 downto 2),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_fmrds,
      pcm_in_left => pcm_bus_l,
      pcm_in_right => pcm_bus_r,
      pwm_out_left => pwm_filt_l,
      pwm_out_right => pwm_filt_r,
      fm_antenna => fm_antenna
    );
    with conv_integer(io_addr(11 downto 4)) select
      fmrds_ce <= io_addr_strobe when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range),
                             '0' when others;
    end generate;


    -- Block RAM
    G_bram: if C_bram_size > 0 generate
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"0"
      else '0';
    bram: entity work.bram
    generic map (
	C_bram_size => C_bram_size,
	C_bram_const_init => C_bram_const_init,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_write_protect_bootloader => C_boot_write_protect,
	C_boot_spi => C_boot_spi
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => bram_i_to_cpu,
	imem_data_ready => bram_i_ready, dmem_data_ready => bram_d_ready,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => bram_d_to_cpu, dmem_data_in => cpu_to_dmem
    );
    end generate;

    -- Debugging SIO instance
    G_debug_sio:
    if C_debug generate
    debug_sio: entity work.sio
    generic map (
      C_clk_freq => C_clk_freq,
      C_big_endian => false
    )
    port map (
      clk => clk, ce => '1', txd => deb_tx, rxd => sio_rxd(0),
      bus_write => deb_sio_tx_strobe, byte_sel => "0001",
      bus_in(7 downto 0) => debug_to_sio_data,
      bus_in(31 downto 8) => x"000000",
      bus_out(7 downto 0) => sio_to_debug_data,
      bus_out(8) => deb_sio_rx_done, bus_out(9) => open,
      bus_out(10) => deb_sio_tx_busy, bus_out(31 downto 11) => open,
      break => open
    );
    end generate;

    sio_txd(0) <= sio_tx(0) when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;

