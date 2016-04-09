---- Copyright (c) 2016 Emard
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

-- this is new and potentially buggy
-- variant of standard ULX2S SRAM
-- with most features
--
-- MIPS CPU 81.25 MHz
-- 1MB SDRAM
-- TV framebuffer (tip of 3.5 mm jack)
-- PCM audio (ring of 3.5 mm jack)
-- 2 SPI ports (flash and SD card)
-- FM/RDS transmitter 87-108 MHz
-- PID controller (3 HW channels + 1 SW simulation)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.numeric_std.all; -- we need signed type
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;
-- use work.sram_pack.all;

-- vendor specific libs (lattice)
library xp2;
use xp2.components.all;

-- this is new and potentially buggy
-- variant of feature-rich ULX2S SRAM
--
-- 1MB SRAM
-- TV framebuffer
-- 16 GPIO with interrupts
-- 1 timer (2xPWM, 2xICP)
-- 1 channel PCM audio out
-- 2 SPI ports (flash and SD card)
-- PCM audio with DMA
-- FM RDS transmitter 87-108MHz (FM plays PCM audio)
-- 4 PID controllers (3 hardware, 1 simulation)
-- 8 LEDs, 5 buttons, 4 switches

entity top is
  generic (
    -- Main clock: 25, 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
    C_clk_freq: integer := 12;

    -- ISA options
    C_arch: integer := ARCH_MI32;
    C_big_endian: boolean := false;

    C_mult_enable: boolean := false;
    C_branch_likely: boolean := true;
    C_sign_extend: boolean := true;
    C_ll_sc: boolean := false;
    C_PC_mask: std_logic_vector(31 downto 0) := x"00001fff"; -- 8K BRAM limit

    -- COP0 options
    C_exceptions: boolean := true;
    C_cop0_count: boolean := true;
    C_cop0_compare: boolean := true;
    C_cop0_config: boolean := true;

    -- CPU core configuration options
    C_branch_prediction: boolean := false;
    C_full_shifter: boolean := false;
    C_result_forwarding: boolean := false;
    C_load_aligner: boolean := false;

    -- This may negatively influence timing closure:
    C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

    -- Debugging / testing options (should be turned off)
    C_debug: boolean := false;

    -- SoC configuration options
    C_bram_size: integer := 4;	-- KBytes
      C_i_rom_only: boolean := true;

    C_sio: integer := 1; -- number of rs232 serial ports
    C_simple_out: integer := 32; -- LEDs (only 8 used but quantized to 32)
    C_simple_in: integer := 32; -- buttons and switches (not all used)
    C_gpio: integer := 0; -- number of GPIO pins
    C_spi: integer := 1; -- number of SPI interfaces
    C_timer: boolean := false
  );
  port (
    CLK_12MHZ: in std_logic;
    RS232_TX: out std_logic;
    RS232_RX: in std_logic;
    --flash_so: in std_logic;
    --flash_cen, flash_sck, flash_si: out std_logic;
    --sdcard_so: in std_logic;
    --sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
    --p_ring: out std_logic;
    --p_tip: out std_logic_vector(3 downto 0);
    LED: out std_logic_vector(3 downto 1)
    --btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
    --sw: in std_logic_vector(3 downto 0);
    --j1_2, j1_3, j1_4, j1_8, j1_9, j1_13, j1_14, j1_15: inout std_logic;
    --j1_16, j1_17, j1_18, j1_19, j1_20, j1_21, j1_22, j1_23: inout std_logic;
    --j2_2, j2_3, j2_4, j2_5, j2_6, j2_7, j2_8, j2_9: inout std_logic;
    --j2_10, j2_11, j2_12, j2_13, j2_16: inout std_logic;
    --sram_a: out std_logic_vector(18 downto 0);
    --sram_d: inout std_logic_vector(15 downto 0);
    --sram_wel, sram_lbl, sram_ubl: out std_logic
    -- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
  );
end top;

architecture Behavioral of top is
  constant C_pipelined_read: boolean := C_clk_freq = 81; -- works only at 81.25 MHz !!!
  signal clk: std_logic;
  signal rs232_break: std_logic;
  signal counter: std_logic_vector(23 downto 0);
  -- signal btn: std_logic_vector(2 downto 1);
begin
  clk <= clk_12MHz;

    glue_bram: entity work.glue_bram
    generic map (
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
      C_movn_movz => C_movn_movz,

	C_clk_freq => C_clk_freq,
	C_mem_size => C_bram_size,
	C_gpio => C_gpio,
	C_sio => C_sio,
	C_spi => C_spi,
	C_timer => C_timer,
	C_debug => C_debug
    )
    port map (
	clk => clk,
	sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
	sio_break(0) => rs232_break,
	--
	spi_sck(0)  => open, -- spi_sck(1)  => open,
	spi_ss(0)   => open, -- spi_ss(1)   => open,
	spi_mosi(0) => open, -- spi_mosi(1) => open,
	spi_miso(0) => '-',  -- spi_miso(1) => '-',
	--gpio(31 downto 0) => gpio(31 downto 0),
	--gpio(127 downto 32) => open,
	--simple_out(2 downto 0) => led(3 downto 1),
        simple_out(1 downto 0) => led(2 downto 1),
	simple_out(31 downto 3) => open,
	--simple_in(0) => btn_k2,
	--simple_in(1) => btn_k3,
	simple_in(31 downto 0) => open
    );
    
    process(clk)
    begin
      if rising_edge(clk) then
        counter <= counter+1;
      end if;
    end process;
    led(3) <= counter(23);
    --led(3 downto 1) <= counter(23 downto 21);
  
end Behavioral;
