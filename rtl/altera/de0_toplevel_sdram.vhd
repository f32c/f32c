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
	C_arch: integer := ARCH_RV32;

	-- Main clock freq, in multiples of 10 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
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
	dram_we_n, dram_cs_n: out std_logic
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

    -- generic SDRAM glue
    glue_sdram: entity work.glue_sdram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk,
	rs232_tx => rs232_txd, rs232_rx => rs232_rxd,
	rs232_break => open,
	gpio => open,
	leds(7 downto 0) => led,
	btns => btns,
	sw(3 downto 0) => sw,
	sdram_addr => dram_addr, sdram_data => dram_dq,
	sdram_ba => dram_ba, sdram_dqm => dram_dqm,
	sdram_ras => dram_ras_n, sdram_cas => dram_cas_n,
	sdram_cke => dram_cke, sdram_clk => dram_clk,
	sdram_we => dram_we_n, sdram_cs => dram_cs_n
    );

    btns <= x"000" & "00" & btn_left & btn_right;
end Behavioral;
