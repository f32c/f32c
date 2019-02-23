
--
-- TODO:
--
-- 02/22/2019
--
-- Enable FM RDS IP block
-- #Resolve clocks issues
--  #- extra clocks
--  #- 81 on CPU vs. 81.25 Mhz required.
--    #- CPU takes integer Mhz option
--    #- what are the other projects doing?
--    #- fpga_ulx2s_sram has FM option
-- #fpga_ulx2s_sram.menu.soc.fm.socopt=_fm_
-- #fpga_ulx2s_sram.menu.soc.fm.build.f_cpu=81250000
-- #fpga_ulx2s_sram.menu.soc.fm.f_cpu_MHz=81
--
-- debug SoC options selection with Arduino
--
-- #Validate clock frequency configuration change with Arduino add-in updates.
--
-- #Hook up fm_antenna to I/O port
--   #- FPGA port GPIO_0 PIN_V12 on DE10-Nano
--   #- top header, lower left corner.

--
-- Menlopark Innovation LLC
-- 02/17/2019
--
-- Top module for DE10-Nano BRAM based FM RDS project.
--
--   - GPIO's are mapped to Arduino header pins on the DE10-Nano.
--
--   - FM Antenna is hooked up to GPIO_0[0] which is PIN_V12 on the FPGA.
--
--     - It is the top header on the DE10-Nano, lower left corner pin and
--       not one of the Arduino header pins.
--
--     - This leaves all the Arduino I/O pins free for Arduino projects and use.
--
--   - Frequency has been set to 81Mhz for FM RDS
--     - Similar to fpga_ulx2s_sram project.
--
--   - BRAM memory set to 64K default
--     - Leave plenty of space for experimentation.
--     - Can increase to 512K with block RAMS on the DE10-Nano FPGA.
--
--   - FM RDS SoC module is mapped to IO_BASE + 0x400
--     - This decodes the range 0xFFFF_FC00 - 0xFFFF_FCFF.
--     - see fmrds_glue_bram.vhd I/O decoder and mux.
--

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

	-- Main clock freq, in multiples of 10 MHz
	C_clk_freq: integer := 100;

        -- Menlo:
	-- SoC configuration options (64K in this configuration)
	C_bram_size: integer := 64;

	-- Debugging
	C_debug: boolean := false
    );
    port (

        --
        -- Ports are specified in glue_de10_nano.qsf and Quartus II
        -- provides them to the top level entity.
        --

	clk_50m: in std_logic;
	rs232_txd: out std_logic;
	rs232_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	gpioa: inout std_logic_vector(33 downto 16);

        -- FM RDS on GPIO_0[0], FPGA pin PIN_V12
        -- set in glue_de10_nano.qsf
        fm_antenna: out std_logic

        -- DE10-Nano has additional GPIO's available
        -- GPIO_0: inout std_logic_vector(35 downto 0)
        -- GPIO_1: inout std_logic_vector(35 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal clk_fmdds: std_logic;
    signal clk_25: std_logic;
    signal btns: std_logic_vector(15 downto 0);
begin

--    clock: entity work.pll_50m
--    generic map (
--	C_clk_freq => C_clk_freq
--    )
--    port map (
--	clk_50m => clk_50m,
--	clk => clk
--    );

    clkgen_100: entity work.clk_50M_250M_25M_100M
    port map(
      refclk => clk_50m,       --  50 MHz input from board
      outclk_0 => clk_fmdds,  -- 250 MHz FM DDS frequency synthesizer
      outclk_1 => clk_25,      --  25 MHz used for VGA when enabled.
      outclk_2 => clk          -- 100 MHz main CPU core clock
    );

    --
    -- This PLL is from top_de10standard_xram_sdram_vector.vhd
    -- which has a Cyclone V at 50Mhz base clock similar to the
    -- DE10-Nano.
    --
    -- PLL's are originally configured using an Altera IP block,
    -- but the project does not have the settings, just the generated
    -- template code that activates the PLL with the state configuration.
    --
    -- This PLL generates 25, 100, and 250Mhz which is used for the
    -- main clock (100Mhz) and FM RDS frequency synthesizer (250Mhz).
    --


    -- Menlo fmrds BRAM glue module.
    glue_bram: entity work.fmrds_glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,

        -- Menlo: Add support for C_fmrds
        C_fmrds => true,
        C_fmdds_hz => 250000000,        -- 250Mhz direct digital synthesis clock
        C_rds_clock_multiply => 57,     -- multiply 57 and divide 3125 from cpu clk 100Mhz
        C_rds_clock_divide => 3125,     -- to get 1.824 Mhz for RDS logic
        C_fm_stereo => false,
        C_fm_filter => false,
        C_fm_downsample => false,
        C_rds_msg_len => 260,

	C_debug => C_debug
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_txd, sio_rxd(0) => rs232_rxd,
	sio_break(0) => open,
	gpio(31 downto 16) => gpioa(31 downto 16), gpio(15 downto 0) => open,
	spi_miso => "",
	simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
	simple_in(15 downto 0) => btns,
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open,

        -- FM RDS support
        clk_fmdds => clk_fmdds,
        fm_antenna => fm_antenna
    );

    btns <= x"000" & "00" & not btn_left & not btn_right;
end Behavioral;
