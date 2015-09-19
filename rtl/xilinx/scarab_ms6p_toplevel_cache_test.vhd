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

	-- Main clock: 81/100/125 MHz
	-- vivado at 81MHz: screen flickers, fetch 1 byte late?
	-- ise at 81MHz: no flicker
	-- at 100MHz both ISE and Vivado don't flicker 
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 16;
	C_i_rom_only: boolean := false;
	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32;
	C_simple_io: boolean := true
    );
    port (
	clk_50MHz: in std_logic;
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
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_cs, flash_cclk, flash_mosi: out std_logic;
	flash_miso: in std_logic;
	sd_clk, sd_cd_dat3, sd_cmd: out std_logic;
	sd_dat0: in std_logic;
	leds: out std_logic_vector(7 downto 0);
	porta, portb: inout std_logic_vector(11 downto 0);
	portc: inout std_logic_vector(7 downto 0);
	TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
	TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
	sw: in std_logic_vector(4 downto 1)
    );
end glue;

architecture Behavioral of glue is
    signal clk, clk_250MHz, clk_25MHz: std_logic;
    signal rs232_break: std_logic;
    signal tmds_out_rgb: std_logic_vector(2 downto 0);
    signal sram_a: std_logic_vector(18 downto 0);
    signal sram_d: std_logic_vector(15 downto 0);
    signal sram_wel, sram_lbl, sram_ubl: std_logic;

    -- SRAM emulation
    signal sram_we_lower, sram_we_upper: std_logic;
    signal from_sram_lower, from_sram_upper: std_logic_vector(7 downto 0);
begin
    -- clock synthesizer: Xilinx Spartan-6 specific
    
    clk112: if C_clk_freq = 112 generate
    clkgen112: entity work.pll_50M_112M5
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
    end generate;

    clk100: if C_clk_freq = 100 generate
    clkgen100: entity work.pll_50M_100M_25M_250M
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz
    );
    end generate;

    clk81: if C_clk_freq = 81 generate
    clkgen81: entity work.pll_50M_81M25
    port map(
      clk_in1 => clk_50MHz, clk_out1 => clk
    );
    end generate;

    clk50: if C_clk_freq = 50 generate
      clk <= clk_50MHz;
    end generate;

    -- reset hard-block: Xilinx Spartan-6 specific
    reset: startup_spartan6
    port map (
	clk => clk, gsr => rs232_break, gts => rs232_break,
	keyclearb => '0'
    );

    -- generic BRAM glue
    glue_bram: entity work.glue_sram
    generic map (
	C_clk_freq => C_clk_freq,
	C_arch => C_arch,
	C_bram_size => C_bram_size,
	--C_spi => C_spi,
	--C_pid => false,
	C_i_rom_only => C_i_rom_only
    )
    port map (
	clk => clk,
	sio_tx => rs232_tx, sio_rx => rs232_rx,
	sio_break => rs232_break,
--	spi_sck(0)  => open,  spi_sck(1)  => open,
--	spi_ss(0)   => open,  spi_ss(1)   => open
--	spi_mosi(0) => open,  spi_mosi(1) => open,
--	spi_miso(0) => '-',   spi_miso(1) => '-',
--	gpio(3 downto 0) => ja_u(3 downto 0),
--	gpio(7 downto 4) => ja_d(3 downto 0),
--	gpio(11 downto 8) => jb_u(3 downto 0),
--	gpio(15 downto 12) => jb_d(3 downto 0),
--	gpio(19 downto 16) => jc_u(3 downto 0),
--	gpio(23 downto 20) => jc_d(3 downto 0),
--	gpio(27 downto 24) => jd_u(3 downto 0),
--	gpio(31 downto 28) => jd_d(3 downto 0),
--	gpio(127 downto 32) => open,
	simple_out(7 downto 0) => leds(7 downto 0),
	simple_out(31 downto 8) => open,
	simple_in(15 downto 0) => open,
	simple_in(19 downto 16) => sw(4 downto 1),
	simple_in(31 downto 20) => open,
	sram_a => sram_a, sram_d => sram_d, sram_wel => sram_wel,
	sram_lbl => sram_lbl, sram_ubl => sram_ubl
    );

    -- differential output buffering for HDMI clock and video
    hdmi_output: entity work.hdmi_out
      port map (
        tmds_in_clk => clk_25MHz,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb => tmds_out_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );

    sram_emul_lower: entity work.bram_true2p_1clk
    generic map (
        dual_port => false,
        data_width => 8,
        addr_width => 12
    )
    port map (
        clk => not clk,
        we_a => sram_we_lower,
        addr_a => sram_a(11 downto 0),
        data_in_a => sram_d(7 downto 0), data_out_a => from_sram_lower,
	we_b => '0', addr_b => (others => '0'),
        data_in_b => (others => '0'), data_out_b => open
    );

    sram_emul_upper: entity work.bram_true2p_1clk
    generic map (
        dual_port => false,
        data_width => 8,
        addr_width => 12
    )
    port map (
        clk => not clk,
        we_a => sram_we_upper,
        addr_a => sram_a(11 downto 0),
        data_in_a => sram_d(15 downto 8), data_out_a => from_sram_upper,
	we_b => '0', addr_b => (others => '0'),
        data_in_b => (others => '0'), data_out_b => open
    );

    sram_d(7 downto 0) <= from_sram_lower when sram_wel = '1'
      else (others => 'Z');
    sram_d(15 downto 8) <= from_sram_upper when sram_wel = '1'
      else (others => 'Z');
    sram_we_lower <= not (sram_wel or sram_lbl);
    sram_we_upper <= not (sram_wel or sram_ubl);

    sdram_clk <= '0';
    sdram_cke <= '0';
    sdram_csn <= '1';
    sdram_rasn <= '1';
    sdram_casn <= '1';
    sdram_wen  <= '1';
    sdram_a    <= (others => '0');
    sdram_ba   <= (others => '0');
    sdram_dqm  <= (others => '0');
    sdram_d    <= (others => 'Z');

    flash_cs   <= '0';
    flash_cclk <= '0';
    flash_mosi <= '0';
    -- flash_miso <= open;
    sd_clk     <= '0';
    sd_cd_dat3 <= '0';
    sd_cmd     <= '0';
    -- sd_dat0 <= open;

end Behavioral;
