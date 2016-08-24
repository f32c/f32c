-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;
use work.axi_pack.all;

entity zybo_xram_ddr3 is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 100/108 MHz (100 for video_mode <= 4, 108 for video_mode >= 59
    C_clk_freq: integer := 100;

    C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

	-- SoC configuration options
    C_bram_size: integer := 16;

    C_axiram: boolean := true;
        -- axi cache ram
	C_acram: boolean := false;
	C_acram_wait_cycles: integer := 2;
	C_acram_emu_kb: integer := 0; -- KB axi_cache emulation (0 to disable, power of 2, MAX 128)

        -- warning: 2K, 16K, 32K cache produces timing critical warnings at 100MHz cpu clock
        -- no errors for 4K or 8K
        C_icache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 4; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

        C_DDR3_DQ_PINS        : integer := 32;
        C_DDR3_DM_WIDTH       : integer := 4; -- 2 per chip
        C_DDR3_DQS_WIDTH      : integer := 4; -- 2 per chip
        C_DDR3_ADDR_WIDTH     : integer := 15;
        C_DDR3_BANKADDR_WIDTH : integer := 3;

        C_vector: boolean := true; -- vector processor unit
        C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
        C_vector_burst_max_bits: integer := 2; -- currently used only for AXI
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_vaddr_bits: integer := 11;
        C_vector_vdata_bits: integer := 32;
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

    C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 7:1280x1024
    -- fixme: non-working modes: 0, 4

    C_vgahdmi: boolean := true;
      C_vgahdmi_axi: boolean := true; -- connect vgahdmi to video_axi_in/out instead to f32c bus arbiter
      C_vgahdmi_cache_size: integer := 8; -- KB video cache (only on f32c bus) (0: disable, 2,4,8,16,32:enable)
      C_vgahdmi_fifo_timeout: integer := 0;
      C_vgahdmi_fifo_burst_max: integer := 8; -- 64 works for MIG
      -- output data width 8bpp
      C_vgahdmi_fifo_data_width: integer := 32; -- should be equal to bitmap depth

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: ZYBO-7z010 MIPS compatible soft-core 100MHz 32MB DDR3"; -- default banner in screen memory
      C_vgatext_mode: integer := 0;   -- 640x480
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 0;   -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          -- 8 bpp compositing
          -- step=horizontal width in pixels
          C_vgatext_bitmap_fifo_step: integer := 640;
          -- height=vertical height in pixels
          C_vgatext_bitmap_fifo_height: integer := 480;
          -- output data width 8bpp
          C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_addr_width: integer := 11;

	C_sio: integer := 1;   -- 1 UART channel
	C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
	C_gpio: integer := 32; -- 32 GPIO bits
	C_timer: boolean := true;
	C_ps2: boolean := false; -- PS/2 keyboard
    C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
    );
    port (
	clk_125m: in std_logic;
        rs232_tx: out std_logic;
        rs232_rx: in std_logic;
	led: out std_logic_vector(3 downto 0);
	sw: in std_logic_vector(3 downto 0);
	ja_u: inout std_logic_vector(3 downto 0);
	ja_d: inout std_logic_vector(3 downto 0);
	jb_u: inout std_logic_vector(3 downto 0);
	jb_d: inout std_logic_vector(3 downto 0);
	jc_u: inout std_logic_vector(3 downto 0);
	jc_d: inout std_logic_vector(3 downto 0);
	jd_u: inout std_logic_vector(3 downto 0);
	jd_d: inout std_logic_vector(3 downto 0);
	hdmi_out_en : out std_logic;
	hdmi_clk_p, hdmi_clk_n: out std_logic;
	hdmi_d_p, hdmi_d_n: out std_logic_vector(2 downto 0);
	vga_g: out std_logic_vector(5 downto 0);
	vga_r, vga_b: out std_logic_vector(4 downto 0);
	vga_hs, vga_vs: out std_logic;
	btn: in std_logic_vector(3 downto 0);
        -- DDR3 named as in ZYBO schematics
        ddr_dq     : inout  std_logic_vector(C_DDR3_DQ_PINS-1 downto 0); -- inout
        ddr_addr      : inout  std_logic_vector(C_DDR3_ADDR_WIDTH-1 downto 0); -- out
        ddr_bankaddr     : inout  std_logic_vector(C_DDR3_BANKADDR_WIDTH-1 downto 0); -- out
        ddr_dm     : inout  std_logic_vector(C_DDR3_DM_WIDTH-1 downto 0); -- out
        ddr_ras_n  : inout  std_logic; -- out
        ddr_cas_n  : inout  std_logic; -- out
        ddr_we_n   : inout  std_logic; -- out
        ddr_cs_n   : inout  std_logic; -- out
        ddr_odt    : inout  std_logic; -- out
        ddr_dqs_p  : inout  std_logic_vector(C_DDR3_DQS_WIDTH-1 downto 0); -- inout
        ddr_dqs_n  : inout  std_logic_vector(C_DDR3_DQS_WIDTH-1 downto 0); -- inout
        ddr_vrp   : inout  std_logic; -- in
        ddr_vrn   : inout  std_logic; -- in
        ddr_clk   : inout  std_logic; -- out
        ddr_clk_n   : inout  std_logic; -- out
        ddr_cke    : inout  std_logic  -- out
    );
end zybo_xram_ddr3;

architecture Behavioral of zybo_xram_ddr3 is
    -- useful for conversion from KB to number of address bits
    function ceil_log2(x: integer)
      return integer is
    begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
    end ceil_log2;
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_30MHz, clk_40MHz, clk_45MHz, clk_50MHz, clk_65MHz,
           clk_100MHz, clk_108MHz, clk_112M5Hz, clk_125MHz, clk_150MHz,
           clk_200MHz, clk_216MHz, clk_225MHz, clk_250MHz,
           clk_325MHz, clk_541MHz: std_logic := '0';
    signal clk_axi: std_logic;
    signal clk_pixel: std_logic;
    signal clk_pixel_shift: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;

    component clk_125_100_200_250_25MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_250mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_125_100_200_125_25MHz is
    Port (
      clk_125mhz_in: in STD_LOGIC;
      clk_25mhz: out STD_LOGIC;
      clk_100mhz: out STD_LOGIC;
      clk_125mhz: out STD_LOGIC;
      clk_200mhz: out STD_LOGIC;
      reset: in STD_LOGIC;
      locked: out STD_LOGIC
    );
    end component;

    component clk_125_100_200_150_30MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_150mhz : out STD_LOGIC;
      clk_30mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_125_100_200_40MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_40mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_125_100_112_225_45MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_225mhz : out STD_LOGIC;
      clk_112m5hz : out STD_LOGIC;
      clk_45mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_125_100_200_250_50MHz is
    Port (
      clk_125mhz_in: in STD_LOGIC;
      clk_50mhz: out STD_LOGIC;
      clk_100mhz: out STD_LOGIC;
      clk_250mhz: out STD_LOGIC;
      clk_200mhz: out STD_LOGIC;
      reset: in STD_LOGIC;
      locked: out STD_LOGIC
    );
    end component;

    component clk_125_108_216_325_65MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_108m333hz : out STD_LOGIC;
      clk_216m666hz : out STD_LOGIC;
      clk_325mhz : out STD_LOGIC;
      clk_65mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_125_108_216_541MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_108m333hz : out STD_LOGIC;
      clk_216m666hz : out STD_LOGIC;
      clk_541m666hz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    signal l00_axi_areset_n     :  std_logic := '1';
    signal l00_axi_aclk         :  std_logic := '0';
    signal l00_axi_awid         :  std_logic_vector(0 downto 0) ; --:= (others => '0');
    signal l00_axi_awaddr       :  std_logic_vector(31 downto 0);
    signal l00_axi_awlen        :  std_logic_vector(7 downto 0);
    signal l00_axi_awsize       :  std_logic_vector(2 downto 0);
    signal l00_axi_awburst      :  std_logic_vector(1 downto 0);
    signal l00_axi_awlock       :  std_logic;
    signal l00_axi_awcache      :  std_logic_vector(3 downto 0);
    signal l00_axi_awprot       :  std_logic_vector(2 downto 0);
    signal l00_axi_awqos        :  std_logic_vector(3 downto 0);
    signal l00_axi_awvalid      :  std_logic;
    signal l00_axi_awready      :  std_logic;
    signal l00_axi_wdata        :  std_logic_vector(31 downto 0);
    signal l00_axi_wstrb        :  std_logic_vector(3 downto 0);
    signal l00_axi_wlast        :  std_logic;
    signal l00_axi_wvalid       :  std_logic;
    signal l00_axi_wready       :  std_logic;
    signal l00_axi_bid          :  std_logic_vector(0 downto 0);
    signal l00_axi_bresp        :  std_logic_vector(1 downto 0);
    signal l00_axi_bvalid       :  std_logic;
    signal l00_axi_bready       :  std_logic;
    signal l00_axi_arid         :  std_logic_vector(0 downto 0);
    signal l00_axi_araddr       :  std_logic_vector(31 downto 0);
    signal l00_axi_arlen        :  std_logic_vector(7 downto 0);
    signal l00_axi_arsize       :  std_logic_vector(2 downto 0);
    signal l00_axi_arburst      :  std_logic_vector(1 downto 0);
    signal l00_axi_arlock       :  std_logic;
    signal l00_axi_arcache      :  std_logic_vector(3 downto 0);
    signal l00_axi_arprot       :  std_logic_vector(2 downto 0);
    signal l00_axi_arqos        :  std_logic_vector(3 downto 0);
    signal l00_axi_arvalid      :  std_logic;
    signal l00_axi_arready      :  std_logic;
    signal l00_axi_rid          :  std_logic_vector(0 downto 0);
    signal l00_axi_rdata        :  std_logic_vector(31 downto 0);
    signal l00_axi_rresp        :  std_logic_vector(1 downto 0);
    signal l00_axi_rlast        :  std_logic;
    signal l00_axi_rvalid       :  std_logic;
    signal l00_axi_rready       :  std_logic;


    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0);
    signal ram_address        : std_logic_vector(29 downto 2);
    signal ram_data_write     : std_logic_vector(31 downto 0);
    signal ram_data_read      : std_logic_vector(31 downto 0);
    signal ram_read_busy      : std_logic := '0';
    signal ram_ready          : std_logic := '1';
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);

    -- zynq ram memory axi port
    signal ram_axi_miso: T_axi64_miso;
    signal ram_axi_mosi: T_axi64_mosi;

    -- main CPU f32c xram axi port 
    signal main_axi_miso: T_axi_miso;
    signal main_axi_mosi: T_axi_mosi;
    
    -- video axi port
    signal video_axi_aresetn: std_logic := '1';
    signal video_axi_aclk: std_logic;
    signal video_axi_miso: T_axi_miso;
    signal video_axi_mosi: T_axi_mosi;

    -- vector axi port
    signal vector_axi_aresetn: std_logic := '1';
    signal vector_axi_miso: T_axi_miso;
    signal vector_axi_mosi: T_axi_mosi;
   
    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
    signal vga_vsync_n, vga_hsync_n: std_logic;

    signal R_blinky: std_logic_vector(26 downto 0);
    signal FCLK_CLK0: std_logic; -- output from zynq

    signal ps2_clk_in : std_logic;
    signal ps2_clk_out : std_logic;
    signal ps2_dat_in : std_logic;
    signal ps2_dat_out : std_logic;
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin
    cpu100M_sdr_640x480: if C_clk_freq = 100 and not C_dvid_ddr and C_video_mode=1 generate
    clk_cpu100M_sdr_640x480: clk_125_100_200_250_25MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_250mhz => clk_250MHz,
             clk_25mhz  => clk_25MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_25MHz;
    clk_pixel_shift <= clk_250MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu100M_ddr_640x360: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=0 generate
    clk_cpu100M_ddr_640x360: clk_125_100_200_125_25MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_125mhz => clk_125MHz,
             clk_25mhz  => clk_25MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_25MHz;
    clk_pixel_shift <= clk_125MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu100M_ddr_640x480: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=1 generate
    clk_cpu100M_ddr_640x480: clk_125_100_200_125_25MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_125mhz => clk_125MHz,
             clk_25mhz  => clk_25MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_25MHz;
    clk_pixel_shift <= clk_125MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu100M_ddr_800x480: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=2 generate
    clk_cpu100M_ddr_800x480: clk_125_100_200_150_30MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_150mhz => clk_150MHz,
             clk_30mhz  => clk_30MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_30MHz;
    clk_pixel_shift <= clk_150MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu100M_ddr_800x600: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=3 generate
    clk_cpu100M_ddr_800x600: clk_125_100_200_40MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_40mhz  => clk_40MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_40MHz;
    clk_pixel_shift <= clk_200MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu100M_ddr_1024x576: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=4 generate
    clk_cpu100M_ddr_1024x576: clk_125_100_200_250_50MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk_100MHz,
             clk_200mhz => clk_200MHz,
             clk_250mhz => clk_250MHz,
             clk_50mhz  => clk_50MHz
    );
    clk <= clk_100MHz;
    clk_pixel <= clk_50MHz;
    clk_pixel_shift <= clk_250MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu108M_ddr_1024x768: if C_clk_freq = 108 and C_dvid_ddr and C_video_mode=5 generate
    clk_cpu108M_ddr_1024x768: clk_125_108_216_325_65MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_108m333hz => clk_108MHz,
             clk_216m666hz => clk_216MHz,
             clk_325mhz => clk_325MHz,
             clk_65mhz  => clk_65MHz
    );
    clk <= clk_108MHz;
    clk_pixel <= clk_65MHz;
    clk_pixel_shift <= clk_325MHz;
    video_axi_aclk <= clk_216MHz;
    clk_axi <= clk_216MHz;
    end generate;

    cpu108M_ddr_1280x1024: if C_clk_freq = 108 and C_dvid_ddr and C_video_mode=7 generate
    clk_cpu108M_ddr_1280x1024: clk_125_108_216_541MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_108m333hz => clk_108MHz,
             clk_216m666hz => clk_216MHz,
             clk_541m666hz => clk_541MHz
    );
    clk <= clk_108MHz;
    clk_pixel <= clk_108MHz;
    clk_pixel_shift <= clk_541MHz;
    video_axi_aclk <= clk_216MHz;
    clk_axi <= clk_216MHz;
    end generate;

    G_vendor_specific_startup: if C_vendor_specific_startup generate
    -- reset hard-block: Xilinx Artix-7 specific
    reset: startupe2
    generic map (
      prog_usr => "FALSE"
    )
    port map (
      cfgmclk => cfgmclk,
      clk => cfgmclk,
      gsr => sio_break,
      gts => '0',
      keyclearb => '0',
      pack => '1',
      usrcclko => clk,
      usrcclkts => '0',
      usrdoneo => '1',
      usrdonets => '0'
    );
    end generate;

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_axiram => C_axiram,
      C_acram => C_acram,
      C_acram_wait_cycles => C_acram_wait_cycles,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,

      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_burst_max_bits => C_vector_burst_max_bits,
      C_vector_registers => C_vector_registers,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,

      C_dvid_ddr => C_dvid_ddr,

      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_axi => C_vgahdmi_axi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_timeout => C_vgahdmi_fifo_timeout,
      C_vgahdmi_fifo_burst_max => C_vgahdmi_fifo_burst_max,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,

      -- vga advanced graphics text+compositing bitmap
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_bram_base => C_vgatext_bram_base,
      C_vgatext_external_mem => C_vgatext_external_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
      C_vgatext_font_bram8 => C_vgatext_font_bram8,
      C_vgatext_bus_read => C_vgatext_bus_read,
      C_vgatext_reg_read => C_vgatext_reg_read,
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
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,

      C_timer => C_timer,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_pixel,
      clk_pixel_shift => clk_pixel_shift,

      cpu_axi_in => main_axi_miso,
      cpu_axi_out => main_axi_mosi,

      vector_axi_in => vector_axi_miso,
      vector_axi_out => vector_axi_mosi,

      acram_en => ram_en,
      acram_addr => ram_address,
      acram_byte_we => ram_byte_we,
      acram_data_rd => ram_data_read,
      acram_data_wr => ram_data_write,
      acram_ready => ram_ready,

      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => sio_break,
      spi_sck(0)  => open,  spi_sck(1)  => open,
      spi_ss(0)   => open,  spi_ss(1)   => open,
      spi_mosi(0) => open,  spi_mosi(1) => open,
      spi_miso(0) => '-',   spi_miso(1) => '-',
      gpio(3 downto 0) => ja_u(3 downto 0),
      gpio(7 downto 4) => ja_d(3 downto 0),
      gpio(11 downto 8) => jb_u(3 downto 0),
      gpio(15 downto 12) => jb_d(3 downto 0),
      gpio(19 downto 16) => jc_u(3 downto 0),
      gpio(23 downto 20) => jc_d(3 downto 0),
      gpio(27 downto 24) => jd_u(3 downto 0),
      gpio(31 downto 28) => jd_d(3 downto 0),
      gpio(127 downto 32) => open,

      -- VGA/HDMI
      video_axi_aresetn => video_axi_aresetn,
      video_axi_aclk => video_axi_aclk,
      video_axi_in => video_axi_miso,
      video_axi_out => video_axi_mosi,
      vga_vsync => vga_vs,
      vga_hsync => vga_hs,
      vga_r(7 downto 3) => vga_r(4 downto 0),
      vga_r(2 downto 0) => open,
      vga_g(7 downto 2) => vga_g(5 downto 0),
      vga_g(1 downto 0) => open,
      vga_b(7 downto 3) => vga_b(4 downto 0),
      vga_b(2 downto 0) => open,
      dvid_red   => dvid_red,
      dvid_green => dvid_green,
      dvid_blue  => dvid_blue,
      dvid_clock => dvid_clock,
      -- simple I/O
      simple_out(2 downto 0) => led(2 downto 0),
      simple_out(31 downto 3) => open,
      simple_in(3 downto 0) => btn(3 downto 0),
      simple_in(15 downto 4) => open,
      simple_in(19 downto 16) => sw(3 downto 0),
      simple_in(31 downto 20) => open
    );

    G_dvi_sdr: if not C_dvid_ddr generate
      tmds_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_clk <= dvid_clock(0);
    end generate;

    G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift,
      clk_n     => '0', -- inverted shift clock not needed on xilinx
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_rgb(2),
      out_green => tmds_rgb(1),
      out_blue  => tmds_rgb(0),
      out_clock => tmds_clk
    );
    end generate;

    -- differential output buffering for HDMI clock and video
    hdmi_out_en <= '1';
    hdmi_output: entity work.hdmi_out
    port map (
      tmds_in_clk => tmds_clk,
      tmds_out_clk_p => hdmi_clk_p,
      tmds_out_clk_n => hdmi_clk_n,
      tmds_in_rgb => tmds_rgb,
      tmds_out_rgb_p => hdmi_d_p,
      tmds_out_rgb_n => hdmi_d_n
    );

    acram_emu_gen: if C_acram_emu_kb > 0 and C_acram generate
    axi_cache_emulation: entity work.acram_emu
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
    --ram_data_read <= x"01234567"; -- debug purpose
    end generate;

    G_acram_real: if C_acram_emu_kb = 0 and C_acram generate
    axi_cache_ram: entity work.axi_cache
    port map (
        sys_clk            => clk,
        reset              => '0', -- release reset when DDR3 is ready

        -- simple RAM bus interface
        i_en               => ram_en,
        addr_next          => (others => '0'),
        addr(31 downto 30) => "00",
        addr(29 downto 2)  => ram_address(29 downto 2),
        addr(1 downto 0)   => "00",
        wbe                => ram_byte_we,
        din                => ram_data_write,
        dout               => ram_data_read,
        readBusy           => ram_read_busy,
        hitcount           => ram_cache_hitcnt,
        readcount          => ram_cache_readcnt,
        debug              => ram_cache_debug,

        -- axi port l00
        m_axi_aresetn      => l00_axi_areset_n,
        m_axi_aclk         => l00_axi_aclk,
        m_axi_awid         => l00_axi_awid,
        m_axi_awaddr       => l00_axi_awaddr,
        m_axi_awlen        => l00_axi_awlen,
        m_axi_awsize       => l00_axi_awsize,
        m_axi_awburst      => l00_axi_awburst,
        m_axi_awlock       => l00_axi_awlock,
        m_axi_awcache      => l00_axi_awcache,
        m_axi_awprot       => l00_axi_awprot,
        m_axi_awqos        => l00_axi_awqos,
        m_axi_awvalid      => l00_axi_awvalid,
        m_axi_awready      => l00_axi_awready,
        m_axi_wdata        => l00_axi_wdata,
        m_axi_wstrb        => l00_axi_wstrb,
        m_axi_wlast        => l00_axi_wlast,
        m_axi_wvalid       => l00_axi_wvalid,
        m_axi_wready       => l00_axi_wready,
        m_axi_bid          => l00_axi_bid,
        m_axi_bresp        => l00_axi_bresp,
        m_axi_bvalid       => l00_axi_bvalid,
        m_axi_bready       => l00_axi_bready,
        m_axi_arid         => l00_axi_arid,
        m_axi_araddr       => l00_axi_araddr,
        m_axi_arlen        => l00_axi_arlen,
        m_axi_arsize       => l00_axi_arsize,
        m_axi_arburst      => l00_axi_arburst,
        m_axi_arlock       => l00_axi_arlock,
        m_axi_arcache      => l00_axi_arcache,
        m_axi_arprot       => l00_axi_arprot,
        m_axi_arqos        => l00_axi_arqos,
        m_axi_arvalid      => l00_axi_arvalid,
        m_axi_arready      => l00_axi_arready,
        m_axi_rid          => l00_axi_rid,
        m_axi_rdata        => l00_axi_rdata,
        m_axi_rresp        => l00_axi_rresp,
        m_axi_rlast        => l00_axi_rlast,
        m_axi_rvalid       => l00_axi_rvalid,
        m_axi_rready       => l00_axi_rready
    );
    ram_ready <= not ram_read_busy;

    u_ddr_mem : entity work.zinq_ram_wrapper
    port map(
        -- ZINQ IO
        FCLK_CLK0 => open,
        FCLK_RESET0_N => open,
        FIXED_IO_mio        => open,
        FIXED_IO_ps_clk     => clk,
        FIXED_IO_ps_porb    => open,
        FIXED_IO_ps_srstb   => open,
        -- physical signals to RAM chip
        ddr_dq              => ddr_dq,
        ddr_dqs_n           => ddr_dqs_n,
        ddr_dqs_p           => ddr_dqs_p,
        ddr_addr            => ddr_addr,
        ddr_ba              => ddr_bankaddr,
        ddr_ras_n           => ddr_ras_n,
        ddr_cas_n           => ddr_cas_n,
        ddr_we_n            => ddr_we_n,
        ddr_ck_p            => ddr_clk,
        ddr_ck_n            => ddr_clk_n,
        ddr_cke             => ddr_cke,
        ddr_dm              => ddr_dm,
        ddr_odt             => ddr_odt,
        ddr_reset_n         => open, -- ddr chip reset_n wired onbard to GND
        FIXED_IO_ddr_vrn    => ddr_vrn,
        FIXED_IO_ddr_vrp    => ddr_vrp,
        -- AXI
        -- port l00
        S_AXI_ACP_aclk         => l00_axi_aclk,
        S_AXI_ACP_awid         => (others => '0'),
        S_AXI_ACP_awaddr       => l00_axi_awaddr,
        S_AXI_ACP_awlen        => l00_axi_awlen(3 downto 0),
        S_AXI_ACP_awsize       => l00_axi_awsize,
        S_AXI_ACP_awburst      => l00_axi_awburst,
        S_AXI_ACP_awlock       => (others => '0'),
        S_AXI_ACP_awcache      => l00_axi_awcache,
        S_AXI_ACP_awprot       => l00_axi_awprot,
        S_AXI_ACP_awqos        => l00_axi_awqos,
        S_AXI_ACP_awvalid      => l00_axi_awvalid,
        S_AXI_ACP_awready      => l00_axi_awready,
        S_AXI_ACP_wdata        => l00_axi_wdata,
        S_AXI_ACP_wstrb        => l00_axi_wstrb,
        S_AXI_ACP_wlast        => l00_axi_wlast,
        S_AXI_ACP_wvalid       => l00_axi_wvalid,
        S_AXI_ACP_wready       => l00_axi_wready,
        S_AXI_ACP_awuser       => (others => '0'),
        S_AXI_ACP_wid          => (others => '0'),
        S_AXI_ACP_bid(2 downto 1) => open,
        S_AXI_ACP_bid(0)       => l00_axi_bid(0),
        S_AXI_ACP_bresp        => l00_axi_bresp,
        S_AXI_ACP_bvalid       => l00_axi_bvalid,
        S_AXI_ACP_bready       => l00_axi_bready,
        S_AXI_ACP_arid         => (others => '0'),
        S_AXI_ACP_araddr       => l00_axi_araddr,
        S_AXI_ACP_arlen        => l00_axi_arlen(3 downto 0),
        S_AXI_ACP_arsize       => l00_axi_arsize,
        S_AXI_ACP_arburst      => l00_axi_arburst,
        S_AXI_ACP_arlock       => (others => '0'),
        S_AXI_ACP_arcache      => l00_axi_arcache,
        S_AXI_ACP_arprot       => l00_axi_arprot,
        S_AXI_ACP_arqos        => l00_axi_arqos,
        S_AXI_ACP_arvalid      => l00_axi_arvalid,
        S_AXI_ACP_arready      => l00_axi_arready,
        S_AXI_ACP_aruser       => (others => '0'),
        S_AXI_ACP_rid(2 downto 1) => open,
        S_AXI_ACP_rid(0)       => l00_axi_rid(0),
        S_AXI_ACP_rdata        => l00_axi_rdata,
        S_AXI_ACP_rresp        => l00_axi_rresp,
        S_AXI_ACP_rlast        => l00_axi_rlast,
        S_AXI_ACP_rvalid       => l00_axi_rvalid,
        S_AXI_ACP_rready       => l00_axi_rready
    );
    l00_axi_aclk <= clk; -- 100 MHz
    end generate; -- G_acram_real

    G_axiram_real: if false and C_axiram generate
    u_zinq_ram: entity work.zinq_ram_wrapper
    port map(
        -- ZINQ IO
        FCLK_CLK0 => FCLK_CLK0,
        FCLK_RESET0_N => open,
        FIXED_IO_mio        => open,
        --FIXED_IO_ps_clk     => clk, -- I don't know what's the purpose of this clock  ?
        FIXED_IO_ps_porb    => open,
        FIXED_IO_ps_srstb   => open,
        -- physical signals to RAM chip
        ddr_dq              => ddr_dq,
        ddr_dqs_n           => ddr_dqs_n,
        ddr_dqs_p           => ddr_dqs_p,
        ddr_addr            => ddr_addr,
        ddr_ba              => ddr_bankaddr,
        ddr_ras_n           => ddr_ras_n,
        ddr_cas_n           => ddr_cas_n,
        ddr_we_n            => ddr_we_n,
        ddr_ck_p            => ddr_clk,
        ddr_ck_n            => ddr_clk_n,
        ddr_cke             => ddr_cke,
        ddr_dm              => ddr_dm,
        ddr_odt             => ddr_odt,
        ddr_reset_n         => open, -- ddr chip reset_n wired onbard to GND
        FIXED_IO_ddr_vrn    => ddr_vrn,
        FIXED_IO_ddr_vrp    => ddr_vrp,
        -- AXI
        -- port l00
        S_AXI_ACP_aclk         => clk, -- f32c cpu clock to axi slave
        S_AXI_ACP_awid         => (others => '0'),
        S_AXI_ACP_awaddr       => x"0" & '1' & main_axi_mosi.awaddr(25 downto 0) & '0', -- drty fix
        S_AXI_ACP_awlen        => main_axi_mosi.awlen(3 downto 0),
        S_AXI_ACP_awsize       => main_axi_mosi.awsize,
        S_AXI_ACP_awburst      => main_axi_mosi.awburst,
        S_AXI_ACP_awlock       => (others => '0'),
        S_AXI_ACP_awcache      => main_axi_mosi.awcache,
        S_AXI_ACP_awprot       => main_axi_mosi.awprot,
        S_AXI_ACP_awqos        => main_axi_mosi.awqos,
        S_AXI_ACP_awvalid      => main_axi_mosi.awvalid,
        S_AXI_ACP_awready      => main_axi_miso.awready,
        S_AXI_ACP_awuser       => (others => '0'),
        S_AXI_ACP_wdata(63 downto 32) => (others => '0'),
        S_AXI_ACP_wdata(31 downto 0) => main_axi_mosi.wdata,
        S_AXI_ACP_wstrb(7 downto 4) => (others => '0'),
        S_AXI_ACP_wstrb(3 downto 0) => main_axi_mosi.wstrb,
        S_AXI_ACP_wlast        => main_axi_mosi.wlast,
        S_AXI_ACP_wvalid       => main_axi_mosi.wvalid,
        S_AXI_ACP_wready       => main_axi_miso.wready,
        S_AXI_ACP_wid          => (others => '0'),
        S_AXI_ACP_bid(2 downto 1) => open,
        S_AXI_ACP_bid(0)       => main_axi_miso.bid(0),
        S_AXI_ACP_bresp        => main_axi_miso.bresp,
        S_AXI_ACP_bvalid       => main_axi_miso.bvalid,
        S_AXI_ACP_bready       => main_axi_mosi.bready,
        S_AXI_ACP_arid         => (others => '0'),
        S_AXI_ACP_araddr       => x"0" & '1' & main_axi_mosi.araddr(25 downto 0) & '0', -- drty fix
        S_AXI_ACP_arlen        => main_axi_mosi.arlen(3 downto 0),
        S_AXI_ACP_arsize       => main_axi_mosi.arsize,
        S_AXI_ACP_arburst      => main_axi_mosi.arburst,
        S_AXI_ACP_arlock       => (others => '0'),
        S_AXI_ACP_arcache      => main_axi_mosi.arcache,
        S_AXI_ACP_arprot       => main_axi_mosi.arprot,
        S_AXI_ACP_arqos        => main_axi_mosi.arqos,
        S_AXI_ACP_arvalid      => main_axi_mosi.arvalid,
        S_AXI_ACP_arready      => main_axi_miso.arready,
        S_AXI_ACP_aruser       => (others => '0'),
        S_AXI_ACP_rid(2 downto 1) => open,
        S_AXI_ACP_rid(0)       => main_axi_miso.rid(0),
        S_AXI_ACP_rdata(63 downto 32) => open,
        S_AXI_ACP_rdata(31 downto 0) => main_axi_miso.rdata,
        S_AXI_ACP_rresp        => main_axi_miso.rresp,
        S_AXI_ACP_rlast        => main_axi_miso.rlast,
        S_AXI_ACP_rvalid       => main_axi_miso.rvalid,
        S_AXI_ACP_rready       => main_axi_mosi.rready
    );
    end generate;

    G_axiram_interconnect_real: if true and C_axiram generate
    axi_interconnect: entity work.axi_interconnect_1m64_3s32_vhd
    port map
    (
      aclk => clk_axi,
      aresetn => '1',

      s00_axi_areset_out_n => open,
      s00_axi_aclk => clk,
      s00_axi_in => main_axi_mosi,
      s00_axi_out => main_axi_miso,

      s01_axi_areset_out_n => vector_axi_aresetn,
      s01_axi_aclk => clk,
      s01_axi_in => vector_axi_mosi,
      s01_axi_out => vector_axi_miso,

      s02_axi_areset_out_n => video_axi_aresetn,
      s02_axi_aclk => video_axi_aclk,
      s02_axi_in => video_axi_mosi,
      s02_axi_out => video_axi_miso,

      m00_axi_areset_out_n => open,
      m00_axi_aclk => clk_axi,
      m00_axi_in => ram_axi_miso,
      m00_axi_out => ram_axi_mosi
    );

    u_zynq_ram: entity work.zinq_ram_wrapper
    port map(
        -- ZINQ IO
        FCLK_CLK0 => FCLK_CLK0,
        FCLK_RESET0_N => open,
        FIXED_IO_mio        => open,
        --FIXED_IO_ps_clk     => clk, -- I don't know what's the purpose of this clock  ?
        FIXED_IO_ps_porb    => open,
        FIXED_IO_ps_srstb   => open,
        -- physical signals to RAM chip
        ddr_dq              => ddr_dq,
        ddr_dqs_n           => ddr_dqs_n,
        ddr_dqs_p           => ddr_dqs_p,
        ddr_addr            => ddr_addr,
        ddr_ba              => ddr_bankaddr,
        ddr_ras_n           => ddr_ras_n,
        ddr_cas_n           => ddr_cas_n,
        ddr_we_n            => ddr_we_n,
        ddr_ck_p            => ddr_clk,
        ddr_ck_n            => ddr_clk_n,
        ddr_cke             => ddr_cke,
        ddr_dm              => ddr_dm,
        ddr_odt             => ddr_odt,
        ddr_reset_n         => open, -- ddr chip reset_n wired onbard to GND
        FIXED_IO_ddr_vrn    => ddr_vrn,
        FIXED_IO_ddr_vrp    => ddr_vrp,
        -- AXI
        -- port l00
        S_AXI_ACP_aclk         => clk_axi, -- f32c cpu clock to axi slave
        S_AXI_ACP_awid         => ram_axi_mosi.awid(2 downto 0),
        S_AXI_ACP_awaddr       => x"1" & ram_axi_mosi.awaddr(27 downto 0), -- drty fix
        S_AXI_ACP_awlen        => ram_axi_mosi.awlen(3 downto 0),
        S_AXI_ACP_awsize       => ram_axi_mosi.awsize,
        S_AXI_ACP_awburst      => ram_axi_mosi.awburst,
        S_AXI_ACP_awlock       => (others => '0'),
        S_AXI_ACP_awcache      => (others => '1'),
        S_AXI_ACP_awprot       => ram_axi_mosi.awprot,
        S_AXI_ACP_awqos        => ram_axi_mosi.awqos,
        S_AXI_ACP_awvalid      => ram_axi_mosi.awvalid,
        S_AXI_ACP_awready      => ram_axi_miso.awready,
        S_AXI_ACP_awuser       => (others => '0'),
        S_AXI_ACP_wdata        => ram_axi_mosi.wdata,
        S_AXI_ACP_wstrb        => ram_axi_mosi.wstrb,
        S_AXI_ACP_wlast        => ram_axi_mosi.wlast,
        S_AXI_ACP_wvalid       => ram_axi_mosi.wvalid,
        S_AXI_ACP_wready       => ram_axi_miso.wready,
        S_AXI_ACP_wid          => (others => '0'),
        S_AXI_ACP_bid          => ram_axi_miso.bid(2 downto 0),
        S_AXI_ACP_bresp        => ram_axi_miso.bresp,
        S_AXI_ACP_bvalid       => ram_axi_miso.bvalid,
        S_AXI_ACP_bready       => ram_axi_mosi.bready,
        S_AXI_ACP_arid         => ram_axi_mosi.arid(2 downto 0),
        S_AXI_ACP_araddr       => x"1" & ram_axi_mosi.araddr(27 downto 0), -- drty fix
        S_AXI_ACP_arlen        => ram_axi_mosi.arlen(3 downto 0),
        S_AXI_ACP_arsize       => ram_axi_mosi.arsize,
        S_AXI_ACP_arburst      => ram_axi_mosi.arburst,
        S_AXI_ACP_arlock       => (others => '0'),
        S_AXI_ACP_arcache      => (others => '1'),
        S_AXI_ACP_arprot       => ram_axi_mosi.arprot,
        S_AXI_ACP_arqos        => ram_axi_mosi.arqos,
        S_AXI_ACP_arvalid      => ram_axi_mosi.arvalid,
        S_AXI_ACP_arready      => ram_axi_miso.arready,
        S_AXI_ACP_aruser       => (others => '0'),
        S_AXI_ACP_rid          => ram_axi_miso.rid(2 downto 0),
        S_AXI_ACP_rdata        => ram_axi_miso.rdata,
        S_AXI_ACP_rresp        => ram_axi_miso.rresp,
        S_AXI_ACP_rlast        => ram_axi_miso.rlast,
        S_AXI_ACP_rvalid       => ram_axi_miso.rvalid,
        S_AXI_ACP_rready       => ram_axi_mosi.rready
    );
    end generate;

    -- ZYNQ should output some clock (100 MHz)
    -- if this clock runs, led will blink
    -- having no clock means non-functional zynq
    process(FCLK_CLK0)
    begin
      if rising_edge(FCLK_CLK0) then
        R_blinky <= R_blinky+1;
      end if;
    end process;
    led(3) <= R_blinky(R_blinky'high);

end Behavioral;
