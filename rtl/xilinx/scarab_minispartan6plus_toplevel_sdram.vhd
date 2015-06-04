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

	-- Main clock: 50/81/100/112
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 64;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
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
	leds: out std_logic_vector(7 downto 0);
	porta, portb: inout std_logic_vector(11 downto 0);
	portc: inout std_logic_vector(7 downto 0);
	sw: in std_logic_vector(4 downto 1)
    );
end glue;

architecture Behavioral of glue is
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
    glue_sdram: entity work.glue_sdram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_mem_size => C_mem_size,
	C_sdram_address_width => 22,
	C_sdram_column_bits => 9,
	C_sdram_startup_cycles => 10100,
	C_sdram_cycles_per_refresh => 1524,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	-- external SDRAM interface
	sdram_addr => sdram_a, sdram_data => sdram_d,
	sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
	sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
	sdram_cke => sdram_cke, sdram_clk => sdram_clk,
	sdram_we => sdram_wen, sdram_cs => sdram_csn,	
	rs232_tx => rs232_tx, rs232_rx => rs232_rx,
	rs232_break => rs232_break,
	gpio(11 downto 0) => porta(11 downto 0),
	gpio(23 downto 12) => portb(11 downto 0),
	gpio(31 downto 24) => portc(7 downto 0),
	leds(7 downto 0) => leds(7 downto 0),
	leds(15 downto 8) => open,
	btns(15 downto 0) => (others => '-'),
	sw(3 downto 0) => sw(4 downto 1),
	sw(15 downto 4) => (others => '-')
    );
end Behavioral;
