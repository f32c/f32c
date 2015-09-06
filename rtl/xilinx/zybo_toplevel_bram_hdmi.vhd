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

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity glue is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/100/125 MHz
	-- at 81: flickers, fetch 1 byte late?
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 128;
	C_vgahdmi: boolean := true;
	C_vgahdmi_mem_kb: integer := 38; -- KB 38K full mono 640x480
	C_vgahdmi_test_picture: integer := 1; -- enable test picture
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
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
	hdmi_clk_p, hdmi_clk_n: out std_logic;
	hdmi_d_p, hdmi_d_n: out std_logic_vector(2 downto 0);
	vga_g: out std_logic_vector(5 downto 0);
	vga_r, vga_b: out std_logic_vector(4 downto 0);
	vga_hs, vga_vs: out std_logic;
	btn: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, clk_250MHz, clk_25MHz: std_logic;
    signal rs232_break: std_logic;
    signal tmds_out_rgb: std_logic_vector(2 downto 0);
begin

    clk81: if C_clk_freq = 81 generate
    clkgen100: entity work.mmcm_125M_81M25_250M521_25M052
    port map(
      clk_in1 => clk_125m, clk_out1 => clk, clk_out2 => clk_250MHz, clk_out3 => clk_25MHz
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_125M_250M_100M_25M
    port map(
      clk_in1 => clk_125m, clk_out1 => clk_250MHz, clk_out2 => clk, clk_out3 => clk_25MHz
    );
    end generate;

    clk125: if C_clk_freq = 125 generate
    clk <= clk_125m;
    end generate;

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_mem_size => C_mem_size,
	C_vgahdmi => C_vgahdmi,
	C_vgahdmi_mem_kb => C_vgahdmi_mem_kb,
	C_vgahdmi_test_picture => C_vgahdmi_test_picture,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	clk_25MHz => clk_25MHz, -- pixel clock
	clk_250MHz => clk_250MHz, -- tmds clock
	sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
	sio_break(0) => open,
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
	tmds_out_rgb => tmds_out_rgb,
	vga_vsync => vga_vs,
	vga_hsync => vga_hs,
	vga_r(2 downto 0) => vga_r(4 downto 2),
	vga_g(2 downto 0) => vga_g(5 downto 3),
	vga_b(2 downto 0) => vga_b(4 downto 2),
	simple_out(3 downto 0) => led(3 downto 0),
	simple_out(31 downto 4) => open,
	simple_in(3 downto 0) => btn(3 downto 0),
	simple_in(15 downto 4) => open,
	simple_in(19 downto 16) => sw(3 downto 0),
	simple_in(31 downto 20) => open
    );
    vga_r(1 downto 0) <= (others => '0');
    vga_g(2 downto 0) <= (others => '0');
    vga_b(1 downto 0) <= (others => '0');

    -- differential output buffering for HDMI clock and video
    hdmi_output: entity work.hdmi_out
      port map (
        tmds_in_clk => clk_25MHz,
        tmds_out_clk_p => hdmi_clk_p,
        tmds_out_clk_n => hdmi_clk_n,
        tmds_in_rgb => tmds_out_rgb,
        tmds_out_rgb_p => hdmi_d_p,
        tmds_out_rgb_n => hdmi_d_n
      );
end Behavioral;
