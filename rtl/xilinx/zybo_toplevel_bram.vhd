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
	C_clk_freq: integer := 125;

	-- SoC configuration options
	C_mem_size: integer := 128;
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	clk_125m: in std_logic;
        rs232_tx: out std_logic;
        rs232_rx: in std_logic;
	led: out std_logic_vector(3 downto 0);
	sw: in std_logic_vector(3 downto 0);
	ja_u: inout std_logic_vector(3 downto 0);
	ja_d: inout std_logic_vector(3 downto 0);
	jb_u: inout std_logic_vector(3 downto 0);
	jb_d: inout std_logic_vector(3 downto 0);
	jc_u: inout std_logic_vector(3 downto 0);
	jc_d: inout std_logic_vector(3 downto 0);
	jd_u: inout std_logic_vector(3 downto 0);
	jd_d: inout std_logic_vector(3 downto 0);
	btn: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal rs232_break: std_logic;
    signal btns: std_logic_vector(7 downto 0);
    signal leds: std_logic_vector(7 downto 0);
    signal switches: std_logic_vector(7 downto 0);
begin
    clk <= clk_125m;
    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_clk_freq => C_clk_freq,
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk,
	rs232_tx => rs232_tx, rs232_rx => rs232_rx,
	rs232_break => open,
	gpio(3 downto 0) => ja_u(3 downto 0),
	gpio(7 downto 4) => ja_d(3 downto 0),
	gpio(11 downto 8) => jb_u(3 downto 0),
	gpio(15 downto 12) => jb_d(3 downto 0),
	gpio(19 downto 16) => jc_u(3 downto 0),
	gpio(23 downto 20) => jc_d(3 downto 0),
	gpio(27 downto 24) => jd_u(3 downto 0),
	gpio(31 downto 28) => jd_d(3 downto 0),
	leds(3 downto 0) => led(3 downto 0),
	leds(7 downto 4) => open,
	btns => btns,
	sw => switches
    );
    btns <= "0000" & btn(3 downto 0);
    switches <= "0000" & sw(3 downto 0);
end Behavioral;
