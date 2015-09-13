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
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_mem_size: integer := 128
    );
    port (
	clk: in std_logic; -- 100 MHz
	RsTx: out std_logic; -- FTDI UART
	RsRx: in std_logic; -- FTDI UART
	JA, JB, JC: inout std_logic_vector(7 downto 0); -- PMODs
	seg: out std_logic_vector(6 downto 0); -- 7-segment display
	dp: out std_logic; -- 7-segment display
	an: out std_logic_vector(3 downto 0); -- 7-segment display
	led: out std_logic_vector(15 downto 0);
	sw: in std_logic_vector(15 downto 0);
	btnC, btnU, btnD, btnL, btnR: in std_logic
    );
end glue;

architecture Behavioral of glue is
    signal rs232_break: std_logic;
    signal btns: std_logic_vector(15 downto 0);
    signal lcd_7seg: std_logic_vector(15 downto 0);
begin
    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk,
	sio_txd(0) => rstx, sio_rxd(0) => rsrx, sio_break(0) => rs232_break,
	gpio(7 downto 0) => ja, gpio(15 downto 8) => jb,
	gpio(23 downto 16) => jc, gpio(127 downto 24) => open,
	simple_out(15 downto 0) => led, simple_out(22 downto 16) => seg,
	simple_out(23) => dp, simple_out(27 downto 24) => an,
	simple_out(31 downto 28) => open,
	simple_in(15 downto 0) => btns, simple_in(31 downto 16) => sw,
	spi_miso => (others => '0')
    );
    btns <= x"00" & "000" & btnc & btnu & btnd & btnl & btnr;

    res: startupe2
    generic map (
	prog_usr => "FALSE"
    )
    port map (
	clk => clk,
	gsr => rs232_break,
	gts => '0',
	keyclearb => '0',
	pack => '1',
	usrcclko => clk,
	usrcclkts => '0',
	usrdoneo => '1',
	usrdonets => '0'
    );

end Behavioral;
