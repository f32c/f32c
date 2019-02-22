
--
-- TODO:
--
-- 02/21/2019
-- Hook up fm_antenna to I/O port
-- Resolve clocks issues
-- Implement Arduino add-in for DE10-Nano, modified clocks, memory sizes.
--

--
-- Menlopark Innovation LLC
-- 02/17/2019
--
-- Top module for DE10-Nano BRAM based FM RDS project.
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
        -- Menlo: from top_xram_sdram.vhd, need 81.25Mhz for FM RDS
	-- C_clk_freq: integer := 83;

        -- Menlo:
	-- SoC configuration options (64K in this configuration)
	C_bram_size: integer := 64;

	-- Debugging
	C_debug: boolean := false
    );
    port (
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
    signal btns: std_logic_vector(15 downto 0);
begin

    clock: entity work.pll_50m
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_50m => clk_50m,
	clk => clk
    );

    -- Menlo fmrds BRAM glue module.
    glue_bram: entity work.fmrds_glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,

        -- Menlo: Add support for C_fmrds
        -- C_fmrds => false,

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
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open

        -- FM RDS support
        -- fm_antenna => GPIO_0(0)
    );

    btns <= x"000" & "00" & not btn_left & not btn_right;
end Behavioral;
