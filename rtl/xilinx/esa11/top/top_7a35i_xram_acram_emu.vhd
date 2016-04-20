--
-- Copyright (c) 2015 Emard
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

-- minimalistic demo to test acram.vhd integrated
-- arbiter with ram emulation acram_emu.vhd

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
	C_debug: boolean := false;

	-- Main clock: 81/100 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 16;

        -- axi cache ram
	C_acram: boolean := true;

        C_icache_expire: boolean := false; -- false: normal i-cache, true: passthru buggy i-cache
        -- warning: 2K, 16K, 32K cache produces timing critical warnings at 100MHz cpu clock
        -- no errors for 4K or 8K
        C_icache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_dcache_size: integer := 8; -- 0, 2, 4, 8, 16, 32 KBytes
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

        C3_NUM_DQ_PINS        : integer := 16;
        C3_MEM_ADDR_WIDTH     : integer := 14;
        C3_MEM_BANKADDR_WIDTH : integer := 3;

	C_sio: integer := 1;   -- 1 UART channel
	C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
	C_gpio: integer := 32; -- 32 GPIO bits
        C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
    );
    port (
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic;
	FPGA_SD_SCLK, FPGA_SD_CMD, FPGA_SD_D3: out std_logic;
	FPGA_SD_D0: in std_logic;
        -- DDR3 ------------------------------------------------------------------
        DDR_DQ                  : inout  std_logic_vector(C3_NUM_DQ_PINS-1 downto 0);       -- mcb3_dram_dq
        DDR_A                   : out    std_logic_vector(C3_MEM_ADDR_WIDTH-1 downto 0);    -- mcb3_dram_a
        DDR_BA                  : out    std_logic_vector(C3_MEM_BANKADDR_WIDTH-1 downto 0);-- mcb3_dram_ba
        DDR_RAS_N               : out    std_logic;                                         -- mcb3_dram_ras_n
        DDR_CAS_N               : out    std_logic;                                         -- mcb3_dram_cas_n
        DDR_WE_N                : out    std_logic;                                         -- mcb3_dram_we_n
        DDR_ODT                 : out    std_logic;                                         -- mcb3_dram_odt
        DDR_CKE                 : out    std_logic;                                         -- mcb3_dram_cke
        DDR_LDM                 : out    std_logic;                                         -- mcb3_dram_dm
        DDR_DQS_P               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs
        DDR_DQS_N               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs_n
        DDR_UDM                 : out    std_logic;                                         -- mcb3_dram_udm
        DDR_CK_P                : out    std_logic;                                         -- mcb3_dram_ck
        DDR_CK_N                : out    std_logic;                                         -- mcb3_dram_ck_n
        DDR_RESET_N             : out    std_logic;
      
	M_EXPMOD0, M_EXPMOD1, M_EXPMOD2, M_EXPMOD3: inout std_logic_vector(7 downto 0); -- EXPMODs
	M_7SEG_A, M_7SEG_B, M_7SEG_C, M_7SEG_D, M_7SEG_E, M_7SEG_F, M_7SEG_G, M_7SEG_DP: out std_logic;
	M_7SEG_DIGIT: out std_logic_vector(3 downto 0);
--	seg: out std_logic_vector(7 downto 0); -- 7-segment display
--	an: out std_logic_vector(3 downto 0); -- 7-segment display
	M_LED: out std_logic_vector(7 downto 0);
	-- PS/2 keyboard
	PS2_A_DATA, PS2_A_CLK, PS2_B_DATA, PS2_B_CLK: inout std_logic;
        -- HDMI
	--VID_D_P, VID_D_N: out std_logic_vector(2 downto 0);
	--VID_CLK_P, VID_CLK_N: out std_logic;
        -- VGA
        VGA_RED, VGA_GREEN, VGA_BLUE: out std_logic_vector(7 downto 0);
        VGA_SYNC_N, VGA_BLANK_N, VGA_CLOCK_P: out std_logic;
        VGA_HSYNC, VGA_VSYNC: out std_logic;
	M_BTN: in std_logic_vector(4 downto 0);
	M_HEX: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_100MHz, clk_200MHz, clk_250MHz: std_logic;

    component clk_d100_100_200_250_25MHz is
    Port (
      clk_100mhz_in_p : in STD_LOGIC;
      clk_100mhz_in_n : in STD_LOGIC;
      clk_100mhz : out STD_LOGIC;
      clk_200mhz : out STD_LOGIC;
      clk_250mhz : out STD_LOGIC;
      clk_25mhz : out STD_LOGIC;
      reset : in STD_LOGIC;
      locked : out STD_LOGIC
    );
    end component clk_d100_100_200_250_25MHz;

    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0);
    signal ram_address        : std_logic_vector(29 downto 2);
    signal ram_data_write     : std_logic_vector(31 downto 0);
    signal ram_data_read      : std_logic_vector(31 downto 0);
    signal ram_read_busy      : std_logic;
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);
   
    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal disp_7seg_segment: std_logic_vector(7 downto 0);
begin
    cpu100MHz: if C_clk_freq = 100 generate
    clk100in_out100_200_250_25: clk_d100_100_200_250_25MHz
    port map(clk_100mhz_in_p => i_100MHz_P,
             clk_100mhz_in_n => i_100MHz_N,
             reset => '0',
             clk_100mhz => clk,
             clk_200mhz => clk_200MHz,
             clk_250mhz => clk_250MHz,
             clk_25mhz  => clk_25MHz
    );
    end generate;

    -- reset hard-block: Xilinx Artix-7 specific
    reset: startupe2
    generic map (
      prog_usr => "FALSE"
    )
    port map (
      clk => clk,
      gsr => sio_break,
      gts => '0',
      keyclearb => '0',
      pack => '1',
      usrcclko => clk,
      usrcclkts => '0',
      usrdoneo => '1',
      usrdonets => '0'
    );

    -- generic BRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_acram => C_acram,
      C_icache_expire => C_icache_expire,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_gpio => C_gpio,
      C_sio => C_sio,
      C_spi => C_spi,
      C_debug => C_debug
    )
    port map (
        clk => clk,
	acram_en => ram_en,
	acram_addr => ram_address,
	acram_byte_we => ram_byte_we,
	acram_data_rd => ram_data_read,
	acram_data_wr => ram_data_write,
	acram_read_busy => ram_read_busy,
        --spi_sck(0)  => open,  spi_sck(1)  => FPGA_SD_SCLK,
        --spi_ss(0)   => open,  spi_ss(1)   => FPGA_SD_D3,
        --spi_mosi(0) => open,  spi_mosi(1) => FPGA_SD_CMD,
        --spi_miso(0) => '-',   spi_miso(1) => FPGA_SD_D0,
	--gpio(7 downto 0) => M_EXPMOD0, gpio(15 downto 8) => M_EXPMOD1,
	--gpio(23 downto 16) => M_EXPMOD2, gpio(31 downto 24) => M_EXPMOD3,
	--gpio(127 downto 32) => open,
	sio_txd(0) => UART1_TXD,
	sio_rxd(0) => UART1_RXD,
	sio_break(0) => sio_break,
	-- simple I/O
	simple_out(7 downto 0) => M_LED, simple_out(15 downto 8) => disp_7seg_segment,
	simple_out(19 downto 16) => M_7SEG_DIGIT, simple_out(31 downto 20) => open,
	simple_in(4 downto 0) => M_BTN,
        simple_in(8 downto 5) => M_HEX,
        simple_in(31 downto 9) => (others => '-')
    );

    m_7seg_a  <= disp_7seg_segment(0);
    m_7seg_b  <= disp_7seg_segment(1);
    m_7seg_c  <= disp_7seg_segment(2);
    m_7seg_d  <= disp_7seg_segment(3);
    m_7seg_e  <= disp_7seg_segment(4);
    m_7seg_f  <= disp_7seg_segment(5);
    m_7seg_g  <= disp_7seg_segment(6);
    m_7seg_dp <= disp_7seg_segment(7);

    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 12
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(13 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_en => ram_en
    );
    --ram_data_read <= x"01234567"; -- debug purpose

end Behavioral;
