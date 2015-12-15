--
-- Copyright (c) 2011-2015 Marko Zec, University of Zagreb
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
use ieee.numeric_std.all; -- we need signed type
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;
use work.sram_pack.all;


entity glue_sram is
    generic (
	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff";

	-- COP0 options
	C_exceptions: boolean := true;
	C_cop0_count: boolean := true;
	C_cop0_compare: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
	C_register_technology: string := "lattice";

	-- This may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

	-- Debugging / testing options (should be turned off)
	C_debug: boolean := false;

	-- SoC configuration options
	C_cpus: integer := 1;
	C_bram_size: integer := 2;	-- 2 or 16 KBytes
	C_i_rom_only: boolean := true;
	C_icache_expire: boolean := false; -- when true i-cache will just pass data, won't keep them
	C_icache_size: integer := 8;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
	C_sram: boolean := true;
	C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
	C_pipelined_read: boolean := true; -- works only at 81.25 MHz !!!
	C_sio: boolean := true;
	C_simple_in: integer range 0 to 128 := 32;
	C_simple_out: integer range 0 to 128 := 32;
	C_gpio: boolean := true;
	C_spi: integer := 0;
	C_spi_turbo_mode: std_logic_vector := "0000";
	C_spi_fixed_speed: std_logic_vector := "1111";
	C_framebuffer: boolean := false;

        -- VGA/HDMI simple 640x480 bitmap only
        C_vgahdmi: boolean := false; -- enable VGA/HDMI output to vga_ and tmds_
        C_vgahdmi_test_picture: integer := 0; -- 0: disable 1:show test picture in Red and Blue channel
        C_vgahdmi_fifo_step: integer := 4*10*17;
        C_vgahdmi_fifo_postpone_step: integer := 4*10*17-8;
        C_vgahdmi_fifo_compositing_length: integer := 17;
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
        C_vgahdmi_fifo_addr_width: integer := 9;

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c";    -- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480
      C_vgatext_bits: integer := 2;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 4;   -- 4KB text+font  memory
      C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
      C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
      C_vgatext_palette: boolean := false;  -- no color palette
      C_vgatext_text: boolean := true;    -- enable optional text generation
        C_vgatext_char_height: integer := 16;   -- character cell height
        C_vgatext_font_height: integer := 8;    -- font height
        C_vgatext_font_depth: integer := 7;      -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := true;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := false;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
        C_vgatext_reg_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
        C_vgatext_text_fifo: boolean := false;  -- disable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 1;
          C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6;   -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := false;     -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 1;   -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := false;  -- disable bitmap FIFO
          C_vgatext_bitmap_fifo_step: integer := 0;  -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
          C_vgatext_bitmap_compositing_length: integer := 0; -- H-compositing (tiny sprites, words size, 1 pixel high)
          C_vgatext_bitmap_fifo_width: integer := 8;  -- bitmap width of FIFO address space length = 2^width * 4 byte
	C_pcm: boolean := true;
	C_timer: boolean := true;
	C_cw_simple_out: integer := -1; -- simple out bit used for CW modulation. -1 to disable
	C_fmrds: boolean := true;
	C_fm_stereo: boolean := false;
	C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
	C_fm_cw_hz: integer := 107900000; -- Hz FM station carrier wave frequency
        C_fmdds_hz: integer := 325000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        --C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
        --C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
        C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
        C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
        C_pid: boolean := true;
        C_pids: integer := 4;
        C_pid_simulator: std_logic_vector(7 downto 0) := ext("1000", 8); -- for each pid choose simulator/real 
	C_dds: boolean := true
    );
    port (
        clk: in std_logic; -- main clock CPU and I/O
	clk_25m: in std_logic := '0'; -- VGA pixel clock 25 MHz
        clk_325m: in std_logic := '0'; -- TV composite video 325 MHz
        clk_cw: in std_logic := '0'; -- CW transmitter 433.92 MHz
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
	spi_miso: in std_logic_vector(C_spi - 1 downto 0);
	vga_hsync, vga_vsync: out std_logic;
	-- vga_r, vga_g, vga_b: out std_logic_vector(C_vgatext_bits-1 downto 0);
	vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0);
	p_ring: out std_logic;
	p_tip: out std_logic_vector(3 downto 0);
	simple_out: out std_logic_vector(31 downto 0);
	simple_in: in std_logic_vector(31 downto 0);
	fm_antenna, cw_antenna: out std_logic;
	gpio: inout std_logic_vector(31 downto 0);
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
	-- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
    );
end glue_sram;

architecture Behavioral of glue_sram is
    constant C_io_ports: integer := C_cpus;

    -- types for signals going to / from f32c core(s)
    type f32c_addr_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 2);
    type f32c_byte_sel is array(0 to (C_cpus - 1)) of
      std_logic_vector(3 downto 0);
    type f32c_data_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 0);
    type f32c_std_logic is array(0 to (C_cpus - 1)) of std_logic;
    type f32c_intr is array(0 to (C_cpus - 1)) of std_logic_vector(5 downto 0);
    type f32c_debug_addr is array(0 to (C_cpus - 1)) of
      std_logic_vector(5 downto 0);

    -- signals to / from f32c cores(s)
    signal res: f32c_std_logic;
    signal intr: f32c_intr;
    signal imem_addr, dmem_addr: f32c_addr_bus;
    signal final_to_cpu_i, final_to_cpu_d, cpu_to_dmem: f32c_data_bus;
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: f32c_std_logic;
    signal imem_data_ready, dmem_data_ready: f32c_std_logic;
    signal dmem_byte_sel: f32c_byte_sel;

    -- SRAM
    signal to_sram: sram_port_array;
    signal sram_ready: sram_ready_array;
    signal from_sram: std_logic_vector(31 downto 0);
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);

    -- Block RAM
    signal bram_i_to_cpu, bram_d_to_cpu: std_logic_vector(31 downto 0);
    signal bram_i_ready, bram_d_ready, dmem_bram_enable: std_logic;

    -- I/O
    signal io_write: std_logic;
    signal io_byte_sel: std_logic_vector(3 downto 0);
    signal io_addr: std_logic_vector(11 downto 2);
    signal cpu_to_io, io_to_cpu: std_logic_vector(31 downto 0);
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_txd, sio_ce, sio_break: std_logic;
    signal io_addr_strobe: std_logic_vector((C_io_ports - 1) downto 0);
    signal next_io_port: integer range 0 to (C_io_ports - 1);
    signal R_cur_io_port: integer range 0 to (C_io_ports - 1);
    signal R_fb_mode: std_logic_vector(1 downto 0) := "11";
    signal R_fb_base_addr: std_logic_vector(29 downto 2) := (others => '0');
    
    signal Rblink: std_logic_vector(31 downto 0);

    -- CPU reset control
    signal R_cpu_reset: std_logic_vector(15 downto 0) := x"fffe";

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

    -- Video framebuffer
    signal R_fb_intr: std_logic;
    signal video_dac: std_logic_vector(3 downto 0);
    signal fb_addr_strobe, fb_data_ready: std_logic;
    signal fb_addr: std_logic_vector(29 downto 2);
    signal fb_tick: std_logic;

    -- VGA/HDMI video
    constant iomap_vga: T_iomap_range := (x"FB80", x"FB8F"); -- VGA/HDMI should be (x"FB90", x"FB9F")
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
    signal vga_textmode_intr: std_logic;
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
    signal vga_textmode_bram_data: std_logic_vector(31 downto 0);

    -- VGA_textmode SRAM/FIFO text access
    signal vga_textmode_text_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_data: std_logic_vector(31 downto 0);
    signal vga_textmode_text_strobe: std_logic;
    signal vga_textmode_text_rewind: std_logic;
    signal vga_textmode_text_ready: std_logic;          -- SDRAM data ready
    signal vga_textmode_text_sram_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_sram_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_textmode_text_sram_ready: std_logic; -- RAM responds to FIFO
    signal vga_textmode_text_active: std_logic;  -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_text_frame: std_logic;

    -- VGA_textmode SRAM/FIFO bitmap access
    signal vga_textmode_bitmap_addr: std_logic_vector(29 downto 2); -- FIFO start or SRAM address
    signal vga_textmode_bitmap_data: std_logic_vector(31 downto 0); -- data from FIFO or SRAM
    signal vga_textmode_bitmap_strobe: std_logic;         -- FIFO fetch next word
    signal vga_textmode_bitmap_rewind: std_logic;         -- rewind FIFO
    signal vga_textmode_bitmap_ready: std_logic;          -- SRAM data ready
    signal vga_textmode_bitmap_sram_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_bitmap_sram_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_textmode_bitmap_sram_ready: std_logic; -- RAM responds to FIFO
    signal vga_textmode_bitmap_active: std_logic;  -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_bitmap_frame: std_logic;

    -- PCM audio
    constant iomap_pcm: T_iomap_range := (x"FBA0", x"FBAF");
    signal pcm_ce: std_logic;
    signal pcm_addr_strobe, pcm_data_ready: std_logic;
    signal pcm_addr: std_logic_vector(29 downto 2);
    signal from_pcm: std_logic_vector(31 downto 0);
    signal pcm_l, pcm_r: std_logic;
    signal pcm_bus_l, pcm_bus_r: signed(15 downto 0);

    -- FM/RDS RADIO
    constant iomap_fmrds: T_iomap_range := (x"FC00", x"FC0F");
    signal fmrds_ce: std_logic;
    signal from_fmrds: std_logic_vector(31 downto 0); -- current address

    -- DDS frequency synthesizer
    signal R_dds, R_dds_fast, R_dds_acc: std_logic_vector(31 downto 0);
    signal R_dds_enable: std_logic;

    -- Simple I/O: onboard LEDs, buttons and switches
    constant iomap_simple_in: T_iomap_range := (x"FF00", x"FF0F");
    constant iomap_simple_out: T_iomap_range := (x"FF10", x"FF1F");
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);

    -- serial I/O (RS232)
    constant iomap_sio: T_iomap_range := (x"FB00", x"FB3F");
    signal sio_range: std_logic := '0';

    -- SPI (on-board Flash, SD card, others...)
    constant iomap_spi: T_iomap_range := (x"FB40", x"FB7F");
    signal spi_range: std_logic := '0';
    type from_spi_type is array (0 to C_spi - 1) of
      std_logic_vector(31 downto 0);
    signal from_spi: from_spi_type;
    signal spi_ce: std_logic_vector(C_spi - 1 downto 0);

    -- GPIO
    constant iomap_gpio: T_iomap_range := (x"F800", x"F87F");
    signal gpio_range: std_logic := '0';
    signal from_gpio: std_logic_vector(31 downto 0);
    signal gpio_ce: std_logic;
    signal gpio_intr: std_logic;
    -- gpio-pid multifunction shared pins
    signal gpio_pid: std_logic_vector(11+16 downto 16);

    -- Timer
    constant iomap_timer: T_iomap_range := (x"F900", x"F93F");
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;
    
    -- PID
    constant iomap_pid: T_iomap_range := (x"FD80", x"FDBF");
    signal from_pid: std_logic_vector(31 downto 0);
    signal pid_ce: std_logic;
    signal pid_intr: std_logic; -- currently unused
    signal pid_bridge_f: std_logic_vector(C_pids-1 downto 0);
    signal pid_bridge_r: std_logic_vector(C_pids-1 downto 0);
    signal pid_encoder_a: std_logic_vector(C_pids-1 downto 0);
    signal pid_encoder_b: std_logic_vector(C_pids-1 downto 0);
    signal pid_simple_out: std_logic_vector(3 downto 0); -- show on LEDs
    constant C_pids_bits: integer := integer(floor((log2(real(C_pids)))+0.5));

    -- debugging only
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_debug: std_logic_vector(7 downto 0);
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin


    --
    -- f32c core(s)
    --
    G_CPU: for i in 0 to (C_cpus - 1) generate
    begin
    intr(i) <= "00" & gpio_intr & timer_intr & from_sio(8) & R_fb_intr
      when i = 0 else "000000";
    res(i) <= R_cpu_reset(i);
    cpu: entity work.cache
    generic map (
	C_arch => C_arch, C_cpuid => i, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_register_technology => C_register_technology,
	C_cop0_count => C_cop0_count, C_cop0_compare => C_cop0_compare,
	C_cop0_config => C_cop0_config, C_exceptions => C_exceptions,
	C_ll_sc => C_ll_sc,
	C_icache_expire => C_icache_expire,
	C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => res(i), intr => intr(i),
	imem_addr => imem_addr(i), imem_data_in => final_to_cpu_i(i),
	imem_addr_strobe => imem_addr_strobe(i),
	imem_data_ready => imem_data_ready(i),
	dmem_addr_strobe => dmem_addr_strobe(i),
	dmem_addr => dmem_addr(i),
	dmem_write => dmem_write(i), dmem_byte_sel => dmem_byte_sel(i),
	dmem_data_in => final_to_cpu_d(i), dmem_data_out => cpu_to_dmem(i),
	dmem_data_ready => dmem_data_ready(i),
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
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
    end generate;

    --
    -- RS232 sio
    --
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => rs232_rx,
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_sio, break => sio_break
    );
    sio_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"30" else '0';
    end generate;

    --
    -- On-board SPI flash and sdcard
    --
    -- SPI
    G_spi: for i in 0 to C_spi - 1 generate
	spi_instance: entity work.spi
	generic map (
	    C_turbo_mode => C_spi_turbo_mode(i) = '1',
	    C_fixed_speed => C_spi_fixed_speed(i) = '1'
	)
	port map (
	    clk => clk, ce => spi_ce(i),
	    bus_write => io_write, byte_sel => io_byte_sel,
	    bus_in => cpu_to_io, bus_out => from_spi(i),
	    spi_sck => spi_sck(i), spi_cen => spi_ss(i),
	    spi_miso => spi_miso(i), spi_mosi => spi_mosi(i)
	);
	spi_ce(i) <= io_addr_strobe(R_cur_io_port) when io_addr(11 downto 6) = x"3" & "01" and
	  conv_integer(io_addr(5 downto 4)) = i else '0';
    end generate;
    G_spi_decoder: if C_spi > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      spi_range <= '1' when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range),
                   '0' when others;
    end generate;

    -- Memory map:
    -- 0x0*******: (4B, RW) : Embedded block RAM (2 - 16 KBytes, fast)
    -- 0x8*******: (4B, RW) : External static RAM (1 MByte, slow)
    -- 0xf****800: (4B, RW) : GPIO data
    -- 0xf****804: (4B, WR) : GPIO control (direction 1-output 0-input)
    -- 0xf****808: (4B, WR) : GPIO rising edge interrupt flag
    -- 0xf****80C: (4B, WR) : GPIO rising edge interrupt enable
    -- 0xf****810: (4B, WR) : GPIO falling edge interrupt flag
    -- 0xf****814: (4B, WR) : GPIO falling edge interrupt enable
    -- 0xf****900: (16B,WR) : TIMER
    -- 0xf****B00: (4B, RW) : SIO
    -- 0xf****B40: (2B, RW) : SPI Flash
    -- 0xf****B50: (2B, RW) : SPI MicroSD
    -- 0xf****B80: (4B, WR) : Video framebuffer control
    -- 0xf****BA0: (4B, RW) : PCM audio DMA first addr (WR) / current addr (RD)
    -- 0xf****BA4: (4B, WR) : PCM audio DMA last addr
    -- 0xf****BA8: (3B, WR) : PCM audio DMA refill frequency (sampling rate)
    -- 0xf****D20: (2B, WR) : Lego Power Functions Infrared Controller
    -- 0xf****F00: (4B, RW) : simple I/O: switches, buttons (RD), LED, LCD (WR)
    -- 0xf****FF0: (1B, WR) : CPU reset bitmap

    --
    -- I/O arbiter
    --
    process(R_cur_io_port, dmem_addr, dmem_addr_strobe)
	variable i, j, t, cpu: integer;
    begin
	for cpu in 0 to (C_cpus - 1) loop
	    if dmem_addr(cpu)(31 downto 28) = x"F" and dmem_addr(cpu)(11) = '1' then
		io_addr_strobe(cpu) <= dmem_addr_strobe(cpu);
	    else
		io_addr_strobe(cpu) <= '0';
	    end if;
	end loop;
	t := R_cur_io_port;
	for i in 0 to (C_io_ports - 1) loop
	    for j in 1 to C_io_ports loop
		if R_cur_io_port = i then
		    t := (i + j) mod C_io_ports;
		    if io_addr_strobe(t) = '1' then
			exit;
		    end if;
		end if;
	    end loop;
	end loop;
	next_io_port <= t;
    end process;

    --
    -- I/O access
    --
    io_write <= dmem_write(R_cur_io_port);
    io_addr <=  '0' & dmem_addr(R_cur_io_port)(10 downto 2);
    io_byte_sel <= dmem_byte_sel(R_cur_io_port);
    cpu_to_io <= cpu_to_dmem(R_cur_io_port);
    process(clk)
    begin
	if rising_edge(clk) then
	    R_cur_io_port <= next_io_port;
	end if;
    end process;

    -- remains of old IO (CPU writes to IO)
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe(R_cur_io_port) = '1'
	  and io_write = '1' then
	    -- DDS
	    if C_dds and io_addr(11 downto 4) = x"7D" then
		R_dds <= cpu_to_io;
	    end if;
	    -- CPU reset control
	    if C_cpus /= 1 and io_addr(11 downto 4) = x"7F" then
		R_cpu_reset <= cpu_to_io(15 downto 0);
	    end if;
	    -- Framebuffer
	    if C_framebuffer and io_addr(11 downto 4) = x"38" then
		if C_big_endian then
		    R_fb_mode <= cpu_to_io(25 downto 24);
		    R_fb_base_addr <=
		      cpu_to_io(11 downto 8) &
		      cpu_to_io(23 downto 16) &
		      cpu_to_io(31 downto 26);
		else
		    R_fb_mode <= cpu_to_io(1 downto 0);
		    R_fb_base_addr <= cpu_to_io(29 downto 2);
		end if;
	    end if;
	end if;
	if C_framebuffer and rising_edge(clk) then
	    if io_addr_strobe(R_cur_io_port) = '1' and
	      io_addr(11 downto 4) = x"38" then
		R_fb_intr <= '0';
	    end if;
	    if fb_tick = '1' then
		R_fb_intr <= '1';
	    end if;
	end if;
    end process;

    --
    -- Simple I/O
    --
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe(R_cur_io_port) = '1' and io_write = '1' then
	    -- simple out
	    if C_simple_out > 0 and io_addr(11 downto 4) = iomap_from(iomap_simple_out, iomap_range) then
		if io_byte_sel(0) = '1' then
		    R_simple_out(7 downto 0) <= cpu_to_io(7 downto 0);
		end if;
		if io_byte_sel(1) = '1' then
		    R_simple_out(15 downto 8) <= cpu_to_io(15 downto 8);
		end if;
		if io_byte_sel(2) = '1' then
		    R_simple_out(23 downto 16) <= cpu_to_io(23 downto 16);
		end if;
		if io_byte_sel(3) = '1' then
		    R_simple_out(31 downto 24) <= cpu_to_io(31 downto 24);
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

    G_simple_out_timer:
    if C_timer = true generate
    ocp_mux(0) <= ocp(0) when ocp_enable(0)='1' else R_simple_out(1);
    ocp_mux(1) <= ocp(1) when ocp_enable(1)='1' else R_simple_out(2);
    simple_out <= R_simple_out(31 downto 3) & ocp_mux & R_simple_out(0) when C_simple_out > 0
      else (others => '-');
    end generate;

    -- big address decoder when CPU reads IO
    process(io_addr, R_simple_in, from_sio, from_spi,
      from_gpio, from_vga_textmode, from_timer)
    begin
	case conv_integer(io_addr(11 downto 4)) is
	when iomap_from(iomap_gpio, iomap_range) to iomap_to(iomap_gpio, iomap_range) =>
	    if C_gpio then
		io_to_cpu <= from_gpio;
	    else
		io_to_cpu <= (others => '-');
	    end if;	
	when iomap_from(iomap_timer, iomap_range) to iomap_to(iomap_timer, iomap_range)  =>
	    if C_timer then
		io_to_cpu <= from_timer;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range)  =>
	    if C_sio then
		io_to_cpu <= from_sio;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when  iomap_from(iomap_pid, iomap_range) to iomap_to(iomap_pid, iomap_range) => -- address 0xFFFFFD80
	    if C_pid then
		io_to_cpu <= from_pid;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range) =>
	    for i in 0 to C_spi - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_spi(i);
		end if;
	    end loop;
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
	when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range)  =>
	    if C_fmrds then
		io_to_cpu <= from_fmrds;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when others =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    --
    -- Block RAM (only CPU #0)
    --
    G_i_d_ram:
    if not C_i_rom_only generate
    begin
    dmem_bram_enable <= dmem_addr_strobe(0) when dmem_addr(0)(31 downto 28) = x"0"
      else '0';
    bram: entity work.bram
    generic map (
	C_mem_size => C_bram_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe(0),
	imem_addr => imem_addr(0), imem_data_out => bram_i_to_cpu,
	imem_data_ready => bram_i_ready, dmem_data_ready => bram_d_ready,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write(0),
	dmem_byte_sel => dmem_byte_sel(0), dmem_addr => dmem_addr(0),
	dmem_data_out => bram_d_to_cpu, dmem_data_in => cpu_to_dmem(0)
    );
    end generate;

    G_i_rom:
    if C_i_rom_only generate
    begin
    bram: entity work.bram
    generic map (
	C_mem_size => C_bram_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe(0),
	imem_addr => imem_addr(0), imem_data_out => bram_i_to_cpu,
	imem_data_ready => bram_i_ready, dmem_data_ready => open,
	dmem_addr_strobe => '0', dmem_write => '0',
	dmem_byte_sel => x"0", dmem_addr => (others => '0'),
	dmem_data_out => open, dmem_data_in => (others => '0')
    );
    end generate;


    --
    -- SRAM
    --
    process(imem_addr, dmem_addr, dmem_byte_sel, cpu_to_dmem, dmem_write,
      dmem_addr_strobe, imem_addr_strobe, fb_addr_strobe, fb_addr,
      sram_ready, io_to_cpu, from_sram)
	variable data_port, instr_port, fb_port, fb_text_port, pcm_port: integer;
	variable sram_data_strobe, sram_instr_strobe: std_logic;
    begin
	for cpu in 0 to (C_cpus - 1) loop
	    data_port := cpu;
	    instr_port := C_cpus + cpu;
	    if dmem_addr(cpu)(31 downto 28) = x"8" then
		sram_data_strobe := dmem_addr_strobe(cpu);
	    else
		sram_data_strobe := '0';
	    end if;
	    if imem_addr(cpu)(31 downto 28) = x"8" then
		sram_instr_strobe := imem_addr_strobe(cpu);
	    else
		sram_instr_strobe := '0';
	    end if;
	    if cpu = 0 then
		-- CPU, data bus
		if io_addr_strobe(cpu) = '1' then
		    if R_cur_io_port = cpu then
			dmem_data_ready(cpu) <= '1';
		    else
			dmem_data_ready(cpu) <= '0';
		    end if;
		    final_to_cpu_d(cpu) <= io_to_cpu;
		elsif sram_data_strobe = '1' then
		    dmem_data_ready(cpu) <= sram_ready(data_port);
		    final_to_cpu_d(cpu) <= from_sram;
		elsif C_i_rom_only then
		    -- XXX assert address eror signal?
		    dmem_data_ready(cpu) <= dmem_addr_strobe(cpu);
		    final_to_cpu_d(cpu) <= (others => '-');
		else
		    dmem_data_ready(cpu) <= bram_d_ready;
		    final_to_cpu_d(cpu) <= bram_d_to_cpu; -- BRAM
		end if;
		-- CPU, instruction bus
		if sram_instr_strobe = '1' then
		    imem_data_ready(cpu) <= sram_ready(instr_port);
		    final_to_cpu_i(cpu) <= from_sram;
		elsif imem_addr_strobe(cpu) = '0' then
		    imem_data_ready(cpu) <= '0';
		    final_to_cpu_i(cpu) <= bram_i_to_cpu;
		else
		    imem_data_ready(cpu) <= bram_i_ready;
		    final_to_cpu_i(cpu) <= bram_i_to_cpu;
		end if;
	    else -- CPU #1, CPU #2...
		-- CPU, data bus
		if io_addr_strobe(cpu) = '1' then
		    if R_cur_io_port = cpu then
			dmem_data_ready(cpu) <= '1';
		    else
			dmem_data_ready(cpu) <= '0';
		    end if;
		    final_to_cpu_d(cpu) <= io_to_cpu;
		elsif sram_data_strobe = '1' then
		    dmem_data_ready(cpu) <= sram_ready(data_port);
		    final_to_cpu_d(cpu) <= from_sram;
		else
		    -- XXX assert address eror signal?
		    dmem_data_ready(cpu) <= '1';
		    final_to_cpu_d(cpu) <= (others => '-');
		end if;
		-- CPU, instruction bus
		if sram_instr_strobe = '1' then
		    imem_data_ready(cpu) <= sram_ready(instr_port);
		    final_to_cpu_i(cpu) <= from_sram;
		else
		    -- XXX assert address eror signal?
		    -- XXX hack for avoiding a deadlock in i-cache FSM
		    imem_data_ready(cpu) <= imem_addr_strobe(cpu);
		    final_to_cpu_i(cpu) <= (others => '-');
		end if;
	    end if;
	    -- CPU, data bus
	    to_sram(data_port).addr_strobe <= sram_data_strobe;
	    to_sram(data_port).write <= dmem_write(cpu);
	    to_sram(data_port).byte_sel <= dmem_byte_sel(cpu);
	    to_sram(data_port).addr <= dmem_addr(cpu)(to_sram(data_port).addr'high downto 2);
	    to_sram(data_port).data_in <= cpu_to_dmem(cpu);
	    -- CPU, instruction bus
	    to_sram(instr_port).addr_strobe <= sram_instr_strobe;
	    to_sram(instr_port).addr <= imem_addr(cpu)(to_sram(instr_port).addr'high downto 2);
	    to_sram(instr_port).data_in <= (others => '-');
	    to_sram(instr_port).write <= '0';
	    to_sram(instr_port).byte_sel <= x"f";
	end loop;
	-- video framebuffer
	if C_framebuffer or C_vgahdmi then
	    fb_port := 2 * C_cpus;
	    to_sram(fb_port).addr_strobe <= fb_addr_strobe;
	    to_sram(fb_port).write <= '0';
	    to_sram(fb_port).byte_sel <= x"f";
	    to_sram(fb_port).addr <= fb_addr;
	    to_sram(fb_port).data_in <= (others => '-');
	    fb_data_ready <= sram_ready(fb_port);
	    --fb_text_port := 2 * C_cpus + 1;
	    --to_sram(fb_text_port).addr_strobe <= '0';
	end if;
	if C_vgatext then
	    fb_port := 2 * C_cpus + 0;
            if C_vgatext_bitmap then
              to_sram(fb_port).addr_strobe <= vga_textmode_bitmap_sram_strobe;
              to_sram(fb_port).addr <= vga_textmode_bitmap_sram_addr(to_sram(fb_port).addr'high downto 2);
              to_sram(fb_port).data_in <= (others => '-');
              to_sram(fb_port).write <= '0';
              to_sram(fb_port).byte_sel <= (others => '1');
              vga_textmode_bitmap_sram_ready <= sram_ready(fb_port);
            end if;
	    fb_text_port := 2 * C_cpus + 1;
            if C_vgatext_text then
              to_sram(fb_text_port).addr_strobe <= vga_textmode_text_sram_strobe;
              to_sram(fb_text_port).addr <= vga_textmode_text_sram_addr(to_sram(fb_text_port).addr'high downto 2);
              to_sram(fb_text_port).data_in <= (others => '-');
              to_sram(fb_text_port).write <= '0';
              to_sram(fb_text_port).byte_sel <= "1111"; -- 32 bits read for RGB
              vga_textmode_text_sram_ready <= sram_ready(fb_text_port);
            end if;
	end if;
	if C_pcm then
	    pcm_port := 2 * C_cpus + 2;
	    to_sram(pcm_port).addr_strobe <= pcm_addr_strobe;
	    to_sram(pcm_port).write <= '0';
	    to_sram(pcm_port).byte_sel <= x"f";
	    to_sram(pcm_port).addr <= pcm_addr;
	    to_sram(pcm_port).data_in <= (others => '-');
	    pcm_data_ready <= sram_ready(pcm_port);
	end if;
    end process;

    G_sram:
    if C_sram generate
    sram: entity work.sram
    generic map (
	C_ports => 2 * C_cpus + 3, -- extra ports: framebuffer, textmode and PCM audio
	C_prio_port => 2 * C_cpus, -- framebuffer
	C_wait_cycles => C_sram_wait_cycles,
	C_pipelined_read => C_pipelined_read
    )
    port map (
	clk => clk, sram_a => sram_a, sram_d => sram_d,
	sram_wel => sram_wel, sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	data_out => from_sram,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- Multi-port connections:
	bus_in => to_sram, ready_out => sram_ready
    );
    end generate;

    --
    -- Video framebuffer
    --
    G_framebuffer:
    if C_framebuffer generate
    fb: entity work.fb
    generic map (
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, clk_dac => clk_325m,
	addr_strobe => fb_addr_strobe,
	addr_out => fb_addr,
	data_ready => fb_data_ready,
	data_in => from_sram,
	mode => R_fb_mode,
	base_addr => R_fb_base_addr,
	dac_out => video_dac,
	tick_out => fb_tick
    );
    end generate;

    -- VGA/HDMI
    G_vgahdmi:
    if C_vgahdmi generate
    vgahdmi: entity work.vgahdmi
    generic map (
      test_picture => C_vgahdmi_test_picture  -- show test picture in background
    )
    port map (
      clk_pixel => clk_25m,
      -- clk_tmds => clk_250MHz,
      fetch_next => vga_fetch_next,
      red_byte    => vga_data_from_fifo(7 downto 5) & "00000",
      green_byte  => vga_data_from_fifo(4 downto 2) & "00000",
      blue_byte   => vga_data_from_fifo(1 downto 0) & "000000",
      bright_byte => (others => '0'),
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync
      -- tmds_out_rgb => tmds_out_rgb
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
      clk_pixel => clk_25m,
      addr_strobe => fb_addr_strobe,
      addr_out => fb_addr,
      data_ready => fb_data_ready, -- data valid for read acknowledge from RAM
      -- data_ready => '1', -- BRAM is eveready
      data_in => vga_data, -- from SDRAM or BRAM
      -- data_in => x"00000001", -- test pattern vertical lines
      -- data_in(7 downto 0) => vga_addr(9 downto 2), -- test if address is in sync with video frame
      -- data_in(31 downto 8) => (others => '0'),
      base_addr => R_fb_base_addr,
      start => S_vga_vsync,
      frame => vga_frame,
      data_out => vga_data_from_fifo(C_vgahdmi_fifo_data_width-1 downto 0),
      fetch_next => vga_fetch_next
    );

    -- vga_data(7 downto 0) <= vga_addr(12 downto 5);
    -- vga_data(7 downto 0) <= x"0F";
    vga_data <= from_sram;

    -- address decoder to set base address and clear interrupts
    with conv_integer(io_addr(11 downto 4)) select
      vga_ce <= io_addr_strobe(R_cur_io_port) when iomap_from(iomap_vga, iomap_range) to iomap_to(iomap_vga, iomap_range),
                                          '0' when others;
    process(clk)
    begin
        if rising_edge(clk) then
            if vga_ce = '1' and io_write = '1' then
                -- cpu write: writes Framebuffer base
                if C_big_endian then
                     -- R_fb_mode <= cpu_to_dmem(25 downto 24);
                     R_fb_base_addr <= -- XXX: revisit, probably wrong;
                      cpu_to_io(11 downto 8) &
                      cpu_to_io(23 downto 16) &
                      cpu_to_io(31 downto 26);
                else
                    -- R_fb_mode <= cpu_to_dmem(1 downto 0);
                    R_fb_base_addr <= cpu_to_io(29 downto 2);
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
    end generate; -- end vgahdmi


  -- VGA textmode
  G_vgatext:  if C_vgatext generate
  vga_video: entity work.VGA_textmode
  generic map (
    C_vgatext_mode => C_vgatext_mode,
    C_vgatext_bits => C_vgatext_bits,
    C_vgatext_bram_mem => C_vgatext_bram_mem,
    C_vgatext_external_mem => C_vgatext_external_mem,
    C_vgatext_reset => C_vgatext_reset,
    C_vgatext_palette => C_vgatext_palette,
    C_vgatext_text => C_vgatext_text,
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
    C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo
  )
  port map (
    reset_i => sio_break,
    clk_i => clk, ce_i => vga_textmode_ce, bus_addr_i => dmem_addr(0)(4 downto 2),
    bus_write_i => dmem_write(0), byte_sel_i => dmem_byte_sel(0),
    bus_data_i => cpu_to_dmem(0), bus_data_o => from_vga_textmode,
    --
    clk_pixel_i => clk_25m,
    --
    bram_addr_o => vga_textmode_bram_addr,
    bram_data_i => vga_textmode_bram_data,
    text_active_o => vga_textmode_text_active,
    --
    textfifo_addr_o => vga_textmode_text_addr,
    textfifo_data_i => vga_textmode_text_data,
    textfifo_strobe_o => vga_textmode_text_strobe,
    textfifo_rewind_o => vga_textmode_text_rewind,
    --
    bitmap_strobe_o => vga_textmode_bitmap_strobe,
    bitmap_addr_o => vga_textmode_bitmap_addr,
    bitmap_ready_i => vga_textmode_bitmap_ready,
    bitmap_data_i => vga_textmode_bitmap_data,
    bitmap_active_o => vga_textmode_bitmap_active,
    --
    red_o => vga_textmode_red,
    green_o => vga_textmode_green,
    blue_o => vga_textmode_blue,
    hsync_o => vga_textmode_hsync,
    vsync_o => vga_textmode_vsync,
    blank_o => vga_textmode_blank
  );

  vga_vsync <= vga_textmode_vsync;
  vga_hsync <= vga_textmode_hsync;
  --process(clk)
  --begin
  --  Rblink <= Rblink+1;
  --end process;
  --vga_vsync <= Rblink(29);
  --vga_hsync <= Rblink(29);

      -- analog vga output
      vga_r <= vga_textmode_red;
      vga_g <= vga_textmode_green;
      vga_b <= vga_textmode_blue;
      vga_vsync <= vga_textmode_vsync;
      vga_hsync <= vga_textmode_hsync;

  -- video FIFO for text+color
  G_vgatext_text_fifo:
  if C_vgatext_text AND C_vgatext_text_fifo generate
    videofifo: entity work.videofifo
    generic map (
      C_postpone_step => C_vgatext_text_fifo_postpone_step,
      C_step => C_vgatext_text_fifo_step,
      C_width => C_vgatext_text_fifo_width -- length = 4 * 2^width
    )
    port map (
      clk => clk,
      clk_pixel => clk_25m,
      addr_strobe => vga_textmode_text_sram_strobe,
      addr_out => vga_textmode_text_sram_addr,
      data_ready => vga_textmode_text_sram_ready, -- data valid for read acknowledge from RAM
      data_in => from_sram, -- from SRAM
      base_addr => vga_textmode_text_addr,
      start => vga_textmode_text_active,
      frame => vga_textmode_text_frame,
      data_out => vga_textmode_text_data,
      fetch_next => vga_textmode_text_strobe,
      rewind => vga_textmode_text_rewind
    );
  end generate;

  -- video FIFO for bitmap
  G_vgatext_bitmap_fifo:
  if C_vgatext_bitmap AND C_vgatext_bitmap_fifo generate
  videofifo: entity work.videofifo
  generic map (
    C_step => C_vgatext_bitmap_fifo_step,
    -- C_compositing_length => C_vgatext_bitmap_compositing_length,
    C_width => C_vgatext_bitmap_fifo_width -- length = 4 * 2^width
  )
  port map (
    clk => clk,
    clk_pixel => clk_25m,
    addr_strobe => vga_textmode_bitmap_sram_strobe,
    addr_out => vga_textmode_bitmap_sram_addr,
    data_ready => vga_textmode_bitmap_sram_ready, -- data valid for read acknowledge from RAM
    data_in => from_sram,
    base_addr => vga_textmode_bitmap_addr,
    start => vga_textmode_bitmap_active,
    frame => vga_textmode_bitmap_frame,
    data_out => vga_textmode_bitmap_data,
    fetch_next => vga_textmode_bitmap_strobe
  );
  end generate;
  G_vgatext_nofifo:
  if C_vgatext_bitmap AND NOT C_vgatext_bitmap_fifo generate
    vga_textmode_bitmap_sram_strobe <= vga_textmode_bitmap_strobe;
    vga_textmode_bitmap_sram_addr <= vga_textmode_bitmap_addr;
    vga_textmode_bitmap_ready <= vga_textmode_bitmap_sram_ready;
    vga_textmode_bitmap_data <= from_sram;
  end generate;

      -- 8KB VGA textmode BRAM (for text+attribute bytes and font)
  G_vga_textmode_bram: if C_vgatext_text generate
  G_vgatext_bram: entity work.VGA_textmode_bram
  generic map (
    C_mem_size    => C_vgatext_bram_mem,
    C_label       => C_vgatext_label,
    C_monochrome  => C_vgatext_monochrome,
    C_font_height => C_vgatext_font_height,
    C_font_depth  => C_vgatext_font_depth
  )
  port map (
    clk => clk, imem_addr => vga_textmode_bram_addr, imem_data_out => vga_textmode_bram_data,
    dmem_write => vga_textmode_dmem_write,
    dmem_byte_sel => dmem_byte_sel(0), dmem_addr => dmem_addr(0),
    dmem_data_out => vga_textmode_dmem_to_cpu, dmem_data_in => cpu_to_dmem(0)
  );
  end generate;

  vgatext_intr: process(clk)
  begin
    if rising_edge(clk) then
        if vga_textmode_ce = '1' then -- interrupt handling: (CPU read or write will clear interrupt)
          vga_textmode_intr <= '0';
        else
          if vga_textmode_text_frame = '1' OR vga_textmode_bitmap_frame = '1' then
          vga_textmode_intr <= '1';
        end if;
      end if;
    end if; -- end rising edge
  end process;

  vga_textmode_dmem_write <= dmem_addr_strobe(0) and dmem_write(0) when dmem_addr(0)(31 downto 28) = x"4" else '0';
  with conv_integer(io_addr(11 downto 4)) select
    vga_textmode_ce <= io_addr_strobe(R_cur_io_port) when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range),
    '0' when others;
  end generate; -- end VGA textmode

    --
    -- PCM audio
    --
    G_pcm:
    if C_pcm generate
    pcm: entity work.pcm
    port map (
	clk => clk, io_ce => pcm_ce, io_addr => io_addr(3 downto 2),
	io_bus_write => io_write, io_byte_sel => io_byte_sel,
	io_bus_in => cpu_to_io, io_bus_out => from_pcm,
	addr_strobe => pcm_addr_strobe, data_ready => pcm_data_ready,
	addr_out => pcm_addr, data_in => from_sram,
	out_pcm_l => pcm_bus_l, out_pcm_r => pcm_bus_r,
	out_r => pcm_r, out_l => pcm_l
    );
    with conv_integer(io_addr(11 downto 4)) select
      pcm_ce <= io_addr_strobe(R_cur_io_port) when iomap_from(iomap_pcm, iomap_range) to iomap_to(iomap_pcm, iomap_range),
                                          '0' when others;
    end generate;

    p_tip <= (others => R_dds_acc(31)) when C_dds and R_dds_enable = '1'
      else video_dac when C_framebuffer and R_fb_mode /= "11"
      else (others => pcm_l);
    p_ring <= R_dds_acc(31) when C_dds and R_dds_enable = '1'
      else pcm_r;

    -- FM/RDS
    G_fmrds:
    if C_fmrds generate
    fm_tx: entity work.fm
    generic map (
      c_fmdds_hz => 325000000, -- Hz FMDDS clock frequency
      C_rds_msg_len => C_rds_msg_len, -- allocate RAM for RDS message
      C_stereo => C_fm_stereo,
      -- multiply/divide to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide
    )
    port map (
      clk => clk, -- RDS and PCM processing clock 81.25 MHz
      clk_fmdds => clk_325m, -- DDS clock 325 MHz
      ce => fmrds_ce, addr => io_addr(3 downto 2),
      bus_write => io_write, byte_sel => io_byte_sel,
      bus_in => cpu_to_io, bus_out => from_fmrds,
      pcm_in_left => pcm_bus_l,
      pcm_in_right => pcm_bus_r,
      fm_antenna => fm_antenna
    );
    with conv_integer(io_addr(11 downto 4)) select
      fmrds_ce <= io_addr_strobe(R_cur_io_port)
                    when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range),
                '0' when others;
    end generate; -- end fm/rds

    --
    -- GPIO
    --
    G_gpio:
    if C_gpio generate
    gpio_inst: entity work.gpio
    port map (
	clk => clk, ce => gpio_ce, addr => io_addr(4 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_gpio,
	gpio_irq => gpio_intr,
        gpio_phys(15 downto 0)  => gpio(15 downto 0),
        gpio_phys(27 downto 16) => gpio_pid(27 downto 16),
        gpio_phys(31 downto 28) => gpio(31 downto 28)
    );
    gpio_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 8) = x"0" else '0';
    end generate;

    -- one selected simple_out enables carrier (CW modulation)
    -- used for carriers of higher frequency than FM DDS
    -- can produce (433 MHz)
    G_cw_antenna:
    if C_cw_simple_out >= 0 and C_simple_out > C_cw_simple_out generate
      cw_antenna <= simple_out(C_cw_simple_out) and clk_cw;
    end generate;

    --
    -- Timer
    --
    G_timer:
    if C_timer generate
    icp <= R_simple_out(3) & R_simple_out(0); -- during debug period, leds will serve as software-generated ICP
    timer: entity work.timer
    generic map (
        C_pres => 10,
        C_bits => 12
    )
    port map (
        clk => clk, ce => timer_ce, addr => io_addr(5 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_timer,
	timer_irq => timer_intr,
	ocp_enable => ocp_enable, -- enable physical output
	ocp => ocp, -- output compare signal
	icp_enable => icp_enable, -- enable physical input
	icp => icp -- input capture signal
    );
    with conv_integer(io_addr(11 downto 4)) select
      timer_ce <= io_addr_strobe(R_cur_io_port) when iomap_from(iomap_timer, iomap_range) to iomap_to(iomap_timer, iomap_range),
                             '0' when others;
    end generate;

    -- PID
    G_pid:
    if C_pid generate
    pid_inst: entity work.pid
    generic map (
        C_simulator => C_pid_simulator,
        C_pids => C_pids,
	C_addr_unit_bits => C_pids_bits
    )
    port map (
	clk => clk, ce => pid_ce, addr => io_addr(C_pids_bits+3 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_pid,
	encoder_a_in(0) => gpio(16),  encoder_b_in(0) => gpio(17),
	bridge_f_out(0) => gpio(18),  bridge_r_out(0) => gpio(19),
	encoder_a_in(1) => gpio(20),  encoder_b_in(1) => gpio(21),
	bridge_f_out(1) => gpio(22),  bridge_r_out(1) => gpio(23),
	encoder_a_in(2) => gpio(24),  encoder_b_in(2) => gpio(25),
	bridge_f_out(2) => gpio(26),  bridge_r_out(2) => gpio(27)
    );
    with conv_integer(io_addr(11 downto 4)) select
      pid_ce <= io_addr_strobe(R_cur_io_port) when iomap_from(iomap_pid, iomap_range) to iomap_to(iomap_pid, iomap_range),
                           '0' when others;
    end generate;

    G_no_pid:
    if not C_pid generate
      gpio(27 downto 16) <= gpio_pid(27 downto 16);
    end generate;

    --
    -- DDS
    --
    process(clk_325m)
    begin
	if rising_edge(clk_325m) then
	    R_dds_fast <= R_dds;
	    R_dds_acc <= R_dds_acc + R_dds_fast;
	end if;
    end process;

    -- Debugging SIO instance
    G_debug_sio:
    if C_debug generate
    debug_sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => false
    )
    port map (
	clk => clk, ce => '1', txd => deb_tx, rxd => rs232_rx,
	bus_write => deb_sio_tx_strobe, byte_sel => "0001",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_out(7 downto 0) => sio_to_debug_data,
	bus_out(8) => deb_sio_rx_done, bus_out(10) => deb_sio_tx_busy,
	break => open
    );
    end generate;

    rs232_tx <= sio_txd when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;
