--
-- Copyright (c) 2016 Marko Zec, University of Zagreb
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

library ecp5um;
use ecp5um.components.all;


entity glue is
    generic (
	C_arch: integer := ARCH_MI32; -- either ARCH_MI32 or ARCH_RV32
	C_big_endian: boolean := false;
	C_debug: boolean := false;

	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 64;
	C_sio: integer := 1;
	C_spi: integer := 0;
	C_gpio: integer := 0;
	C_simple_io: boolean := true
    );
    port (
	clk_100_p, clk_100_n: in std_logic;
	tx: out std_logic;
	rx: in std_logic;
	led: out std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk_100m: std_logic;
    signal rs232_break: std_logic;
begin

    clock_diff2se:
    ILVDS port map(A => clk_100_p, AN => clk_100_n, Z => clk_100m);

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_bram_size,
	C_debug => C_debug,
	C_sio => C_sio,
	C_spi => C_spi,
	C_gpio => C_gpio
    )
    port map (
	clk => clk_100m,
	sio_txd(0) => tx,
	sio_rxd(0) => rx,
	sio_break(0) => rs232_break,
	simple_out(7 downto 0) => led, simple_out(31 downto 8) => open,
	simple_in => (others => '0'),
	spi_miso => (others => '0')
    );
end Behavioral;
