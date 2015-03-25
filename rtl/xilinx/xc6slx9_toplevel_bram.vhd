--
-- Copyright 2015 Marko Zec, University of Zagreb
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
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

-- $Id: nexys3_toplevel_bram.vhd 2636 2015-03-25 15:07:09Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;


entity glue is
    generic (
	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 112;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	led: out std_logic_vector(7 downto 0);
	btn_center, btn_south, btn_north, btn_east, btn_west: in std_logic;
	sw: in std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, rs232_break: std_logic;
    signal btns: std_logic_vector(7 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    clkgen: entity work.pll_25M_112M5
    --generic map(
    --  C_clk_freq => C_clk_freq,
    --  C_debug => false
    --)
    port map(
      clk_in1 => clk_25m, clk_out1 => clk
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
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk,
	rs232_tx => rs232_dce_txd, rs232_rx => rs232_dce_rxd,
	rs232_break => rs232_break, gpio => open,
	leds => led, btns => btns, sw => sw
    );
    btns <= "000" & btn_west & btn_east & btn_north & btn_south & btn_center;
end Behavioral;
