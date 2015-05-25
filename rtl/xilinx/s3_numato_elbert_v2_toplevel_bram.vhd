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

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity glue is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;

	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 12;

	-- SoC configuration options
	C_mem_size: integer := 6;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	Clk_12MHz: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	SevenSegment: out std_logic_vector(7 downto 0);
	Enable: out std_logic_vector(2 downto 0);
	IO_P1, IO_P2, IO_P4, IO_P6: inout std_logic_vector(7 downto 0);
	-- IO_P5: inout std_logic_vector(5 downto 0);
	LED: out std_logic_vector(7 downto 0);
	Switch: in std_logic_vector(5 downto 0);
	DPSwitch: in std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal rs232_break: std_logic;
begin

--    clock synthesizer
--    clkgen: entity work.clkgen
--    generic map(
--	C_clk_freq => C_clk_freq
--    )
--    port map(
--	clk_50m => Clk_12MHz, clk => clk
--    );
    clk <= Clk_12MHz;
    
    -- reset hard-block: Xilinx Spartan-3 specific
    reset: startup_spartan3
    port map (
        clk => clk, gsr => rs232_break, gts => rs232_break
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk,
	rs232_tx => rs232_dce_txd, rs232_rx => rs232_dce_rxd,
	rs232_break => rs232_break,
	gpio(7 downto 0)   => IO_P1(7 downto 0),
	gpio(15 downto 8)  => IO_P2(7 downto 0),
	gpio(23 downto 16) => IO_P4(7 downto 0),
	gpio(31 downto 24) => IO_P6(7 downto 0),
	leds(7 downto 0) => led, 
	leds(15 downto 8) => open,
	lcd_7seg(7 downto 0) => SevenSegment(7 downto 0),
	lcd_7seg(10 downto 8) => Enable(2 downto 0),
	lcd_7seg(15 downto 11) => open,
	btns(5 downto 0) => Switch(5 downto 0),
	btns(15 downto 6) => (x"00" & "00"),
	sw(7 downto 0) => DPSwitch(7 downto 0),
	sw(15 downto 8) => x"00"
    );
end Behavioral;
