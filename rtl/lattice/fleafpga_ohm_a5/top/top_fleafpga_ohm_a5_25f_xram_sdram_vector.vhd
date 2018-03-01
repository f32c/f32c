-- (c)EMARD
-- License=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

use work.f32c_pack.all;

library ecp5u;
use ecp5u.components.all;

entity fleafpga_ohm_xram_sdram_vector is
  generic (
    -- ISA: either ARCH_MI32 or ARCH_RV32
    C_arch: integer := ARCH_MI32;
    C_debug: boolean := false;

    -- Main clock: 25/78/100/125 MHz
    C_clk_freq: integer := 100;

    -- SoC configuration options
    C_bram_size: integer := 2;
    C_acram: boolean := false;
    C_acram_wait_cycles: integer := 3; -- 3 or more
    C_acram_emu_kb: integer := 16; -- KB axi_cache emulation (power of 2)
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
    C_vector_float_divide: boolean := false; -- false will not have float divide (/) will save much LUTs and DSPs

    -- video parameters common for vgahdmi and vgatext
    C_dvid_ddr: boolean := true; -- generate HDMI with DDR
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 5:1024x768

    C_vgahdmi: boolean := false;
    C_vgahdmi_cache_size: integer := 8;
    -- normally this should be  actual bits per pixel
    C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
    C_vgahdmi_cache_size: integer := 0;
    C_vgahdmi_cache_use_i: boolean := false;

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FleaFPGA Ohm f32c: 100MHz MIPS-compatible soft-core, 32MB SDRAM";
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
	-- System clock and reset
	sys_clock		: in		std_logic;	-- 25MHz clock input from external xtal oscillator.
	sys_reset		: in		std_logic;	-- master reset input from reset header.

	-- On-board status LED
	n_led1			: buffer	std_logic;
 
	-- Digital video out
	LVDS_Red		: out		std_logic_vector(1 downto 0);
	LVDS_Green		: out		std_logic_vector(1 downto 0);
	LVDS_Blue		: out		std_logic_vector(1 downto 0);
	LVDS_ck			: out		std_logic_vector(1 downto 0);
	
	-- USB Slave (FT230x) debug interface 
	slave_tx_o 		: out		std_logic;
	slave_rx_i 		: in		std_logic;
	slave_cts_i		: in		std_logic;	-- Receives signal from #RTS pin on FT230x, where applicable.

	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
	Dram_Clk		: out		std_logic;	-- clock to SDRAM
	Dram_CKE		: out		std_logic;	-- clock to SDRAM
	Dram_n_Ras		: out		std_logic;	-- SDRAM RAS
	Dram_n_Cas		: out		std_logic;	-- SDRAM CAS
	Dram_n_We		: out		std_logic;	-- SDRAM write-enable
	Dram_BA			: out		std_logic_vector(1 downto 0);	-- SDRAM bank-address
	Dram_Addr		: out		std_logic_vector(12 downto 0);	-- SDRAM address bus
	Dram_Data		: inout		std_logic_vector(15 downto 0);	-- data bus to/from SDRAM
	Dram_n_cs		: out		std_logic;
	Dram_dqm		: out		std_logic_vector(1 downto 0);

	-- GPIO Header pins declaration (RasPi compatible GPIO format)
	-- gpio0 = GPIO_IDSD
	-- gpio1 = GPIO_IDSC
	GPIO			: inout		std_logic_vector(27 downto 0);

	-- Sigma Delta ADC ('Enhanced' Ohm-specific GPIO functionality)
	-- NOTE: Must comment out GPIO_5, GPIO_7, GPIO_10 AND GPIO_24 as instructed in the pin constraints file (.LPF) in order to use
	--ADC0_input	: in		std_logic;
	--ADC0_error	: buffer	std_logic;
	--ADC1_input	: in		std_logic;
	--ADC1_error	: buffer	std_logic;
	--ADC2_input	: in		std_logic;
	--ADC2_error	: buffer	std_logic;
	--ADC3_input	: in		std_logic;
	--ADC3_error	: buffer	std_logic;

	-- SD/MMC Interface (Support either SPI or nibble-mode)
	mmc_dat1		: in		std_logic;
	mmc_dat2		: in		std_logic;
	mmc_n_cs		: out		std_logic;
	mmc_clk			: out		std_logic;
	mmc_mosi		: out		std_logic; 
	mmc_miso		: in		std_logic;

	-- PS/2 Mode enable, keyboard and Mouse interfaces
	PS2_enable		: out		std_logic;
	PS2_clk1		: inout		std_logic;
	PS2_data1		: inout		std_logic;

	PS2_clk2		: inout		std_logic;
	PS2_data2		: inout		std_logic
  );
end;

architecture Behavioral of fleafpga_ohm_xram_sdram_vector is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
  signal clk, rs232_break, rs232_break2: std_logic;
  signal clk_sdram: std_logic;
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

  component OLVDS
    port(A: in std_logic; Z, ZN: out std_logic);
  end component;

begin
  minimal_25MHz: if C_clk_freq=25 and C_video_mode=-1 generate
    clk <= sys_clock;
  end generate;

  ddr_640x480_25MHz: if C_clk_freq=25 and (C_video_mode=0 or C_video_mode=1) generate
  clk_25M: entity work.clk_25_100_125_25
    port map(
      CLKI        =>  sys_clock,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  open       -- 100 MHz
     );
    clk <= clk_pixel; 
  end generate;

  old_ddr_640x480_78MHz: if false and C_clk_freq=78 and (C_video_mode=0 or C_video_mode=1) generate
  old_clk_78M: entity work.clk_25_78_125_25
    port map(
      CLKI        =>  sys_clock,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  clk        --  78.125 MHz CPU
     );
  end generate;

  ddr_640x480_78MHz: if C_clk_freq=78 and (C_video_mode=0 or C_video_mode=1) generate
  clk_78M: entity work.clk_25_125p_125n_78_78s
    port map(
      CLKI        =>  sys_clock,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk,       --  78.125 MHz CPU
      CLKOS3      =>  clk_sdram  --  78.125 MHz phase 146' SDRAM
     );
  clk_pixel <= sys_clock;
  end generate;

  ddr_640x480_100MHz: if C_clk_freq=100 and (C_video_mode=0 or C_video_mode=1) generate
  clk_100M: entity work.clk_25_100_125_25
    port map(
      CLKI        =>  sys_clock,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  clk        -- 100 MHz CPU
     );
  end generate;

  ddr_640x480_125MHz: if C_clk_freq=125 and (C_video_mode=0 or C_video_mode=1) generate
  clk_125M: entity work.clk_25_100_125_25
    port map(
      CLKI        =>  sys_clock,
      CLKOP       =>  clk_dvi,   -- 125 MHz
      CLKOS       =>  clk_dvin,  -- 125 MHz inverted
      CLKOS2      =>  clk_pixel, --  25 MHz
      CLKOS3      =>  open        -- 100 MHz CPU
     );
     clk <= clk_dvi; -- 125 MHz
  end generate;

  -- full featured XRAM glue
  glue_xram: entity work.glue_xram
  generic map (
    C_arch => C_arch,
    C_clk_freq => C_clk_freq,
    C_bram_size => C_bram_size,
    C_branch_prediction => C_branch_prediction,
    C_acram => C_acram,
    C_acram_wait_cycles => C_acram_wait_cycles,
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
    sio_rxd(0) => slave_rx_i,
    sio_rxd(1) => '1',
    sio_txd(0) => slave_tx_o,
    sio_txd(1) => open,
    sio_break(0) => rs232_break,
    sio_break(1) => rs232_break2,

    spi_sck(0)  => open,  spi_sck(1)  => mmc_clk,
    spi_ss(0)   => open,  spi_ss(1)   => mmc_n_cs,
    spi_mosi(0) => open,  spi_mosi(1) => mmc_mosi,
    spi_miso(0) => '0',   spi_miso(1) => mmc_miso,

    gpio(27 downto 0) => gpio(27 downto 0),
    simple_out(31 downto 1) => open,
    simple_out(0) => n_led1,
    simple_in(31 downto 0) => open,

    -- 2 MSB audio channel bits are not used in "default" setup.
    -- jack_tip(3 downto 2) => audio_l(1 downto 0),
    -- jack_ring(3 downto 2) => audio_r(1 downto 0),
    -- 4-bit could be used down to 75 ohm load
    -- but FPGA will stop working (IO overload)
    -- if standard 17 ohm earphones are plugged.
    --jack_tip => audio_l,
    --jack_ring => audio_r,

    -- cw_antenna => ant_433mhz,

    -- external SDRAM interface
    sdram_addr => dram_addr, sdram_data => dram_data,
    sdram_ba => dram_ba, sdram_dqm => dram_dqm,
    sdram_ras => dram_n_ras, sdram_cas => dram_n_cas,
    sdram_cke => dram_cke, sdram_clk => dram_clk,
    sdram_we => dram_n_we, sdram_cs => dram_n_cs,

    -- acram_emu (AXI cache emulation using BRAM)
    acram_en => ram_en,
    acram_addr(29 downto 2) => ram_address(29 downto 2),
    acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
    acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
    acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
    acram_ready => ram_ready,

    dvid_red   => dvid_red,
    dvid_green => dvid_green,
    dvid_blue  => dvid_blue,
    dvid_clock => dvid_clock
  );
  -- dram_clk <= not clk_sdram;
  
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

  --gpdi_data_channels: for i in 0 to 2 generate
  --  gpdi_diff_data: OLVDS
  --  port map(A => ddr_d(i), Z => gpdi_dp(i), ZN => gpdi_dn(i));
  --end generate;
  --gpdi_diff_clock: OLVDS
  --port map(A => ddr_clk, Z => gpdi_clkp, ZN => gpdi_clkn);

  gpdi_red: OLVDS
  port map(A => ddr_d(2), Z => lvds_red(0), ZN => lvds_red(1));
  gpdi_green: OLVDS
  port map(A => ddr_d(1), Z => lvds_green(0), ZN => lvds_green(1));
  gpdi_blue: OLVDS
  port map(A => ddr_d(0), Z => lvds_blue(0), ZN => lvds_blue(1));
  gpdi_diff_clock: OLVDS
  port map(A => ddr_clk, Z => lvds_ck(0), ZN => lvds_ck(1));

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

end Behavioral;
