library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
library ecp5u;
use ecp5u.components.all;


entity top_sdram is
    generic (
	C_arch: natural := ARCH_MI32;
	C_clk_freq: natural := 84; -- 25, 74, 84, 93, 112, 124, 135
	C_sio_init_baudrate: integer := 115200;
	C_icache_size: natural := 8;
	C_dcache_size: natural := 8;
	C_mult_enable: boolean := true;
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
	C_cpus: natural := 1
    );
    port (
	clk_25m: in std_logic;

	-- SDRAM
	sdram_clk: out std_logic;
	sdram_cke: out std_logic;
	sdram_csn: out std_logic;
	sdram_rasn: out std_logic;
	sdram_casn: out std_logic;
	sdram_wen: out std_logic;
	sdram_a: out std_logic_vector (12 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_d: inout std_logic_vector (15 downto 0);

	-- On-board simple IO
	led: out std_logic_vector(7 downto 0);
	btn_pwr, btn_f1, btn_f2: in std_logic;
	btn_up, btn_down, btn_left, btn_right: in std_logic;
	sw: in std_logic_vector(3 downto 0);

	-- GPIO
	gp: inout std_logic_vector(27 downto 0);
	gn: inout std_logic_vector(27 downto 0);

	-- Audio jack 3.5mm
	p_tip: inout std_logic_vector(3 downto 0);
	p_ring: inout std_logic_vector(3 downto 0);
	p_ring2: inout std_logic_vector(3 downto 0);

	-- SIO0 (FTDI)
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;

	-- Digital Video (differential outputs)
	gpdi_dp, gpdi_dn: out std_logic_vector(3 downto 0);

	-- i2c shared for digital video and RTC
	gpdi_scl, gpdi_sda: inout std_logic;

	-- SPI flash (SPI #0)
	flash_so: in std_logic;
	flash_si: out std_logic;
	flash_cen: out std_logic;
	--flash_sck: out std_logic; -- accessed via special ECP5 primitive
	flash_holdn, flash_wpn: out std_logic := '1';

	-- SD card (SPI #1)
	sd_cmd: inout std_logic;
	sd_clk: out std_logic;
	sd_d: inout std_logic_vector(3 downto 0);
	sd_cdn: in std_logic;
	sd_wp: in std_logic;

	-- ADC MAX11123 (SPI #2)
	adc_csn: out std_logic;
	adc_sclk: out std_logic;
	adc_mosi: out std_logic;
	adc_miso: in std_logic;

	-- PCB antenna
	ant: out std_logic;

	-- '1' = power off
	shutdown: out std_logic := '0'
    );
end top_sdram;

architecture x of top_sdram is
    signal clk, pll_lock: std_logic;
    signal clk_135m, clk_123m75, clk_112m5: std_logic;
    signal clk_92m8125, clk_84m375, clk_74m25: std_logic;
    signal reset: std_logic;
    signal sio_break: std_logic;
    signal flash_sck: std_logic;
    signal flash_csn: std_logic;

    signal R_simple_in: std_logic_vector(19 downto 0);

begin
    -- f32c SoC
    I_top: entity work.glue_sdram_min
    generic map (
	C_arch => C_arch,
	C_clk_freq => C_clk_freq,
	C_cpus => C_cpus,
	C_icache_size => C_icache_size,
	C_dcache_size => C_dcache_size,
	C_mult_enable => C_mult_enable,
	C_branch_prediction => C_branch_prediction,
	C_full_shifter => C_full_shifter,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_spi => 3,
	C_simple_out => 8,
	C_simple_in => 20,
	C_sio_init_baudrate => C_sio_init_baudrate,
	C_debug => false
    )
    port map (
	clk => clk,
	reset => reset,
	sdram_clk => open,
	sdram_cke => sdram_cke,
	sdram_cs => sdram_csn,
	sdram_we => sdram_wen,
	sdram_ba => sdram_ba,
	sdram_dqm => sdram_dqm,
	sdram_ras => sdram_rasn,
	sdram_cas => sdram_casn,
	sdram_addr => sdram_a,
	sdram_data => sdram_d,
	sio_rxd(0) => rs232_rx,
	sio_txd(0) => rs232_tx,
	sio_break(0) => sio_break,
	simple_in => R_simple_in,
	simple_out => led,
	spi_ss(0) => flash_csn,
	spi_ss(1) => sd_d(3),
	spi_ss(2) => adc_csn,
	spi_sck(0) => flash_sck,
	spi_sck(1) => sd_clk,
	spi_sck(2) => adc_sclk,
	spi_mosi(0) => flash_si,
	spi_mosi(1) => sd_cmd,
	spi_mosi(2) => adc_mosi,
	spi_miso(0) => flash_so,
	spi_miso(1) => sd_d(0),
	spi_miso(2) => adc_miso
    );
    R_simple_in <= sw & x"00" & '0' & not btn_pwr & btn_f2 & btn_f1
      & btn_up & btn_down & btn_left & btn_right when rising_edge(clk);

    -- Route SDRAM clock through a DDR register for precise signal timings
    I_sdram_clk: ODDRX1F
    port map (sclk => clk, rst => '0', d0 => '0', d1 => '1', Q => sdram_clk);

    -- SPI flash clock has to be routed through a ECP5-specific primitive
    I_flash_mux: USRMCLK
    port map (
	USRMCLKTS => flash_csn,
	USRMCLKI => flash_sck
    );
    flash_cen <= flash_csn;

    I_pll: entity work.pll_25m
    port map (
	clk_25m => clk_25m,
	clk_371m25 => open, clk_168m75 => open, clk_135m => clk_135m,
	clk_123m75 => clk_123m75, clk_112m5 => clk_112m5,
	clk_92m8125 => clk_92m8125, clk_84m375 => clk_84m375,
	clk_74m25 => clk_74m25, lock => pll_lock
    );

    clk <= clk_135m when C_clk_freq = 135
      else clk_123m75 when C_clk_freq = 124
      else clk_112m5 when C_clk_freq = 112
      else clk_92m8125 when C_clk_freq = 93
      else clk_84m375 when C_clk_freq = 84
      else clk_74m25 when C_clk_freq = 74
      else clk_25m when C_clk_freq = 25
      else '0';
    reset <= not pll_lock or sio_break;
end x;
