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
-- use IEEE.STD_LOGIC_ARITH.ALL; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all; -- we need signed type
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;

entity glue_bram is
    generic (
	C_clk_freq: integer;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"0003ffff"; -- 256 K
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

	-- SoC configuration options
	C_bram_size: integer := 16;	-- in KBytes
	C_boot_spi: boolean := false;
	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
	C_sio_fixed_baudrate: boolean := false;
	C_sio_break_detect: boolean := true;
        C_sio_break_detect_delay_ms: integer := 200; -- ms (milliseconds) serial break
	C_spi: integer := 0;
	C_spi_turbo_mode: std_logic_vector := "0000";
	C_spi_fixed_speed: std_logic_vector := "1111";
	C_simple_in: integer range 0 to 128 := 32;
	C_simple_out: integer range 0 to 128 := 32;
	C_vgahdmi: boolean := false; -- enable VGA/HDMI output to vga_ and tmds_
	C_vgahdmi_mem_kb: integer := 4; -- mem size of framebuffer
	C_vgahdmi_dbl_x: integer := 0; -- double-size x pixel
	C_vgahdmi_dbl_y: integer := 0; -- double-size y-pixel
	C_vgahdmi_fifo_step: integer := 0; -- 0 (dbl_y = 0), 40 (dbl_x = 1, dbl_y = 1), 80 (dbl_x = 0, dbl_y = 1)
	C_vgahdmi_fifo_width: integer := 4; -- 4 (dbl_y = 0),  6 (dbl_x = 1, dbl_y = 1),  7 (dbl_x = 0, dbl_y = 1)
	C_vgahdmi_test_picture: integer := 0; -- 0: disable 1:show test picture in Red and Blue channel

	-- Xark's feature-rich bitmap+textmode VGA
	-- it can mix 8bpp bitmap and tiled graphics on the same screen
	-- choice of many of video modes
	-- minimal mode needs only 4K BRAM
	C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
        C_vgatext_label: string := "f32c";    -- default banner in screen memory
        C_vgatext_mode: integer := 0;   -- 640x480
        C_vgatext_bits: integer := 2;   -- 64 possible colors
        C_vgatext_bram_mem: integer := 4;   -- 4KB text+font  memory
        C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
        C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
        C_vgatext_palette: boolean := false;  -- no color palette
        C_vgatext_text: boolean := true;    -- enable optional text generation
        C_vgatext_font_bram8: boolean := false;  -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16;   -- character cell height
        C_vgatext_font_height: integer := 8;    -- font height
        C_vgatext_font_depth: integer := 7;			-- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := true;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := false;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
        C_vgatext_reg_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only

        C_vgatext_text_fifo: boolean := false;  -- disable text memory FIFO
        C_vgatext_text_fifo_postpone_step: integer := 0;
        C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
        C_vgatext_text_fifo_width: integer := 6; 	-- width of FIFO address space (default=4) length = 2^width * 4 bytes

        C_vgatext_bitmap: boolean := false;     -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := false;  -- disable bitmap FIFO
        C_vgatext_bitmap_fifo_step: integer := 0;	-- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_width: integer := 8;	-- bitmap width of FIFO address space length = 2^width * 4 byte

	C_cw_simple_out: integer := -1; -- simple out bit used for CW modulation. -1 to disable
	C_fmrds: boolean := false; -- enable FM/RDS output to fm_antenna
	C_fm_stereo: boolean := false;
	C_rds_msg_len: integer := 260; -- bytes of circular sent message, typical 52 for PS or 260 PS+RT
        C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250000000, 325000000)
        C_rds_clock_multiply: integer := 57; -- multiply 57 and divide 3125 from cpu clk 100 MHz
        C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
	C_gpio: integer range 0 to 128 := 32;
	C_ps2: boolean := false;
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
	clk_cw: in std_logic := '0'; -- CW clock (433.92 MHz)
	sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
	sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
	spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
	spi_miso: in std_logic_vector(C_spi - 1 downto 0);
	simple_in: in std_logic_vector(31 downto 0);
	simple_out: out std_logic_vector(31 downto 0); -- it is always OUT but xilinx compiles only if inout
	pid_encoder_a, pid_encoder_b: in  std_logic_vector(C_pids-1 downto 0) := (others => '-');
	pid_bridge_f,  pid_bridge_r:  out std_logic_vector(C_pids-1 downto 0);
	vga_hsync, vga_vsync: out std_logic; -- it is always out but xilinx compiles if inout
	vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0);
	tmds_out_rgb: out std_logic_vector(2 downto 0);
	fm_antenna, cw_antenna: out std_logic;
        -- PS/2 Keyboard
	ps2_clk_in : in std_logic := '1';
	ps2_dat_in : in std_logic := '1';
	ps2_clk_out : out std_logic;
	ps2_dat_out : out std_logic;
	gpio: inout std_logic_vector(127 downto 0)
    );
end glue_bram;

architecture Behavioral of glue_bram is
    signal imem_addr: std_logic_vector(31 downto 2);
    signal imem_data_read: std_logic_vector(31 downto 0);
    signal imem_addr_strobe, imem_data_ready: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_bram_write, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
    signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);
    signal intr: std_logic_vector(5 downto 0); -- interrupt

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

    -- Simple I/O: onboard LEDs, buttons and switches
    constant iomap_simple_in: T_iomap_range := (x"FF00", x"FF0F");
    constant iomap_simple_out: T_iomap_range := (x"FF10", x"FF1F");
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);

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

    -- Timer
    constant iomap_timer: T_iomap_range := (x"F900", x"F93F");
    signal timer_range: std_logic := '0';
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;

    -- GPIO
    constant iomap_gpio: T_iomap_range := (x"F800", x"F87F");
    signal gpio_range: std_logic := '0';
    constant C_gpios: integer := (C_gpio+31)/32; -- number of gpio units
    type gpios_type is array (C_gpios-1 downto 0) of std_logic_vector(31 downto 0);
    signal from_gpio, gpios: gpios_type;
    signal gpio_ce: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr_joint: std_logic := '0';

    -- PS/2 Keyboard port
    constant iomap_ps2: T_iomap_range := (x"FF20", x"FF2F");
    signal ps2_ce: std_logic := '0';
    signal from_ps2: std_logic_vector(31 downto 0);

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

    -- Framebuffer
    signal R_fb_base_addr: std_logic_vector(29 downto 2);
    signal R_fb_intr: std_logic;

    -- VGA/HDMI video
    constant iomap_vga: T_iomap_range := (x"FB80", x"FB8F"); -- VGA/HDMI should be (x"FB90", x"FB9F")
    signal vga_ce: std_logic; -- '1' when address is in iomap_vga range
    signal vga_fetch_next: std_logic; -- video module requests next data from fifo
    signal vga_addr: std_logic_vector(29 downto 2); -- from fifo to RAM
    -- signal vga_debug_rd_addr: std_logic_vector(19 downto 2); -- from fifo to RAM
    signal vga_data, vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal video_bram_write: std_logic; -- from CPU to RAM
    signal vga_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_data_ready: std_logic; -- RAM responds to FIFO
    signal vga_n_vsync, vga_n_hsync: std_logic; -- intermediate signals for xilinx to be happy
    signal vga_line_repeat: std_logic;
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
    signal vga_textmode_bram_data: std_logic_vector(31 downto 0);
    signal vga_textmode_bram_data_in: std_logic_vector(31 downto 0);
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
    signal vga_textmode_bitmap_data: std_logic_vector(31 downto 0); -- data from FIFO or SRAM
    signal vga_textmode_bitmap_strobe: std_logic;				  -- FIFO fetch next word
    signal vga_textmode_bitmap_rewind: std_logic;         -- rewind FIFO
    signal vga_textmode_bitmap_ready: std_logic;					-- SRAM data ready
    signal vga_textmode_bitmap_active: std_logic;  -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_bitmap_frame: std_logic;


    -- FM/RDS RADIO
    constant iomap_fmrds: T_iomap_range := (x"FC00", x"FC0F");
    signal from_fmrds: std_logic_vector(31 downto 0);
    signal fmrds_ce: std_logic;

    -- 433 MHz
    signal simple_out_cw: std_logic;

    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    -- f32c core
    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_cop0_compare => C_cop0_compare,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => sio_break_internal(0), intr => intr,
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => '0', snoop_addr => "------------------------------",
	flush_i_line => open, flush_d_line => open,
	-- debugging
	debug_in_data => sio_to_debug_data,
	debug_in_strobe => deb_sio_rx_done,
	debug_in_busy => open,
	debug_out_data => debug_to_sio_data,
	debug_out_strobe => deb_sio_tx_strobe,
	debug_out_busy => deb_sio_tx_busy,
	debug_active => debug_active
    );
    final_to_cpu <= io_to_cpu when io_addr_strobe = '1'
      else vga_textmode_dmem_to_cpu when C_vgatext AND C_vgatext_bus_read AND dmem_addr(31 downto 30) = "01" -- address 0x40000000
      else dmem_to_cpu;
    -- warning: only sio 0 generates interrupt
    intr <= "00" & gpio_intr_joint & timer_intr & from_sio(0)(8) & R_fb_intr;
    -- added bit dmem_addr(11) = '1' to distinguish from RDS memory placed at 0xFFFFF000
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11" and dmem_addr(11) = '1'
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    imem_data_ready <= '1';
    dmem_data_ready <= '1';

    -- big address decoder when CPU reads IO
    process(io_addr, R_simple_in, R_simple_out, from_sio, from_timer, from_gpio, from_ps2, from_vga_textmode)
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
	when iomap_from(iomap_ps2, iomap_range) to iomap_to(iomap_ps2, iomap_range) =>
            if C_ps2 then
		io_to_cpu <= from_ps2;
            end if;
	when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range) =>
            if C_vgatext then
		io_to_cpu <= from_vga_textmode;
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
	when others  =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    -- simple_out: physical pin output, most efficient LUT-saving
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then
	    -- simple out
	    if C_simple_out > 0 and io_addr(11 downto 4) = iomap_from(iomap_simple_out, iomap_range) then
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

    -- one selected simple_out enables carrier (CW modulation)
    -- used for carriers of higher frequency than FM DDS
    -- can produce (433 MHz)
    G_cw_antenna:
    if C_cw_simple_out >= 0 and C_simple_out > C_cw_simple_out generate
      cw_antenna <= R_simple_out(C_cw_simple_out) and clk_cw;
    end generate;

    -- RS232 sio
    G_sio: for i in 0 to C_sio - 1 generate
	sio_instance: entity work.sio
	generic map (
	    C_clk_freq => C_clk_freq,
	    C_init_baudrate => C_sio_init_baudrate,
	    C_fixed_baudrate => C_sio_fixed_baudrate,
	    C_break_detect => C_sio_break_detect,
	    C_break_resets_baudrate => C_sio_break_detect,
	    C_break_detect_delay_ms => C_sio_break_detect_delay_ms,
	    C_big_endian => C_big_endian
	)
	port map (
	    clk => clk, ce => sio_ce(i), txd => sio_tx(i), rxd => sio_rx(i),
	    bus_write => dmem_write, byte_sel => dmem_byte_sel,
	    bus_in => cpu_to_dmem, bus_out => from_sio(i),
	    break => sio_break_internal(i)
	);
        sio_ce(i) <= io_addr_strobe when sio_range='1' and conv_integer(io_addr(5 downto 4)) = i
                else '0';
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
        spi_ce(i) <= io_addr_strobe when spi_range='1' and conv_integer(io_addr(5 downto 4)) = i
                else '0';
    end generate;
    G_spi_decoder: if C_spi > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      spi_range <= '1' when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range),
                   '0' when others;
    end generate;

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
    gpio_ce(i) <= io_addr_strobe when gpio_range='1' and conv_integer(io_addr(6 downto 5)) = i
             else '0';
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

    -- PS2 keyboard/mouse port
    G_ps2:
    if C_ps2 generate
    ps2_inst: entity work.ps2
    generic map (
      C_clk_freq => C_clk_freq
    )
    port map (
      clk => clk, ce => ps2_ce,
      reset => sio_break_internal(0),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_ps2,
      ps2_clk_in => ps2_clk_in,
      ps2_dat_in => ps2_dat_in,
      ps2_clk_out => ps2_clk_out,
      ps2_dat_out => ps2_dat_out
    );
    with conv_integer(io_addr(11 downto 4)) select
        ps2_ce <= io_addr_strobe when iomap_from(iomap_ps2, iomap_range) to iomap_to(iomap_ps2, iomap_range),
                  '0' when others;
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

    -- VGA/HDMI
    G_vgahdmi:
    if C_vgahdmi generate
    vgahdmi: entity work.vgahdmi
    generic map (
      dbl_x => C_vgahdmi_dbl_x,
      dbl_y => C_vgahdmi_dbl_y,
      test_picture => C_vgahdmi_test_picture
    )
    port map (
      clk_pixel => clk_25MHz,
      clk_tmds => clk_250MHz,
      fetch_next => vga_fetch_next,
      red_byte => vga_data_from_fifo(7 downto 0),
      green_byte => vga_data_from_fifo(15 downto 8),
      blue_byte => vga_data_from_fifo(23 downto 16),
      bright_byte => vga_data_from_fifo(31 downto 24),
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      vga_hsync => vga_n_hsync,
      vga_vsync => vga_n_vsync,
      line_repeat => vga_line_repeat,
      tmds_out_rgb => tmds_out_rgb
    );
    vga_vsync <= vga_n_vsync;
    vga_hsync <= vga_n_hsync;
    videofifo: entity work.videofifo
    generic map (
      C_step => C_vgahdmi_fifo_step,
      C_width => C_vgahdmi_fifo_width -- bits
    )
    port map (
      clk => clk,
      clk_pixel => clk_25MHz,
      addr_strobe => vga_addr_strobe,
      addr_out => vga_addr,
      -- debug_rd_addr => vga_debug_rd_addr,
      data_ready => '1', -- data valid for read acknowledge from RAM (BRAM is eveready)
      data_in => vga_data, -- from memory
      -- data_in => x"00000055", -- some debug constant
      -- data_in(7 downto 0) => vga_addr(9 downto 2), -- see if address resets correctly
      -- data_in(7 downto 0) => vga_debug_rd_addr(9 downto 2), -- see if address resets correctly
      -- data_in(31 downto 8) => (others => '0'),
      base_addr => R_fb_base_addr,
      start => vga_n_vsync,
      rewind => vga_line_repeat,
      data_out => vga_data_from_fifo,
      fetch_next => vga_fetch_next
    );

    -- vga_data(7 downto 0) <= vga_addr(12 downto 5);
    -- vga_data(7 downto 0) <= x"0F";
    -- WARNING: video BRAM is write-only
    video_bram_write <=
      dmem_addr_strobe and dmem_write when dmem_addr(31 downto 28) = x"8" else '0';
    videobram: entity work.bram_video
    generic map (
      C_mem_size => C_vgahdmi_mem_kb -- KB
    )
    port map (
	clk => clk,
	imem_addr(17 downto 2) => vga_addr(17 downto 2),
	imem_addr(31 downto 18) => (others => '0'),
	imem_data_out => vga_data(7 downto 0),
	dmem_write => video_bram_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => open, dmem_data_in => cpu_to_dmem(7 downto 0)
    );
    vga_data(15 downto 8)  <= vga_data(7 downto 0);
    vga_data(23 downto 16) <= vga_data(7 downto 0);
    vga_data(31 downto 24) <= vga_data(7 downto 0);

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
		    R_fb_base_addr <=
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
                if vga_n_vsync = '0' then -- fixme: vsync is long, should be 1-clock tick here
                    R_fb_intr <= '1';
                end if;
            end if;
	end if; -- end rising edge
    end process;
    end generate; -- end vgahdmi

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
        C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo
      )
      port map (
        reset_i => sio_break_internal(0),
        clk_i => clk, ce_i => vga_textmode_ce, bus_addr_i => dmem_addr(4 downto 2),
        bus_write_i => dmem_write, byte_sel_i => dmem_byte_sel,
        bus_data_i => cpu_to_dmem, bus_data_o => from_vga_textmode,
        --
        clk_pixel_i => clk_25MHz,
        --
    bram_addr_o => vga_textmode_bram_addr,
    bram_data_i => vga_textmode_bram_data_in,
    text_active_o => vga_textmode_text_active,
    --
    textfifo_addr_o => vga_textmode_text_addr,
    textfifo_data_i => vga_textmode_text_data,
    textfifo_strobe_o => vga_textmode_text_strobe,
    textfifo_rewind_o =>vga_textmode_text_rewind,
        --
    bitmap_strobe_o => vga_textmode_bitmap_strobe,
        bitmap_addr_o => vga_textmode_bitmap_addr,
        bitmap_ready_i => vga_textmode_bitmap_ready,
    bitmap_data_i => vga_textmode_bitmap_data,
    bitmap_rewind_o => vga_textmode_bitmap_rewind,
    bitmap_active_o => vga_textmode_bitmap_active,
        --
        red_o => vga_textmode_red,
        green_o => vga_textmode_green,
        blue_o => vga_textmode_blue,
        hsync_o => vga_textmode_hsync,
        vsync_o => vga_textmode_vsync,
        blank_o => vga_textmode_blank
      );

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
      -- data_in => from_sdram, -- from SDRAM or BRAM
      data_in => x"00000001", -- test pattern vertical lines
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
    bitmap_videofifo: entity work.videofifo
      generic map (
      C_step => C_vgatext_bitmap_fifo_step,
      C_width => C_vgatext_bitmap_fifo_width -- length = 4 * 2^width
      )
      port map (
        clk => clk,
        clk_pixel => clk_25MHz,
        addr_strobe => vga_addr_strobe,
        addr_out => vga_addr,
        data_ready => vga_data_ready, -- data valid for read acknowledge from RAM
        -- data_in => from_sdram, -- from SDRAM or BRAM
        data_in => x"00000001", -- test pattern vertical lines
        base_addr => vga_textmode_bitmap_addr,
      start => vga_textmode_bitmap_active,
      frame => vga_textmode_bitmap_frame,
      data_out => vga_textmode_bitmap_data,
      fetch_next => vga_textmode_bitmap_strobe
      );
      end generate;

      -- DVI-D Encoder Block (Thanks Hamster ;-)
      G_vgatext_dvid: entity work.dvid_out
      generic map (
        C_depth	=>	C_vgatext_bits
      )
      port map (
        clk_pixel => clk_25MHz,
        clk_tmds  => clk_250MHz,

        red_p   => vga_textmode_red(C_vgatext_bits-1 downto 0),
        green_p	=> vga_textmode_green(C_vgatext_bits-1 downto 0),
        blue_p	=> vga_textmode_blue(C_vgatext_bits-1 downto 0),

        blank	=> vga_textmode_blank,
        hsync	=> vga_textmode_hsync,
        vsync	=> vga_textmode_vsync,

        -- outputs to TMDS drivers
        tmds_out_rgb => tmds_out_rgb
      );
      -- analog vga output
      vga_r(7 downto 8-C_vgatext_bits) <= vga_textmode_red(C_vgatext_bits-1 downto 0);
      vga_r(7-C_vgatext_bits downto 0) <= (others => '0');
      vga_g(7 downto 8-C_vgatext_bits) <= vga_textmode_green(C_vgatext_bits-1 downto 0);
      vga_g(7-C_vgatext_bits downto 0) <= (others => '0');
      vga_b(7 downto 8-C_vgatext_bits) <= vga_textmode_blue(C_vgatext_bits-1 downto 0);
      vga_b(7-C_vgatext_bits downto 0) <= (others => '0');
      vga_vsync <= vga_textmode_vsync;
      vga_hsync <= vga_textmode_hsync;

      -- 8KB VGA textmode BRAM (for text+attribute bytes and font)
  G_vga_textmode_bram: if C_vgatext_text generate
	G_vgatext_bram: entity work.vga_textmode_bram
      generic map (
        C_mem_size    => C_vgatext_bram_mem,
        C_label	      => C_vgatext_label,
        C_monochrome  => C_vgatext_monochrome,
        C_font_height => C_vgatext_font_height,
        C_font_depth  => C_vgatext_font_depth
      )
      port map (
        clk => clk, imem_addr => vga_textmode_bram_addr, imem_data_out => vga_textmode_bram_data,
        dmem_write => vga_textmode_dmem_write,
        dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
        dmem_data_out => vga_textmode_dmem_to_cpu, dmem_data_in => cpu_to_dmem
      );
  end generate;

  vgatext_intr: process(clk)
  begin
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

  vga_textmode_bram_data_in <= vga_textmode_bram_data when (NOT C_vgatext_font_bram8 OR vga_textmode_bram_addr(15) = '0') else
    vga_textmode_bram_data(31 downto 8) & vga_textmode_bram8_data;

      vga_textmode_dmem_write <= dmem_addr_strobe and dmem_write when dmem_addr(31 downto 30) = "01" else '0';

  G_vgatext_bram8_wr: if C_vgatext_font_bram8 generate
    vga_textmode_dmem8_write <= dmem_addr_strobe and dmem_write when dmem_addr(31 downto 30) = "01" AND dmem_addr(15) = '1' else '0';
  end generate;

      with conv_integer(io_addr(11 downto 4)) select
            vga_textmode_ce <= io_addr_strobe when iomap_from(iomap_vga_textmode, iomap_range) to iomap_to(iomap_vga_textmode, iomap_range),
                               '0' when others;
    end generate; -- end VGA textmode

    -- FM/RDS
    G_fmrds:
    if C_fmrds generate
    fm_tx: entity work.fm
    generic map (
      c_fmdds_hz => C_fmdds_hz, -- Hz FMDDS clock frequency
      C_rds_msg_len => C_rds_msg_len, -- allocate RAM for RDS message
      C_stereo => C_fm_stereo,
      -- multiply/divide to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide
      -- example settings for 25 MHz clock
      -- c_rds_clock_multiply => 228,
      -- c_rds_clock_divide => 3125
      -- settings for super slow (100Hz debug) clock
      -- c_rds_clock_multiply => 1,
      -- c_rds_clock_divide => 812500
    )
    port map (
      clk => clk, -- RDS and PCM processing clock 81.25 MHz
      clk_fmdds => clk_fmdds,
      ce => fmrds_ce, addr => dmem_addr(3 downto 2),
      bus_write => dmem_write, byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem, bus_out => from_fmrds,
      pcm_in_left => (others => '0'),
      pcm_in_right => (others => '0'),
--      debug => from_fmrds,
      fm_antenna => fm_antenna
    );
    with conv_integer(io_addr(11 downto 4)) select
      fmrds_ce <= io_addr_strobe when iomap_from(iomap_fmrds, iomap_range) to iomap_to(iomap_fmrds, iomap_range),
                           '0' when others;
    end generate;

    -- Block RAM
    dmem_bram_write <=
      dmem_addr_strobe and dmem_write when dmem_addr(31 downto 30) = "00" else '0';

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
