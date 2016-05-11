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

entity esa11_acram_ddr3 is
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

        C3_NUM_DQ_PINS        : integer := 16;
        C3_MEM_ADDR_WIDTH     : integer := 14;
        C3_MEM_BANKADDR_WIDTH : integer := 3;

	C_vgahdmi: boolean := false;
	C_video_cache_size: integer := 8; -- KB video cache (vgahdmi) (0: disable, 2,4,8,16,32:enable) 

    C_vgatext: boolean := true;    -- Xark's feature-rich bitmap+textmode VGA
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
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic;
	FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
	FPGA_SD_D0: in std_logic;
	-- two onboard green LEDs next to yellow and red
        FPGA_LED2, FPGA_LED3: out std_logic;
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
end esa11_acram_ddr3;

architecture Behavioral of esa11_acram_ddr3 is
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

    signal calib_done           : std_logic;

    signal l00_axi_areset_n     :  std_logic := '1';
    signal l00_axi_aclk         :  std_logic := '0';
    signal l00_axi_awid         :  std_logic_vector(0 downto 0);
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
    clk100in_out100_200_250_25: clk_d100_100_200_250_25MHz
    port map(clk_100mhz_in_p => i_100MHz_P,
             clk_100mhz_in_n => i_100MHz_N,
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

      C_video_cache_size => C_video_cache_size,
      C_vgahdmi => C_vgahdmi,

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
	clk_pixel => clk_25MHz,
	clk_pixel_shift => clk_250MHz,
	acram_en => ram_en,
	acram_addr => ram_address,
	acram_byte_we => ram_byte_we,
	acram_data_rd => ram_data_read,
	acram_data_wr => ram_data_write,
	acram_ready => ram_ready,
	sio_txd(0) => UART1_TXD, 
	sio_rxd(0) => UART1_RXD,
	sio_break(0) => sio_break,
        spi_sck(0)  => open,  spi_sck(1)  => FPGA_SD_SCLK,
        spi_ss(0)   => open,  spi_ss(1)   => FPGA_SD_D3,
        spi_mosi(0) => open,  spi_mosi(1) => FPGA_SD_CMD,
        spi_miso(0) => '-',   spi_miso(1) => FPGA_SD_D0,
	gpio(7 downto 0) => M_EXPMOD0, gpio(15 downto 8) => M_EXPMOD1,
	gpio(23 downto 16) => M_EXPMOD2, gpio(31 downto 24) => M_EXPMOD3,
	gpio(127 downto 32) => open,
        -- PS/2 Keyboard
        ps2_clk_in   => ps2_clk_in,
        ps2_dat_in   => ps2_dat_in,
        ps2_clk_out  => ps2_clk_out,
        ps2_dat_out  => ps2_dat_out,
        -- VGA/HDMI
	vga_vsync => vga_vsync_n,
	vga_hsync => vga_hsync_n,
	vga_r => VGA_RED,
	vga_g => VGA_GREEN,
	vga_b => VGA_BLUE,
        dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
        dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
        dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
        dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
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
    VGA_SYNC_N <= '1';
    VGA_BLANK_N <= '1';
    VGA_CLOCK_P <= clk_25MHz;
    VGA_VSYNC <= vga_vsync_n;
    VGA_HSYNC <= vga_hsync_n;

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
        reset              => not calib_done, -- release reset when DDR3 is ready

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

    u_ddr_mem : entity work.axi_mpmc
    port map(
        sys_rst              => not clk_locked, -- release reset when clock is stable
        sys_clk_i            => clk_200MHz, -- should be 200MHz
        init_calib_complete  => calib_done, -- becomes high cca 0.3 seconds after startup
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
        -- port l00
        s00_axi_areset_out_n => l00_axi_areset_n,
        s00_axi_aclk         => l00_axi_aclk,
        s00_axi_awid         => l00_axi_awid,
        s00_axi_awaddr       => l00_axi_awaddr,
        s00_axi_awlen        => l00_axi_awlen,
        s00_axi_awsize       => l00_axi_awsize,
        s00_axi_awburst      => l00_axi_awburst,
        s00_axi_awlock       => l00_axi_awlock,
        s00_axi_awcache      => l00_axi_awcache,
        s00_axi_awprot       => l00_axi_awprot,
        s00_axi_awqos        => l00_axi_awqos,
        s00_axi_awvalid      => l00_axi_awvalid,
        s00_axi_awready      => l00_axi_awready,
        s00_axi_wdata        => l00_axi_wdata,
        s00_axi_wstrb        => l00_axi_wstrb,
        s00_axi_wlast        => l00_axi_wlast,
        s00_axi_wvalid       => l00_axi_wvalid,
        s00_axi_wready       => l00_axi_wready,
        s00_axi_bid          => l00_axi_bid,
        s00_axi_bresp        => l00_axi_bresp,
        s00_axi_bvalid       => l00_axi_bvalid,
        s00_axi_bready       => l00_axi_bready,
        s00_axi_arid         => l00_axi_arid,
        s00_axi_araddr       => l00_axi_araddr,
        s00_axi_arlen        => l00_axi_arlen,
        s00_axi_arsize       => l00_axi_arsize,
        s00_axi_arburst      => l00_axi_arburst,
        s00_axi_arlock       => l00_axi_arlock,
        s00_axi_arcache      => l00_axi_arcache,
        s00_axi_arprot       => l00_axi_arprot,
        s00_axi_arqos        => l00_axi_arqos,
        s00_axi_arvalid      => l00_axi_arvalid,
        s00_axi_arready      => l00_axi_arready,
        s00_axi_rid          => l00_axi_rid,
        s00_axi_rdata        => l00_axi_rdata,
        s00_axi_rresp        => l00_axi_rresp,
        s00_axi_rlast        => l00_axi_rlast,
        s00_axi_rvalid       => l00_axi_rvalid,
        s00_axi_rready       => l00_axi_rready,
        -- port l01
        s01_axi_areset_out_n => l01_axi_areset_n,
        s01_axi_aclk         => l01_axi_aclk,
        s01_axi_awid         => l01_axi_awid,
        s01_axi_awaddr       => l01_axi_awaddr,
        s01_axi_awlen        => l01_axi_awlen,
        s01_axi_awsize       => l01_axi_awsize,
        s01_axi_awburst      => l01_axi_awburst,
        s01_axi_awlock       => l01_axi_awlock,
        s01_axi_awcache      => l01_axi_awcache,
        s01_axi_awprot       => l01_axi_awprot,
        s01_axi_awqos        => l01_axi_awqos,
        s01_axi_awvalid      => l01_axi_awvalid,
        s01_axi_awready      => l01_axi_awready,
        s01_axi_wdata        => l01_axi_wdata,
        s01_axi_wstrb        => l01_axi_wstrb,
        s01_axi_wlast        => l01_axi_wlast,
        s01_axi_wvalid       => l01_axi_wvalid,
        s01_axi_wready       => l01_axi_wready,
        s01_axi_bid          => l01_axi_bid,
        s01_axi_bresp        => l01_axi_bresp,
        s01_axi_bvalid       => l01_axi_bvalid,
        s01_axi_bready       => l01_axi_bready,
        s01_axi_arid         => l01_axi_arid,
        s01_axi_araddr       => l01_axi_araddr,
        s01_axi_arlen        => l01_axi_arlen,
        s01_axi_arsize       => l01_axi_arsize,
        s01_axi_arburst      => l01_axi_arburst,
        s01_axi_arlock       => l01_axi_arlock,
        s01_axi_arcache      => l01_axi_arcache,
        s01_axi_arprot       => l01_axi_arprot,
        s01_axi_arqos        => l01_axi_arqos,
        s01_axi_arvalid      => l01_axi_arvalid,
        s01_axi_arready      => l01_axi_arready,
        s01_axi_rid          => l01_axi_rid,
        s01_axi_rdata        => l01_axi_rdata,
        s01_axi_rresp        => l01_axi_rresp,
        s01_axi_rlast        => l01_axi_rlast,
        s01_axi_rvalid       => l01_axi_rvalid,
        s01_axi_rready       => l01_axi_rready,
        -- port l02
        s02_axi_areset_out_n => l02_axi_areset_n,
        s02_axi_aclk         => l02_axi_aclk,
        s02_axi_awid         => l02_axi_awid,
        s02_axi_awaddr       => l02_axi_awaddr,
        s02_axi_awlen        => l02_axi_awlen,
        s02_axi_awsize       => l02_axi_awsize,
        s02_axi_awburst      => l02_axi_awburst,
        s02_axi_awlock       => l02_axi_awlock,
        s02_axi_awcache      => l02_axi_awcache,
        s02_axi_awprot       => l02_axi_awprot,
        s02_axi_awqos        => l02_axi_awqos,
        s02_axi_awvalid      => l02_axi_awvalid,
        s02_axi_awready      => l02_axi_awready,
        s02_axi_wdata        => l02_axi_wdata,
        s02_axi_wstrb        => l02_axi_wstrb,
        s02_axi_wlast        => l02_axi_wlast,
        s02_axi_wvalid       => l02_axi_wvalid,
        s02_axi_wready       => l02_axi_wready,
        s02_axi_bid          => l02_axi_bid,
        s02_axi_bresp        => l02_axi_bresp,
        s02_axi_bvalid       => l02_axi_bvalid,
        s02_axi_bready       => l02_axi_bready,
        s02_axi_arid         => l02_axi_arid,
        s02_axi_araddr       => l02_axi_araddr,
        s02_axi_arlen        => l02_axi_arlen,
        s02_axi_arsize       => l02_axi_arsize,
        s02_axi_arburst      => l02_axi_arburst,
        s02_axi_arlock       => l02_axi_arlock,
        s02_axi_arcache      => l02_axi_arcache,
        s02_axi_arprot       => l02_axi_arprot,
        s02_axi_arqos        => l02_axi_arqos,
        s02_axi_arvalid      => l02_axi_arvalid,
        s02_axi_arready      => l02_axi_arready,
        s02_axi_rid          => l02_axi_rid,
        s02_axi_rdata        => l02_axi_rdata,
        s02_axi_rresp        => l02_axi_rresp,
        s02_axi_rlast        => l02_axi_rlast,
        s02_axi_rvalid       => l02_axi_rvalid,
        s02_axi_rready       => l02_axi_rready
    );
    l00_axi_aclk <= clk; -- 100 MHz
    l01_axi_aclk <= '0'; -- port l01 not used
    l02_axi_aclk <= '0'; -- port l02 not used
    end generate; -- G_acram_real

    FPGA_LED2 <= calib_done; -- should turn on 0.3 seconds after startup and remain on
    FPGA_LED3 <= ram_read_busy; -- more RAM traffic -> more LED brightness

end Behavioral;
