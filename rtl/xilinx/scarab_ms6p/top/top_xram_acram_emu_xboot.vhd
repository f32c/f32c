--
-- Copyright (c) 2015 Davor Jadrijevic
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
-- glue_xram with sram emulation using BRAM
-- this emulation is not timing identical with real sram
-- C_sram_pipelined_read is disabled

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;
use work.f32c_pack.all;
use work.boot_block_pack.all;
use work.boot_sio_mi32el.all;
use work.boot_sio_mi32eb.all;
use work.boot_sio_rv32el.all;
use work.boot_rom_mi32el.all;

entity scarab_xram_acram_emu_xboot is
generic
(
  -- ISA: either ARCH_MI32 or ARCH_RV32
  C_arch: integer := ARCH_MI32;
  C_debug: boolean := false;

  -- Main clock: 50/81/100/112 MHz
  C_clk_freq: integer := 50;
  C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

  -- SoC configuration options
  C_bram_size: integer := 0; -- KB or 0 to disable
  C_bram_const_init: boolean := true; -- true: preload BRAM with bootloader
  C_boot_write_protect: boolean := true; -- leave boot block in BRAM writeable

  -- external boot rom
  C_xboot_rom: boolean := true;
  C_boot_rom_data_bits: integer := 32; -- number of bits in output from bootrom_emu

  -- axi cache ram
  C_xram_base: std_logic_vector(31 downto 28) := x"0"; -- XRAM (acram emu) at address 0 (instead of disabled BRAM)
  C_acram: boolean := true;
  C_acram_wait_cycles: integer := 3; -- real axi_cache works with 2, acram_emu needs 3 (should be fixed)
  C_acram_emu_kb: integer := 32; -- KB axi_cache emulation (power of 2, MAX 64)

  C_icache_size: integer := 0; -- 0, 2, 4, 8, 16, 32 KBytes
  C_dcache_size: integer := 0; -- 0, 2, 4, 8, 16, 32 KBytes
  C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 25bits -> 2^25 -> 32MB to be cached

  C_vgahdmi: boolean := true;

    C_vgatext: boolean := false; -- Xark's feature-rich bitmap+textmode VGA
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

	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32
);
port
(
	clk_50MHz: in std_logic;
        sdram_clk   : out std_logic;
        sdram_cke   : out std_logic;
        sdram_csn   : out std_logic;
        sdram_rasn  : out std_logic;
        sdram_casn  : out std_logic;
        sdram_wen   : out std_logic;
        sdram_a     : out std_logic_vector (12 downto 0);
        sdram_ba    : out std_logic_vector(1 downto 0);
        sdram_dqm   : out std_logic_vector(1 downto 0);
        sdram_d     : inout std_logic_vector (15 downto 0);
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_cs, flash_cclk, flash_mosi: out std_logic;
	flash_miso: in std_logic;
	sd_clk, sd_cd_dat3, sd_cmd: out std_logic;
	sd_dat0: in std_logic;
	leds: out std_logic_vector(7 downto 0);
	porta, portb: inout std_logic_vector(11 downto 0);
	portc: inout std_logic_vector(11 downto 0);
        portd: inout std_logic_vector(3 downto 0); -- fm and cw antennas are here
        porte, portf: inout std_logic_vector(11 downto 0);
        audio1, audio2: out std_logic := '0'; -- 3.5mm audio jack
        TMDS_in_P, TMDS_in_N: out std_logic_vector(2 downto 0);
        TMDS_in_CLK_P, TMDS_in_CLK_N: out std_logic;
        FPGA_SDA, FPGA_SCL: inout std_logic; -- i2c on TMDS_in
	TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
	TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
	sw: in std_logic_vector(4 downto 1)
);
end;

architecture Behavioral of scarab_xram_acram_emu_xboot is
    -- useful for conversion from KB to number of address bits
    function ceil_log2(x: integer)
      return integer is
    begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
    end ceil_log2;
    signal clk, clk_250MHz, clk_25MHz: std_logic;
    signal rs232_break: std_logic;
    signal S_reset: std_logic := '0';
    -- external DMA will preload boot ROM
    signal xdma_addr: std_logic_vector(29 downto 2) := (others => '0'); -- preload address 0x00000000 XRAM
    signal xdma_strobe: std_logic := '0';
    signal xdma_data_ready: std_logic;
    signal xdma_write: std_logic := '0';
    signal xdma_byte_sel: std_logic_vector(3 downto 0) := (others => '1');
    signal xdma_data_in: std_logic_vector(31 downto 0) := (others => '-');
    -- signals for ROM emulation
    signal S_rom_reset, S_rom_next_data: std_logic;
    signal S_rom_data: std_logic_vector(C_boot_rom_data_bits-1 downto 0);
    signal S_rom_valid: std_logic;

    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
    signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_ready          : std_logic;
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);

    signal tmds_rgb: std_logic_vector(2 downto 0);
    signal tmds_clk: std_logic;
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M_25M_250M
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_50M_81M25
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
    end generate;

    clk50: if C_clk_freq = 50 generate
      clk <= clk_50MHz;
    end generate;

    G_vendor_specific_startup: if C_vendor_specific_startup generate
    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
    );
    end generate;

    -- generic BRAM glue
    glue_bram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_bram_const_init => C_bram_const_init,
      C_boot_write_protect => C_boot_write_protect,
      C_xdma => C_xboot_rom,
      C_xram_base => C_xram_base,
      C_acram => C_acram,
      C_acram_wait_cycles => C_acram_wait_cycles,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,

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
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width
	--C_spi => C_spi,
	--C_pid => false,
    )
    port map (
      clk => clk,
      clk_pixel => clk_25MHz,
      clk_pixel_shift => clk_250MHz,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      sio_break(0) => rs232_break,
      reset => S_reset,
      xdma_addr => xdma_addr, xdma_strobe => xdma_strobe,
      xdma_write => '1', xdma_byte_sel => "1111",
      xdma_data_in => xdma_data_in, xdma_data_ready => xdma_data_ready,
--	spi_sck(0)  => open,  spi_sck(1)  => open,
--	spi_ss(0)   => open,  spi_ss(1)   => open
--	spi_mosi(0) => open,  spi_mosi(1) => open,
--	spi_miso(0) => '-',   spi_miso(1) => '-',
--	gpio(3 downto 0) => ja_u(3 downto 0),
--	gpio(7 downto 4) => ja_d(3 downto 0),
--	gpio(11 downto 8) => jb_u(3 downto 0),
--	gpio(15 downto 12) => jb_d(3 downto 0),
--	gpio(19 downto 16) => jc_u(3 downto 0),
--	gpio(23 downto 20) => jc_d(3 downto 0),
--	gpio(27 downto 24) => jd_u(3 downto 0),
--	gpio(31 downto 28) => jd_d(3 downto 0),
--	gpio(127 downto 32) => open,
      simple_out(7 downto 0) => leds(7 downto 0),
      simple_out(31 downto 8) => open,
      simple_in(15 downto 0) => open,
      simple_in(19 downto 16) => sw(4 downto 1),
      simple_in(31 downto 20) => open,

      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,

      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready
    );

    -- differential output buffering for HDMI clock and video
    hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_clk,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb    => tmds_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );

    hdmi_output2: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_clk, -- some monitor prefer this clock
        tmds_out_clk_p => tmds_in_clk_p,
        tmds_out_clk_n => tmds_in_clk_n,
        tmds_in_rgb    => tmds_rgb,
        tmds_out_rgb_p => tmds_in_p,
        tmds_out_rgb_n => tmds_in_n
      );
    
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

    -- disable onboard sdram chip
    sdram_clk <= '0';
    sdram_cke <= '0';
    sdram_csn <= '1';
    sdram_rasn <= '1';
    sdram_casn <= '1';
    sdram_wen  <= '1';
    sdram_a    <= (others => '0');
    sdram_ba   <= (others => '0');
    sdram_dqm  <= (others => '0');
    sdram_d    <= (others => 'Z');

    flash_cs   <= '0';
    flash_cclk <= '0';
    flash_mosi <= '0';
    -- flash_miso <= open;
    sd_clk     <= '0';
    sd_cd_dat3 <= '0';
    sd_cmd     <= '0';
    -- sd_dat0 <= open;
    
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
        C_content => boot_sio_mi32el,
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

end Behavioral;
