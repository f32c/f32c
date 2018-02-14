-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

library ecp5u;
use ecp5u.components.all;

entity ulx3s_passthru_wifi is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
  clk_25MHz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndtr: inout  std_logic;
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en, wifi_gpio0, wifi_gpio2, wifi_gpio16, wifi_gpio17: inout  std_logic := 'Z'; -- '0' will disable wifi by default

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(1 to 4);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO (some are shared with wifi and adc)
  gp, gn: inout std_logic_vector(27 downto 0) := (others => 'Z');

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0';

  -- Audio jack 3.5mm
  audio_l, audio_r, audio_v: inout std_logic_vector(3 downto 0) := (others => 'Z');

  -- Digital Video (differential outputs)
  --gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  --gpdi_clkp, gpdi_clkn: out std_logic;

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_dat0_do: inout std_logic := 'Z'; -- wifi_gpio2
  sd_dat3_csn, sd_cmd_di: in std_logic; -- wifi_gpio13, wifi_gpio15
  sd_clk: in std_logic; -- wifi_gpio14
  sd_dat1_irq, sd_dat2: in std_logic; -- wifi_gpio4, wifi_gpio12
  sd_cdn, sd_wp: in std_logic 
  );
end;

architecture Behavioral of ulx3s_passthru_wifi is
  signal R_blinky: std_logic_vector(26 downto 0);
  signal S_prog_in, S_prog_out: std_logic_vector(1 downto 0);
  signal R_spi_miso: std_logic_vector(7 downto 0);
begin

  -- TX/RX passthru
  ftdi_rxd <= wifi_txd;
  wifi_rxd <= ftdi_txd;

  -- Programming logic
  -- SERIAL  ->  ESP32
  -- DTR RTS -> EN IO0
  --  1   1     1   1
  --  0   0     1   1
  --  1   0     0   1
  --  0   1     1   0
  S_prog_in(1) <= ftdi_ndtr;
  S_prog_in(0) <= ftdi_nrts;
  S_prog_out <= "01" when S_prog_in = "10" else
                "10" when S_prog_in = "01" else
                "11";
  wifi_en <= S_prog_out(1);
  wifi_gpio0 <= S_prog_out(0) and btn(0); -- holding BTN0 will hold gpio0 LOW, signal for ESP32 to take control
  --sd_dat0_do <= '0' when wifi_gpio0 = '0' else 'Z'; -- gpio2 together with gpio2 to 0  
  --sd_dat2 <= '0' when wifi_gpio0 = '0' else 'Z'; -- wifi gpio12
  sd_dat0_do <= '0' when (S_prog_in(0) xor S_prog_in(1)) = '1' else
                R_spi_miso(0) when oled_csn = '0' else -- SPI reading buttons with OLED CSn
                'Z'; -- gpio2 to 0 during programming init
  -- sd_dat2 <= '0' when (S_prog_in(0) xor S_prog_in(1)) = '1' else 'Z'; -- wifi gpio12
  -- permanent flashing mode
  -- wifi_en <= ftdi_nrts;
  -- wifi_gpio0 <= ftdi_ndtr;

  oled_csn <= wifi_gpio17;
  oled_clk <= sd_clk; -- wifi_gpio14
  oled_mosi <= sd_cmd_di; -- wifi_gpio15
  oled_dc <= wifi_gpio16;
  oled_resn <= gp(11); -- wifi_gpio25

  -- show OLED signals on the LEDs
  -- show SD signals on the LEDs
  -- led(5 downto 0) <= sd_clk & sd_dat2 & sd_dat3_csn & sd_cmd_di & sd_dat0_do & sd_dat1_irq;
  led(7 downto 0) <= oled_csn & R_spi_miso(0) & sd_clk & sd_dat2 & sd_dat3_csn & sd_cmd_di & sd_dat0_do & sd_dat1_irq;

  -- clock alive blinky
  process(clk_25MHz)
  begin
      if rising_edge(clk_25MHz) then
        R_blinky <= R_blinky+1;
      end if;
  end process;
  -- led(7) <= R_blinky(R_blinky'high);

  y_btn: if true generate
  process(sd_clk, wifi_gpio17) -- gpio17 is OLED CSn
  begin
    if wifi_gpio17 = '1' then
      R_spi_miso <= '0' & btn; -- sample button state during csn=1
    else
      if rising_edge(sd_clk) then
        R_spi_miso <= R_spi_miso(R_spi_miso'high-1 downto 0) & R_spi_miso(R_spi_miso'high) ; -- shift to the left
      end if;
    end if;
  end process;
  end generate;

end Behavioral;
