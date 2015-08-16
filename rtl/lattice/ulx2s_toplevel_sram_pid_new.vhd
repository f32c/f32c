--
-- Copyright (c) 2011-2015 Marko Zec, University of Zagreb
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
use ieee.numeric_std.all; -- we need signed type
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;
use work.sram_pack.all;


entity toplevel is
    generic (
	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff";

	-- COP0 options
	C_exceptions: boolean := true;
	C_cop0_count: boolean := true;
	C_cop0_compare: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
	C_register_technology: string := "lattice";

	-- This may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

	-- Debugging / testing options (should be turned off)
	C_debug: boolean := false;

	-- SoC configuration options
	C_cpus: integer := 1;
	C_bram_size: integer := 2;	-- 2 or 16 KBytes
	C_i_rom_only: boolean := true;
	C_icache_size: integer := 8;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
	C_sram: boolean := true;
	C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
	C_pipelined_read: boolean := true; -- works only at 81.25 MHz !!!
	C_sio: boolean := true;
	C_leds_btns: boolean := true;
	C_gpio: boolean := true;
	C_flash: boolean := true;
	C_sdcard: boolean := true;
	C_framebuffer: boolean := false;
	C_pcm: boolean := true;
	C_timer: boolean := true;
	C_tx433: boolean := false; -- set (C_framebuffer := false, C_dds := false) for 433MHz transmitter
	C_fmrds: boolean := true; -- either FM or tx433
	C_fm_stereo: boolean := false;
	C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
        C_fmdds_hz: integer := 325000000; -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        --C_rds_clock_multiply: integer := 57; -- multiply and divide from cpu clk 100 MHz
        --C_rds_clock_divide: integer := 3125; -- to get 1.824 MHz for RDS logic
        C_rds_clock_multiply: integer := 912; -- multiply and divide from cpu clk 81.25 MHz
        C_rds_clock_divide: integer := 40625; -- to get 1.824 MHz for RDS logic
        C_pid: boolean := true;
        C_pids: integer := 4;
        C_pid_simulator: std_logic_vector(7 downto 0) := ext("1000", 8); -- for each pid choose simulator/real 
	C_dds: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_so: in std_logic;
	flash_cen, flash_sck, flash_si: out std_logic;
	sdcard_so: in std_logic;
	sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
	p_ring: out std_logic;
	p_tip: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	j1_2, j1_3, j1_4, j1_8, j1_9, j1_13, j1_14, j1_15: inout std_logic;
	j1_16, j1_17, j1_18, j1_19, j1_20, j1_21, j1_22, j1_23: inout std_logic;
	j2_2, j2_3, j2_4, j2_5, j2_6, j2_7, j2_8, j2_9: inout std_logic;
	j2_10, j2_11, j2_12, j2_13, j2_16: inout std_logic;
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
	-- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
    );
end toplevel;

architecture Behavioral of toplevel is
  signal btn: std_logic_vector(4 downto 0);
begin
  btn <= btn_left & btn_right & btn_up & btn_down & btn_center;
  inst_glue_sram: entity work.glue_sram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_mult_enable => C_mult_enable,
	C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend,
	C_ll_sc => C_ll_sc,
	C_PC_mask => C_PC_mask,
	C_exceptions => C_exceptions,
	C_cop0_count => C_cop0_count,
	C_cop0_compare => C_cop0_compare,
	C_cop0_config => C_cop0_config,
	C_branch_prediction => C_branch_prediction,
	C_full_shifter => C_full_shifter,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_register_technology => C_register_technology,
	C_movn_movz => C_movn_movz,
	C_debug => C_debug,
	C_cpus => C_cpus,
	C_bram_size => C_bram_size,
	C_i_rom_only => C_i_rom_only,
	C_icache_size => C_icache_size,	-- 0, 2, 4 or 8 KBytes
	C_dcache_size => C_dcache_size,	-- 0, 2, 4 or 8 KBytes
	C_sram => C_sram,
	C_sram_wait_cycles => C_sram_wait_cycles, -- ISSI, OK do 87.5 MHz
	C_pipelined_read => C_pipelined_read, -- works only at 81.25 MHz !!!
	C_sio => C_sio,
	C_simple_io => C_leds_btns,
	C_gpio => C_gpio,
	C_flash => C_flash,
	C_sdcard => C_sdcard,
	C_framebuffer => C_framebuffer,
	C_pcm => C_pcm,
	C_timer => C_timer,
	C_tx433 => C_tx433, -- set (C_framebuffer => false, C_dds => false) for 433MHz transmitter
	C_fmrds => C_fmrds, -- either FM or tx433
	C_fm_stereo => C_fm_stereo,
	C_rds_msg_len => C_rds_msg_len, -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
        C_fmdds_hz => C_fmdds_hz, -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        C_rds_clock_multiply => C_rds_clock_multiply, -- multiply and divide from cpu clk 81.25 MHz
        C_rds_clock_divide => C_rds_clock_divide, -- to get 1.824 MHz for RDS logic
        C_pid => C_pid,
        C_pids => C_pids,
        C_pid_simulator => C_pid_simulator, -- for each pid choose simulator/real 
	C_dds => C_dds
    )
    port map (
	clk_25m => clk_25m,
	rs232_tx => rs232_tx,
	rs232_rx => rs232_rx,
	flash_so => flash_so,
	flash_cen => flash_cen,
	flash_sck => flash_sck,
	flash_si => flash_si,
	sdcard_so => sdcard_so,
	sdcard_cen => sdcard_cen,
	sdcard_sck => sdcard_sck,
	sdcard_si => sdcard_si,
	p_ring => p_ring,
	p_tip => p_tip,
	simple_out(7 downto 0) => led,
	simple_in(4 downto 0) => btn,
	simple_in(19 downto 16) => sw,
        gpio(0)  => j1_2,  gpio(1)  => j1_3,  gpio(2)  => j1_4,   gpio(3)  => j1_8,
	gpio(4)  => j1_9,  gpio(5)  => j1_4,  gpio(6)  => j1_14,  gpio(7)  => j1_15,
	gpio(8)  => j1_16, gpio(9)  => j1_17, gpio(10) => j1_18,  gpio(11) => j1_19,
	gpio(12) => j1_20, gpio(13) => j1_21, gpio(14) => j1_22,  gpio(15) => j1_23,
	--  gpio(27 downto 16) multifunciton: PID
	--  encoder_in_a       encoder_in_b       bridge_f_out        bridge_r_out
	gpio(16) => j2_2,  gpio(17) => j2_3,  gpio(18) => j2_4,   gpio(19) => j2_5,  -- PID0
	gpio(20) => j2_6,  gpio(21) => j2_7,  gpio(22) => j2_8,   gpio(23) => j2_9,  -- PID1 
	gpio(24) => j2_10, gpio(25) => j2_11, gpio(26) => j2_12,  gpio(27) => j2_13, -- PID2
	--  gpio(28) multifunction: antenna
	gpio(28) => j2_16, -- output 87-108MHz or 433MHz
	sram_a => sram_a, sram_d => sram_d,
	sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	sram_wel => sram_wel
    );
    
end Behavioral;
