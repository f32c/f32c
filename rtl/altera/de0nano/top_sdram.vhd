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
	-- Main clock freq, in multiples of 10 MHz, or 81
	C_clk_freq: integer := 81;

	-- ISA
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_movn_movz: boolean := false;
	C_exceptions: boolean := true;

	-- Optimization
	C_branch_prediction: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true; -- XXX! false broken!
	C_full_shifter: boolean := true;

	-- SoC configuration options
	C_PC_mask: std_logic_vector := x"81ffffff"; -- 32 MB
	C_bram_size: integer := 8;
	C_simple_in: integer := 32;
	C_simple_out: integer := 8;
	C_gpio: integer := 0
    );
    port (
	clk_50m: in std_logic;
	rs232_txd: out std_logic;
	rs232_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	dram_addr: out std_logic_vector(12 downto 0);
	dram_dq: inout std_logic_vector(15 downto 0);
	dram_ba: out std_logic_vector(1 downto 0);
	dram_dqm: out std_logic_vector(1 downto 0);
	dram_ras_n, dram_cas_n: out std_logic;
	dram_cke, dram_clk: out std_logic;
	dram_we_n, dram_cs_n: out std_logic;
	video_dac: out std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, clk_325m: std_logic;
    signal btns: std_logic_vector(15 downto 0);
begin

    G_generic_clk:
    if C_clk_freq /= 81 generate
    clock_generic: entity work.pll_50m
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_50m => clk_50m,
	clk => clk
    );
    end generate;

    G_81m_clk:
    if C_clk_freq = 81 generate
    clock_81m25: entity work.pll_50m_81m25
    port map (
	inclk0 => clk_50m,
	c0 => clk,	-- 81.25 MHz
	c1 => clk_325m,	-- 325.0 MHz
	c2 => open	-- 162.5 Mhz
    );
    end generate;

    -- generic SDRAM glue
    glue_sdram: entity work.glue_sdram_fb
    generic map (
	C_clk_freq => C_clk_freq,

	-- ISA
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend,
	C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable,
	C_exceptions => C_exceptions,

	-- Optimization
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_full_shifter => C_full_shifter,

	-- SoC
	C_PC_mask => C_PC_mask,
	C_bram_size => C_bram_size,
	C_simple_in => C_simple_in,
	C_simple_out => C_simple_out,
	C_gpio => C_gpio
    )
    port map (
	clk => clk, clk_325m => clk_325m,
	clk_25mhz => '0', -- XXX vgadhmi needs this
	sio_txd(0) => rs232_txd, sio_rxd(0) => rs232_rxd, sio_break => open,
	gpio => open,
	spi_miso => "",
	simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
	simple_in(15 downto 0) => btns,
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open,
	sdram_addr => dram_addr, sdram_data => dram_dq,
	sdram_ba => dram_ba, sdram_dqm => dram_dqm,
	sdram_ras => dram_ras_n, sdram_cas => dram_cas_n,
	sdram_cke => dram_cke, sdram_clk => dram_clk,
	sdram_we => dram_we_n, sdram_cs => dram_cs_n
    );

    btns <= x"000" & "00" & not btn_left & not btn_right;
end Behavioral;
