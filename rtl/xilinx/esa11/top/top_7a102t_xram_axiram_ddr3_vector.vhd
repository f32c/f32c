--
-- Copyright (c) 2015 Emanuel Stiebler
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;
use work.axi_pack.all;

entity esa11_xram_axiram_ddr3 is
  generic (
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

	-- SoC configuration options
	C_bram_size: integer := 16; -- K default 16
	C_boot_write_protect: boolean := true; -- set to 'false' for 1K bram size

        -- axi ram
	C_axiram: boolean := true; -- default true
	C_axi_mig_data_bits: integer := 32; -- bits 32 or 128 (data bus width in link between MIG and AXI interconnect), default 32

        C_mult_enable: boolean := true;
        C_mul_acc: boolean := false;    -- MI32 only, default false
        C_mul_reg: boolean := false;    -- MI32 only, default false

        -- integer multiplication doesn't work for CPU clock 100MHz, works at 83MHz
        -- cache 4K doesn't work vectors at 100MHz CPU clock
        -- cacke 2K or 8K vectors work at 100MHz CPU clock
        C_icache_size: integer := 8; -- K 0, 2, 4, 8, 16, 32 KBytes, default 8
        C_dcache_size: integer := 8; -- K 0, 2, 4, 8, 16, 32 KBytes, default 8
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

        -- DDR3 parameters (don't touch)
        C3_NUM_DQ_PINS        : integer := 16;
        C3_MEM_ADDR_WIDTH     : integer := 14;
        C3_MEM_BANKADDR_WIDTH : integer := 3;

        C_vector: boolean := true; -- vector processor unit
        C_vector_axi: boolean := true; -- true: use AXI I/O, false use f32c RAM port I/O
        C_vector_burst_max_bits: integer := 6; -- bits describe max burst, default 6: burst length 2^6=64
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_bram_pass_thru: boolean := false; -- number of internal vector registers min 2, each takes 8K
        C_vector_vaddr_bits: integer := 11; -- bits default 11: 2^11=2048 elements
        C_vector_vdata_bits: integer := 32; -- bits default 32: 32-bit float, don't touch
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

        C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)
        C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024, default 1

        C_vgahdmi: boolean := true;
          C_vgahdmi_axi: boolean := true; -- connect vgahdmi to video_axi_in/out instead to f32c bus arbiter
          C_vgahdmi_cache_size: integer := 8; -- KB video cache (only on f32c bus) (0: disable, 2,4,8,16,32:enable, default 8)
          C_vgahdmi_fifo_timeout: integer := 0; -- default 0
          C_vgahdmi_fifo_burst_max_bits: integer := 6; -- 6 bits -> 64x32-bit words
          C_vgahdmi_fifo_data_width: integer := 32; -- bits per pixel (default 32)

    C_vgatext: boolean := false; -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: ESA11-7a102t MIPS compatible soft-core 80MHz 256MB DDR3"; -- default banner as initial content of screen BRAM, NOP for RAM
      C_vgatext_bits: integer := 4; -- 64 possible colors
      C_vgatext_bram_mem: integer := 0; -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height 16: 80x30, 8: 80x60
        C_vgatext_font_height: integer := 16; -- font height 16: 80x30, 8: 80x60
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true; -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true; -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true; -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          C_vgatext_bitmap_fifo_timeout: integer := 48; -- abort compositing 48 pixels before end of line
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
    C_timer: boolean := true; -- false: no timer
    C_ps2: boolean := false; -- no PS/2 keyboard
    C_gpio: integer := 32; -- 0: disabled, 32:32 GPIO bits
    C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
  );
  port (
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic;
	FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
	FPGA_SD_D0: in std_logic;
	FPGA_CCLK_CONF_DCLK: out std_logic;
	FPGA_CSO, FPGA_MOSI: out std_logic;
	FPGA_MISO_INTERNAL: in std_logic;
        -- DDR3 ------------------------------------------------------------------
        DDR_DQ                  : inout  std_logic_vector(C3_NUM_DQ_PINS-1 downto 0);       -- mcb3_dram_dq
        DDR_A                   : out    std_logic_vector(C3_MEM_ADDR_WIDTH-1 downto 0);    -- mcb3_dram_a
        DDR_BA                  : out    std_logic_vector(C3_MEM_BANKADDR_WIDTH-1 downto 0);-- mcb3_dram_ba
        DDR_RAS_N               : out    std_logic;                                         -- mcb3_dram_ras_n
        DDR_CAS_N               : out    std_logic;                                         -- mcb3_dram_cas_n
        DDR_WE_N                : out    std_logic;                                         -- mcb3_dram_we_n
        DDR_ODT                 : out    std_logic;                                         -- mcb3_dram_odt
        DDR_CKE                 : out    std_logic;                                         -- mcb3_dram_cke
        DDR_LDM                 : out    std_logic;                                         -- mcb3_dram_dm
        DDR_DQS_P               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs
        DDR_DQS_N               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs_n
        DDR_UDM                 : out    std_logic;                                         -- mcb3_dram_udm
        DDR_CK_P                : out    std_logic;                                         -- mcb3_dram_ck
        DDR_CK_N                : out    std_logic;                                         -- mcb3_dram_ck_n
        DDR_RESET_N             : out    std_logic;
      
	M_EXPMOD0, M_EXPMOD1, M_EXPMOD2, M_EXPMOD3: inout std_logic_vector(7 downto 0); -- EXPMODs
	M_7SEG_A, M_7SEG_B, M_7SEG_C, M_7SEG_D, M_7SEG_E, M_7SEG_F, M_7SEG_G, M_7SEG_DP: out std_logic;
	M_7SEG_DIGIT: out std_logic_vector(3 downto 0);
--	seg: out std_logic_vector(7 downto 0); -- 7-segment display
--	an: out std_logic_vector(3 downto 0); -- 7-segment display
	M_LED: out std_logic_vector(7 downto 0);
	-- PS/2 keyboard
	PS2_A_DATA, PS2_A_CLK, PS2_B_DATA, PS2_B_CLK: inout std_logic;
        -- HDMI
	VID_D_P, VID_D_N: out std_logic_vector(2 downto 0);
	VID_CLK_P, VID_CLK_N: out std_logic;
        -- VGA
        VGA_RED, VGA_GREEN, VGA_BLUE: out std_logic_vector(7 downto 0);
        VGA_SYNC_N, VGA_BLANK_N, VGA_CLOCK_P: out std_logic;
        VGA_HSYNC, VGA_VSYNC: out std_logic;
	M_BTN: in std_logic_vector(4 downto 0);
	M_HEX: in std_logic_vector(3 downto 0)
  );
end esa11_xram_axiram_ddr3;

architecture Behavioral of esa11_xram_axiram_ddr3 is
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_30MHz, clk_40MHz, clk_45MHz, clk_50MHz, clk_65MHz, clk_75MHz, clk_80MHz, clk_81MHz, clk_83MHz,
           clk_100MHz, clk_108MHz, clk_112M5Hz, clk_125MHz, clk_150MHz,
           clk_200MHz, clk_216MHz, clk_225MHz, clk_250MHz,
           clk_325MHz, clk_375MHz, clk_541MHz: std_logic := '0';
    signal clk_axi: std_logic;
    signal clk_pixel: std_logic;
    signal clk_pixel_shift: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;
    type T_mode_clk_freq is array(0 to 7) of integer;
    -- CPU clocks for each video mode. must match PLL clock generator
    -- Use up to 83 MHz. 100 MHz is overclock which manifests
    -- as sometimes wrong integer multiplication in Galaga,
    -- descending group of ships becomes slightly disordered in x direction
    constant C_mode_clk_freq: T_mode_clk_freq :=
    (
      83, -- mode 0  640x360  83 100 MHz
      83, -- mode 1  640x480  83 100 MHz
      80, -- mode 2  800x480  80 100 MHz
      83, -- mode 3  800x600  83 100 MHz
      83, -- mode 4 1024x576  83 100 MHz
      81, -- mode 5 1024x768  81 108 MHz
      80, -- mode 6 1280x768  80 100 MHz
      83  -- mode 7 1280x1024 83 108 MHz
    );
    constant C_clk_freq: integer := C_mode_clk_freq(C_video_mode);

    component clk_d100_100_200_250_25MHz is
    Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_250mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_250_25MHz;

    component clk_d100_100_200_125_25MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_200M : out STD_LOGIC;
      clk_125M : out STD_LOGIC;
      clk_25M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_125_25MHz;

    component clk_d100_83_100_200_125_25MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_83M333 : out STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_200M : out STD_LOGIC;
      clk_125M : out STD_LOGIC;
      clk_25M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_83_100_200_125_25MHz;

    component clk_d100_100_200_150_30MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_80M : out STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_200M : out STD_LOGIC;
      clk_150M : out STD_LOGIC;
      clk_30M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_150_30MHz;

    component clk_d100_100_200_40MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_83M333 : out STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_200M : out STD_LOGIC;
      clk_40M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_40MHz;

    component clk_d100_100_112_225_45MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_225M : out STD_LOGIC;
      clk_112M5 : out STD_LOGIC;
      clk_45M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_112_225_45MHz;

    component clk_d100_100_200_250_50MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_83M333 : out STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_200M : out STD_LOGIC;
      clk_250M : out STD_LOGIC;
      clk_50M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_250_50MHz;

    component clk_d100_108_216_325_65MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_81M25 : out STD_LOGIC;
      clk_108M333 : out STD_LOGIC;
      clk_216M666 : out STD_LOGIC;
      clk_325M : out STD_LOGIC;
      clk_65M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_108_216_325_65MHz;

    component clk_d100_100_225_375_75MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_80M357 : out STD_LOGIC;
      clk_100M : out STD_LOGIC;
      clk_225M : out STD_LOGIC;
      clk_375M : out STD_LOGIC;
      clk_75M : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component;

    component clk_d100_108_216_541MHz is
    Port (
      clk_100M_in_p : in STD_LOGIC;
      clk_100M_in_n : in STD_LOGIC;
      clk_83M333 : out STD_LOGIC;
      clk_108M333 : out STD_LOGIC;
      clk_216M666 : out STD_LOGIC;
      clk_541M666 : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_108_216_541MHz;

    signal calib_done           : std_logic := '0';

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

    signal vga_clk: std_logic;
    signal S_vga_red, S_vga_green, S_vga_blue: std_logic_vector(7 downto 0);
    signal S_vga_blank: std_logic;
    signal S_vga_vsync, S_vga_hsync: std_logic;
    signal S_vga_fetch_next, S_vga_line_repeat: std_logic;
    signal S_vga_active_enabled: std_logic;
    signal S_vga_addr: std_logic_vector(29 downto 2);
    signal S_vga_addr_strobe: std_logic;
    signal S_vga_suggest_cache: std_logic;
    signal S_vga_suggest_burst: std_logic_vector(15 downto 0);
    signal S_vga_data, S_vga_data_debug: std_logic_vector(31 downto 0);
    signal S_vga_read_ready: std_logic;
    signal S_vga_data_ready: std_logic;
    signal red_byte, green_byte, blue_byte: std_logic_vector(7 downto 0);

    -- CPU memory axi port
    signal main_axi_areset_n: std_logic := '1';
    signal main_axi_miso: T_axi_miso;
    signal main_axi_mosi: T_axi_mosi;

    -- video axi port
    signal video_axi_areset_n: std_logic := '1';
    signal video_axi_aclk: std_logic;
    signal video_axi_miso: T_axi_miso;
    signal video_axi_mosi: T_axi_mosi;

    -- vector axi port
    signal vector_axi_areset_n: std_logic := '1';
    signal vector_axi_miso: T_axi_miso;
    signal vector_axi_mosi: T_axi_mosi;

    -- to switch glue/plasma vga
    signal glue_vga_vsync, glue_vga_hsync: std_logic;
    signal glue_vga_red, glue_vga_green, glue_vga_blue: std_logic_vector(7 downto 0);

    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
    --signal vga_vsync_n, vga_hsync_n: std_logic;
    signal ps2_clk_in : std_logic;
    signal ps2_clk_out : std_logic;
    signal ps2_dat_in : std_logic;
    signal ps2_dat_out : std_logic;
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin
    cpu100M_sdr_640x480: if C_clk_freq = 100 and not C_dvid_ddr and C_video_mode=1 generate
    clk_cpu100M_sdr_640x480: clk_d100_100_200_250_25MHz
    port map(clk_100mhz_in_p => i_100MHz_P,
             clk_100mhz_in_n => i_100MHz_N,
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
    end generate;

    cpu83_100M_ddr_640x480: if (C_clk_freq = 83 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode<=1 generate
    clk_cpu83_100M_ddr_640x480: clk_d100_83_100_200_125_25MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_83M333 => clk_83MHz,
             clk_100M => clk_100MHz,
             clk_200M => clk_200MHz,
             clk_125M => clk_125MHz,
             clk_25M  => clk_25MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu83M_ddr_640x480: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_ddr_640x480: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_25MHz;
    clk_pixel_shift <= clk_125MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu80_100M_ddr_800x480: if (C_clk_freq = 80 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=2 generate
    clk_cpu80_100M_ddr_800x480: clk_d100_100_200_150_30MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_80M => clk_80MHz,
             clk_100M => clk_100MHz,
             clk_200M => clk_200MHz,
             clk_150M => clk_150MHz,
             clk_30M  => clk_30MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu80M_ddr_800x480: if C_clk_freq = 80 generate
      clk <= clk_80MHz;
    end generate;
    cpu100M_ddr_800x480: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_30MHz;
    clk_pixel_shift <= clk_150MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu83_100M_ddr_800x600: if (C_clk_freq = 83 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=3 generate
    clk_cpu83_100M_ddr_800x600: clk_d100_100_200_40MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_83M333 => clk_83MHz,
             clk_100M => clk_100MHz,
             clk_200M => clk_200MHz,
             clk_40M  => clk_40MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu83M_ddr_800x600: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_ddr_800x600: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_40MHz;
    clk_pixel_shift <= clk_200MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu83_100M_ddr_1024x576: if (C_clk_freq = 83 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=4 generate
    clk_cpu83_100M_ddr_1024x576: clk_d100_100_200_250_50MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_83M333 => clk_83MHz,
             clk_100M => clk_100MHz,
             clk_200M => clk_200MHz,
             clk_250M => clk_250MHz,
             clk_50M  => clk_50MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu83M_ddr_1024x576: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_ddr_1024x576: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_50MHz;
    clk_pixel_shift <= clk_250MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu81_108M_ddr_1024x768: if (C_clk_freq = 81 or C_clk_freq = 108) and C_dvid_ddr and C_video_mode=5 generate
    clk_cpu81_108M_ddr_1024x768: clk_d100_108_216_325_65MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_81M25 => clk_81MHz,
             clk_108M333 => clk_108MHz,
             clk_216M666 => clk_216MHz,
             clk_325M => clk_325MHz,
             clk_65M  => clk_65MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu81M_ddr_1024x768: if C_clk_freq = 81 generate
      clk <= clk_81MHz;
    end generate;
    cpu108M_ddr_1024x768: if C_clk_freq = 108 generate
      clk <= clk_108MHz;
    end generate;
    clk_pixel <= clk_65MHz;
    clk_pixel_shift <= clk_325MHz;
    video_axi_aclk <= clk_216MHz;
    clk_axi <= clk_216MHz;
    end generate;

    cpu80_100M_ddr_1280x768: if (C_clk_freq = 80 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=6 generate
    clk_cpu80_100M_ddr_1280x768: clk_d100_100_225_375_75MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_80M357 => clk_80MHz,
             clk_100M => clk_100MHz,
             clk_225M => clk_225MHz,
             clk_375M => clk_375MHz,
             clk_75M  => clk_75MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu80M_ddr_1280x768: if C_clk_freq = 80 generate
      clk <= clk_80MHz;
    end generate;
    cpu100M_ddr_1280x768: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_75MHz;
    clk_pixel_shift <= clk_375MHz;
    video_axi_aclk <= clk_225MHz;
    clk_axi <= clk_225MHz;
    end generate;

    cpu83_108M_ddr_1280x1024: if (C_clk_freq = 83 or C_clk_freq = 108) and C_dvid_ddr and C_video_mode=7 generate
    clk_cpu83_108M_ddr_1280x1024: clk_d100_108_216_541MHz
    port map(clk_100M_in_p => i_100MHz_P,
             clk_100M_in_n => i_100MHz_N,
             clk_83M333 => clk_83MHz,
             clk_108M333 => clk_108MHz,
             clk_216M666 => clk_216MHz,
             clk_541M666 => clk_541MHz,
             locked => clk_locked,
             reset => '0'
    );
    cpu83M_ddr_1280x1024: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu108M_ddr_1280x1024: if C_clk_freq = 108 generate
      clk <= clk_108MHz;
    end generate;
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

    ps2_dat_in	<= PS2_A_DATA;
    PS2_A_DATA	<= '0' when ps2_dat_out='0' else 'Z';
    ps2_clk_in	<= PS2_A_CLK;
    PS2_A_CLK	<= '0' when ps2_clk_out='0' else 'Z';

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_boot_write_protect => C_boot_write_protect,
      C_axiram => C_axiram,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_mult_enable => C_mult_enable, C_mul_acc => C_mul_acc, C_mul_reg => C_mul_reg,
      C_gpio => C_gpio,
      C_timer => C_timer,
      C_sio => C_sio,
      C_spi => C_spi,
      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_burst_max_bits => C_vector_burst_max_bits,
      C_vector_registers => C_vector_registers,
      C_vector_bram_pass_thru => C_vector_bram_pass_thru,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,
      --C_ps2 => C_ps2,
      C_dvid_ddr => C_dvid_ddr,
      --
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_axi => C_vgahdmi_axi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_timeout => C_vgahdmi_fifo_timeout,
      C_vgahdmi_fifo_burst_max_bits => C_vgahdmi_fifo_burst_max_bits,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,

      -- vga advanced graphics text+compositing bitmap
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_video_mode,
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
      C_vgatext_bitmap_fifo_timeout => C_vgatext_bitmap_fifo_timeout,
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,

      C_debug => C_debug
    )
    port map (
        clk => clk,
	clk_pixel => clk_pixel,
	clk_pixel_shift => clk_pixel_shift,
	cpu_axi_in => main_axi_miso,
	cpu_axi_out => main_axi_mosi,
        video_axi_aresetn => video_axi_areset_n,
        video_axi_aclk => video_axi_aclk,
        video_axi_in => video_axi_miso,
        video_axi_out => video_axi_mosi,
        vector_axi_in => vector_axi_miso,
        vector_axi_out => vector_axi_mosi,
	sio_txd(0) => UART1_TXD, 
	sio_rxd(0) => UART1_RXD,
	sio_break(0) => sio_break,
        spi_sck(0)  => FPGA_CCLK_CONF_DCLK, spi_sck(1)  => FPGA_SD_SCLK,
        spi_ss(0)   => FPGA_CSO,            spi_ss(1)   => FPGA_SD_D3,
        spi_mosi(0) => FPGA_MOSI,           spi_mosi(1) => FPGA_SD_CMD,
        spi_miso(0) => FPGA_MISO_INTERNAL,  spi_miso(1) => FPGA_SD_D0,
	gpio(7 downto 0) => M_EXPMOD0, gpio(15 downto 8) => M_EXPMOD1,
	gpio(23 downto 16) => M_EXPMOD2, gpio(31 downto 24) => M_EXPMOD3,
	gpio(127 downto 32) => open,
        -- PS/2 Keyboard
        ps2_clk_in   => ps2_clk_in,
        ps2_dat_in   => ps2_dat_in,
        ps2_clk_out  => ps2_clk_out,
        ps2_dat_out  => ps2_dat_out,
        -- VGA/HDMI
	vga_vsync => glue_vga_vsync,
	vga_hsync => glue_vga_hsync,
	vga_r => glue_vga_red,
	vga_g => glue_vga_green,
	vga_b => glue_vga_blue,
        dvid_red   => dvid_red,
        dvid_green => dvid_green,
        dvid_blue  => dvid_blue,
        dvid_clock => dvid_clock,
	-- simple I/O
	simple_out(7 downto 0) => M_LED, simple_out(15 downto 8) => disp_7seg_segment,
	simple_out(19 downto 16) => M_7SEG_DIGIT, simple_out(31 downto 20) => open,
	simple_in(4 downto 0) => M_BTN,
        simple_in(8 downto 5) => M_HEX,
        simple_in(31 downto 9) => (others => '-')
    );

    m_7seg_a  <= disp_7seg_segment(0);
    m_7seg_b  <= disp_7seg_segment(1);
    m_7seg_c  <= disp_7seg_segment(2);
    m_7seg_d  <= disp_7seg_segment(3);
    m_7seg_e  <= disp_7seg_segment(4);
    m_7seg_f  <= disp_7seg_segment(5);
    m_7seg_g  <= disp_7seg_segment(6);
    m_7seg_dp <= disp_7seg_segment(7);

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
    hdmi_output: entity work.hdmi_out
    port map (
        tmds_in_clk => tmds_clk, -- clk_25MHz or tmds_clk
        tmds_out_clk_p => VID_CLK_P,
        tmds_out_clk_n => VID_CLK_N,
        tmds_in_rgb => tmds_rgb,
        tmds_out_rgb_p => VID_D_P,
        tmds_out_rgb_n => VID_D_N
    );

    G_axiram_real: if C_axiram generate
    u_ddr_mem : entity work.axi_mpmc
    generic map
    (
      C_mig_data_bits => C_axi_mig_data_bits, -- 32 or 128
      C_mig_wstrb_bits => C_axi_mig_data_bits/8  -- 4 or 16 (byte_select, normally C_mig_data_bits/8)
    )
    port map(
        sys_rst              => not clk_locked, -- release reset when clock is stable
        sys_clk_i            => clk_axi, -- not less than 200MHz, but not too much faster either
        -- physical signals to RAM chip
        ddr3_dq              => ddr_dq,
        ddr3_dqs_n           => ddr_dqs_n,
        ddr3_dqs_p           => ddr_dqs_p,
        ddr3_addr            => ddr_a,
        ddr3_ba              => ddr_ba,
        ddr3_ras_n           => ddr_ras_n,
        ddr3_cas_n           => ddr_cas_n,
        ddr3_we_n            => ddr_we_n,
        ddr3_reset_n         => ddr_reset_n,
        ddr3_ck_p(0)         => ddr_ck_p,
        ddr3_ck_n(0)         => ddr_ck_n,
        ddr3_cke(0)          => ddr_cke,
        ddr3_dm(1)           => ddr_udm,
        ddr3_dm(0)           => ddr_ldm,
        ddr3_odt(0)          => ddr_odt,

        -- multiport axi interface (AXI slaves)
        s00_axi_areset_out_n => main_axi_areset_n,
        s00_axi_aclk         => clk,
        s00_axi_in           => main_axi_mosi,
        s00_axi_out          => main_axi_miso,

        s01_axi_areset_out_n => vector_axi_areset_n,
        s01_axi_aclk         => clk,
        s01_axi_in           => vector_axi_mosi,
        s01_axi_out          => vector_axi_miso,

        s02_axi_areset_out_n => video_axi_areset_n,
        s02_axi_aclk         => video_axi_aclk,
        s02_axi_in           => video_axi_mosi,
        s02_axi_out          => video_axi_miso,

        init_calib_complete  => calib_done -- becomes high cca 0.3 seconds after startup
    );
    end generate; -- G_acram_real

    --FPGA_LED2 <= calib_done; -- should turn on 0.3 seconds after startup and remain on
    --FPGA_LED3 <= ram_read_busy; -- more RAM traffic -> more LED brightness

    vga_f32c: if C_vgahdmi or C_vgatext generate
    VGA_SYNC_N <= '1';
    VGA_BLANK_N <= '1';
    VGA_CLOCK_P <= clk_pixel;
    VGA_VSYNC <= glue_vga_vsync;
    VGA_HSYNC <= glue_vga_hsync;
    vga_red <= glue_vga_red;
    vga_green <= glue_vga_green;
    vga_blue <= glue_vga_blue;
    end generate;

end Behavioral;
