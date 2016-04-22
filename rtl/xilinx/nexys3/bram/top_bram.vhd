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
	C_debug: boolean := false;
	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 80;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_100m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	ja, jb, jc, jd: inout std_logic_vector(7 downto 0); -- PMODs
	seg: out std_logic_vector(7 downto 0); -- 7-segment display
	an: out std_logic_vector(3 downto 0); -- 7-segment display
	led: out std_logic_vector(7 downto 0);
	btn_center, btn_south, btn_north, btn_east, btn_west: in std_logic;
	sw: in std_logic_vector(7 downto 0);
	MemOE, MemWR, MemAdv, MemWait, MemClk: out std_logic;
	RamCS, RamCRE, RamUB, RamLB: out std_logic;
	FlashCS, FlashRp, QuadSpiFlashCS, QuadSpiFlashSck: out std_logic;
	MemAdr: out std_logic_vector(26 downto 1);
	MemDB: inout std_logic_vector(15 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    clkgen: entity work.clkgen
    generic map(
	C_clk_freq => C_clk_freq
    )
    port map(
	clk_100m => clk_100m, clk => clk
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
	C_mem_size => C_mem_size,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_dce_txd, sio_rxd(0) => rs232_dce_rxd,
	sio_break(0) => rs232_break,
	spi_sck(0)  => open,  spi_sck(1)  => open,
	spi_ss(0)   => open,  spi_ss(1)   => open,
	spi_mosi(0) => open,  spi_mosi(1) => open,
	spi_miso(0) => '-',   spi_miso(1) => '-',
	gpio(7 downto 0) => ja(7 downto 0),
	gpio(15 downto 8) => jb(7 downto 0),
	gpio(23 downto 16) => jc(7 downto 0),
	gpio(31 downto 24) => jd(7 downto 0),
	gpio(127 downto 32) => open,
	simple_out(7 downto 0) => led(7 downto 0),
	simple_out(15 downto 8) => seg(7 downto 0),
	simple_out(19 downto 16) => an(3 downto 0),
	simple_out(31 downto 20) => open,
	simple_in(0) => btn_west, simple_in(1) => btn_east,
	simple_in(2) => btn_north, simple_in(3) => btn_south,
	simple_in(4) => btn_center,
	simple_in(12 downto 5) => sw(7 downto 0),
	simple_in(31 downto 13) => open
    );

    -- Assign unused signals
    MemAdr <= (others => '0');
    MemDB <= (others => 'Z');
    MemOE <= '1';
    MemWR <= '1';
    MemAdv <= '0';
    MemWait <= 'Z';
    MemClk <= '0';
    RamCS <= '1';
    RamCRE <= '0';
    RamUB <= '1';
    RamLB <= '1';
    FlashCS <= '1';
    FlashRp <= 'Z';
    QuadSpiFlashCS <= '1';
    QuadSpiFlashSck <= '0';
    
end Behavioral;
