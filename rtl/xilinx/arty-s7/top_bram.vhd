--
-- Copyright (c) 2015, 2023 Marko Zec
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
	C_bram_size: integer := 128
    );
    port (
	clk100mhz: in std_logic; -- 100 MHz
	sw: in std_logic_vector(3 downto 0);
	led: out std_logic_vector(3 downto 0);
	led0_r, led0_g, led0_b: out std_logic;
	led1_r, led1_g, led1_b: out std_logic;
	btn: in std_logic_vector(3 downto 0);
	ja, jb, jc, jd: inout std_logic_vector(7 downto 0); -- PMODs
	uart_rxd_out: out std_logic; -- FTDI UART
	uart_txd_in: in std_logic; -- FTDI UART
	qspi_dq: inout std_logic_vector(3 downto 0);
	qspi_cs: out std_logic
    );
end glue;

architecture Behavioral of glue is
    signal rs232_break: std_logic;
    signal flash_clk: std_logic;
begin
    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,
	C_spi => 1
    )
    port map (
	clk => clk100mhz,
	sio_txd(0) => uart_rxd_out, sio_rxd(0) => uart_txd_in,
	sio_break(0) => rs232_break,
	gpio(7 downto 0) => ja, gpio(15 downto 8) => jb,
	gpio(23 downto 16) => jc, gpio(31 downto 24) => jd,
	gpio(127 downto 32) => open,
	simple_out(3 downto 0) => led,
	simple_out(31 downto 4) => open,
	simple_in(3 downto 0) => btn, simple_in(15 downto 4) => x"000",
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => x"000",
	spi_ss(0) => qspi_cs,
	spi_sck(0) => flash_clk,
	spi_mosi(0) => qspi_dq(0),
	spi_miso(0) => qspi_dq(1)
    );
    qspi_dq(2) <= '1'; -- wp_n
    qSpi_dq(3) <= '1'; -- hold_n

    res: startupe2
    generic map (
	prog_usr => "FALSE"
    )
    port map (
	clk => clk100mhz,
	gsr => '0',
	gts => '0',
	keyclearb => '0',
	pack => '1',
	usrcclko => flash_clk,
	usrcclkts => '0',
	usrdoneo => '1',
	usrdonets => '1'
    );

end Behavioral;
