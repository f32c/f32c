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
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;

entity zybo_xram_ddr3 is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/100 MHz
	C_clk_freq: integer := 100;

	C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

	-- SoC configuration options
	C_bram_size: integer := 16;

        -- axi cache ram
	C_acram: boolean := true;
	C_acram_wait_cycles: integer := 2;
	C_acram_emu_kb: integer := 0; -- KB axi_cache emulation (0 to disable, power of 2, MAX 128)

        C_icache_expire: boolean := false; -- false: normal i-cache, true: passthru buggy i-cache
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

	C_vgahdmi: boolean := true;
	C_vgahdmi_test_picture: integer := 1; -- enable test picture

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: ESA11-7a35i MIPS compatible soft-core 100MHz 32MB DDR3"; -- default banner in screen memory
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
    signal clk_25MHz, clk_100MHz, clk_200MHz, clk_250MHz: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;

    component clk_d100_100_200_250_25MHz is
    Port (
      clk_125mhz_in : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_250mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_250_25MHz;

    signal calib_done           : std_logic;

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

    signal l01_axi_areset_n     :  std_logic := '1';
    signal l01_axi_aclk         :  std_logic := '0';
    signal l01_axi_awid         :  std_logic_vector(0 downto 0);
    signal l01_axi_awaddr       :  std_logic_vector(31 downto 0);
    signal l01_axi_awlen        :  std_logic_vector(7 downto 0);
    signal l01_axi_awsize       :  std_logic_vector(2 downto 0);
    signal l01_axi_awburst      :  std_logic_vector(1 downto 0);
    signal l01_axi_awlock       :  std_logic;
    signal l01_axi_awcache      :  std_logic_vector(3 downto 0);
    signal l01_axi_awprot       :  std_logic_vector(2 downto 0);
    signal l01_axi_awqos        :  std_logic_vector(3 downto 0);
    signal l01_axi_awvalid      :  std_logic;
    signal l01_axi_awready      :  std_logic;
    signal l01_axi_wdata        :  std_logic_vector(31 downto 0);
    signal l01_axi_wstrb        :  std_logic_vector(3 downto 0);
    signal l01_axi_wlast        :  std_logic;
    signal l01_axi_wvalid       :  std_logic;
    signal l01_axi_wready       :  std_logic;
    signal l01_axi_bid          :  std_logic_vector(0 downto 0);
    signal l01_axi_bresp        :  std_logic_vector(1 downto 0);
    signal l01_axi_bvalid       :  std_logic;
    signal l01_axi_bready       :  std_logic;
    signal l01_axi_arid         :  std_logic_vector(0 downto 0);
    signal l01_axi_araddr       :  std_logic_vector(31 downto 0);
    signal l01_axi_arlen        :  std_logic_vector(7 downto 0);
    signal l01_axi_arsize       :  std_logic_vector(2 downto 0);
    signal l01_axi_arburst      :  std_logic_vector(1 downto 0);
    signal l01_axi_arlock       :  std_logic;
    signal l01_axi_arcache      :  std_logic_vector(3 downto 0);
    signal l01_axi_arprot       :  std_logic_vector(2 downto 0);
    signal l01_axi_arqos        :  std_logic_vector(3 downto 0);
    signal l01_axi_arvalid      :  std_logic;
    signal l01_axi_arready      :  std_logic;
    signal l01_axi_rid          :  std_logic_vector(0 downto 0);
    signal l01_axi_rdata        :  std_logic_vector(31 downto 0);
    signal l01_axi_rresp        :  std_logic_vector(1 downto 0);
    signal l01_axi_rlast        :  std_logic;
    signal l01_axi_rvalid       :  std_logic;
    signal l01_axi_rready       :  std_logic;

    signal l02_axi_areset_n     :  std_logic := '1';
    signal l02_axi_aclk         :  std_logic := '0';
    signal l02_axi_awid         :  std_logic_vector(0 downto 0);
    signal l02_axi_awaddr       :  std_logic_vector(31 downto 0);
    signal l02_axi_awlen        :  std_logic_vector(7 downto 0);
    signal l02_axi_awsize       :  std_logic_vector(2 downto 0);
    signal l02_axi_awburst      :  std_logic_vector(1 downto 0);
    signal l02_axi_awlock       :  std_logic;
    signal l02_axi_awcache      :  std_logic_vector(3 downto 0);
    signal l02_axi_awprot       :  std_logic_vector(2 downto 0);
    signal l02_axi_awqos        :  std_logic_vector(3 downto 0);
    signal l02_axi_awvalid      :  std_logic;
    signal l02_axi_awready      :  std_logic;
    signal l02_axi_wdata        :  std_logic_vector(31 downto 0);
    signal l02_axi_wstrb        :  std_logic_vector(3 downto 0);
    signal l02_axi_wlast        :  std_logic;
    signal l02_axi_wvalid       :  std_logic;
    signal l02_axi_wready       :  std_logic;
    signal l02_axi_bid          :  std_logic_vector(0 downto 0);
    signal l02_axi_bresp        :  std_logic_vector(1 downto 0);
    signal l02_axi_bvalid       :  std_logic;
    signal l02_axi_bready       :  std_logic;
    signal l02_axi_arid         :  std_logic_vector(0 downto 0);
    signal l02_axi_araddr       :  std_logic_vector(31 downto 0);
    signal l02_axi_arlen        :  std_logic_vector(7 downto 0);
    signal l02_axi_arsize       :  std_logic_vector(2 downto 0);
    signal l02_axi_arburst      :  std_logic_vector(1 downto 0);
    signal l02_axi_arlock       :  std_logic;
    signal l02_axi_arcache      :  std_logic_vector(3 downto 0);
    signal l02_axi_arprot       :  std_logic_vector(2 downto 0);
    signal l02_axi_arqos        :  std_logic_vector(3 downto 0);
    signal l02_axi_arvalid      :  std_logic;
    signal l02_axi_arready      :  std_logic;
    signal l02_axi_rid          :  std_logic_vector(0 downto 0);
    signal l02_axi_rdata        :  std_logic_vector(31 downto 0);
    signal l02_axi_rresp        :  std_logic_vector(1 downto 0);
    signal l02_axi_rlast        :  std_logic;
    signal l02_axi_rvalid       :  std_logic;
    signal l02_axi_rready       :  std_logic;

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
   
    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
    signal vga_vsync_n, vga_hsync_n: std_logic;
    signal ps2_clk_in : std_logic;
    signal ps2_clk_out : std_logic;
    signal ps2_dat_in : std_logic;
    signal ps2_dat_out : std_logic;
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin
    cpu100MHz: if C_clk_freq = 100 generate
    clk125in_out100_200_250_25: clk_d100_100_200_250_25MHz
    port map(clk_125mhz_in => clk_125m,
             reset => '0',
             locked => clk_locked,
             clk_100mhz => clk,
             clk_200mhz => clk_200MHz,
             clk_250mhz => clk_250MHz,
             clk_25mhz  => clk_25MHz
    );
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
      C_acram => C_acram,
      C_acram_wait_cycles => C_acram_wait_cycles,
      C_icache_expire => C_icache_expire,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      --C_ps2 => C_ps2,

      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_test_picture => C_vgahdmi_test_picture,

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

      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_25MHz, -- pixel clock
      clk_pixel_shift => clk_250MHz, -- tmds clock
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

        -- PS/2 Keyboard
        --ps2_clk_in   => ps2_clk_in,
        --ps2_dat_in   => ps2_dat_in,
        --ps2_clk_out  => ps2_clk_out,
        --ps2_dat_out  => ps2_dat_out,

      acram_en => ram_en,
      acram_addr => ram_address,
      acram_byte_we => ram_byte_we,
      acram_data_rd => ram_data_read,
      acram_data_wr => ram_data_write,
      acram_ready => ram_ready,

      -- VGA/HDMI
      vga_vsync => vga_vs,
      vga_hsync => vga_hs,
      vga_r(7 downto 3) => vga_r(4 downto 0),
      vga_r(2 downto 0) => open,
      vga_g(7 downto 2) => vga_g(5 downto 0),
      vga_g(1 downto 0) => open,
      vga_b(7 downto 3) => vga_b(4 downto 0),
      vga_b(2 downto 0) => open,
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
	-- simple I/O
      simple_out(3 downto 0) => led(3 downto 0),
      simple_out(31 downto 4) => open,
      simple_in(3 downto 0) => btn(3 downto 0),
      simple_in(15 downto 4) => open,
      simple_in(19 downto 16) => sw(3 downto 0),
      simple_in(31 downto 20) => open
    );

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

    acram_emu_gen: if C_acram_emu_kb > 0 generate
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

    G_acram_real: if C_acram_emu_kb = 0 generate
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
        S_AXI_GP0_aclk         => l00_axi_aclk,
        S_AXI_GP0_awid         => "00000" & l00_axi_awid(0),
        S_AXI_GP0_awaddr       => l00_axi_awaddr,
        S_AXI_GP0_awlen        => l00_axi_awlen(3 downto 0),
        S_AXI_GP0_awsize       => l00_axi_awsize,
        S_AXI_GP0_awburst      => l00_axi_awburst,
        S_AXI_GP0_awlock       => (others => l00_axi_awlock),
        S_AXI_GP0_awcache      => l00_axi_awcache,
        S_AXI_GP0_awprot       => l00_axi_awprot,
        S_AXI_GP0_awqos        => l00_axi_awqos,
        S_AXI_GP0_awvalid      => l00_axi_awvalid,
        S_AXI_GP0_awready      => l00_axi_awready,
        S_AXI_GP0_wdata        => l00_axi_wdata,
        S_AXI_GP0_wstrb        => l00_axi_wstrb,
        S_AXI_GP0_wlast        => l00_axi_wlast,
        S_AXI_GP0_wvalid       => l00_axi_wvalid,
        S_AXI_GP0_wready       => l00_axi_wready,
        S_AXI_GP0_wid          => (others => '0'),
        S_AXI_GP0_bid(0)       => l00_axi_bid(0),
        S_AXI_GP0_bid(5 downto 1) => open,
        S_AXI_GP0_bresp        => l00_axi_bresp,
        S_AXI_GP0_bvalid       => l00_axi_bvalid,
        S_AXI_GP0_bready       => l00_axi_bready,
        S_AXI_GP0_arid         => "00000" & l00_axi_arid,
        S_AXI_GP0_araddr       => l00_axi_araddr,
        S_AXI_GP0_arlen        => l00_axi_arlen(3 downto 0),
        S_AXI_GP0_arsize       => l00_axi_arsize,
        S_AXI_GP0_arburst      => l00_axi_arburst,
        S_AXI_GP0_arlock       => (others => l00_axi_arlock),
        S_AXI_GP0_arcache      => l00_axi_arcache,
        S_AXI_GP0_arprot       => l00_axi_arprot,
        S_AXI_GP0_arqos        => l00_axi_arqos,
        S_AXI_GP0_arvalid      => l00_axi_arvalid,
        S_AXI_GP0_arready      => l00_axi_arready,
        S_AXI_GP0_rid(0)       => l00_axi_rid(0),
        S_AXI_GP0_rid(5 downto 1) => open,
        S_AXI_GP0_rdata        => l00_axi_rdata,
        S_AXI_GP0_rresp        => l00_axi_rresp,
        S_AXI_GP0_rlast        => l00_axi_rlast,
        S_AXI_GP0_rvalid       => l00_axi_rvalid,
        S_AXI_GP0_rready       => l00_axi_rready
    );
    l00_axi_aclk <= clk; -- 100 MHz
    l01_axi_aclk <= '0'; -- port l01 not used
    l02_axi_aclk <= '0'; -- port l02 not used
    end generate; -- G_acram_real

    --FPGA_LED2 <= calib_done; -- should turn on 0.3 seconds after startup and remain on
    --FPGA_LED3 <= ram_read_busy; -- more RAM traffic -> more LED brightness

end Behavioral;
