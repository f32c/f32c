library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
library ecp5u;
use ecp5u.components.all;


entity top_sdram is
    generic (
	C_arch: natural := ARCH_MI32;
	C_clk_freq: natural := 90; -- 25, 74, 90, 93, 112, 124
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
	sdram_a: out std_logic_vector(12 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_d: inout std_logic_vector(15 downto 0);

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
	rs232_rts: in std_logic;
	rs232_dtr: in std_logic;

	-- Digital Video (differential outputs)
	gpdi_dp: out std_logic_vector(3 downto 0);

	-- i2c shared for digital video and RTC
	gpdi_scl, gpdi_sda: inout std_logic;

	-- SPI flash (SPI #0)
	--flash_sck: out std_logic; -- accessed via ECP5-specifc primitive
	flash_cen: out std_logic;
	flash_so: inout std_logic;
	flash_si: inout std_logic;
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
	adc_mosi: inout std_logic;
	adc_miso: inout std_logic;

	-- ESP32
	esp32_rxd: out std_logic;
	esp32_txd: in std_logic;
	esp32_en: inout std_logic := 'Z';
	esp32_gpio0: inout std_logic := 'Z';
	esp32_gpio19: inout std_logic := 'Z';
	esp32_gpio21: inout std_logic := 'Z';
	esp32_gpio22: inout std_logic := 'Z';
	esp32_gpio25: inout std_logic := 'Z';
	esp32_gpio26: inout std_logic := 'Z';
	esp32_gpio27: inout std_logic := 'Z';
	esp32_gpio35: inout std_logic := 'Z';

	-- PCB antenna
	ant: out std_logic;

	-- '1' = power off
	shutdown: out std_logic := '0'
    );
end top_sdram;

architecture x of top_sdram is
    signal clk: std_logic;
    signal clk_123m75, clk_112m5: std_logic;
    signal clk_92m8125, clk_90m, clk_74m25: std_logic;
    signal reset, pll_lock: std_logic;
    signal f32c_rxd, f32c_txd, sio_break: std_logic;
    signal sio_sel: std_logic_vector(3 downto 0);
    signal flash_sck: std_logic;
    signal flash_csn: std_logic;

    signal R_simple_in: std_logic_vector(19 downto 0);

    constant C_esp32_cnt_max: natural := C_clk_freq * 1000 * 10; -- 10 ms
    signal R_esp32_cnt: natural range 0 to C_esp32_cnt_max := C_esp32_cnt_max;
    signal R_rts, R_dtr: std_logic;
    signal R_esp32_pwrup_wait: boolean := true;
    signal R_esp32_en, R_esp32_gpio0: boolean;
    signal cons_f32c: boolean;
    signal cons_esp32: boolean;

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
	sio_rxd(0) => f32c_rxd,
	sio_txd(0) => f32c_txd,
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
	clk_123m75 => clk_123m75, clk_112m5 => clk_112m5,
	clk_92m8125 => clk_92m8125, clk_90m => clk_90m,
	clk_74m25 => clk_74m25, lock => pll_lock
    );

    clk <= clk_123m75 when C_clk_freq = 124
      else clk_112m5 when C_clk_freq = 112
      else clk_92m8125 when C_clk_freq = 93
      else clk_90m when C_clk_freq = 90
      else clk_74m25 when C_clk_freq = 74
      else clk_25m when C_clk_freq = 25
      else '0';
    reset <= not pll_lock or sio_break;

    I_sbrk_cnt: entity work.sbrk_cnt
    generic map (
	C_clk_freq_hz => C_clk_freq * 1000000
    )
    port map (
	clk => clk,
	rxd => rs232_rx,
	sel => sio_sel
    );
    cons_esp32 <= sio_sel = x"0";
    cons_f32c <= sio_sel = x"1";

    -- SIO -> f32c
    f32c_rxd <= rs232_rx when cons_f32c else '1';

    -- SIO -> ESP32
    esp32_rxd <= rs232_rx when cons_esp32 else '1';

    -- ESP32, f32c -> SIO
    rs232_tx <= esp32_txd when cons_esp32 else f32c_txd when cons_f32c else '1';

    --
    -- ESP32 reset logic.  We emulate the following hardware circuit:
    -- DTR 1, RTS 0: pull down EN, a small capacitor holds it low for a while
    -- DTR 0, RTS 1: pull down IO0
    --
    -- At powerup we MUST generate a reset pulse, otherwise ESP32 won't
    -- boot reliably (occasionally gets stuck in bootloader), because
    -- ULX3S doesn't have a built-in capacitor between EN pin and GND.
    --
    process(clk)
    begin
    if rising_edge(clk) then
	R_rts <= rs232_rts;
	R_dtr <= rs232_dtr;
	if R_esp32_pwrup_wait then
	    if R_esp32_cnt = 0 then
		R_esp32_pwrup_wait <= false;
		R_esp32_en <= false;
	    else
		R_esp32_cnt <= R_esp32_cnt - 1;
		R_esp32_en <= true;
	    end if;
	elsif cons_esp32 and R_rts = '0' and R_dtr = '1' then
	    R_esp32_en <= true;
	    R_esp32_gpio0 <= true;
	    R_esp32_cnt <= C_esp32_cnt_max;
	elsif R_esp32_cnt = 0 then
	    R_esp32_gpio0 <= false;
	else
	    R_esp32_cnt <= R_esp32_cnt - 1;
	    if R_esp32_cnt = C_esp32_cnt_max / 2 then
		R_esp32_en <= false;
	    end if;
	end if;
    end if;
    end process;

    esp32_en <= '0' when R_esp32_en else 'Z';
    esp32_gpio0 <= '1' when R_esp32_pwrup_wait
      else rs232_dtr when R_esp32_gpio0 else 'Z';
end x;
