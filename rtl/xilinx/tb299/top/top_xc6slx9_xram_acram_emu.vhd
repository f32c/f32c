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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;

entity glue is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_mult_enable: boolean := false;
	C_mul_acc: boolean := false;
        C_exceptions: boolean := false;
	C_debug: boolean := false;

        -- CPU core configuration options
        C_branch_likely: boolean := true;
        C_branch_prediction: boolean := false;
        C_full_shifter: boolean := true;
        C_result_forwarding: boolean := true;
        C_load_aligner: boolean := true;
        C_regfile_synchronous_read: boolean := true;

	-- Main clock: 25/50/67/71/77/83/100
	C_clk_freq: integer := 25;
	C_vendor_specific_startup: boolean := false; -- true: this board won't start without it

	-- SoC configuration options
	C_bram_size: integer := 2;
	C_acram: boolean := true;
	C_acram_wait_cycles: integer := 3; -- 3 or more
        C_acram_emu_kb: integer := 32; -- KB axi_cache emulation (power of 2, MAX 32)
        C_icache_size: integer := 0;	-- 0, 2, 4, 8, 16 or 32 KBytes
        C_dcache_size: integer := 0;	-- 0, 2, 4, 8, 16 or 32 KBytes
        C_cached_addr_bits: integer := 15; -- lower address bits that are cached: 15bits -> 2^15 -> 32KB to be cached
	C_sio: integer := 1;
	C_spi: integer := 0;
	C_gpio: integer := 0;
	C_simple_io: boolean := true;
	C_timer: boolean := false;

        -- C_dvid_ddr = false: clk_pixel_shift = 250MHz
        -- C_dvid_ddr = true: clk_pixel_shift = 125MHz
        -- (fixme: DDR video output mode doesn't work on scarab)
        C_dvid_ddr: boolean := true;
        C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024
        C_shift_clock_synchronizer: boolean := false; -- some hardware may need this enabled
        C_compositing2_write_while_reading: boolean := true; -- true for normal operation

        C_vgahdmi: boolean := true;
        C_vgahdmi_compositing: integer := 2;
        -- insert cache between RAM and compositing2 video fifo
        C_vgahdmi_cache_size: integer := 0; -- KB size 0:disable 2,4,8,16,32:enable
        C_vgahdmi_cache_use_i: boolean := true; -- use I-data caching style, faster
        -- normally this should be  actual bits per pixel
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8 -- bpp (currently 8/16/32 supported)
    );
    port (
	clk_25m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	gpio: inout std_logic_vector(39 downto 0);
	icp: in std_logic_vector(1 downto 0);
	ocp: out std_logic_vector(1 downto 0) := (others => '0');
        flash_csn, flash_clk, flash_mosi: out std_logic;
        flash_miso: in std_logic;
        tmds_p, tmds_n: out std_logic_vector(3 downto 0);
	btn_k2, btn_k3: in std_logic
    );
end glue;

architecture Behavioral of glue is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;
  signal clk, rs232_break: std_logic;
  signal clk_pixel: std_logic; -- 25 MHz
  -- signal clk_pixel_shift: std_logic; -- 125 MHz
  signal clk_pixel_shift_p: std_logic; -- 125 MHz
  signal clk_pixel_shift_n: std_logic; -- 125 MHz inverted (180 deg phase)
  signal clk_locked: std_logic;
  signal S_reset: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic := '1';
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal tmds_out_crgb: std_logic_vector(3 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 10, -- 100 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk83: if C_clk_freq = 83 generate
    clkgen83: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 12, --  83.333 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk77: if C_clk_freq = 77 generate
    clkgen77: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 13, --  76.923 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk71: if C_clk_freq = 71 generate
    clkgen71: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 14, --  71.429 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk67: if C_clk_freq = 67 generate
    clkgen67: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 15, --  66.667 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk50: if C_clk_freq = 50 generate
    clkgen50: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 20, --  50 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => clk_pixel,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    clk25: if C_clk_freq = 25 generate
    clkgen25: entity work.xil_pll
    generic map(
      clk_in_period_ns => 40.0, -- input 25 MHz
      clk_mult => 40, -- default fVCO = 1000 MHz
      clk_div0 => 40, --  25 MHz
      clk_div1 => 40, --  25 MHz
      clk_div2 => 8,  -- 125 MHz
      clk_div3 => 8, clk_phase3 => 180.0 -- 125 MHz phase inverted
    )
    port map(
      clk_in => clk_25m,
      clk_out0 => clk,
      clk_out1 => open,
      clk_out2 => clk_pixel_shift_p,
      clk_out3 => open,
      locked => clk_locked
    );
    clk_pixel <= clk;
    clk_pixel_shift_n <= not clk_pixel_shift_p;
    end generate;

    G_vendor_specific_startup: if C_vendor_specific_startup generate
    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
      clk => clk, gsr => rs232_break, gts => rs232_break,
      keyclearb => '0'
    );
    end generate; -- G_vendor_specific_startup

    S_reset <= not clk_locked;

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_mult_enable => C_mult_enable,
	C_mul_acc => C_mul_acc,
        C_regfile_synchronous_read => C_regfile_synchronous_read,
        C_branch_likely => C_branch_likely,
        C_branch_prediction => C_branch_prediction,
        C_result_forwarding => C_result_forwarding,
        C_load_aligner => C_load_aligner,
        C_full_shifter => C_full_shifter,
        C_exceptions => C_exceptions,
	C_bram_size => C_bram_size,
	C_acram => C_acram,
        C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
        C_cached_addr_bits => C_cached_addr_bits,
        -- HDMI/DVI-D output SDR or DDR
        C_dvid_ddr => C_dvid_ddr,
        C_shift_clock_synchronizer => C_shift_clock_synchronizer,
        C_compositing2_write_while_reading => C_compositing2_write_while_reading,
        -- vga simple compositing bitmap only graphics
        C_vgahdmi => C_vgahdmi,
        C_vgahdmi_compositing => C_vgahdmi_compositing,
        C_vgahdmi_mode => C_video_mode,
        C_vgahdmi_cache_size => C_vgahdmi_cache_size,
        C_vgahdmi_cache_use_i => C_vgahdmi_cache_use_i,
        C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_timer => C_timer,
	C_debug => C_debug
    )
    port map (
	clk => clk,
        clk_pixel => clk_pixel, -- pixel clock
        clk_pixel_shift => clk_pixel_shift_p, -- tmds clock 10x pixel clock for SDR or 5x for DDR
	sio_txd(0) => rs232_dce_txd, sio_rxd(0) => rs232_dce_rxd,
	sio_break(0) => rs232_break,
	reset => S_reset,
        acram_en => ram_en,
        acram_addr(29 downto 2) => ram_address(29 downto 2),
        acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
        acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
        acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
        acram_ready => ram_ready,
	--spi_sck(0)  => flash_clk,  -- spi_sck(1)  => open,
	--spi_ss(0)   => flash_csn,  -- spi_ss(1)   => open,
	--spi_mosi(0) => flash_mosi, -- spi_mosi(1) => open,
	--spi_miso(0) => flash_miso, -- spi_miso(1) => '-',
	gpio(127 downto 32) => open,
	gpio(31 downto 0) => gpio(31 downto 0),
	-- icp => icp, ocp => ocp,
        dvid_clock => dvid_clock,
        dvid_red   => dvid_red,
        dvid_green => dvid_green,
        dvid_blue  => dvid_blue,
	simple_out(31 downto 8) => open,
	simple_out(7 downto 0) => led(7 downto 0),
	simple_in(31 downto 2) => open,
	simple_in(1) => btn_k3,
	simple_in(0) => btn_k2
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
      acram_en => ram_en
    );
    end generate;

    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout0: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift_p,
      clk_n     => clk_pixel_shift_n,
      reset     => '0',
      in_clock  => dvid_clock,
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      out_clock => tmds_out_crgb(3),
      out_red   => tmds_out_crgb(2),
      out_green => tmds_out_crgb(1),
      out_blue  => tmds_out_crgb(0)
    );

    -- differential output buffering for HDMI clock and video
    hdmi_output0: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_out_crgb(3),
        tmds_out_clk_p => tmds_p(3),
        tmds_out_clk_n => tmds_n(3),
        tmds_in_rgb    => tmds_out_crgb(2 downto 0),
        tmds_out_rgb_p => tmds_p(2 downto 0),
        tmds_out_rgb_n => tmds_n(2 downto 0)
      );

end Behavioral;
