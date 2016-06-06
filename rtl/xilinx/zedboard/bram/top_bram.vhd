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

entity glue is
    generic (
	-- ISA
	C_arch: integer := ARCH_MI32;

	-- Main clock freq, in multiples of 10 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 32
    );
    port (
	GCLK: in std_logic; -- 100 MHz
	LD: out std_logic_vector(7 downto 0);
	BTNC, BTND, BTNL, BTNR, BTNU: in std_logic;
	SW: in std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal btns: std_logic_vector(15 downto 0);
begin

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size
    )
    port map (
	clk => gclk,
	sio_txd(0) => open, sio_rxd(0) => '1',
	sio_break(0) => open,
	gpio => open,
	spi_miso => "",
	simple_out(7 downto 0) => ld, simple_out(31 downto 8) => open,
	simple_in(15 downto 0) => btns,
	simple_in(19 downto 16) => sw, simple_in(31 downto 20) => open
    );

    btns <= x"00" & "000" & btnc & btnu & btnd & btnl & btnr;
end Behavioral;
