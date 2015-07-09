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

	-- Main clock: 81 or 112 not used clock is 100Mhz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	clk_100m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	Switch: in std_logic_vector(5 downto 0);
	sw: in std_logic_vector(7 downto 0);
	IO_P6: inout std_logic_vector(7 downto 0);
	IO_P7: inout std_logic_vector(7 downto 0);
	IO_P8: inout std_logic_vector(7 downto 0);
	IO_P9: inout std_logic_vector(7 downto 0);
	SevenSegment: out std_logic_vector(7 downto 0); -- 7-segment display
	SevenSegmentEnable: out std_logic_vector(2 downto 0) -- 7-segment display
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
    signal btns: std_logic_vector(5 downto 0);
	 signal lcd_7seg: std_logic_vector(15 downto 0);
	 signal gpio: std_logic_vector(31 downto 0);
	 
begin
    --  clock synthesizer: Xilinx Spartan-6 specific

clk100: if C_clk_freq = 100 generate
clk <= clk_100m;
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
	C_mem_size => C_mem_size,
	C_debug => C_debug
   )
   port map (
	clk => clk,
	rs232_tx => rs232_dce_txd, rs232_rx => rs232_dce_rxd,
	rs232_break => rs232_break,
	gpio => gpio,
	leds(7 downto 0) => led,
	leds(15 downto 8) => open,
	btns(5 downto 0) => btns, 
	btns(15 downto 6) => open,
   sw(7 downto 0) => sw,
	sw(15 downto 8) => open,
	lcd_7seg => lcd_7seg
    );
btns <= Switch(5 downto 0);
SevenSegment <= lcd_7seg(7 downto 0);
SevenSegmentEnable <= lcd_7seg(10 downto 8);
IO_P6(7 downto 0) <= gpio(7 downto 0);
IO_P7(7 downto 0) <= gpio(15 downto 8);
IO_P8(7 downto 0) <= gpio(23 downto 16);
IO_P9(7 downto 0) <= gpio(31 downto 24);
end Behavioral;
