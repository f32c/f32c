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

entity ulx3s_xram_sdram_vector is
  generic
  (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 25/78/89/100/104 MHz
    C_clk_freq: integer := 89;

    -- SoC configuration options
    C_xboot_rom: boolean := false; -- false default, bootloader initializes XRAM with external DMA
    C_bram_size: integer := 2; -- 2 default, must be disabled with 0 when C_xboot_emu = true
    C_bram_const_init: boolean := true; -- true default, MAX10 cannot preload bootloader using VHDL constant intializer
    C_boot_write_protect: boolean := true; -- true default, may leave boot block writeable to save some LUTs
    C_boot_rom_data_bits: integer := 32; -- number of bits in output from bootrom_emu
    C_boot_spi: boolean := true; -- SPI bootloader is larger and allows setting of baudrate
    --  RAM    C_xram_base  C_PC_mask    C_cached_addr_bits  C_bram_size  C_xboot_rom  Comment
    --  32 MB  "8"          x"81ffffff"  25                  2            false        ULX3S default
    --  32 MB  "0"          x"01ffffff"  25                  0            true         XRAM only, no BRAM
    --   1 MB  "8"          x"800fffff"  20                  2            false        ULX2S simulaton
    --   1 MB  "1"          x"100fffff"  20                  2            false        custom
    -- RAM start address x"8" -> 0x80000000 (needs C_PC_mask x"800fffff" for 1MB or x"81ffffff" for 32MB)
    C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- 8 default for C_xboot_rom=false, 0 for C_xboot_rom=true, sets XRAM base address
    C_PC_mask: std_logic_vector(31 downto 0) := x"81ffffff"; -- ULX3S default 32MB
    -- C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff"; -- ULX2S simulation 1MB
    C_cached_addr_bits: integer := 25; -- ULX3S default 25->32MB
    -- C_cached_addr_bits: integer := 26; -- ULX3S 26->64MB
    -- C_cached_addr_bits: integer := 20; -- ULX2S simulation 1MB
    C_acram: boolean := false; -- false default (ulx3s has sdram chip)
    C_acram_wait_cycles: integer := 3; -- 3 or more
    C_acram_emu_kb: integer := 128; -- KB axi_cache emulation (power of 2)
    C_sdram: boolean := true; -- true default
    C_sdram_wait_cycles: integer := 2; -- RAS/CAS/PRE wait cycles (2 or 3)
    C_icache_size: integer := 2; -- 2 default
    C_dcache_size: integer := 2; -- 2 default
    C_branch_prediction: boolean := false; -- false default
    C_sio: integer := 2; -- 2 default
    C_usbsio: std_logic_vector := "0100"; -- "0000"-disable, "0100" enumerate over US2
    C_spi: integer := 3; -- 2 default
    C_simple_io: boolean := true; -- true default
    C_gpio: integer := 96; -- 64 default for ulx3s, additional gpio for audio DAC testing
    C_gpio_pullup: boolean := false; -- false default
    C_gpio_adc: integer := 0; -- number of analog ports for ADC (on A0-A5 pins)
    C_timer: boolean := true; -- true default
    C_pcm: boolean := false; -- PCM audio (wav playing)
    C_synth: boolean := false; -- Polyphonic synth
      C_synth_zero_cross: boolean := true; -- volume changes at zero-cross, spend 1 BRAM to remove clicks
      C_synth_amplify: integer := 0; -- 0 for 24-bit digital reproduction, 5 for PWM (clipping possible)
    C_spdif: boolean := false; -- SPDIF output
    C_cw_simple_out: integer := -1; -- 7 default, simple_out bit for 433MHz modulator. -1 to disable. for 433MHz transmitter set (C_framebuffer => false, C_dds => false)
    C_fmrds: boolean := true; -- enable FM/RDS output to fm_antenna
      C_fm_stereo: boolean := false;
      C_fm_filter: boolean := false;
      C_fm_downsample: boolean := false;
      C_rds_msg_len: integer := 260; -- bytes of circular sent message, typical 52 for PS or 260 PS+RT
      C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz)
      --C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
      --C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
      C_rds_clock_multiply: integer := 63; -- multiply and divide from cpu clk 89.285714 MHz
      C_rds_clock_divide: integer := 3084; -- to get 1.824 MHz for RDS logic
      --C_rds_clock_multiply: integer := 57; -- multiply 57 and divide 3125 from cpu clk 100 MHz
      --C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic

    -- enabling passthru autodetect reduces fmax or vector divide must be disabled on 45f
    C_passthru_autodetect: boolean := false; -- false: normal, true: autodetect programming of ESP32 and passthru serial port
    C_passthru_clk_Hz: real := 25.0E6; -- passthru state machine uses 25 MHz clock
    C_passthru_break: real := 10.0E-3; -- seconds (approximately) to detect serial break and enter f32c mode

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
    C_shift_clock_synchronizer: boolean := true; -- logic that synchronizes DVI clock with pixel clock.

    C_vgahdmi: boolean := true;
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
    C_vgahdmi_cache_size: integer := 0; -- 0 default (disabled, cache flush not yet implemented)
    C_vgahdmi_cache_use_i: boolean := false;
    C_compositing2_write_while_reading: boolean := true; -- default true

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
  port
  (
  clk_25mhz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndtr: inout  std_logic;
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic; -- '0' will disable wifi by default
  wifi_gpio0, wifi_gpio5, wifi_gpio16, wifi_gpio17: inout std_logic := 'Z';

  -- USB
  --usb_fpga_dp, usb_fpga_dn: in std_logic; -- differential input (currently not used)
  usb_fpga_pu_dp, usb_fpga_pu_dn: inout std_logic; -- pull up/down control
  usb_fpga_bd_dp, usb_fpga_bd_dn: inout std_logic; -- single-ended bidirectional

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
  gpdi_dp, gpdi_dn: out std_logic_vector(3 downto 0);

  -- i2c shared for digital video and RTC
  gpdi_scl, gpdi_sda: inout std_logic;

  -- Flash ROM (SPI0)
  -- commented out because it can't be used as GPIO
  -- when bitstream is loaded from config flash
  flash_miso   : in      std_logic;
  flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  flash_csn    : out     std_logic;
  flash_holdn, flash_wpn: out std_logic := '1';

  -- SD card (SPI1)
  sd_cmd: inout std_logic := 'Z';
  sd_d: inout std_logic_vector(3 downto 0);
  sd_clk: inout std_logic := 'Z';
  sd_cdn, sd_wp: in std_logic;

  nc: inout std_logic_vector(8 downto 0) -- not connected pins to force compiler to use some logic
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
  signal clk_pixel_shift, clk_pixel: std_logic;
  signal clk_usbsio: std_logic;
  signal clk_fm: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
  signal dvid_crgb: std_logic_vector(7 downto 0);
  signal ddr_d: std_logic_vector(3 downto 0);
  signal R_blinky: std_logic_vector(26 downto 0);
  signal S_spdif_out: std_logic;

  signal S_reset, S_reset_during_dma, R_reset: std_logic := '0'; -- reset to hold during DMA preload
  signal R_reset_counter: std_logic_vector(20 downto 0); -- btn0 debouncer
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
  constant C_break_counter_bits: integer := 1+ceil_log2(integer(C_passthru_clk_Hz*C_passthru_break));
  signal R_break_counter: std_logic_vector(C_break_counter_bits-1 downto 0) := (others => '0');
  signal S_f32c_sd_csn, S_f32c_sd_clk, S_f32c_sd_miso, S_f32c_sd_mosi: std_logic;
  signal S_flash_csn, S_flash_clk: std_logic;

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
      CLKOP       =>  clk_pixel_shift, -- 125 MHz
      CLKOS       =>  open,            -- 125 MHz inverted
      CLKOS2      =>  clk_pixel,       --  25 MHz
      CLKOS3      =>  open             -- 100 MHz
     );
    clk <= clk_pixel; 
  end generate;

  ddr_640x480_78MHz: if C_clk_freq=78 and (C_video_mode=0 or C_video_mode=1) generate
    clk_78M: entity work.clk_25_78_125_25
    port map(
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_pixel_shift, -- 125 MHz
      CLKOS       =>  open,            -- 125 MHz inverted
      CLKOS2      =>  clk_pixel,       --  25 MHz
      CLKOS3      =>  clk              --  78.125 MHz CPU
     );
  end generate;

  ddr_640x480_89MHz: if C_clk_freq=89 and (C_video_mode=0 or C_video_mode=1) generate
    clk_89M: entity work.clk_25_125_89_89s_48
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_pixel_shift, -- 125    MHz DVI
      clkout(1)   =>  clk,             --  89.28 MHz CPU
      clkout(2)   =>  sdram_clk,       --  89.28 MHz SDRAM phase shift 180 deg
      clkout(3)   =>  clk_usbsio       --  48.07 MHz USB
     );
    clk_pixel <= not clk_25MHz;
    clk_250M_100M_100Ms_89: entity work.clk_25_250_100_100s
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_fm,          -- 250 MHz FM
      clkout(1)   =>  open,            -- 100 MHz CPU
      clkout(2)   =>  open             -- 100 MHz SDRAM phase shift 180 deg
    );
  end generate;

  ddr_640x480_104MHz: if C_clk_freq=104 and (C_video_mode=0 or C_video_mode=1) generate
    clk_104M: entity work.clk_25_125_104_104s_48
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_pixel_shift, -- 125    MHz DVI
      clkout(1)   =>  clk,             -- 104.17 MHz CPU
      clkout(2)   =>  sdram_clk,       -- 104.17 MHz SDRAM phase shift 180 deg
      clkout(3)   =>  clk_usbsio       --  48.07 MHz USB
     );
    clk_pixel <= not clk_25MHz;
    clk_250M_100M_100Ms_104: entity work.clk_25_250_100_100s
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_fm,          -- 250 MHz FM
      clkout(1)   =>  open,            -- 100 MHz CPU
      clkout(2)   =>  open             -- 100 MHz SDRAM phase shift 180 deg
    );
  end generate;

  ddr_640x480_100MHz: if C_clk_freq=100 and (C_video_mode=0 or C_video_mode=1) generate
    clk_125M_48M: entity work.clk_25_125_89_89s_48
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_pixel_shift, -- 125    MHz DVI
      clkout(1)   =>  open,            --  89.28 MHz CPU
      clkout(2)   =>  open,            --  89.28 MHz SDRAM phase shift 180 deg
      clkout(3)   =>  clk_usbsio       --  48.07 MHz USB
     );
    clk_pixel <= not clk_25MHz;
    clk_250M_100M_100Ms_100: entity work.clk_25_250_100_100s
    port map(
      clkin       =>  clk_25MHz,
      clkout(0)   =>  clk_fm,          -- 250 MHz FM
      clkout(1)   =>  clk,             -- 100 MHz CPU
      clkout(2)   =>  sdram_clk        -- 100 MHz SDRAM phase shift 180 deg
    );
  end generate;

--  tv_512x288_81MHz: if C_fmrds generate
--  clk_81M25: entity work.clk_25_325_25_81
--    port map(
--      CLKI        =>  clk_25MHz,
--      CLKOP       =>  clk_pal,          -- 325 MHz for PAL
--      CLKOS       =>  open,             --  25 MHz
--      CLKOS2      =>  open              --  81.25 MHz CPU
--     );
--  end generate;

  G_yes_passthru_autodetect: if C_passthru_autodetect generate
    -- Autodetect programming of ESP32 and f32c

    -- Programming logic
    -- SERIAL  ->  ESP32
    -- DTR RTS -> EN IO0
    --  1   1     1   1
    --  0   0     1   1
    --  1   0     0   1
    --  0   1     1   0
    S_prog_in(1) <= ftdi_ndtr;
    S_prog_in(0) <= ftdi_nrts;
    S_prog_out <= "01" when S_prog_in = "10" else
                  "10" when S_prog_in = "01" else
                  "11";
    wifi_en <= S_prog_out(1);
    wifi_gpio0 <= S_prog_out(0) and btn(0); -- holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control
    sd_d(0) <= '0' when S_prog_in = "01" else 'Z'; -- wifi_gpio2 to 0 during programming init
    sd_d(3) <= '1' when R_esp32_mode = '1' else '0' when S_f32c_sd_csn = '0' else 'Z';
    sd_clk <= '1' when R_esp32_mode = '1' else S_f32c_sd_clk when S_f32c_sd_csn = '0' else 'Z';
    S_f32c_sd_miso <= sd_d(0);
    sd_cmd <= '1' when R_esp32_mode = '1' else S_f32c_sd_mosi when S_f32c_sd_csn = '0' else 'Z';
    sd_d(2 downto 1) <= (others => '1') when R_esp32_mode = '1' else (others => 'Z');
    
    -- S_f32c_sd_csn <= '1'; -- force disabled for debugging

    -- detect serial break
    G_detect_serial_break: if true generate
    process(clk_25MHz)
    begin
      if rising_edge(clk_25MHz) then
        -- f32c serial break detection
        if ftdi_txd = '1' then
          R_break_counter <= (others => '0');
        else
          if R_break_counter(R_break_counter'high) = '0' then
            R_break_counter <= R_break_counter + 1;
          end if;
        end if;
      end if;
    end process;
    end generate;

    -- autodetect ESP32 programming mode
    G_autodetect_esp32_prog: if true generate
    process(clk_25MHz)
    begin
      if rising_edge(clk_25MHz) then
        -- esp32 detection
        if R_break_counter(R_break_counter'high) = '1' and R_esp32_mode = '1' then -- serial break detected during esp32 mode
          R_esp32_mode <= '0'; -- serial break -> esp32 mode off
        else
          if S_prog_in = "01" then -- esp32 prog init detected -> enter esp32 mode
            R_esp32_mode <= '1';
          end if; -- esp32 prog detect
        end if; -- f32c serial break detect
      end if;
    end process;
    end generate;
    -- both USB and WiFi can upload binary executable to f32c
    -- because AND mixture of ftdi and wifi TXD is connected to f32c RXD
    -- and f32c TXD is connected to both ftdi and wifi RXD
    -- (not both on the same time)
    -- S_rxd <= '1' when R_esp32_mode='1' else (ftdi_txd and wifi_txd);
    S_rxd <= R_esp32_mode or (ftdi_txd and wifi_txd); -- same logic function as above line
    ftdi_rxd <= wifi_txd when R_esp32_mode='1' else S_txd;
    wifi_rxd <= ftdi_txd when R_esp32_mode='1' else S_txd;
  end generate;
  G_no_passthru_autodetect: if not C_passthru_autodetect generate
    -- both USB and WiFi can upload binary executable to f32c
    -- (not both on the same time)
    S_rxd <= ftdi_txd and wifi_txd;
    ftdi_rxd <= S_txd;
    wifi_rxd <= S_txd;
    wifi_gpio0 <= btn(0); -- pressing BTN0 will escape to ESP32 file select menu
    wifi_en <= '0';
    sd_d(3) <= S_f32c_sd_csn;
    sd_clk <= S_f32c_sd_clk;
    S_f32c_sd_miso <= sd_d(0);
    sd_cmd <= S_f32c_sd_mosi;
    sd_d(2 downto 1) <= (others => '1');
  end generate;
  
  -- hold pushbutton BTN1 to upload to f32c over USB
  -- released BTN1 will pass-thru serial to ESP32

  -- full featured XRAM glue
  glue_xram: entity work.glue_xram
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_bram_const_init => C_bram_const_init,
    C_boot_write_protect => C_boot_write_protect,
    C_boot_spi => C_boot_spi,
    C_branch_prediction => C_branch_prediction,
    C_PC_mask => C_PC_mask,
    C_icache_size => C_icache_size,
    C_dcache_size => C_dcache_size,
    C_cached_addr_bits => C_cached_addr_bits,
    C_acram => C_acram,
    C_acram_wait_cycles => C_acram_wait_cycles,
    C_sdram => C_sdram,
    C_sdram_clock_range => 2,
    C_sdram_ras => C_sdram_wait_cycles,
    C_sdram_cas => C_sdram_wait_cycles,
    C_sdram_pre => C_sdram_wait_cycles,
    C_sdram_address_width => C_cached_addr_bits-1, -- RAM addr is 16-bit based (24 for 32MB), cached addr is 8-bit based (25 for 32MB)
    C_sdram_column_bits => C_cached_addr_bits-16, -- 9 for 32MB, 10 for 64MB
    C_sdram_startup_cycles => 14000,
    C_sdram_cycles_per_refresh => 1524,
    C_xdma => C_xboot_rom,
    C_xram_base => C_xram_base,
    C_debug => C_debug,
    C_sio => C_sio,
    C_usbsio => C_usbsio,
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

    C_fmrds => C_fmrds, -- either FM or tx433
      C_fm_stereo => C_fm_stereo,
      C_fm_filter => C_fm_filter,
      C_fm_downsample => C_fm_downsample,
      C_rds_msg_len => C_rds_msg_len, -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
      C_fmdds_hz => C_fmdds_hz, -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
      C_rds_clock_multiply => C_rds_clock_multiply, -- multiply and divide from cpu clk 81.25 MHz
      C_rds_clock_divide => C_rds_clock_divide,  -- to get 1.824 MHz for RDS logic

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
    C_shift_clock_synchronizer => C_shift_clock_synchronizer,
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
  port map (
    clk => clk,
    clk_pixel => clk_pixel,
    clk_pixel_shift => clk_pixel_shift,
    clk_usbsio => clk_usbsio,
    clk_fmdds => clk_fm,
    reset => S_reset,
    sio_rxd(0) => S_rxd,
    --sio_rxd(1) => open,
    usbsio_dp(1) => usb_fpga_bd_dp,
    sio_txd(0) => S_txd,
    --sio_txd(1) => open,
    usbsio_dn(1) => usb_fpga_bd_dn,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,

    spi_ss(0)   => S_flash_csn,  spi_ss(1)   => S_f32c_sd_csn,   spi_ss(2)   => oled_csn,
    spi_sck(0)  => S_flash_clk,  spi_sck(1)  => S_f32c_sd_clk,   spi_sck(2)  => oled_clk,
    spi_mosi(0) => flash_mosi,   spi_mosi(1) => S_f32c_sd_mosi,  spi_mosi(2) => oled_mosi,
    spi_miso(0) => flash_miso,   spi_miso(1) => S_f32c_sd_miso,  spi_miso(2) => open,

    gpio(127 downto 96) => open, -- not allocated
    gpio(95 downto 76) => open, -- 12 pins free
    gpio(75 downto 72) => audio_v,
    gpio(71 downto 68) => audio_r,
    gpio(67 downto 64) => audio_l,
    gpio(63 downto 28+32) => open, -- 4 pins free
    gpio(27+32 downto 32) => gn(27 downto 0),
    gpio(31 downto 30) => open, -- 2 pins free
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
    simple_out(12) => open,
    simple_out(11) => oled_dc,
    simple_out(10) => oled_resn,
    simple_out(9) => open,
    simple_out(8) => open,
    simple_out(7 downto 0) => led(7 downto 0),
    simple_in(31 downto 21) => (others => '0'),
    simple_in(20) => adc_miso,
    simple_in(19 downto 16) => sw,
    simple_in(15 downto 7) => (others => '0'),
    simple_in(6 downto 0) => btn,

    -- 2 MSB audio channel bits are not used in "default" setup.
    audio_l(3 downto 2) => open, -- audio_l(1 downto 0),
    audio_r(3 downto 2) => open, -- audio_r(1 downto 0),
    -- 4-bit could be used down to 75 ohm load
    -- but FPGA will stop working (IO overload)
    -- if standard 17 ohm earphones are plugged.
    spdif_out => open, -- audio_v(0),

    --cw_antenna => ant_433mhz,
    fm_antenna => ant_433mhz,

    -- exposed DMA for boot preloader
    xdma_addr => xdma_addr, xdma_strobe => xdma_strobe,
    xdma_write => '1', xdma_byte_sel => "1111",
    xdma_data_in => xdma_data_in,
    xdma_data_ready => xdma_data_ready,

    -- external SDRAM interface
    sdram_addr => sdram_a, sdram_data(15 downto 0) => sdram_d,
    sdram_ba => sdram_ba, sdram_dqm(1 downto 0) => sdram_dqm,
    sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
    sdram_cke => sdram_cke, sdram_clk => open,
    sdram_we => sdram_wen, sdram_cs => sdram_csn,

    -- acram_emu (AXI cache emulation using BRAM)
    acram_en => ram_en,
    acram_addr(29 downto 2) => ram_address(29 downto 2),
    acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
    acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
    acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
    acram_ready => ram_ready,

    dvid_clock => dvid_crgb(7 downto 6),
    dvid_red   => dvid_crgb(5 downto 4),
    dvid_green => dvid_crgb(3 downto 2),
    dvid_blue  => dvid_crgb(1 downto 0)
  );

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
        reset_in => rs232_break, -- input reset rising edge (from serial break) starts DMA preload
        reset_out => S_reset_during_dma, -- 1 during DMA preload (holds CPU in reset state) FIXME on glue_xram module use this instead of R_reset
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
      gpdi_dp(i) <= dvid_crgb(2*i);
      gpdi_dn(i) <= not dvid_crgb(2*i);
    end generate;
  end generate;

  G_dvid_ddr: if C_dvid_ddr generate
    -- this module instantiates vendor specific buffers for ddr-differential
    G_ddr_diff: for i in 0 to 3 generate
      gpdi_ddr: ODDRX1F port map(D0=>dvid_crgb(2*i), D1=>dvid_crgb(2*i+1), Q=>ddr_d(i), SCLK=>clk_pixel_shift, RST=>'0');
      gpdi_diff: OLVDS port map(A => ddr_d(i), Z => gpdi_dp(i), ZN => gpdi_dn(i));
    end generate;
  end generate;

  flash_clock: entity work.ecp5_flash_clk
  port map
  (
    flash_csn => rs232_break,
    flash_clk => S_flash_clk
  );
  flash_csn <= S_flash_csn;

  -- USB 1.1
  G_yes_usbserial: if C_usbsio /= "0000" generate
    usb_fpga_pu_dp <= '1'; -- D+ pullup enabled to activate USB 1.1 enumeration
    usb_fpga_pu_dn <= 'Z'; -- D- pullup/down disabled to activate USB 1.1 enumeration
    -- manual reset as USB-serial currently doesn't support break
    process(clk)
    begin
      if rising_edge(clk) then
        if btn(0) = '0' then
          R_reset_counter <= (others => '0');
        else
          if R_reset_counter(R_reset_counter'high) = '0' then
            R_reset_counter <= R_reset_counter + 1;
          end if;
        end if;
      R_reset <= not R_reset_counter(R_reset_counter'high);
      end if;
    end process;
  end generate;

  G_not_usbserial: if C_usbsio(0) = '0' generate
    R_reset <= rs232_break;
  end generate;

end Behavioral;
