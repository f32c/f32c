--
-- Copyright (c) 2015, 2016 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;


entity glue is
    generic (
	C_arch: integer := ARCH_MI32; -- either ARCH_MI32 or ARCH_RV32
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_mul_reg: boolean := true;
	C_debug: boolean := false;

	C_clk_freq: integer := 80;

	-- SoC configuration options
	C_bram_size: integer := 32;
	C_sio: integer := 1;
	C_spi: integer := 0;
	C_gpio: integer := 0;
	C_simple_io: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	led: out std_logic_vector(7 downto 0);
	btn_pwr, btn_f1, btn_f2: in std_logic;
	btn_up, btn_down, btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0)
    );
end glue;

architecture x of glue is
    signal clk, pll_lock: std_logic;
    signal clk_133m, clk_66m, clk_160m, clk_80m: std_logic;
    signal reset: std_logic;
    signal sio_break: std_logic;

    signal R_simple_in: std_logic_vector(19 downto 0);

begin
    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_mult_enable => C_mult_enable,
	C_mul_reg => C_mul_reg,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_bram_size,
	C_debug => C_debug,
	C_sio => C_sio,
	C_spi => C_spi,
	C_gpio => C_gpio
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_tx,
	sio_rxd(0) => rs232_rx,
	sio_break(0) => sio_break,
	simple_out(7 downto 0) => led,
	simple_in(19 downto 0) => R_simple_in,
	spi_miso => open
    );
    R_simple_in <= sw & x"00" & '0' & not btn_pwr & btn_f2 & btn_f1
      & btn_up & btn_down & btn_left & btn_right when rising_edge(clk);

    I_pll: entity work.pll
    port map (
	clki => clk_25m,
	stdby => '0',
	enclk_133m => '1',
	enclk_66m => '1',
	enclk_160m => '1',
	enclk_80m => '1',
	clk_133m => clk_133m,
	clk_66m => clk_66m,
	clk_160m => clk_160m,
	clk_80m => clk_80m,
	lock => pll_lock
    );

    clk <= clk_160m when C_clk_freq = 160
      else clk_133m when C_clk_freq = 133
      else clk_80m when C_clk_freq = 80
      else clk_66m;
    reset <= not pll_lock or sio_break;

end x;
