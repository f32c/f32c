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


entity scarab_bram is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_RV32;
	C_debug: boolean := false;

	-- Main clock: 50/81/100/112
	C_clk_freq: integer := 81;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_50MHz: in std_logic;
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
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_cs, flash_cclk, flash_mosi: out std_logic;
	flash_miso: in std_logic;
	sd_clk, sd_cd_dat3, sd_cmd: out std_logic;
        sd_dat0, sd_dat1, sd_dat2: in std_logic;
	leds: out std_logic_vector(7 downto 0);
        porta, portb, portc: inout std_logic_vector(11 downto 0);
        portd: inout std_logic_vector(3 downto 0); -- fm and cw antennas are here
        porte, portf: inout std_logic_vector(11 downto 0);
        audio1, audio2: out std_logic; -- 3.5mm audio jack
        -- warning TMDS_in is used as output
        TMDS_in_P, TMDS_in_N: out std_logic_vector(2 downto 0);
        TMDS_in_CLK_P, TMDS_in_CLK_N: out std_logic;
        FPGA_SDA, FPGA_SCL: inout std_logic; -- i2c on TMDS_in
        TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
        TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
	sw: in std_logic_vector(4 downto 1)
    );
end scarab_bram;

architecture Behavioral of scarab_bram is
    signal clk, rs232_break: std_logic;
    signal btns: std_logic_vector(1 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
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

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_mem_size,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
	sio_break(0) => rs232_break,
	spi_sck(0)  => flash_cclk,  spi_sck(1)  => sd_clk,
	spi_ss(0)   => flash_cs,    spi_ss(1)   => sd_cd_dat3,
	spi_mosi(0) => flash_mosi,  spi_mosi(1) => sd_cmd,
	spi_miso(0) => flash_miso,  spi_miso(1) => sd_dat0,
        gpio(11 downto  0) => porta(11 downto 0),
        gpio(23 downto 12) => portb(11 downto 0),
        gpio(35 downto 24) => portc(11 downto 0),
        gpio(37 downto 36) => open, -- because cw/fm antennas on portd(1 downto 0)
        gpio(39 downto 38) => portd( 3 downto 2), -- tx antennas
        gpio(51 downto 40) => porte(11 downto 0),
        -- portf: GPIO
        -- gpio(63 downto 52) => portf(11 downto 0),
        gpio(63 downto 52) => open,
        gpio(127 downto 64) => open,
	simple_out(7 downto 0) => leds(7 downto 0),
	simple_out(31 downto 8) => open,
	simple_in(15 downto 0) => open,
	simple_in(19 downto 16) => sw(4 downto 1),
	simple_in(31 downto 20) => open
    );

    sdram_clk <= '0';
    sdram_cke <= '0';
    sdram_csn <= '1';
    sdram_rasn <= '1';
    sdram_casn <= '1';
    sdram_wen <= '1';
    sdram_a <= (others => '0');
    sdram_ba <= (others => '0');
    sdram_dqm <= (others => '0');
    sdram_d <= (others => 'Z');
    
    audio1 <= '0';
    audio2 <= '0';

    -- differential output buffering for HDMI clock and video
    hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => '0',
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb    => (others => '0'),
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );

    -- hdmi "in" port can be used as second output
    -- so user don't need to think which one works :)
    hdmi_output2: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => '0',
        tmds_out_clk_p => tmds_in_clk_p,
        tmds_out_clk_n => tmds_in_clk_n,
        tmds_in_rgb    => (others => '0'),
        tmds_out_rgb_p => tmds_in_p,
        tmds_out_rgb_n => tmds_in_n
      );
    
end Behavioral;
