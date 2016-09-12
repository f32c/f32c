-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library lattice;
use lattice.components.all;

use work.f32c_pack.all;

entity sparrowhawk is
  generic (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 25, 28, 41, 81, 100 MHz
    C_clk_freq: integer := 25;

    -- SoC configuration options
    C_bram_size: integer := 2;
    C_acram: boolean := true;
    C_icache_size: integer := 2;
    C_dcache_size: integer := 2;
    C_sram8: boolean := false;
    C_branch_prediction: boolean := false;
    C_sio: integer := 2;
    C_spi: integer := 2;
    C_simple_io: boolean := true;
    C_gpio: integer := 32;
    C_gpio_pullup: boolean := false;
    C_gpio_adc: integer := 0; -- number of analog ports for ADC (on A0-A5 pins)

    C_vector: boolean := true; -- vector processor unit
    C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
    C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
    C_vector_vaddr_bits: integer := 11;
    C_vector_vdata_bits: integer := 32;
    C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
    C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
    C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

    -- video parameters common for vgahdmi and vgatext
    C_dvid_ddr: boolean := false; -- generate HDMI with DDR
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 5:1024x768

    C_vgahdmi: boolean := true;
    C_vgahdmi_cache_size: integer := 8;
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FleaFPGA-Uno f32c: 50MHz MIPS-compatible soft-core, 512KB SRAM";
    C_vgatext_bits: integer := 4;   -- 4096 possible colors
    C_vgatext_bram_mem: integer := 8;   -- 8KB text+font  memory
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := true;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
    C_vgatext_font_bram8: boolean := true;    -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
    C_vgatext_char_height: integer := 16;   -- character cell height
    C_vgatext_font_height: integer := 16;    -- font height
    C_vgatext_font_depth: integer := 8;     -- font char depth, 7=128 characters or 8=256 characters
    C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
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
  port (
  clk_100_p, clk_100_n: in std_logic;  -- main clock input from 100MHz clock source
  cy_clkout: in std_logic;  -- cypress CPU clock, firmware configurable 12/24/48MHz clock source

  -- UART0 (USB slave serial)
  tx: out   std_logic;
  rx: in    std_logic;

  -- we have to output from hdmi_pcs module
  -- otherwise hdmi_pcs will be removed by the optimizer
  dvi_output0_hdoutp, dvi_output0_hdoutn, dvi_output0_half_clk, dvi_output0_full_clk: out std_logic_vector(3 downto 0);
  dvi_output1_hdoutp, dvi_output1_hdoutn, dvi_output1_half_clk, dvi_output1_full_clk: out std_logic_vector(3 downto 0);

  -- ASIC side pins for PCSD.  These pins must exist for the PCS core.
  refclkp, refclkn, hdinp_ch0, hdinn_ch0, hdinp_ch1, hdinn_ch1, hdinp_ch2, hdinn_ch2, hdinp_ch3, hdinn_ch3: in std_logic;
  hdoutp_ch0, hdoutn_ch0, hdoutp_ch1, hdoutn_ch1, hdoutp_ch2, hdoutn_ch2, hdoutp_ch3, hdoutn_ch3: out std_logic;

  -- hdmi auxiliary signals
  hdmi_out_oe_n_0, hdmi_out_oe_n_1: out std_logic := '0';
  hdmi_out_ddc_en_0, hdmi_out_ddc_en_1: out std_logic := '1';
  hdmi_out_hpd_0, hdmi_out_hpd_1: out std_logic := '1';

  led: out std_logic_vector(7 downto 0);
  btn, dip: in std_logic_vector(3 downto 0);

  hdr_io: inout std_logic_vector(21 downto 0);

  -- SD card
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic;
  sd_clk, sd_pwrn: out std_logic;
  sd_cdn, sd_wp: in std_logic;

  -- SPI1 to Flash ROM
  flash_miso   : in      std_logic;
  flash_mosi   : out     std_logic;
  flash_clk    : out     std_logic;
  flash_csn    : out     std_logic
  );
end;

architecture Behavioral of sparrowhawk is
  component ILVDS
    port (A, AN: in std_logic; Z: out std_logic);
  end component;

  component hdmi_transmitter
  port
  (
    rstn, resync, txclk: in std_logic;
    tx_video_ch0, tx_video_ch1, tx_video_ch2: in std_logic_vector(7 downto 0);
    tx_audio_ch0, tx_audio_ch1, tx_audio_ch2: in std_logic_vector(3 downto 0);
    tx_ctl: in std_logic_vector(3 downto 0);
    tx_hsync, tx_vsync, tx_vde, tx_ade, tx_format: in std_logic;
    red_fill, green_fill, blue_fill, audio_mute: in std_logic;
    hdmi_txd_ch0, hdmi_txd_ch1, hdmi_txd_ch2: out std_logic_vector(9 downto 0)
  );
  end component;

  component sci_config
  port
  (
    rstn, pix_clk, osc_clk, force_tx_en, sel_low_res: in std_logic;
    sci_active, sci_wren: out std_logic;
    sci_addr: out std_logic_vector(8 downto 0);
    sci_data: out std_logic_vector(7 downto 0)
  );
  end component;

  signal clk, rs232_break, rs232_break2: std_logic;
  signal clk_100: std_logic;
  signal clk_dvi, clk_dvin, clk_pixel: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal vga_hsync, vga_vsync: std_logic;
  signal vga_r, vga_g, vga_b: std_logic_vector(7 downto 0);
  signal dvi_clk: std_logic_vector(9 downto 0) := "0000011111";
  signal dvi_r, dvi_g, dvi_b: std_logic_vector(9 downto 0);
  signal flip_dvi_clk: std_logic_vector(9 downto 0) := "1111100000"; -- PCS takes this as input
  signal flip_dvi_r, flip_dvi_g, flip_dvi_b: std_logic_vector(9 downto 0);
  signal dvi_pcs_tx_clk: std_logic; -- full rate tx clock 165 MHz
  signal dvi_pcs_tx_serdes_rst_c, dvi_pcs_tx_sync_qd_c, dvi_pcs_rst_n, dvi_pcs_serdes_rst_qd_c: std_logic;
  signal sci_sel_ch: std_logic_vector (3 downto 0);
  signal sci_wrdata: std_logic_vector (7 downto 0);
  signal sci_addr: std_logic_vector (8 downto 0);
  signal sci0_rddata, sci1_rddata: std_logic_vector (7 downto 0);
  signal sci_sel_quad: std_logic;
  signal sci_rd: std_logic;
  signal sci_wrn, sci_wren: std_logic;
  signal sci0_int, sci1_int: std_logic;

  signal R_blinky: std_logic_vector(23 downto 0);
begin
  -- convert external differential clock input to internal single ended clock
  clock_diff2se:
  ILVDS port map(A=>clk_100_p, AN=>clk_100_n, Z=>clk_100);

  video_mode_1_640x480_100MHz: if C_clk_freq=100 and C_video_mode=1 generate
  clk_640x480_100M: entity work.clk_100M_150M_25M
  port map(
    CLK    => clk_100,
    CLKOP  => dvi_pcs_tx_clk,
    CLKOS  => clk_dvin,
    CLKOK  => clk_pixel
   );
   clk <= clk_100;
  end generate;

  video_mode_1_640x480_25MHz: if C_clk_freq=25 and C_video_mode=1 generate
  clk_640x480_25M: entity work.clk_100M_150M_25M
  port map(
    CLK    => clk_100,
    CLKOP  => dvi_pcs_tx_clk,
    CLKOS  => clk_dvin,
    CLKOK  => clk_pixel
   );
   clk <= clk_pixel;
  end generate;

  video_mode_1_640x480_81MHz: if C_clk_freq=81 and C_video_mode=1 generate
  clk_640x480_81M25: entity work.clkgen_100_81M25_40M625_27M083
  port map(
    CLK         => clk_100,
    CLKOP       => clk
--    CLKOP       =>  clk_dvi,
--    CLKOS       =>  clk_dvin,
--    CLKOS2      =>  clk_pixel,
--    CLKOS3      =>  clk
   );
  end generate;

  video_mode_1_640x480_81MHz: if C_clk_freq=41 and C_video_mode=1 generate
  clk_640x480_40M625: entity work.clkgen_100_81M25_40M625_27M083
  port map(
    CLK         => clk_100,
    CLKOK       => clk
--    CLKOP       =>  clk_dvi,
--    CLKOS       =>  clk_dvin,
--    CLKOS2      =>  clk_pixel,
--    CLKOS3      =>  clk
   );
  end generate;

  video_mode_2_800x480_28MHz: if C_clk_freq=28 and C_video_mode=2 generate
  clk_800x480_28M: entity work.clk_100M_165M_27M5
  port map(
    CLK    => clk_100,
    CLKOP  => dvi_pcs_tx_clk,
    CLKOS  => clk_dvin,
    CLKOK  => clk_pixel
   );
   clk <= clk_pixel;
  end generate;

  -- full feature XRAM glue
  glue_xram: entity work.glue_xram
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_acram => C_acram,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_sram8 => C_sram8,
    C_debug => C_debug,
    C_sio => C_sio,
    C_spi => C_spi,
    C_gpio => C_gpio,
    C_gpio_pullup => C_gpio_pullup,
    C_gpio_adc => C_gpio_adc,
    C_branch_prediction => C_branch_prediction,

    C_vector => C_vector,
    C_vector_axi => C_vector_axi,
    C_vector_registers => C_vector_registers,
    C_vector_vaddr_bits => C_vector_vaddr_bits,
    C_vector_vdata_bits => C_vector_vdata_bits,
    C_vector_float_addsub => C_vector_float_addsub,
    C_vector_float_multiply => C_vector_float_multiply,
    C_vector_float_divide => C_vector_float_divide,

    C_dvid_ddr => C_dvid_ddr,
    -- vga simple compositing bitmap only graphics
    C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
    -- vga textmode + bitmap full feature graphics
    C_vgatext => C_vgatext,
        C_vgatext_label => C_vgatext_label,
        C_vgatext_mode => C_video_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_bus_read => C_vgatext_bus_read,
        C_vgatext_reg_read => C_vgatext_reg_read,
        C_vgatext_text => C_vgatext_text,
        C_vgatext_font_bram8 => C_vgatext_font_bram8,
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
        C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
        C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width
  )
  port map (
    clk => clk,
    clk_pixel => clk_pixel,
    clk_pixel_shift => '0',
    sio_rxd(0) => rx,
    --sio_rxd(1) => open,
    sio_txd(0) => tx,
    --sio_txd(1) => open,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,

    spi_sck(0)  => flash_clk,  spi_sck(1)  => sd_clk,
    spi_ss(0)   => flash_csn,  spi_ss(1)   => sd_dat3_csn,
    spi_mosi(0) => flash_mosi, spi_mosi(1) => sd_cmd_di,
    spi_miso(0) => flash_miso, spi_miso(1) => sd_dat0_do,

    gpio(127 downto 22) => open,
    gpio(21 downto 0) => hdr_io,

    simple_out(7 downto 0) => led(7 downto 0),
    simple_out(31 downto 8) => open,
    simple_in(3 downto 0) => btn,
    simple_in(19 downto 16) => dip,

    acram_addr(16 downto 2) => ram_address(16 downto 2),
    acram_data_wr => ram_data_write,
    acram_data_rd => ram_data_read,
    acram_byte_we => ram_byte_we,
    acram_ready => ram_ready,
    acram_en => ram_en,

    -- vga_hsync => vga_hsync, vga_vsync => vga_vsync,
    -- vga_r => vga_r, vga_g => vga_g, vga_b => vga_b,
    dvi_r => dvi_r, dvi_g => dvi_g, dvi_b => dvi_b
  );

  acram_emulation: entity work.acram_emu
  generic map
  (
      C_addr_width => 15
  )
  port map
  (
      clk => clk,
      acram_a => ram_address(16 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
  );

  flip_dvi_signals:
  for i in 0 to 9 generate
    -- f32c outputs HDMI reverse bit order?
    -- flip the bit order MSB<->LSB
    flip_dvi_clk(i) <= dvi_clk(9-i);
    flip_dvi_r(i) <= dvi_r(9-i);
    flip_dvi_g(i) <= dvi_g(9-i);
    flip_dvi_b(i) <= dvi_b(9-i);
  end generate;

  -- vendor specific modules for DVI output
  -- for channel order, see sparrowhawk user's manual table 7
  i_dvi_output0: entity hdmi_pcs
  --generic map ( USER_CONFIG_FILE => "hdmi_pcs.txt" )
  port map
  (
    fpga_txrefclk => dvi_pcs_tx_clk,

    txiclk_ch0 => clk_pixel,
    txdata_ch0 => flip_dvi_r, -- HDMI D2 red
    hdoutp_ch0 => dvi_output0_hdoutp(0),
    hdoutn_ch0 => dvi_output0_hdoutn(0),
    tx_full_clk_ch0 => dvi_output0_full_clk(0),
    tx_half_clk_ch0 => dvi_output0_half_clk(0),
    tx_pwrup_ch0_c => '1',
    tx_div2_mode_ch0_c => '0',
    sci_sel_ch0 => sci_sel_ch(0),

    txiclk_ch1 => clk_pixel,
    txdata_ch1 => flip_dvi_g, -- HDMI D1 green
    hdoutp_ch1 => dvi_output0_hdoutp(1),
    hdoutn_ch1 => dvi_output0_hdoutn(1),
    tx_full_clk_ch1 => dvi_output0_full_clk(1),
    tx_half_clk_ch1 => dvi_output0_half_clk(1),
    tx_pwrup_ch1_c => '1',
    tx_div2_mode_ch1_c => '0',
    sci_sel_ch1 => sci_sel_ch(1),

    txiclk_ch2 => clk_pixel,
    txdata_ch2 => flip_dvi_b, -- HDMI D0 blue
    hdoutp_ch2 => dvi_output0_hdoutp(2),
    hdoutn_ch2 => dvi_output0_hdoutn(2),
    tx_full_clk_ch2 => dvi_output0_full_clk(2),
    tx_half_clk_ch2 => dvi_output0_half_clk(2),
    tx_pwrup_ch2_c => '1',
    tx_div2_mode_ch2_c => '0',
    sci_sel_ch2 => sci_sel_ch(2),

    txiclk_ch3 => clk_pixel,
    txdata_ch3 => flip_dvi_clk, -- HDMI clock
    hdoutp_ch3 => dvi_output0_hdoutp(3),
    hdoutn_ch3 => dvi_output0_hdoutn(3),
    tx_full_clk_ch3 => dvi_output0_full_clk(3),
    tx_half_clk_ch3 => dvi_output0_half_clk(3),
    tx_pwrup_ch3_c => '1',
    tx_div2_mode_ch3_c => '0',
    sci_sel_ch3 => sci_sel_ch(3),

    -- auxilliary control
    sci_wrdata => sci_wrdata,
    sci_addr => sci_addr(5 downto 0),
    sci_rddata => sci0_rddata,
    sci_sel_quad => sci_sel_quad,
    sci_rd => sci_rd,
    sci_wrn => sci_wrn,
    sci_int => sci0_int,
    tx_serdes_rst_c => '0',
    tx_sync_qd_c => '0',
    serdes_rst_qd_c => '0',
    rst_n => '1'
  );

  i_dvi_output1: entity hdmi_pcs
  --generic map ( USER_CONFIG_FILE => "hdmi_pcs.txt" )
  port map
  (
    fpga_txrefclk => dvi_pcs_tx_clk,

    txiclk_ch0 => clk_pixel,
    txdata_ch0 => flip_dvi_r, -- HDMI D2 red
    hdoutp_ch0 => dvi_output1_hdoutp(0),
    hdoutn_ch0 => dvi_output1_hdoutn(0),
    tx_full_clk_ch0 => dvi_output1_full_clk(0),
    tx_half_clk_ch0 => dvi_output1_half_clk(0),
    tx_pwrup_ch0_c => '1',
    tx_div2_mode_ch0_c => '0',
    sci_sel_ch0 => sci_sel_ch(0),

    txiclk_ch1 => clk_pixel,
    txdata_ch1 => flip_dvi_g, -- HDMI D1 green
    hdoutp_ch1 => dvi_output1_hdoutp(1),
    hdoutn_ch1 => dvi_output1_hdoutn(1),
    tx_full_clk_ch1 => dvi_output1_full_clk(1),
    tx_half_clk_ch1 => dvi_output1_half_clk(1),
    tx_pwrup_ch1_c => '1',
    tx_div2_mode_ch1_c => '0',
    sci_sel_ch1 => sci_sel_ch(1),

    txiclk_ch2 => clk_pixel,
    txdata_ch2 => flip_dvi_b, -- HDMI D0 blue
    hdoutp_ch2 => dvi_output1_hdoutp(2),
    hdoutn_ch2 => dvi_output1_hdoutn(2),
    tx_full_clk_ch2 => dvi_output1_full_clk(2),
    tx_half_clk_ch2 => dvi_output1_half_clk(2),
    tx_pwrup_ch2_c => '1',
    tx_div2_mode_ch2_c => '0',
    sci_sel_ch2 => sci_sel_ch(2),

    txiclk_ch3 => clk_pixel,
    txdata_ch3 => flip_dvi_clk, -- HDMI clock
    hdoutp_ch3 => dvi_output1_hdoutp(3),
    hdoutn_ch3 => dvi_output1_hdoutn(3),
    tx_full_clk_ch3 => dvi_output1_full_clk(3),
    tx_half_clk_ch3 => dvi_output1_half_clk(3),
    tx_pwrup_ch3_c => '1',
    tx_div2_mode_ch3_c => '0',
    sci_sel_ch3 => sci_sel_ch(3),

    -- auxilliary control
    sci_wrdata => sci_wrdata,
    sci_addr => sci_addr(5 downto 0),
    sci_rddata => sci1_rddata,
    sci_sel_quad => sci_sel_quad,
    sci_rd => sci_rd,
    sci_wrn => sci_wrn,
    sci_int => sci1_int,
    tx_serdes_rst_c => '0',
    tx_sync_qd_c => '0',
    serdes_rst_qd_c => '0',
    rst_n => '1'
  );

  i_sci_config: sci_config
  port map
  (
    rstn => '1',
    pix_clk => clk_pixel,
    osc_clk => clk_100,
    force_tx_en => '1',
    sel_low_res => '1',
    sci_active => open,
    sci_wren => sci_wren,
    sci_addr => sci_addr,
    sci_data => sci_wrdata
  );

  sci_rd <= '0';
  sci_wrn <= not sci_wren;
  sci_sel_quad <= sci_addr(8) and (not sci_addr(7)) and (not sci_addr(6));

  -- clock alive blinky
  process(dvi_pcs_tx_clk)
  begin
      if rising_edge(dvi_pcs_tx_clk) then
        R_blinky <= R_blinky+1;
      end if;
  end process;
  --led(7) <= R_blinky(R_blinky'high);

  --led(7 downto 4) <= vga_g(7 downto 4);
  --led(7 downto 4) <= flip_dvi_b(7 downto 4);

end Behavioral;
