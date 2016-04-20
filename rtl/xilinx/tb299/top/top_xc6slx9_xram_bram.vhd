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

	-- Main clock: 81/112
	C_clk_freq: integer := 81;

	-- SoC configuration options
	C_bram_size: integer := 32;
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	Led: out std_logic_vector(7 downto 0);
	gpio: inout std_logic_vector(39 downto 0);
	btn_k2, btn_k3: in std_logic
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_25M_112M5
    port map(
      clk_in1 => clk_25m, clk_out1 => clk
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_25M_81M25
    port map(
      clk_in1 => clk_25m, clk_out1 => clk
    );
    end generate;

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
    );

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_bram_size => C_bram_size,
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
	gpio(31 downto 0) => gpio(31 downto 0),
	gpio(127 downto 32) => open,
	simple_out(7 downto 0) => Led(7 downto 0),
	simple_out(31 downto 8) => open,
	simple_in(0) => btn_k2,
	simple_in(1) => btn_k3,
	simple_in(31 downto 2) => open
    );
end Behavioral;
