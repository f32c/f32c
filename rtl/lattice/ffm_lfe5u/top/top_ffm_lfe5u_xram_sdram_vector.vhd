-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

use work.f32c_pack.all;

use work.boot_block_pack.all;
use work.boot_sio_mi32el.all;
use work.boot_sio_mi32eb.all;
use work.boot_sio_rv32el.all;
use work.boot_rom_mi32el.all;

library ecp5u;
use ecp5u.components.all;

entity ffm_lfe5u_xram_sdram_vector is
  generic
  (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 25/78/100 MHz
    C_clk_freq: integer := 100;

    -- SoC configuration options
    C_xboot_rom: boolean := false; -- false default, bootloader initializes XRAM with external DMA
    C_bram_size: integer := 2; -- 2 default, must be disabled with 0 when C_xboot_emu = true
    C_bram_const_init: boolean := true; -- true default, MAX10 cannot preload bootloader using VHDL constant intializer
    C_boot_write_protect: boolean := true; -- true default, may leave boot block writeable to save some LUTs
    C_boot_rom_data_bits: integer := 32; -- number of bits in output from bootrom_emu
    C_boot_spi: boolean := true; -- SPI bootloader is larger and allows setting of baudrate
    C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- 8 default for C_xboot_rom=false, 0 for C_xboot_rom=true, sets XRAM base address
    C_acram: boolean := false; -- false default (ulx3s has sdram chip)
    C_acram_wait_cycles: integer := 3; -- 3 or more
    C_acram_emu_kb: integer := 128; -- KB axi_cache emulation (power of 2)
    C_sdram: boolean := false; -- 16-bit SDRAM
    C_sdram32: boolean := true; -- 32-bit SDRAM
    C_sdram_clock_range: integer := 1; -- standard value good for all
    C_icache_size: integer := 2; -- 2 default
    C_dcache_size: integer := 2; -- 2 default
    C_cached_addr_bits: integer := 25; -- lower address bits than C_cached_addr_bits are cached
    C_branch_prediction: boolean := false; -- false default
    C_sio: integer := 2; -- 2 default
    C_spi: integer := 2; -- 2 default
    C_simple_io: boolean := true; -- true default
    C_gpio: integer := 64; -- 64 default for ulx3s
    C_gpio_pullup: boolean := false; -- false default
    C_gpio_adc: integer := 0; -- number of analog ports for ADC (on A0-A5 pins)
    C_timer: boolean := true; -- true default
    C_pcm: boolean := true; -- PCM audio (wav playing)
    C_synth: boolean := false; -- Polyphonic synth
      C_synth_zero_cross: boolean := true; -- volume changes at zero-cross, spend 1 BRAM to remove clicks
      C_synth_amplify: integer := 0; -- 0 for 24-bit digital reproduction, 5 for PWM (clipping possible)
    C_spdif: boolean := false; -- SPDIF output
    C_cw_simple_out: integer := 7; -- 7 default, simple_out bit for 433MHz modulator. -1 to disable. for 433MHz transmitter set (C_framebuffer => false, C_dds => false)

    C_vector: boolean := true; -- vector processor unit
    C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
    C_vector_bram_pass_thru: boolean := false; -- false: default, true: c2_vector_fast won't work
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
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
    C_vgahdmi_cache_size: integer := 0; -- 0 default (disabled, cache flush not yet implemented)
    C_vgahdmi_cache_use_i: boolean := false;
    C_compositing2_write_while_reading: boolean := true; -- default true

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FFM-LFE5U f32c: 100MHz MIPS-compatible soft-core, 64MB SDRAM";
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
  port
  (
  clk_100mhz_p: in std_logic;  -- main clock input from 100MHz differential clock source
  usb_clk, eth_clk: in std_logic; -- USB 60 MHz and ETH 50 MHz single ended clocks

  -- UART3 (FT4232 port 3) direction named from FPGA standpoint
  uart3_txd: out   std_logic;
  uart3_rxd: in    std_logic;

  -- SDRAM
  dr_clk: out std_logic;
  dr_cke: out std_logic;
  dr_cs_n: out std_logic;
  dr_ras_n: out std_logic;
  dr_cas_n: out std_logic;
  dr_we_n: out std_logic;
  dr_a: out std_logic_vector (12 downto 0);
  dr_ba: out std_logic_vector(1 downto 0);
  dr_dqm: out std_logic_vector(3 downto 0);
  dr_d: inout std_logic_vector (31 downto 0);

  -- Onboard blinky
  led: out std_logic_vector(3 downto 1);

  -- GPIO
  fioa: inout std_logic_vector(7 downto 0);
  fiob: inout std_logic_vector(31 downto 20);
  fioc: inout std_logic_vector(69 downto 47);

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

  -- Digital Video (differential outputs)
  vid_d_p, vid_d_n: out std_logic_vector(3 downto 0);
  vid_rscl, vid_rsda: inout std_logic;

  -- Flash ROM (SPI0)
  -- commented out because it can't be used as GPIO
  -- when bitstream is loaded from config flash
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_m_cmd: inout std_logic := 'Z';
  sd_m_d: inout std_logic_vector(3 downto 0) := (others => 'Z');
  sd_m_clk: inout std_logic := 'Z';
  sd_m_cdet: in std_logic
  );
end;

architecture Behavioral of ffm_lfe5u_xram_sdram_vector is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
  signal clk, S_sio_break, S_sio_break2: std_logic;
  signal clk_100: std_logic;
  signal clk_pixel_shift, clk_pixel: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
  signal dvid_crgb: std_logic_vector(7 downto 0);
  signal ddr_d: std_logic_vector(3 downto 0);
  signal S_vga_blank: std_logic;
  signal S_vga_hsync, S_vga_vsync: std_logic;
  signal R_blinky: std_logic_vector(26 downto 0);
  signal S_spdif_out: std_logic;

  signal S_reset: std_logic := '0'; -- reset to hold during DMA preload
  -- exposed DMA signals for boot preloader
  signal xdma_addr: std_logic_vector(29 downto 2) := ('0', others => '0'); -- preload address 0x00000000 XRAM
  signal xdma_strobe: std_logic := '0';
  signal xdma_data_ready: std_logic := '0';
  signal xdma_write: std_logic := '0';
  signal xdma_byte_sel: std_logic_vector(3 downto 0) := (others => '1');
  signal xdma_data_in: std_logic_vector(31 downto 0) := (others => '-');
  -- signals for ROM emulation
  signal S_rom_reset, S_rom_next_data: std_logic;
  signal S_rom_data: std_logic_vector(C_boot_rom_data_bits-1 downto 0);
  signal S_rom_valid: std_logic;

  -- dual ESP32/f32c programming mode
  signal S_rxd, S_txd: std_logic; -- mix USB and WiFi
  signal S_prog_in, S_prog_out: std_logic_vector(1 downto 0);
  signal R_esp32_mode: std_logic := '0';
  signal S_f32c_sd_csn, S_f32c_sd_clk, S_f32c_sd_miso, S_f32c_sd_mosi: std_logic;
  
  -- clock testing
  signal clk_test_usb, clk_test_eth: std_logic;
  signal R_cnt_usb, R_cnt_eth: std_logic_vector(23 downto 0);
  alias ps2_led_green: std_logic is fioa(5);
  alias ps2_led_red: std_logic is fioa(7);

  component OLVDS
    port(A: in std_logic; Z, ZN: out std_logic);
  end component;

begin
  --minimal_25MHz: if C_clk_freq=25 and C_video_mode=-1 generate
  --  clk <= clk_25MHz;
  --end generate;

  --ddr_640x480_25MHz: if C_clk_freq=25 and (C_video_mode=0 or C_video_mode=1) generate
  --clk_25M: entity work.clk_25_100_125_25
  --  port map(
  --    CLKI        =>  clk_100MHz_p,
  --    CLKOP       =>  clk_pixel_shift,   -- 125 MHz
  --    CLKOS       =>  open,      -- 125 MHz inverted
  --    CLKOS2      =>  clk_pixel, --  25 MHz
  --    CLKOS3      =>  open       -- 100 MHz
  --   );
  --  clk <= clk_pixel; 
  --end generate;

  --ddr_640x480_78MHz: if C_clk_freq=78 and (C_video_mode=0 or C_video_mode=1) generate
  --clk_78M: entity work.clk_25_78_125_25
  --  port map(
  --    CLKI        =>  clk_25MHz,
  --    CLKOP       =>  clk_pixel_shift,   -- 125 MHz
  --    CLKOS       =>  open,  -- 125 MHz inverted
  --    CLKOS2      =>  clk_pixel, --  25 MHz
  --    CLKOS3      =>  clk        --  78.125 MHz CPU
  --   );
  --end generate;

  ddr_640x480_100MHz: if C_clk_freq=100 and (C_video_mode=0 or C_video_mode=1) generate
  clk_100M: entity work.clk_d100_25_125_100_83MHz
    port map(
      CLKI        =>  clk_100MHz_p,     -- 100 MHz differential input
      CLKOP       =>  clk_pixel,        --  25 MHz
      CLKOS       =>  clk_pixel_shift,  -- 125 MHz
      CLKOS2      =>  clk,              -- 100 MHz CPU
      CLKOS3      =>  open              --  83 MHz CPU
    );
  end generate;

  --ddr_640x480_100MHz: if C_clk_freq=125 and (C_video_mode=0 or C_video_mode=1) generate
  --clk_100M: entity work.clk_25_100_125_25
  --  port map(
  --    CLKI        =>  clk_25MHz,
  --    CLKOP       =>  clk_pixel_shift,   -- 125 MHz
  --    CLKOS       =>  open,  -- 125 MHz inverted
  --    CLKOS2      =>  clk_pixel, --  25 MHz
  --    CLKOS3      =>  open       -- 100 MHz
  --   );
  --clk <= clk_pixel_shift;
  --end generate;

  -- serial port direct route
  S_rxd <= uart3_rxd;
  uart3_txd <= S_txd;

  -- hold pushbutton BTN1 to upload to f32c over USB
  -- released BTN1 will pass-thru serial to ESP32
  

  -- full featured XRAM glue
  glue_xram: entity work.glue_xram
  generic map
  (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_bram_const_init => C_bram_const_init,
    C_boot_write_protect => C_boot_write_protect,
    C_boot_spi => C_boot_spi,
    C_branch_prediction => C_branch_prediction,
    C_acram => C_acram,
    C_acram_wait_cycles => C_acram_wait_cycles,
    C_sdram => C_sdram,
    C_sdram32 => C_sdram32,
    -- C_sdram_clock_range => 2,
    C_sdram_address_width => 24,
    C_sdram_column_bits => 9,
    C_sdram_startup_cycles => 10100,
    C_sdram_cycles_per_refresh => 1524,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_cached_addr_bits => C_cached_addr_bits,
    C_xdma => C_xboot_rom,
    C_xram_base => C_xram_base,
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
    C_synth => C_synth,
    C_synth_zero_cross => C_synth_zero_cross,
    C_synth_amplify => C_synth_amplify,
    -- SPDIF output
    C_spdif => C_spdif,

    C_cw_simple_out => C_cw_simple_out,

    C_vector => C_vector,
    C_vector_axi => C_vector_axi,
    C_vector_bram_pass_thru => C_vector_bram_pass_thru,
    C_vector_registers => C_vector_registers,
    C_vector_vaddr_bits => C_vector_vaddr_bits,
    C_vector_vdata_bits => C_vector_vdata_bits,
    C_vector_float_addsub => C_vector_float_addsub,
    C_vector_float_multiply => C_vector_float_multiply,
    C_vector_float_divide => C_vector_float_divide,

    C_dvid_ddr => C_dvid_ddr,
    -- vga simple compositing bitmap only graphics
    C_compositing2_write_while_reading => C_compositing2_write_while_reading,
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
  port map
  (
    clk => clk,
    clk_pixel => clk_pixel,
    clk_pixel_shift => clk_pixel_shift,
    reset => S_reset,
    sio_rxd(0) => S_rxd,
    sio_rxd(1) => open,
    sio_txd(0) => S_txd,
    sio_txd(1) => open,
    sio_break(0) => S_sio_break,
    sio_break(1) => S_sio_break2,

    spi_sck(0)  => open,  spi_sck(1)  => sd_m_clk,
    spi_ss(0)   => open,  spi_ss(1)   => sd_m_d(3),
    spi_mosi(0) => open,  spi_mosi(1) => sd_m_cmd,
    spi_miso(0) => '0',   spi_miso(1) => sd_m_d(0),

    gpio(127 downto 23+32) => open,
    gpio(22+32 downto 32) => fioc(69 downto 47),
    gpio(31 downto 30) => open,
    gpio(29) => vid_rsda,
    gpio(28) => vid_rscl,
    gpio(27 downto 12) => open,
    gpio(11 downto 0) => fiob(31 downto 20),
    simple_out(31 downto 3) => open,
    simple_out(2 downto 0) => led(3 downto 1),
    simple_in(31 downto 21) => (others => '0'),
    simple_in(20) => open,
    simple_in(19 downto 16) => open,
    simple_in(15 downto 7) => (others => '0'),
    simple_in(6 downto 0) => open,

    -- 2 MSB audio channel bits are not used in "default" setup.
    audio_l(3 downto 2) => open,
    audio_r(3 downto 2) => open,
    -- 4-bit could be used down to 75 ohm load
    -- but FPGA will stop working (IO overload)
    -- if standard 17 ohm earphones are plugged.
    spdif_out => open,

    cw_antenna => open,

    -- exposed DMA for boot preloader
    xdma_addr => xdma_addr, xdma_strobe => xdma_strobe,
    xdma_write => '1', xdma_byte_sel => "1111",
    xdma_data_in => xdma_data_in,
    xdma_data_ready => xdma_data_ready,

    -- external SDRAM interface
    sdram_addr => dr_a, sdram_data => dr_d,
    sdram_ba => dr_ba, sdram_dqm => dr_dqm,
    sdram_ras => dr_ras_n, sdram_cas => dr_cas_n,
    sdram_cke => dr_cke, sdram_clk => dr_clk,
    sdram_we => dr_we_n, sdram_cs => dr_cs_n,

    -- acram_emu (AXI cache emulation using BRAM)
    acram_en => ram_en,
    acram_addr(29 downto 2) => ram_address(29 downto 2),
    acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
    acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
    acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
    acram_ready => ram_ready,

    -- ***** VGA *****
    vga_hsync => S_vga_hsync,
    vga_vsync => S_vga_vsync,
    vga_blank => S_vga_blank,
    vga_r => dv_d(23 downto 16),
    vga_g => dv_d(15 downto 8),
    vga_b => dv_d(7 downto 0),

    -- ***** DVI *****
    dvid_clock => dvid_crgb(7 downto 6),
    dvid_red   => dvid_crgb(5 downto 4),
    dvid_green => dvid_crgb(3 downto 2),
    dvid_blue  => dvid_crgb(1 downto 0)
  );
  dv_clk <= clk_pixel;
  dv_hsync <= S_vga_hsync;
  dv_vsync <= S_vga_vsync;
  dv_de <= not S_vga_blank;

  -- preload the f32c bootloader and reset CPU
  -- preloads initially at startup and during each reset of the CPU
  G_xboot_rom: if C_xboot_rom generate
      boot_preload: entity work.boot_preloader
      generic map
      (
	-- ROM data bits
	C_rom_data_bits => C_boot_rom_data_bits, -- bits in the ROM
	-- ROM size in addr bits
	-- SoC configuration options
	C_boot_addr_bits => 8 -- 8: 256x4-byte = 1K bootloader size
      )
      port map
      (
        clk => clk,
        reset_in => S_sio_break, -- input reset rising edge (from serial break) starts DMA preload
        reset_out => S_reset, -- S_reset, 1 during DMA preload (holds CPU in reset state)
        rom_reset => S_rom_reset,
        rom_next_data => S_rom_next_data,
        rom_data => S_rom_data,
        rom_valid => S_rom_valid,
        addr => xdma_addr(9 downto 2), -- must fit bootloader size 1K 10-bit byte address
        data => xdma_data_in, -- comes from register - last read data will stay on the bus
        strobe => xdma_strobe, -- use strobe as strobe and as write signal
        ready => xdma_data_ready -- response from RAM arbiter (write completed)
      );
      bootrom_emu: entity work.bootrom_emu
      generic map
      (
        C_content => boot_rom_mi32el,
        C_data_bits => C_boot_rom_data_bits
      )
      port map
      (
        clk => clk,
        reset => S_rom_reset,
        next_data => S_rom_next_data,
        data => S_rom_data,
        valid => S_rom_valid
      );
  end generate;

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

  G_dvid_sdr: if not C_dvid_ddr generate
    -- this module instantiates single ended inverters to simulate differential
    G_sdr_se: for i in 0 to 3 generate
      vid_d_p(i) <= dvid_crgb(2*i);
      vid_d_n(i) <= not dvid_crgb(2*i);
    end generate;
  end generate;

  G_dvid_ddr: if C_dvid_ddr generate
    -- this module instantiates vendor specific buffers for ddr-differential
    G_ddr_diff: for i in 0 to 3 generate
      gpdi_ddr: ODDRX1F port map(D0=>dvid_crgb(2*i), D1=>dvid_crgb(2*i+1), Q=>ddr_d(i), SCLK=>clk_pixel_shift, RST=>'0');
      gpdi_diff: OLVDS port map(A => ddr_d(i), Z => vid_d_p(i), ZN => vid_d_n(i));
    end generate;
  end generate;

  -- ADV7513 i2c initializer
  i2c_send: entity work.i2c_sender
  port map
  (
    clk => clk_pixel,
    resend => S_sio_break,
    sioc => dv_scl,
    siod => dv_sda
  );

  -- testing additional clocks
  I_clk_usb: entity work.clk_60_30_150_100_85MHz
    port map(
      CLKI        =>  usb_clk,          --  50 MHz input
      CLKOP       =>  clk_test_usb,     --  25 MHz
      CLKOS       =>  open,             -- 125 MHz
      CLKOS2      =>  open,              -- 100 MHz CPU
      CLKOS3      =>  open              --  83 MHz CPU
    );
  process(clk_test_usb)
  begin
    if rising_edge(clk_test_usb) then
      R_cnt_usb <= R_cnt_usb+1;
    end if;
  end process;
  ps2_led_red <= R_cnt_usb(R_cnt_usb'high);

  I_clk_eth: entity work.clk_50_25_125_100_83MHz
    port map(
      CLKI        =>  eth_clk,          --  50 MHz input
      CLKOP       =>  clk_test_eth,     --  25 MHz
      CLKOS       =>  open,             -- 125 MHz
      CLKOS2      =>  open,              -- 100 MHz CPU
      CLKOS3      =>  open              --  83 MHz CPU
    );
  process(clk_test_eth)
  begin
    if rising_edge(clk_test_eth) then
      R_cnt_eth <= R_cnt_eth+1;
    end if;
  end process;
  ps2_led_green <= R_cnt_eth(R_cnt_eth'high);

end Behavioral;
