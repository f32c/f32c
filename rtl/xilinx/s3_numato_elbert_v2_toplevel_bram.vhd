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
	C_arch: integer := ARCH_RV32;

	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 60;

	-- CPU configuration
	C_big_endian: boolean := false;
	C_sign_extend: boolean := false;
	C_branch_likely: boolean := false;
	C_mult_enable: boolean := false;
	C_branch_prediction: boolean := false;
	C_load_aligner: boolean := false;
	C_result_forwarding: boolean := false;
	C_full_shifter: boolean := false;
	C_exceptions: boolean := false;

	-- SoC configuration options
	C_mem_size: integer := 6;
	C_PC_mask: std_logic_vector := x"00001fff"; -- 8 K
	C_sio_fixed_baudrate: boolean := true;
	C_sio_break_detect: boolean := false;
	C_simple_in: integer := 0;
	C_simple_out: integer := 4;
	C_gpio: integer := 0;
	C_timer: boolean := false
    );
    port (
	Clk_12MHz: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	SevenSegment: out std_logic_vector(7 downto 0);
	Enable: out std_logic_vector(2 downto 0);
	IO_P1, IO_P2, IO_P4, IO_P6: inout std_logic_vector(7 downto 0);
	-- IO_P5: inout std_logic_vector(5 downto 0);
	LED: out std_logic_vector(7 downto 0);
	Switch: in std_logic_vector(5 downto 0);
	DPSwitch: in std_logic_vector(7 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal rs232_break: std_logic;
begin

    -- clock synthesizer
    clkgen: entity work.clkgen
    generic map(
	C_clk_freq => C_clk_freq
    )
    port map(
	clk_12m => Clk_12MHz, clk => clk
    );
    
    -- reset hard-block: Xilinx Spartan-3 specific
    reset: startup_spartan3
    port map (
        clk => clk, gsr => rs232_break, gts => rs232_break
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_bram
    generic map (
	C_PC_mask => C_PC_mask,
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend,
	C_mem_size => C_mem_size,
	C_mult_enable => C_mult_enable,
	C_branch_prediction => C_branch_prediction,
	C_load_aligner => C_load_aligner,
	C_result_forwarding => C_result_forwarding,
	C_full_shifter => C_full_shifter,
	C_exceptions => C_exceptions,
	C_sio_fixed_baudrate => C_sio_fixed_baudrate,
	C_sio_break_detect => C_sio_break_detect,
	C_simple_in => C_simple_in,
	C_simple_out => C_simple_out,
	C_gpio => C_gpio,
	C_timer => C_timer
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_dce_txd, sio_rxd(0) => rs232_dce_rxd,
	sio_break(0) => rs232_break,
	gpio(7 downto 0)   => IO_P1(7 downto 0),
	gpio(15 downto 8)  => IO_P2(7 downto 0),
	gpio(23 downto 16) => IO_P4(7 downto 0),
	gpio(31 downto 24) => IO_P6(7 downto 0),
	gpio(127 downto 32) => open,
	simple_out(7 downto 0) => LED,
	simple_out(15 downto 8) => SevenSegment(7 downto 0),
	simple_out(18 downto 16) => Enable(2 downto 0),
	simple_out(31 downto 19) => open,
	simple_in(5 downto 0) => Switch(5 downto 0),
	simple_in(15 downto 6) => x"00" & "00",
	simple_in(23 downto 16) => DPSwitch(7 downto 0),
	simple_in(31 downto 24) => x"00"
    );
end Behavioral;
