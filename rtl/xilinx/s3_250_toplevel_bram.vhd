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
	C_clk_freq: integer := 50;

	-- SoC configuration options
	C_mem_size: integer := 16;
	C_sio: integer := 1;
	C_spi: integer := 1;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_50m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	flash_so: in std_logic;
	flash_cen, flash_sck, flash_si: out std_logic;
	LED: out std_logic_vector(1 downto 0);
	WINGA: inout std_logic_vector(15 downto 0);
	INPUT: in std_logic_vector(14 downto 0)
    );
end glue;

architecture Behavioral of glue is
signal clk, rs232_break: std_logic;
begin

    -- clock synthesizer
    clkgen: entity work.clkgen
    generic map(
	C_clk_freq => C_clk_freq
    )
    port map(
	clk_50m => clk_50m, clk => clk
    );
	 
    -- reset hard-block: Xilinx Spartan-3 specific
    reset: startup_spartan3
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break
    );
     -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_mem_size => C_mem_size,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_dce_txd,
	sio_rxd(0) => rs232_dce_rxd,
	sio_break(0) => rs232_break,
  	spi_sck(0) => flash_sck,
  	spi_ss(0) => flash_cen,
  	spi_mosi(0) => flash_si,
  	spi_miso(0) => flash_so,
	simple_out(1 downto 0) => LED(1 downto 0),
	simple_out(31 downto 2) => open,
	simple_in(14 downto 0) => INPUT(14 downto 0), 
	simple_in(31 downto 15) => x"0000" & '0', 
	gpio(15 downto 0) => WINGA(15 downto 0),
	gpio(127 downto 16) => open
    );
end Behavioral;
