-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

use work.f32c_pack.all;

library ecp5u;
use ecp5u.components.all;

entity ulx3s_xram_sdram_vector is
  generic (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 25/78/100 MHz
    C_clk_freq: integer := 100;

    -- SoC configuration options
    C_bram_size: integer := 2;
    C_acram: boolean := false;
    C_acram_emu_kb: integer := 32; -- KB axi_cache emulation (power of 2)
    C_sdram: boolean := true;
    C_icache_size: integer := 2;
    C_dcache_size: integer := 2;
    C_sram8: boolean := false;
    C_branch_prediction: boolean := false;
    C_sio: integer := 2;
    C_spi: integer := 2;
    C_simple_io: boolean := true;
    C_gpio: integer := 64;
    C_gpio_pullup: boolean := false;
    C_gpio_adc: integer := 0; -- number of analog ports for ADC (on A0-A5 pins)
    C_timer: boolean := true;

    C_pcm: boolean := true; -- PCM audio (wav playing)
    C_synth: boolean := false; -- Polyphonic synth
      C_synth_zero_cross: boolean := true; -- volume changes at zero-cross, spend 1 BRAM to remove clicks
      C_synth_amplify: integer := 0; -- 0 for 24-bit digital reproduction, 5 for PWM (clipping possible)
    C_spdif: boolean := false; -- SPDIF output (to audio jack tip)

    C_cw_simple_out: integer := 7; -- simple_out bit for 433MHz modulator. -1 to disable. for 433MHz transmitter set (C_framebuffer => false, C_dds => false)

    C_vector: boolean := true; -- vector processor unit
    C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
    C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
    C_vector_vaddr_bits: integer := 11;
    C_vector_vdata_bits: integer := 32;
    C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
    C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
    C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

    -- video parameters common for vgahdmi and vgatext
    C_dvid_ddr: boolean := true; -- generate HDMI with DDR
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 5:1024x768

    C_vgahdmi: boolean := true;
    C_vgahdmi_cache_size: integer := 8;
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
    C_vgahdmi_cache_size: integer := 0;
    C_vgahdmi_cache_use_i: boolean := false;

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "ULX3S f32c: 100MHz MIPS-compatible soft-core, 32MB SDRAM";
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
  clk_25MHz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic := 'Z'; -- '0' will disable wifi by default
  wifi_gpio0, wifi_gpio2, wifi_gpio16, wifi_gpio17: inout std_logic := 'Z';

  -- ADC MAX11123
  adc_csn, adc_sclk, adc_mosi: out std_logic;
  adc_miso: in std_logic;

  -- SDRAM
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

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(3 downto 0);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO
  gp, gn: inout std_logic_vector(27 downto 0);

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0';

  -- Audio jack 3.5mm
  audio_l, audio_r, audio_v: inout std_logic_vector(3 downto 0) := (others => 'Z');

  -- Onboard antenna 433 MHz
  ant_433mhz: out std_logic;

  -- Digital Video (differential outputs)
  gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  gpdi_clkp, gpdi_clkn: out std_logic;

  -- i2c shared for digital video and RTC
  gpdi_scl, gpdi_sda: inout std_logic;

  -- Flash ROM (SPI0)
  -- commented out because it can't be used as GPIO
  -- when bitstream is loaded from config flash
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic;
  sd_clk: out std_logic;
  sd_cdn, sd_wp: in std_logic
  );
end;

architecture Behavioral of ulx3s_xram_sdram_vector is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
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
  signal ddr_d: std_logic_vector(2 downto 0);
  signal ddr_clk: std_logic;
  signal R_blinky: std_logic_vector(26 downto 0);
  signal S_spdif_out: std_logic;

  component OLVDS
    port(A: in std_logic; Z, ZN: out std_logic);
  end component;

begin
  minimal_25MHz: if C_clk_freq=25 and C_video_mode=-1 generate
    clk <= clk_25MHz;
  end generate;

  ddr_640x480_25MHz: if C_clk_freq=25 and (C_video_mode=0 or C_video_mode=1) generate
  clk_25M: entity work.clk_25_100_125_25
    port map(
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  open       -- 100 MHz
     );
    clk <= clk_pixel; 
  end generate;

  ddr_640x480_78MHz: if C_clk_freq=78 and (C_video_mode=0 or C_video_mode=1) generate
  clk_78M: entity work.clk_25_78_125_25
    port map(
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  clk        --  78.125 MHz CPU
     );
  end generate;

  ddr_640x480_100MHz: if C_clk_freq=100 and (C_video_mode=0 or C_video_mode=1) generate
  clk_100M: entity work.clk_25_100_125_25
    port map(
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  clk        -- 100 MHz CPU
     );
  end generate;

  -- full featured XRAM glue
  glue_xram: entity work.glue_xram
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_branch_prediction => C_branch_prediction,
    C_acram => C_acram,
    C_sdram => C_sdram,
    C_sdram_address_width => 24,
    C_sdram_column_bits => 9,
    C_sdram_startup_cycles => 10100,
    C_sdram_cycles_per_refresh => 1524,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_sram8 => C_sram8,
    C_debug => C_debug,
    C_sio => C_sio,
    C_spi => C_spi,
    C_gpio => C_gpio,
    C_gpio_pullup => C_gpio_pullup,
    C_gpio_adc => C_gpio_adc,
    C_timer => C_timer,

    -- DMA wav playing
    C_pcm => C_pcm,
    -- Polyphonic sound synthesizer (todo: support synth in vector glue)
    --C_synth => C_synth,
    --C_synth_zero_cross => C_synth_zero_cross,
    --C_synth_amplify => C_synth_amplify,
    -- SPDIF output
    --C_spdif => C_spdif,

    C_cw_simple_out => C_cw_simple_out,

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
    clk_pixel_shift => clk_dvi,
    sio_rxd(0) => ftdi_txd,
    sio_rxd(1) => wifi_txd,
    sio_txd(0) => ftdi_rxd,
    sio_txd(1) => wifi_rxd,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,

    spi_sck(0)  => open,  spi_sck(1)  => sd_clk,
    spi_ss(0)   => open,  spi_ss(1)   => sd_dat3_csn,
    spi_mosi(0) => open,  spi_mosi(1) => sd_cmd_di,
    spi_miso(0) => '0',   spi_miso(1) => sd_dat0_do,

    gpio(127 downto 28+32) => open,
    gpio(27+32 downto 32) => gn(27 downto 0),
    gpio(31 downto 30) => open,
    gpio(29) => gpdi_sda,
    gpio(28) => gpdi_scl,
    gpio(27 downto 0) => gp(27 downto 0),
    simple_out(31 downto 19) => open,
    simple_out(18) => adc_mosi,
    simple_out(17) => adc_sclk,
    simple_out(16) => adc_csn,
    simple_out(15) => open,
    simple_out(14) => open, -- wifi_en
    simple_out(13) => shutdown,
    simple_out(12) => oled_csn,
    simple_out(11) => oled_dc,
    simple_out(10) => oled_resn,
    simple_out(9) => oled_mosi,
    simple_out(8) => oled_clk,
    simple_out(7 downto 0) => led(7 downto 0),
    simple_in(31 downto 21) => (others => '0'),
    simple_in(20) => adc_miso,
    simple_in(19 downto 16) => sw,
    simple_in(15 downto 7) => (others => '0'),
    simple_in(6 downto 0) => btn,

    -- 2 MSB audio channel bits are not used in "default" setup.
    jack_tip(3 downto 2) => audio_l(1 downto 0),
    jack_ring(3 downto 2) => audio_r(1 downto 0),
    -- 4-bit could be used down to 75 ohm load
    -- but FPGA will stop working (IO overload)
    -- if standard 17 ohm earphones are plugged.
    --jack_tip => audio_l,
    --jack_ring => audio_r,

    cw_antenna => ant_433mhz,

    -- external SDRAM interface
    sdram_addr => sdram_a, sdram_data => sdram_d,
    sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
    sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
    sdram_cke => sdram_cke, sdram_clk => sdram_clk,
    sdram_we => sdram_wen, sdram_cs => sdram_csn,

    dvid_red   => dvid_red,
    dvid_green => dvid_green,
    dvid_blue  => dvid_blue,
    dvid_clock => dvid_clock
  );

  G_acram: if C_acram generate
  acram_emulation: entity work.acram_emu
  generic map
  (
      C_addr_width => 8 + ceil_log2(C_acram_emu_kb)
  )
  port map
  (
      clk => clk,
      acram_a => ram_address(9 + ceil_log2(C_acram_emu_kb) downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
  );
  end generate;

  -- this module instantiates vendor specific modules ddr_out to
  -- convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  G_vgatext_ddrout: entity work.ddr_dvid_out_se
  port map
  (
    clk       => clk_dvi,
    clk_n     => clk_dvin,
    in_red    => dvid_red,
    in_green  => dvid_green,
    in_blue   => dvid_blue,
    in_clock  => dvid_clock,
    out_red   => ddr_d(2),
    out_green => ddr_d(1),
    out_blue  => ddr_d(0),
    out_clock => ddr_clk
  );

  gpdi_data_channels: for i in 0 to 2 generate
    gpdi_diff_data: OLVDS
    port map(A => ddr_d(i), Z => gpdi_dp(i), ZN => gpdi_dn(i));
  end generate;
  gpdi_diff_clock: OLVDS
  port map(A => ddr_clk, Z => gpdi_clkp, ZN => gpdi_clkn);

  -- clock alive blinky
  process(clk)
  begin
      if rising_edge(clk) then
        R_blinky <= R_blinky+1;
      end if;
  end process;

  -- led(7) <= R_blinky(R_blinky'high);
  -- test staircase ramp voltage on AUDIO:
  --audio_l <= R_blinky(R_blinky'high-4 downto R_blinky'high-7);
  --audio_r <= R_blinky(R_blinky'high-4 downto R_blinky'high-7);
  --audio_v <= R_blinky(R_blinky'high-4 downto R_blinky'high-7);
  
  wifi_gpio0 <= btn(0); -- pressing BTN0 will escape to ESP32 file select menu

end Behavioral;
