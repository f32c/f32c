--
-- TODO: hookup SPI to glue_bram.vhd entity
--
-- spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
-- spi_miso: in std_logic_vector(C_spi - 1 downto 0);
--
-- MenloParkInnovation LLC 02/27/2019
--
-- Create a BRAM version of F32C for Terasic DE10-Lite with
-- Altera MAX10 FPGA.
--
-- Note: BRAMS's appear to have been unsupported in F32C for
-- undocumented reasons. It's likely the synthesis error from
-- Quartus II if the FPGA is not configured for providing RAM
-- initialization data is the reason. The fix is to change
-- the Quartus II settings to provide RAM initialization data
-- in the FPGA bitsteam.
--
-- Assignments -> Device ... -> Device and Pin Options ... -> Configuration Mode  
--   to  
-- "Single Uncompressed Image with memory initialization (512 Kbits UFM)" 
--
-- In addition standard DE10-Lite top level signal names are
-- used, and the conversion to F32C signal names is done
-- in this file.
--
-- Copyright (c) 2015 Marko Zec, University of Zagreb
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

use work.f32c_pack.all;

entity glue is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;

	-- Main clock freq

	-- C_clk_freq: integer := 100; -- This does not work
	--C_clk_freq: integer := 75;   -- This does not work
	C_clk_freq: integer := 50;     -- works.
	-- C_clk_freq: integer := 25;  -- works.

	-- SoC configuration options (32K in this configuration)
	C_bram_size: integer := 32;

        -- SPI instances
	C_spi: integer := 0;
	C_spi_turbo_mode: std_logic_vector := "0000";
	C_spi_fixed_speed: std_logic_vector := "1111";

	-- Debugging
	C_debug: boolean := false
    );
    port (

        --
        -- Note: Signals to the top level module are defined in the .qsf
        -- file for the build configuration de10_lite_pins.qsf.
        --
        -- Note also that VHDL is case insensitive. The .qsf file uses
        -- upper case, while here the F32C convention is lower case signal
        -- parameters. You must use upper case if interfacing with
        -- System Verilog modules as Verilog is case sensitive for signal names.
        --

	max10_clk1_50, max10_clk2_50: in std_logic;

        -- SDRAM
        dram_addr: out std_logic_vector(12 downto 0);
        dram_ba: out std_logic_vector(1 downto 0);
        dram_ras_n: out std_logic;
        dram_cas_n: out std_logic;
        dram_dqm: out std_logic_vector(1 downto 0);
        dram_dq: inout std_logic_vector(15 downto 0);
        dram_we_n: out std_logic;
        dram_clk: in std_logic;
        dram_clke: out std_logic;
        dram_cs_n: out std_logic;

        -- 7 Segment Hex displays
	hex0, hex1, hex2, hex3, hex4, hex5: out std_logic_vector(7 downto 0);

        -- Buttons
	key: in std_logic_vector(1 downto 0);

        -- LED
	ledr: out std_logic_vector(9 downto 0);

        -- Switches
	sw: in std_logic_vector(9 downto 0);

        -- VGA
        vga_hs, vga_vs: out std_logic;
        vga_r, vga_g, vga_b: out std_logic_vector(3 downto 0);

        -- Accelerometer
        gsensor_cs_n: out std_logic;
        gsensor_int: in std_logic_vector(2 downto 1);
        gsensor_sclk: in std_logic;
        gsensor_sdi: in std_logic;
        gsensor_sdo: out std_logic;

        -- Arduino
	arduino_io: inout std_logic_vector(15 downto 0);
        arduino_reset_n: inout std_logic;

        -- GPIO
	gpio: inout std_logic_vector(35 downto 0)

        -- TODO: Ensure all these are mapped.
	--gpioa: inout std_logic_vector(33 downto 16)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal rs232_rxd: std_logic;
    signal rs232_txd: std_logic;
    signal btns: std_logic_vector(15 downto 0);
    signal btn_left: std_logic;
    signal btn_right: std_logic;
    signal simple_out_bit_9: std_logic;
begin

    --
    -- Signal selection from DE10-Lite signals to F32C signals.
    --

    -- RXD, TXD are the standard Arduino D0 and D1.
    rs232_rxd <= arduino_io(0);
    arduino_io(1) <= rs232_txd;
    
    -- gpio mapped to Arduino pins

    -- ledr(9) mapped to arduino_io(13) in addition to simple_out(9)
    -- This allows Arduino programs to flash LED on D13 as with Arduino UNO.
    ledr(9) <= simple_out_bit_9 or arduino_io(13);

    -- buttons
    btn_left <= key(0);
    btn_right <= key(1);
    btns <= x"000" & "00" & not btn_left & not btn_right;

    -- 7 Segment displays
    -- TODO: Map to simple_out when Arduino pins are renumbered.

    -- dram
    -- Feature for another module.

    -- VGA
    -- Feature for another module.

    --
    -- The following allows selection of multiple standard clock
    -- frequencies.
    --

    G_25m_clk: if C_clk_freq = 25 generate
    clkgen_25: entity work.clk_50M_25M_125MP_125MN_100M_83M33
    port map(
      inclk0 => max10_clk1_50, --  50 MHz input from board
      inclk1 => max10_clk2_50, --  50 MHz input from board (backup clock)
      c0 => clk,               --  25 MHz
      c1 => open,              -- 125 MHz positive
      c2 => open,              -- 125 MHz negative
      c3 => open,              -- 100 MHz
      c4 => open               --  83.333 MHz
    );
    end generate;

    G_50m_clk: if C_clk_freq = 50 generate
    clk <= max10_clk1_50;
    clkgen_50: entity work.clk_50M_25M_125MP_125MN_100M_83M33
    port map(
      inclk0 => max10_clk1_50, --  50 MHz input from board
      inclk1 => max10_clk2_50, --  50 MHz input from board (backup clock)
      c0 => open,              --  25 MHz clk_pixel
      c1 => open,              -- 125 MHz positive
      c2 => open,              -- 125 MHz negative
      c3 => open,              -- 100 MHz
      c4 => open               --  83.333 MHz
    );
    end generate;

    G_75M_clk: if C_clk_freq = 75 generate
    clkgen_75: entity work.clk_50M_25M_250M_75M
    port map(
      inclk0 => max10_clk1_50, --  50 MHz input from board
      inclk1 => max10_clk2_50, --  50 MHz input from board (backup clock)
      c0 => open,              --  25 MHz clk_pixel
      c1 => open,              -- 250 MHz
      c2 => clk                --  75 MHz
    );
    end generate;

    G_83m_clk: if C_clk_freq = 83 generate
    clkgen_83: entity work.clk_50M_25M_125MP_125MN_100M_83M33
    port map(
      inclk0 => max10_clk1_50, --  50 MHz input from board
      inclk1 => max10_clk2_50, --  50 MHz input from board (backup clock)
      c0 => open,              --  25 MHz
      c1 => open,              -- 125 MHz positive
      c2 => open,              -- 125 MHz negative
      c3 => open,              -- 100 MHz
      c4 => clk                --  83.333 MHz
    );
    end generate;

    G_100m_clk: if C_clk_freq = 100 generate
    clkgen_100: entity work.clk_50M_25M_125MP_125MN_100M_83M33
    port map(
      inclk0 => max10_clk1_50, --  50 MHz input from board
      inclk1 => max10_clk2_50, --  50 MHz input from board (backup clock)
      c0 => open,              --  25 MHz
      c1 => open,              -- 125 MHz positive
      c2 => open,              -- 125 MHz negative
      c3 => clk,               -- 100 MHz
      c4 => open               --  83.333 MHz
    );
    end generate;

    --
    -- generic BRAM glue
    --
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,

        -- SPI instances
	C_spi => C_spi,
	C_spi_turbo_mode => C_spi_turbo_mode,
	C_spi_fixed_speed => C_spi_fixed_speed,

	C_debug => C_debug
    )
    port map (
	clk => clk,

        -- Serial I/O instance 0
	sio_txd(0) => rs232_txd,
        sio_rxd(0) => rs232_rxd,
	sio_break(0) => open,

        -- SPI instance 0
        --
        -- TODO: Must multiplex these signals when SPI is enabled.
        -- spi_ss(0)   => open, -- arduino_io(10)
	-- spi_mosi(0) => open, -- arduino_io(11)
        -- spi_miso(0) => open, -- arduino_io(12)
        -- spi_clk(0)  => open, -- arduino_io(13)

        spi_miso => "", -- arduino_io(12)

        --
        -- gpio 128 bits availble.
        --

        -- Arduino D0 and D1 is mapped to rs232 RXD and rs232_TXD.
        gpio(1 downto 0) => open,

        -- Arduino I/O mapped to gpio 15-2
        gpio(15 downto 2) => arduino_io(15 downto 2),

        -- GPIO mapped to gpio 47 - 16
	gpio(47 downto 16) => gpio(31 downto 0),

	gpio(127 downto 48) => open,

        -- simple_out 32 bits
	simple_out(8 downto 0) => ledr(8 downto 0),

        -- led(9) is multiplexed with arduino(13) and simple_out(9)
        simple_out(9) => simple_out_bit_9,

        simple_out(31 downto 10) => open,

        -- simple_in 32 bits
	simple_in(15 downto 0) => btns,
	simple_in(25 downto 16) => sw,
        simple_in(31 downto 26) => open
    );

end Behavioral;
