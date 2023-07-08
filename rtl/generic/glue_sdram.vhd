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
use IEEE.MATH_REAL.ALL;
use ieee.numeric_std.all; -- we need signed type

use work.f32c_pack.all;
use work.sram_pack.all;

entity glue_sdram is
generic (
  C_clk_freq: integer;

  -- ISA options
  C_arch: integer := ARCH_MI32;
  C_big_endian: boolean := false;
  C_mult_enable: boolean := true;
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

  -- Negatively influences timing closure, hence disabled
  C_movn_movz: boolean := false;

  -- CPU debugging
  C_debug: boolean := false;

  -- SDRAM parameters
  C_sdram_address_width : integer := 24;
  C_sdram_column_bits : integer := 9;
  C_sdram_startup_cycles : integer := 10100;
  C_sdram_cycles_per_refresh : integer := 1524;

  -- RAM emulation
  -- 0: normal SDRAM, no emulation
  -- 11:8K, 12:16K, 13:32K ... RAM emulation
  C_ram_emu_addr_width: integer := 0;
  C_ram_emu_wait_states: integer := 0;

  -- SoC configuration options
  C_bram_size: integer := 2;	-- in KBytes
  C_boot_spi: boolean := true;
  C_icache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
  C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
  C_sdram: boolean := true;
  C_sdram_base: std_logic_vector(31 downto 28) := x"8"; -- x"8" maps RAM to 0x80000000
  C_sdram_separate_arbiter: boolean := false;
  C_sio: integer := 1;
  C_sio_init_baudrate: integer := 115200;
  C_sio_fixed_baudrate: boolean := false;
  C_sio_break_detect: boolean := true;
  C_spi: integer := 0;
  C_spi_turbo_mode: std_logic_vector := "0000";
  C_spi_fixed_speed: std_logic_vector := "1111";
  C_simple_in: integer range 0 to 128 := 32;
  C_simple_out: integer range 0 to 128 := 32;
  -- VGA/HDMI simple 640x480 bitmap only
  C_vgahdmi: boolean := false; -- enable VGA/HDMI output to vga_ and tmds_
  C_vgahdmi_use_bram: boolean := false;
  C_vgahdmi_test_picture: integer := 0; -- 0: disable 1:show test picture in Red and Blue channel
  C_vgahdmi_fifo_step: integer := 4*10*17;
  C_vgahdmi_fifo_postpone_step: integer := 4*10*17-8;
  C_vgahdmi_fifo_compositing_length: integer := 17;
  C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
  C_vgahdmi_fifo_addr_width: integer := 9;
  -- Xark's feature-rich bitmap+textmode VGA
  -- it can mix 8bpp bitmap and tiled graphics on the same screen
  -- choice of many of video modes
  -- minimal mode needs only 4K BRAM
	C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
		C_vgatext_label: string := "f32c";    -- default banner in screen memory
    C_vgatext_mode: integer := 0;   -- 640x480
    C_vgatext_bits: integer := 2;   -- 64 possible colors
    C_vgatext_bram_mem: integer := 4;   -- 4KB text+font  memory
    C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- start address of textmode bram x"4" -> 0x40000000
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := false;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
      C_vgatext_font_bram8: boolean := false;  -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
      C_vgatext_char_height: integer := 16;   -- character cell height
      C_vgatext_font_height: integer := 8;    -- font height
      C_vgatext_font_depth: integer := 8;			-- font char depth, 7=128 characters or 8=256 characters
      C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
      C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
      C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
      C_vgatext_finescroll: boolean := false;   -- true for pixel level character scrolling and line length modulo
      C_vgatext_cursor: boolean := true;    -- true for optional text cursor
      C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
      C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_reg_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
      C_vgatext_text_fifo_postpone_step: integer := 0;
      C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
        C_vgatext_text_fifo_width: integer := 6; 	-- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := false;     -- true for optional bitmap generation
      C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 256-color bitmap
      C_vgatext_bitmap_fifo: boolean := false;  -- disable bitmap FIFO
        C_vgatext_bitmap_fifo_step: integer := 0; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_postpone_step: integer := 0; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_addr_width: integer := 8;	-- bitmap width of FIFO address space length = 2^width * 4 byte
        C_vgatext_bitmap_fifo_data_width: integer := 32; -- data width from the fifo
        C_vgatext_bitmap_fifo_compositing_length: integer := 0;	-- compositing length (0 disabled)
        -- compositing for typical values 9 or 17 use with step 640/4 and width 9)
        -- compositing length 9: 1 word for offset, 8 words for bitmap (thin h-sprites 32x1 of 8bpp pixels)
        -- compositing length 17: 1 word for offset, 16 words for bitmap (thin h-sprites 64x1 of 8bpp pixels)

    C_pcm: boolean := true;
    C_fmrds: boolean := false; -- enable FM/RDS output to fm_antenna
      C_fm_stereo: boolean := false;
      C_rds_msg_len: integer := 260; -- bytes of circular sent message, typical 52 for PS or 260 PS+RT
      C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250000000, 325000000)
      C_rds_clock_multiply: integer := 57; -- multiply 57 and divide 3125 from cpu clk 100 MHz
      C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
    C_gpio: integer range 0 to 128 := 32;
    C_pids: integer range 0 to 8 := 0; -- number of pids 0:disable, 2-8:enable
      C_pid_simulator: std_logic_vector(7 downto 0) := (others => '0'); -- for each pid choose simulator/real
      C_pid_prescaler: integer range 10 to 26 := 18; -- control loop frequency f_clk/2^prescaler
      C_pid_precision: integer range 0 to 8 := 1; -- fixed point PID precision
      C_pid_pwm_bits: integer range 11 to 32 := 12; -- PWM output frequency f_clk/2^pwmbits (min 11 => 40kHz @ 81.25MHz)
      C_pid_fp: integer range 0 to 26 := 8; -- loop frequency value for pid calculation, use 26-C_pid_prescaler
    C_timer: boolean := true
);
port (
  clk: in std_logic;
  clk_25MHz: in std_logic := '0'; -- VGA pixel clock 25 MHz
  clk_250MHz: in std_logic := '0'; -- HDMI bit shift clock, default 0 if no HDMI
  clk_fmdds: in std_logic := '0'; -- FM DDS clock (>216 MHz)
  sdram_addr: out std_logic_vector(12 downto 0);
  sdram_data: inout std_logic_vector(15 downto 0);
  sdram_ba: out std_logic_vector(1 downto 0);
  sdram_dqm: out std_logic_vector(1 downto 0);
  sdram_ras, sdram_cas: out std_logic;
  sdram_cke, sdram_clk: out std_logic;
  sdram_we, sdram_cs: out std_logic;
  sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
  sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
  spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
  spi_miso: in std_logic_vector(C_spi - 1 downto 0);
  simple_in: in std_logic_vector(31 downto 0);
  simple_out: out std_logic_vector(31 downto 0);
  pid_encoder_a, pid_encoder_b: in  std_logic_vector(C_pids-1 downto 0) := (others => '-');
  pid_bridge_f,  pid_bridge_r:  out std_logic_vector(C_pids-1 downto 0);
  vga_hsync, vga_vsync: out std_logic;
  vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0);
  tmds_out_rgb: out std_logic_vector(2 downto 0);
  fm_antenna, cw_antenna: out std_logic;
  gpio: inout std_logic_vector(127 downto 0)
);
end glue_sdram;

architecture Behavioral of glue_sdram is
    signal imem_addr: std_logic_vector(31 downto 2);
    signal S_imem_addr_in_xram: std_logic;
    signal imem_data_read: std_logic_vector(31 downto 0);
    signal imem_addr_strobe, imem_data_ready: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal S_dmem_addr_in_xram: std_logic;
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_bram_write, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
    signal final_to_cpu_i, final_to_cpu_d: std_logic_vector(31 downto 0);
    signal io_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);
    signal intr: std_logic_vector(5 downto 0); -- interrupt

    -- SDRAM
    signal to_sdram: sram_port_array;
    signal sdram_ready: sram_ready_array;
    signal from_sdram: std_logic_vector(31 downto 0);
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);
    constant instr_port: integer := 0;
    constant data_port: integer := 1;
    constant fb_port: integer := 2;
    constant fb_text_port: integer := 3;
    constant pcm_port: integer := 4;
    constant C_sdram_ports: integer := 5;

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

    -- Timer
    constant iomap_timer: T_iomap_range := (x"F900", x"F93F");
    signal timer_range: std_logic := '0';
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;

    -- Framebuffer
    signal R_fb_base_addr: std_logic_vector(29 downto 2);
    signal R_fb_intr: std_logic;

    -- VGA/HDMI video
    constant iomap_vga: T_iomap_range := (x"FB90", x"FB9F");
    signal vga_ce: std_logic; -- '1' when address is in iomap_vga range
    signal vga_fetch_next: std_logic; -- video module requests next data from fifo
    signal vga_addr: std_logic_vector(29 downto 2);
    signal vga_data, vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_data_bram: std_logic_vector(7 downto 0);
    signal video_bram_write: std_logic;
    signal vga_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_data_ready: std_logic; -- RAM responds to FIFO
    signal S_vga_vsync, S_vga_hsync: std_logic; -- intermediate signals for xilinx to be happy
    signal vga_frame: std_logic;

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
    signal vga_textmode_text_ready: std_logic;					-- SDRAM data ready
    signal vga_textmode_text_sdram_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_sdram_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_textmode_text_sdram_ready: std_logic; -- RAM responds to FIFO
    signal vga_textmode_text_active: std_logic;  -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_text_frame: std_logic;

    -- VGA_textmode SRAM/FIFO bitmap access
    signal vga_textmode_bitmap_addr: std_logic_vector(29 downto 2); -- FIFO start or SRAM address
    signal vga_textmode_bitmap_data: std_logic_vector(C_vgatext_bitmap_fifo_data_width-1 downto 0); -- data from FIFO or SRAM
    signal vga_textmode_bitmap_strobe: std_logic;				  -- FIFO fetch next word
    signal vga_textmode_bitmap_rewind: std_logic;         -- rewind FIFO
    signal vga_textmode_bitmap_ready: std_logic;					-- SRAM data ready
    signal vga_textmode_bitmap_active: std_logic;  -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_bitmap_frame: std_logic;

    -- PCM audio
    constant iomap_pcm: T_iomap_range := (x"FBA0", x"FBAF");
    signal pcm_ce: std_logic;
    signal pcm_addr_strobe, pcm_data_ready: std_logic;
    signal pcm_addr: std_logic_vector(29 downto 2);
    signal from_pcm: std_logic_vector(31 downto 0);
    signal pcm_l, pcm_r: std_logic;
    signal pcm_bus_l, pcm_bus_r: ieee.numeric_std.signed(15 downto 0);

    -- FM/RDS RADIO
    constant iomap_fmrds: T_iomap_range := (x"FC00", x"FC0F");
    signal from_fmrds: std_logic_vector(31 downto 0);
    signal fmrds_ce: std_logic;

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

    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    -- f32c core
    cpu: entity work.f32c_cache
    generic map (
      C_arch => C_arch, C_cpuid => 0, C_clk_freq => C_clk_freq,
      C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
      C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
      C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
      C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
      C_cop0_compare => C_cop0_compare,
      C_branch_prediction => C_branch_prediction,
      C_result_forwarding => C_result_forwarding,
      C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
      C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
      C_xram_base => C_sdram_base, -- hacky part of address decoding in the cache
      C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_sdram_address_width, -- +1 ? e.g. 20 bits will cache 1MB
      -- debugging only
      C_debug => C_debug
    )
    port map (
      clk => clk, reset => sio_break_internal(0), intr => intr,
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
      debug_active => debug_active
    );
    -- both internal bram and external RAM are cached
    -- the cache must distinguish between them so
    -- RAM base address must be passed to cache module
    -- it is not enough to only decode them here
    S_imem_addr_in_xram <= '1' when imem_addr(31 downto 28) = C_sdram_base else '0';
    S_dmem_addr_in_xram <= '1' when dmem_addr(31 downto 28) = C_sdram_base else '0';
    -- f32c 'standard' RAM hardcoded at 0x80000000
    -- using most significant address bit (bit 32), which is
    --S_imem_addr_in_xram <= imem_addr(31);
    --S_dmem_addr_in_xram <= dmem_addr(31);
    final_to_cpu_i <= from_sdram when S_imem_addr_in_xram = '1' else imem_data_read;
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1'
      else vga_textmode_dmem_to_cpu when C_vgatext AND C_vgatext_bus_read AND dmem_addr(31 downto 28) = C_vgatext_bram_base -- address 0x40000000
      else from_sdram when S_dmem_addr_in_xram = '1'
      else dmem_to_cpu;
    intr <= "00" & gpio_intr_joint & timer_intr & from_sio(0)(8) & R_fb_intr;
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"F" -- iomap at 0xFxxxxxxx
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    imem_data_ready <= sdram_ready(instr_port) when S_imem_addr_in_xram = '1'
      else imem_addr_strobe; -- MUST deassert ACK when strobe is low!!!
    dmem_data_ready <= sdram_ready(data_port) when S_dmem_addr_in_xram = '1'
      else '1'; -- I/O or BRAM have no wait states

    -- SDRAM
    G_sdram:
    if C_sdram generate
    -- port 0: instruction bus
    to_sdram(instr_port).addr_strobe <= imem_addr_strobe when
      S_imem_addr_in_xram = '1' else '0';
    to_sdram(instr_port).addr <= imem_addr(to_sdram(instr_port).addr'high downto 2);
    to_sdram(instr_port).data_in <= (others => '-');
    to_sdram(instr_port).write <= '0';
    to_sdram(instr_port).byte_sel <= "1111";
    -- port 1: data bus
    to_sdram(data_port).addr_strobe <= dmem_addr_strobe when
      S_dmem_addr_in_xram = '1' else '0';
    to_sdram(data_port).addr <= dmem_addr(to_sdram(data_port).addr'high downto 2);
    to_sdram(data_port).data_in <= cpu_to_dmem;
    to_sdram(data_port).write <= dmem_write;
    to_sdram(data_port).byte_sel <= dmem_byte_sel;
    -- port 2: VGA/HDMI video read
    G_bitmap_sram: if C_vgahdmi OR (C_vgatext AND C_vgatext_bitmap) generate
    to_sdram(fb_port).addr_strobe <= vga_addr_strobe;
    to_sdram(fb_port).addr <= vga_addr(to_sdram(fb_port).addr'high downto 2);
    to_sdram(fb_port).data_in <= (others => '-');
    to_sdram(fb_port).write <= '0';
    to_sdram(fb_port).byte_sel <= "1111"; -- 32 bits read for RGB
    vga_data_ready <= sdram_ready(fb_port);
    end generate;
    -- port 3: VGA/HDMI video text+color read
    G_text_sram: if C_vgatext AND C_vgatext_text_fifo generate
    to_sdram(fb_text_port).addr_strobe <= vga_textmode_text_sdram_strobe;
    to_sdram(fb_text_port).addr <= vga_textmode_text_sdram_addr(to_sdram(fb_text_port).addr'high downto 2);
    to_sdram(fb_text_port).data_in <= (others => '-');
    to_sdram(fb_text_port).write <= '0';
    to_sdram(fb_text_port).byte_sel <= "1111"; -- 32 bits read for RGB
    vga_textmode_text_sdram_ready <= sdram_ready(fb_text_port);
    end generate;
    -- port 4: PCM audio DMA
    G_pcm_sdram: if C_pcm generate
        to_sdram(pcm_port).addr_strobe <= pcm_addr_strobe;
        to_sdram(pcm_port).write <= '0';
        to_sdram(pcm_port).byte_sel <= "1111";
        to_sdram(pcm_port).addr <= pcm_addr;
        to_sdram(pcm_port).data_in <= (others => '-');
        pcm_data_ready <= sdram_ready(pcm_port);
    end generate;

    use_sdram: if (not C_sdram_separate_arbiter) and C_ram_emu_addr_width = 0 generate
    sdram: entity work.sdram_controller
    generic map (
      C_ports => C_sdram_ports,
      --C_prio_port => 2, -- VGA priority port not yet implemented
      --C_ras => 3,
      --C_cas => 3,
      --C_pre => 3,
      --C_clock_range => 2,
      sdram_address_width => C_sdram_address_width,
      sdram_column_bits => C_sdram_column_bits,
      sdram_startup_cycles => C_sdram_startup_cycles,
      cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
      clk => clk, reset => sio_break_internal(0),
      -- internal connections
      data_out => from_sdram, bus_in => to_sdram, ready_out => sdram_ready,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- external SDRAM interface
      sdram_addr => sdram_addr, sdram_data => sdram_data,
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
      sdram_ras => sdram_ras, sdram_cas => sdram_cas,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk,
      sdram_we => sdram_we, sdram_cs => sdram_cs
    );
    end generate; -- sdram

    use_arbiter_sdram: if C_sdram_separate_arbiter and C_ram_emu_addr_width = 0 generate
    inst_sdram_arbiter: entity work.arbiter
    generic map (
      C_ports => C_sdram_ports
    )
    port map (
      clk => clk, reset => sio_break_internal(0),
      -- internal connections
      bus_out => from_sdram, bus_in => to_sdram, ready_out => sdram_ready,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- arbiter-RAM connection
      addr_strobe => xram_request, write => xram_write,
      addr => xram_addr, byte_sel => xram_byte_sel,
      data_in => xram_data_in, data_out => xram_data_out,
      ready_next_cycle => xram_ready_next_cycle
    );
    inst_sdram: entity work.sdram_ctrl
    generic map (
      --C_ras => 3,
      --C_cas => 3,
      --C_pre => 3,
      --C_clock_range => 2,
      sdram_address_width => C_sdram_address_width,
      sdram_column_bits => C_sdram_column_bits,
      sdram_startup_cycles => C_sdram_startup_cycles,
      cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
      clk => clk, reset => sio_break_internal(0),
      -- arbiter-RAM connection
      cmd_enable => xram_request, cmd_wr => xram_write,
      cmd_address => xram_addr(C_sdram_address_width-2 downto 0),
      cmd_byte_enable => xram_byte_sel,
      cmd_data_in => xram_data_in, data_out => xram_data_out,
      ready_next_cycle => xram_ready_next_cycle,
      -- physical SDRAM interface
      sdram_addr => sdram_addr, sdram_data => sdram_data,
      sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
      sdram_ras => sdram_ras, sdram_cas => sdram_cas,
      sdram_cke => sdram_cke, sdram_clk => sdram_clk,
      sdram_we => sdram_we, sdram_cs => sdram_cs
    );
    end generate; -- end arbiter_sdram

    -- for debugging SDRAM and i-cache issues
    -- here is simple arbiter and BRAM based RAM emulation
    use_arbiter_ramemu: if C_ram_emu_addr_width > 0 generate
    inst_emu_arbiter: entity work.arbiter
    generic map (
      C_ports => C_sdram_ports
    )
    port map (
      clk => clk, reset => sio_break_internal(0),
      -- internal connections
      bus_out => from_sdram, bus_in => to_sdram, ready_out => sdram_ready,
      snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
      -- external RAM connection
      addr_strobe => xram_request, write => xram_write,
      addr => xram_addr, byte_sel => xram_byte_sel,
      data_in => xram_data_in, data_out => xram_data_out,
      ready_next_cycle => xram_ready_next_cycle
    );
    inst_ram_emu: entity work.ram_emu
    generic map (
      C_wait_states => C_ram_emu_wait_states,
      C_addr_width => C_ram_emu_addr_width
    )
    port map (
      clk => clk, reset => sio_break_internal(0),
      request => xram_request, write => xram_write,
      addr => xram_addr, byte_sel => xram_byte_sel,
      data_in => xram_data_in, data_out => xram_data_out,
      ready_next_cycle => xram_ready_next_cycle
    );
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
    end generate; -- end arbiter_ramemu
    end generate; -- end final G_sdram

    -- RS232 sio
    G_sio: for i in 0 to C_sio - 1 generate
        sio_instance: entity work.sio
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
    -- I/O
    --
    process(clk)
    begin
        if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then
            -- simple out
            if C_simple_out > 0 and io_addr(11 downto 4) = x"71" then
                if dmem_byte_sel(0) = '1' then
                    R_simple_out(7 downto 0) <= cpu_to_dmem(7 downto 0);
                end if;
                if dmem_byte_sel(1) = '1' then
                    R_simple_out(15 downto 8) <= cpu_to_dmem(15 downto 8);
		end if;
                if dmem_byte_sel(2) = '1' then
                    R_simple_out(23 downto 16) <= cpu_to_dmem(23 downto 16);
                end if;
                if dmem_byte_sel(3) = '1' then
                    R_simple_out(31 downto 24) <= cpu_to_dmem(31 downto 24);
                end if;
            end if;
        end if;
        if rising_edge(clk) then
            R_simple_in(C_simple_in - 1 downto 0) <=
              simple_in(C_simple_in - 1 downto 0);
        end if;
    end process;

    G_simple_out_standard:
    if C_timer = false generate
        simple_out(C_simple_out - 1 downto 0) <=
          R_simple_out(C_simple_out - 1 downto 0);
    end generate;
    -- muxing simple_io to show PWM of timer on LEDs
    G_simple_out_timer:
    if C_timer = true generate
      ocp_mux(0) <= ocp(0) when ocp_enable(0)='1' else R_simple_out(1);
      ocp_mux(1) <= ocp(1) when ocp_enable(1)='1' else R_simple_out(2);
      simple_out <= R_simple_out(31 downto 3) & ocp_mux & R_simple_out(0) when C_simple_out > 0
      else (others => '-');
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
            for i in 0 to (C_simple_in + 31) / 4 - 1 loop
                if conv_integer(io_addr(3 downto 2)) = i then
                    io_to_cpu(C_simple_in - i * 32 - 1 downto i * 32) <=
                      R_simple_in(C_simple_in - i * 32 - 1 downto i * 32);
                end if;
            end loop;
        when iomap_from(iomap_simple_out, iomap_range) to iomap_to(iomap_simple_out, iomap_range) =>
            for i in 0 to (C_simple_out + 31) / 4 - 1 loop
                if conv_integer(io_addr(3 downto 2)) = i then
                    io_to_cpu(C_simple_out - i * 32 - 1 downto i * 32) <=
                      R_simple_out(C_simple_out - i * 32 - 1 downto i * 32);
                end if;
            end loop;
        when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range) =>
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
    icp <= R_simple_out(3) & R_simple_out(0); -- during debug period, leds will serve as software-generated ICP
    timer: entity work.timer
    generic map (
      C_pres => 10,
      C_bits => 12
    )
    port map (
      clk => clk, ce => timer_ce, addr => dmem_addr(5 downto 2),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_timer,
      timer_irq => timer_intr,
      ocp_enable => ocp_enable, -- enable physical output
      ocp => ocp, -- output compare signal
      icp_enable => icp_enable, -- enable physical input
      icp => icp -- input capture signal
    );
    with conv_integer(io_addr(11 downto 4)) select
      timer_ce <= io_addr_strobe when iomap_from(iomap_timer, iomap_range) to iomap_to(iomap_timer, iomap_range),
                             '0' when others;
    end generate;

    -- VGA/HDMI
    G_vgahdmi:
    if C_vgahdmi generate
    vgahdmi: entity work.vgahdmi
    generic map (
      test_picture => C_vgahdmi_test_picture  -- show test picture in background
    )
    port map (
      clk_pixel => clk_25MHz,
      clk_tmds => clk_250MHz,
      fetch_next => vga_fetch_next,
      red_byte    => vga_data_from_fifo(7 downto 5) & "00000",
      green_byte  => vga_data_from_fifo(4 downto 2) & "00000",
      blue_byte   => vga_data_from_fifo(1 downto 0) & "000000",
      bright_byte => (others => '0'),
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync,
      tmds_out_rgb => tmds_out_rgb
    );
    vga_vsync <= not S_vga_vsync;
    vga_hsync <= not S_vga_hsync;
    comp_fifo: entity work.compositing_fifo
    generic map (
      C_step => C_vgahdmi_fifo_step,
      C_postpone_step => C_vgahdmi_fifo_postpone_step,
      C_compositing_length => C_vgahdmi_fifo_compositing_length,
      C_data_width => C_vgahdmi_fifo_data_width,
      C_addr_width => C_vgahdmi_fifo_addr_width
    )
    port map (
      clk => clk,
      clk_pixel => clk_25MHz,
      addr_strobe => vga_addr_strobe,
      addr_out => vga_addr,
      data_ready => vga_data_ready, -- data valid for read acknowledge from RAM
      -- data_ready => '1', -- BRAM is eveready
      data_in => vga_data, -- from SDRAM or BRAM
      -- data_in => x"00000001", -- test pattern vertical lines
      -- data_in(7 downto 0) => vga_addr(9 downto 2), -- test if address is in sync with video frame
      -- data_in(31 downto 8) => (others => '0'),
      base_addr => R_fb_base_addr,
      active => not S_vga_vsync,
      frame => vga_frame,
      data_out => vga_data_from_fifo(C_vgahdmi_fifo_data_width-1 downto 0),
      fetch_next => vga_fetch_next
    );
    -- vga_data(7 downto 0) <= vga_addr(12 downto 5);
    -- vga_data(7 downto 0) <= x"0F";
    vga_data <= from_sdram;

    -- address decoder to set base address and clear interrupts
    with conv_integer(io_addr(11 downto 4)) select
      vga_ce <= io_addr_strobe when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range),
                           '0' when others;
    process(clk)
    begin
        if rising_edge(clk) then
            if vga_ce = '1' and dmem_write = '1' then
                -- cpu write: writes Framebuffer base
                if C_big_endian then
                     -- R_fb_mode <= cpu_to_dmem(25 downto 24);
                     R_fb_base_addr <= -- XXX: revisit, probably wrong;
                      cpu_to_dmem(11 downto 8) &
                      cpu_to_dmem(23 downto 16) &
                      cpu_to_dmem(31 downto 26);
                else
                    -- R_fb_mode <= cpu_to_dmem(1 downto 0);
                    R_fb_base_addr <= cpu_to_dmem(29 downto 2);
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
        reset_i => sio_break_internal(0),
        clk_i => clk, ce_i => vga_textmode_ce, bus_addr_i => dmem_addr(4 downto 2),
        bus_write_i => dmem_write, byte_sel_i => dmem_byte_sel,
        bus_data_i => cpu_to_dmem, bus_data_o => from_vga_textmode,

        clk_pixel_i => clk_25MHz,

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
            clk_pixel => clk_25MHz,
            addr_strobe => vga_textmode_text_sdram_strobe,
            addr_out => vga_textmode_text_sdram_addr,
            data_ready => vga_textmode_text_sdram_ready, -- data valid for read acknowledge from RAM
            data_in => from_sdram, -- from SDRAM or BRAM
            -- data_in => x"00000001", -- test pattern vertical lines
            base_addr => vga_textmode_text_addr,
            start => vga_textmode_text_active,
            frame => vga_textmode_text_frame,
            data_out => vga_textmode_text_data,
            fetch_next => vga_textmode_text_strobe,
            rewind => vga_textmode_text_rewind
          );
      end generate; -- G_vgatext_fifo

      -- video FIFO for bitmap
      G_vgatext_bitmap_fifo:
      if C_vgatext_bitmap AND C_vgatext_bitmap_fifo generate
        bitmap_videofifo: entity work.compositing_fifo
          generic map (
            C_step => C_vgatext_bitmap_fifo_step,
            C_postpone_step => C_vgatext_bitmap_fifo_postpone_step,
            C_compositing_length => C_vgatext_bitmap_fifo_compositing_length,
            C_data_width => C_vgatext_bitmap_fifo_data_width,
            C_addr_width => C_vgatext_bitmap_fifo_addr_width
          )
          port map (
            clk => clk,
            clk_pixel => clk_25MHz,
            addr_strobe => vga_addr_strobe,
            addr_out => vga_addr,
            data_ready => vga_data_ready, -- data valid for read acknowledge from RAM
            data_in => from_sdram, -- from SDRAM or BRAM
            -- data_in => x"00000001", -- test pattern vertical lines
            base_addr => vga_textmode_bitmap_addr,
            active => vga_textmode_bitmap_active,
            frame => vga_textmode_bitmap_frame,
            data_out => vga_textmode_bitmap_data,
            fetch_next => vga_textmode_bitmap_strobe
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
            dmem_write => vga_textmode_dmem_write,
            dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr(15 downto 2),
            dmem_data_out => open, dmem_data_in => cpu_to_dmem(7 downto 0)
          );
      end generate; -- G_vga_textmode_bram8

      -- DVI-D Encoder Block (Thanks Hamster ;-)
      G_vgatext_dvid: entity work.dvid_out
        generic map (
          C_depth   => C_vgatext_bits
        )
        port map (
          clk_pixel => clk_25MHz,
          clk_tmds  => clk_250MHz,

          red_p     => vga_textmode_red(C_vgatext_bits-1 downto 0),
          green_p   => vga_textmode_green(C_vgatext_bits-1 downto 0),
          blue_p    => vga_textmode_blue(C_vgatext_bits-1 downto 0),

          blank     => vga_textmode_blank,
          hsync     => vga_textmode_hsync,
          vsync     => vga_textmode_vsync,

          -- outputs to TMDS drivers
          tmds_out_rgb => tmds_out_rgb
        );

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
      addr_out => pcm_addr, data_in => from_sdram,
      out_pcm_l => pcm_bus_l, out_pcm_r => pcm_bus_r,
      out_r => pcm_r, out_l => pcm_l
    );
    with conv_integer(io_addr(11 downto 4)) select
      pcm_ce <= io_addr_strobe when iomap_from(iomap_pcm, iomap_range) to iomap_to(iomap_pcm, iomap_range),
                                          '0' when others;
    end generate;


    -- FM/RDS
    G_fmrds:
    if C_fmrds generate
    fm_tx: entity work.fm
    generic map (
      c_fmdds_hz => C_fmdds_hz, -- Hz FMDDS clock frequency
      C_rds_msg_len => C_rds_msg_len, -- allocate RAM for RDS message
      C_stereo => C_fm_stereo,
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
      fm_antenna => fm_antenna
    );
    with conv_integer(io_addr(11 downto 4)) select
      fmrds_ce <= io_addr_strobe when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range),
                           '0' when others;
    end generate;


    -- Block RAM
    dmem_bram_write <=
      dmem_addr_strobe and dmem_write when dmem_addr(31 downto 28) = x"0" else '0';

    bram: entity work.bram
    generic map (
	C_bram_size => C_bram_size,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_boot_spi => C_boot_spi
    )
    port map (
      clk => clk, imem_addr => imem_addr, imem_data_out => imem_data_read,
      dmem_write => dmem_bram_write,
      dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
      dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );

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

