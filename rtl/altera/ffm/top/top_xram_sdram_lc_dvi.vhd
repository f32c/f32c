-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

use work.f32c_pack.all;

entity ffm_xram_sdram is
    generic
    (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;
	C_branch_prediction: boolean := true;

	-- Main clock: 50/75/100
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 16;
	C_bram_const_init: boolean := true;
        C_icache_size: integer := 2;
        C_dcache_size: integer := 2;
        C_cached_addr_bits: integer := 26; -- for 64 MB SDRAM
        C_xram_emu_kb: integer := 128; -- KB XRAM emu size (power of 2, MAX 128 here)
        C_acram: boolean := false;
        C_sdram: boolean := false;
        C_sdram32: boolean := true;

        C_vector: boolean := true; -- vector processor unit (works up to 100 MHz)
        C_vector_axi: boolean := false; -- vector processor bus type (false: normal f32c)
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_bram_pass_thru: boolean := true; -- Cyclone-V won't compile with pass_thru=false
        C_vector_vaddr_bits: integer := 11;
        C_vector_vdata_bits: integer := 32;
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
        C_spi: integer := 2;
	C_gpio: integer := 32;
	C_timer: boolean := true;
	C_simple_io: boolean := true;

        C_dvid_ddr: boolean := false; -- generate HDMI with DDR, currently FFM v2r0 differential green wired wrong.
        C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 5:1024x768, 10:1920x1080
        C_hdmi_out: boolean := true;
        C_compositing2_write_while_reading: boolean := false; -- nonfunctional, can't be enabled for Cyclone-V

        C_vgahdmi: boolean := true; -- simple VGA bitmap with compositing
        C_vgahdmi_cache_size: integer := 0; -- KB (0 to disable, 2,4,8,16,32 to enable, leave disabled, cache flush not implemented)
        -- normally this should be actual bits per pixel
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
        C_vgahdmi_compositing: integer := 2; -- 2: default compositing2

        -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FFM f32c: 100MHz MIPS-compatible soft-core, 32MB SDRAM";
    C_vgatext_bits: integer := 4;   -- 4096 possible colors
    C_vgatext_bram_mem: integer := 8;   -- 8KB text+font  memory
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := true;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
    C_vgatext_font_bram8: boolean := true;    -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
    C_vgatext_char_height: integer := 8;   -- character cell height
    C_vgatext_font_height: integer := 8;    -- font height
    C_vgatext_font_depth: integer := 8;     -- font char depth, 7=128 characters or 8=256 characters
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
    C_vgatext_bitmap: boolean := false;     -- true for optional bitmap generation
    C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 16-color bitmap
    C_vgatext_bitmap_fifo: boolean := true;  -- disable bitmap FIFO
    -- step=horizontal width in pixels
    C_vgatext_bitmap_fifo_step: integer := 640;
    -- height=vertical height in pixels
    C_vgatext_bitmap_fifo_height: integer := 480;
    -- output data width 8bpp
    C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
    -- bitmap width of FIFO address space length = 2^width * 4 byte
    C_vgatext_bitmap_fifo_addr_width: integer := 11
    );
    port
    (
	clock_50a: in std_logic;
	-- RS232
	uart3_txd: out std_logic; -- rs232 txd
	uart3_rxd: in std_logic; -- rs232 rxd
	-- LED
	led: out std_logic;
	-- SD card (SPI)
        sd_m_clk, sd_m_cmd: out std_logic;
        sd_m_d: inout std_logic_vector(3 downto 0); 
        sd_m_cdet: in std_logic;
        -- SDRAM
	dr_clk: out std_logic;
	dr_cke: out std_logic;
	dr_cs_n: out std_logic;
	dr_a: out std_logic_vector(12 downto 0);
	dr_ba: out std_logic_vector(1 downto 0);
	dr_ras_n, dr_cas_n: out std_logic;
	dr_dqm: out std_logic_vector(3 downto 0);
	dr_d: inout std_logic_vector(31 downto 0);
	dr_we_n: out std_logic;
	-- FFM Module IO
	-- fio: inout std_logic_vector(69 downto 0);
	-- ADV7513 video chip
        dv_clk: inout std_logic;
        dv_sda: inout std_logic;
        dv_scl: inout std_logic;
        dv_int: inout std_logic;
        dv_de: inout std_logic;
        dv_hsync: inout std_logic;
        dv_vsync: inout std_logic;
        dv_spdif: inout std_logic;
        dv_mclk: inout std_logic;
        dv_i2s: inout std_logic_vector(3 downto 0);
        dv_sclk: inout std_logic;
        dv_lrclk: inout std_logic;
        dv_d: inout std_logic_vector(23 downto 0);
	-- Low-Cost HDMI video out
	vid_d_p, vid_d_n: out std_logic_vector(2 downto 0);
	vid_clk_p, vid_clk_n: out std_logic
    );
end;

architecture Behavioral of ffm_xram_sdram is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
  signal clk: std_logic;
  signal clk_pixel, clk_pixel_shift, clk_pixel_shift_n: std_logic;
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal ddr_dvid: std_logic_vector(3 downto 0);
  signal vid_lvds_p: std_logic_vector(3 downto 0);
  signal S_vga_blank: std_logic;
  signal S_vga_hsync, S_vga_vsync: std_logic;
  signal S_uart_break: std_logic := '0';
--  alias dv_clk: std_logic is fio(32);
--  alias dv_sda: std_logic is fio(33);
--  alias dv_scl: std_logic is fio(34);
--  alias dv_int: std_logic is fio(35);
--  alias dv_de: std_logic is fio(36);
--  alias dv_hsync: std_logic is fio(37);
--  alias dv_vsync: std_logic is fio(38);
--  alias dv_spdif: std_logic is fio(39);
--  alias dv_mclk: std_logic is fio(40);
--  alias dv_i2s: std_logic_vector(3 downto 0) is fio(44 downto 41);
--  alias dv_sclk: std_logic is fio(45);
--  alias dv_lrclk: std_logic is fio(46);
--  alias dv_d: std_logic_vector(23 downto 0) is fio(93 downto 70); -- attention, here must be reverse ordered bits
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
begin
    -- clock: generic, direct from onboard oscillator
    G_generic_clk:
    if C_clk_freq = 50 generate
      clk <= clock_50a;
      clk_pixel <= clock_50a; -- wrong, should be 25 MHz
      clk_pixel_shift <= clock_50a; -- wrong, should be 250 MHz
    end generate;

    G_75MHz_clk: if C_clk_freq = 75 and C_video_mode = 1 generate
    clkgen_75: entity work.clk_125p_125n_25_75_100
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel_shift,   --  125 MHz phase 0
      outclk_1 => clk_pixel_shift_n, --  125 MHz phase 180
      outclk_2 => clk_pixel,         --   25 MHz pixel clock
      outclk_3 => clk,               --   75 MHz CPU clock
      outclk_4 => open               --  100 MHz unused clock
    );
    end generate;

    G_100MHz_vidmod1_ddr_clk: if C_clk_freq = 100 and C_video_mode = 1 and C_dvid_ddr generate
    clkgen_100_vidmod1_ddr: entity work.clk_125p_125n_25_75_100
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel_shift,   --  125 MHz phase 0
      outclk_1 => clk_pixel_shift_n, --  125 MHz phase 180
      outclk_2 => clk_pixel,         --   25 MHz pixel clock
      outclk_3 => open,              --   75 MHz unused
      outclk_4 => clk                --  100 MHz CPU clock
    );
    end generate;

    G_100MHz_vidmod1_sdr_clk: if C_clk_freq = 100 and C_video_mode = 1 and not C_dvid_ddr generate
    clkgen_100_vidmod1_sdr: entity work.clk_250_25_75_100
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel_shift,   --  250 MHz pixel shift for HDMI
      outclk_1 => clk_pixel,         --   25 MHz pixel clock
      outclk_2 => open,              --   75 MHz unused
      outclk_3 => clk                --  100 MHz CPU clock
    );
    end generate;

    G_100MHz_vidmod2_clk: if C_clk_freq = 100 and C_video_mode = 2 generate
    clkgen_100_vidmod2: entity work.clk_148M44p_148M44n_29M69_79M16_98M96
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel_shift,   --  148.44 MHz unused
      outclk_1 => clk_pixel_shift_n, --  148.44 MHz phase 180 unused
      outclk_2 => clk_pixel,         --   29.69 MHz pixel clock
      outclk_3 => open,              --   79.16 MHz unused
      outclk_4 => clk                --   98.96 MHz CPU clock
    );
    end generate;

    G_100MHz_vidmod6_clk: if C_clk_freq = 100 and C_video_mode = 6 generate
    clkgen_100_vidmod6: entity work.clk_125p_125n_25_75_100
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => open,              --  125 MHz phase 0
      outclk_1 => open,              --  125 MHz phase 180
      outclk_2 => open,              --   25 MHz unused
      outclk_3 => clk_pixel,         --   75 MHz pixel clock
      outclk_4 => clk                --  100 MHz CPU clock
    );
    end generate;

    G_100MHz_vidmod10_clk: if C_clk_freq = 100 and C_video_mode = 10 generate
    clkgen_100_vidmod10: entity work.clk_148M44p_148M44n_29M69_79M16_98M96
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel,         --  148.44 MHz pixel clock
      outclk_1 => open,              --  148.44 MHz phase 180 unused
      outclk_2 => open,              --   29.69 MHz unused
      outclk_3 => open,              --   79.16 MHz unused
      outclk_4 => clk                --   98.96 MHz CPU clock
    );
    end generate;

    G_148MHz_vidmod2_clk: if C_clk_freq = 148 and C_video_mode = 2 generate
    clkgen_148_vidmod2: entity work.clk_148M44p_148M44n_29M69_79M16_98M96
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk,               --  148.44 MHz CPU clock
      outclk_1 => open,              --  148.44 MHz phase 180 unused
      outclk_2 => clk_pixel,         --   29.69 MHz pixel clock
      outclk_3 => open,              --   79.16 MHz unused
      outclk_4 => open               --   98.96 MHz unused
    );
    end generate;

    G_148MHz_vidmod10_clk: if C_clk_freq = 148 and C_video_mode = 10 generate
    clkgen_148_vidmod10: entity work.clk_148M44p_148M44n_29M69_79M16_98M96
    port map(
      refclk   => clock_50a,         --   50 MHz input from board
      rst      => '0',               --    0:don't reset
      outclk_0 => clk_pixel,         --  148.44 MHz CPU and pixel clock
      outclk_1 => open,              --  148.44 MHz phase 180 unused
      outclk_2 => open,              --   29.69 MHz unused
      outclk_3 => open,              --   79.16 MHz unused
      outclk_4 => open               --   98.96 MHz unused
    );
    clk <= clk_pixel; -- 148 MHz!
    end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_branch_prediction => C_branch_prediction,
      C_bram_size => C_bram_size,
      C_bram_const_init => C_bram_const_init,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_acram => C_acram,
      C_sdram => C_sdram,
      C_sdram32 => C_sdram32,
      C_sdram_address_width => 24,
      C_sdram_column_bits => 9,
      C_sdram_startup_cycles => 10100,
      C_sdram_cycles_per_refresh => 1524,
      -- vector processor
      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_registers => C_vector_registers,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_bram_pass_thru => C_vector_bram_pass_thru,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,
      -- vga simple bitmap
      C_dvid_ddr => C_dvid_ddr,
      C_compositing2_write_while_reading => C_compositing2_write_while_reading,
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_vgahdmi_compositing => C_vgahdmi_compositing,
      C_gpio => C_gpio,
      C_timer => C_timer,
      C_sio => C_sio,
      C_sio_init_baudrate => C_sio_init_baudrate,
      C_spi => C_spi,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_pixel,
      clk_pixel_shift => clk_pixel_shift,
      sio_txd(0) => uart3_txd, sio_rxd(0) => uart3_rxd,
      sio_break(0) => S_uart_break, -- at UART break, also resend i2c to ADV7513
      spi_sck(0)  => open,  spi_sck(1)  => sd_m_clk,
      spi_ss(0)   => open,  spi_ss(1)   => sd_m_d(3),
      spi_mosi(0) => open,  spi_mosi(1) => sd_m_cmd,
      spi_miso(0) => open,  spi_miso(1) => sd_m_d(0),
      gpio(31 downto 30) => open,
      gpio(29) => open, -- dv_sda,
      gpio(28) => open, -- dv_scl,
      gpio(27 downto 0) => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready,
      sdram_addr => dr_a, sdram_data => dr_d,
      sdram_ba => dr_ba, sdram_dqm => dr_dqm,
      sdram_ras => dr_ras_n, sdram_cas => dr_cas_n,
      sdram_cke => dr_cke, sdram_clk => dr_clk,
      sdram_we => dr_we_n, sdram_cs => dr_cs_n,
      -- ***** VGA *****
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync,
      vga_blank => S_vga_blank,
      vga_r => dv_d(23 downto 16),
      vga_g => dv_d(15 downto 8),
      vga_b => dv_d(7 downto 0),
      -- ***** DVI *****
      dvid_red   => dvid_red,
      dvid_green => dvid_green,
      dvid_blue  => dvid_blue,
      dvid_clock => dvid_clock,
      -- ***** Simple IO ******
      simple_out(0) => led,
      simple_out(31 downto 1) => open,
      simple_in(1 downto 0) => (others => '0'), simple_in(31 downto 2) => open
    );
    dv_clk <= clk_pixel;
    dv_hsync <= S_vga_hsync;
    dv_vsync <= S_vga_vsync;
    dv_de <= not S_vga_blank;

    G_yes_acram: if C_acram generate
    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 8 + ceil_log2(C_xram_emu_kb)
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(9 + ceil_log2(C_xram_emu_kb) downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
    );
    end generate;

    -- single eneded outputs simulating differential buffering for DVI clock and video
    G_sdr_dvi_out: if C_hdmi_out and not C_dvid_ddr generate
    dvi_output: entity work.hdmi_out
      port map
      (
        tmds_in_rgb    => dvid_red(0) & dvid_green(0) & dvid_blue(0),
        tmds_out_rgb_p => vid_d_p,   -- D2+ red  D1+ green  D0+ blue
        tmds_out_rgb_n => vid_d_n,   -- D2- red  D1- green  D0- blue
        tmds_in_clk    => dvid_clock(0),
        tmds_out_clk_p => vid_clk_p, -- CLK+ clock
        tmds_out_clk_n => vid_clk_n  -- CLK- clock
      );
    end generate;

    -- DDR output buffering for DVI clock and video
    G_ddr_dvi_out: if C_hdmi_out and C_dvid_ddr generate
    ddr_dvi_output: entity work.dvi_lvds
      port map
      (
        tx_in       => dvid_red & dvid_green & dvid_blue & dvid_clock,
        tx_inclock  => clk_pixel_shift,
        tx_out      => vid_lvds_p
      );
      vid_d_p <= vid_lvds_p(3 downto 1);
      vid_clk_p <= vid_lvds_p(0);

    i2c_send: entity work.i2c_sender_adv7513
      port map
      (
        clk => clk_pixel,
        resend => S_uart_break,
        sioc => dv_scl,
        siod => dv_sda
      );
    end generate;

end Behavioral;
