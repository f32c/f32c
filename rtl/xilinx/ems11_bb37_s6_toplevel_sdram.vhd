--
-- Copyright (c) 2015 Emanuel Stiebler
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

		-- Main clock: 50/81/100/112
		C_clk_freq: integer := 100;

		-- SoC configuration options
		C_mem_size: integer := 64;
		C_sio: integer := 1;
		C_spi: integer := 2;
		C_gpio: integer := 32
    );
    port (
		i_50MHz: in std_logic;
      sdram_clk   : out std_logic;
      sdram_cke   : out std_logic;
      sdram_csn   : out std_logic;
      sdram_rasn  : out std_logic;
      sdram_casn  : out std_logic;
      sdram_wen   : out std_logic;
      sdram_a     : out std_logic_vector (12 downto 0);
      sdram_ba    : out std_logic_vector(1 downto 0);
      sdram_dqm   : out std_logic_vector(1 downto 0);
      sdram_d     : inout std_logic_vector (15 downto 0);
		
		UART1_TXD: out std_logic;
		UART1_RXD: in std_logic;
		FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
		FPGA_SD_D0: in std_logic;
		EXPMOD1, EXPMOD2, EXPMOD3, EXPMOD4: inout std_logic_vector(7 downto 0); -- EXPMODs
		seg: out std_logic_vector(7 downto 0); -- 7-segment display
		an: out std_logic_vector(3 downto 0); -- 7-segment display
		led: out std_logic_vector(7 downto 0);

		t1, t2, t3, t4: in std_logic;
		hex: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is

    signal clk, sdram_clk_internal: std_logic;
    signal sio_break: std_logic;
    signal btns: std_logic_vector(1 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
    port map(
      clk_in1 => i_50MHz, clk_out1 => clk
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M
    port map(
      clk_in1 => i_50MHz, clk_out1 => clk
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_50M_81M25
    port map(
      clk_in1 => i_50MHz, clk_out1 => clk
    );
    end generate;

    clk50: if C_clk_freq = 50 generate
      clk <= i_50MHz;
    end generate;

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => sio_break, gts => sio_break,
	keyclearb => '0'
    );

    -- generic SDRAM glue
    glue_sdram: entity work.glue_bram
    generic map (
		C_arch => C_arch,
		C_clk_freq => C_clk_freq,
		C_mem_size => C_mem_size,
		C_gpio => C_gpio,
		C_sio => C_sio,
		C_spi => C_spi,
		C_sdram_address_width => 24,
		C_sdram_column_bits => 9,
		C_sdram_startup_cycles => 10100,
		C_sdram_cycles_per_refresh => 1524,
		C_debug => C_debug
    )
    port map (
		clk => clk,
		-- external SDRAM interface
		sdram_addr => sdram_a, sdram_data => sdram_d,
		sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
		sdram_ras => sdram_rasn, sdram_cas => sdram_casn,
		sdram_cke => sdram_cke, sdram_clk => sdram_clk_internal,
		sdram_we => sdram_wen, sdram_cs => sdram_csn,	
		
		sio_txd(0) => UART1_TXD, 
		sio_rxd(0) => UART1_RXD,
		sio_break(0) => sio_break,
      spi_sck(0)  => open,  spi_sck(1)  => FPGA_SD_SCLK,
      spi_ss(0)   => open,  spi_ss(1)   => FPGA_SD_D3,
      spi_mosi(0) => open,  spi_mosi(1) => FPGA_SD_CMD,
      spi_miso(0) => '-',   spi_miso(1) => FPGA_SD_D0,
		gpio(7 downto 0) => EXPMOD1, gpio(15 downto 8) => EXPMOD2,
		gpio(23 downto 16) => EXPMOD3, gpio(31 downto 24) => EXPMOD4,
		gpio(127 downto 32) => open,
		simple_out(7 downto 0) => led, simple_out(15 downto 8) => seg, 
		simple_out(19 downto 16) => an, simple_out(31 downto 20) => open,
		simple_in(0) => t1,
		simple_in(1) => t2,
      simple_in(2) => t3,
      simple_in(3) => t4,
      simple_in(4) => '0',     -- will be center button one day,
      simple_in(8 downto 5) => hex,
      simple_in(31 downto 9) => (others => '-')
    );

    -- SDRAM clock output needs special routing on Spartan-6
    sdram_clk_forward : ODDR2
    generic map(
	DDR_ALIGNMENT => "NONE", INIT => '0', SRTYPE => "SYNC"
    )
    port map (
	Q => sdram_clk, C0 => clk, C1 => sdram_clk_internal, CE => '1',
	R => '0', S => '0', D0 => '0', D1 => '1'
    );
end Behavioral;
