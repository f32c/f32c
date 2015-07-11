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
	C_clk_freq: integer := 80;

	-- SoC configuration options
	C_mem_size: integer := 128;
	C_leds_btns: boolean := true
    );
    port (
	clk_50m: in std_logic;
	rs232_txd: out std_logic;
	rs232_rxd: in std_logic;
	lcd_db: out std_logic_vector(3 downto 0);
	lcd_e, lcd_rs, lcd_rw, lcd_bl: out std_logic;
	btn_south, btn_north, btn_east, btn_west, btn_center: in std_logic;
	gpio: inout std_logic_vector(7 downto 0);
	led: out std_logic_vector(7 downto 0);
	sw: in std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
    signal lcd_7seg: std_logic_vector(15 downto 0);
    signal btns: std_logic_vector(15 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    clkgen: entity work.clkgen
    generic map(
	C_clk_freq => C_clk_freq
    )
    port map(
	clk_50m => clk_50m, clk => clk
    );

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
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
	sio_txd(0) => rs232_txd, sio_rxd(0) => rs232_rxd,
	sio_break(0) => rs232_break,
	gpio(7 downto 0) => gpio, gpio(31 downto 8) => open,
	leds(7 downto 0) => led, leds(15 downto 8) => open,
	lcd_7seg => lcd_7seg, btns => btns,
	sw(7 downto 0) => sw, sw(15 downto 8) => x"00"
    );
    lcd_db <= lcd_7seg(3 downto 0);
    lcd_rs <= lcd_7seg(4);
    lcd_e <= lcd_7seg(5);
    lcd_rw <= '0';
    lcd_bl <= '1';
    btns <= x"00" & "000" & btn_center &
      btn_north & btn_south & btn_west & btn_east;
end Behavioral;
