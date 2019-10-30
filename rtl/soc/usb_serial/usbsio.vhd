-- (C)2019 EMARD
-- LICENSE=BSD

-- f32c bus interface for usb-serial port

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity usbsio is
    generic (
	C_big_endian: boolean := false;
	C_bypass: boolean := false -- false: normal, true: serial loopback (debug)
    );
    port (
	ce, clk: in std_logic;
	reset: in std_logic; -- warning reset going to mixed clock domains
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	break: out std_logic; -- TODO: missing support in usb_serial
	-- USB interface
	usb_clk: in std_logic; -- 48 MHz or 60 MHz for USB PHY
	usb_diff_dp: in std_logic; -- differential input D+,D-
	usb_dp: inout std_logic; -- single-ended D+
	usb_dn: inout std_logic  -- single-ended D-
    );
end;

--
-- SIO -> CPU data word:
-- 31..11  unused
--     10  set if tx busy
--      9  reserved
--      8  set if R_rx_byte is unread, reset on read
--   7..0  R_rx_byte
--
-- CPU -> SIO data word:
-- 31..16  clock divisor (or unused)
--  15..8  unused
--   7..0  tx_byte
--
architecture Behavioral of usbsio is
    -- application-side USB-serial buffer size constants
    constant RXBUFSIZE_BITS : integer := 11; -- buffer = 2^RXBUFSIZE_BITS bytes
    constant TXBUFSIZE_BITS : integer := 10; -- buffer = 2^TXBUFSIZE_BITS bytes

    -- application-side USB-serial signals
    signal usb_devreset :   std_logic;
    signal usb_busreset :   std_logic;
    signal usb_highspeed :  std_logic;
    signal usb_suspend :    std_logic;
    signal usb_online :     std_logic;
    signal usb_rxval :      std_logic;
    signal usb_rxdat :      std_logic_vector(7 downto 0);
    signal usb_rxrdy :      std_logic;
    signal usb_rxlen :      std_logic_vector(RXBUFSIZE_BITS-1 downto 0);
    signal usb_txval :      std_logic;
    signal usb_txdat :      std_logic_vector(7 downto 0);
    signal usb_txrdy :      std_logic;
    signal usb_txroom :     std_logic_vector(TXBUFSIZE_BITS-1 downto 0);
    signal usb_txcork :     std_logic;

    -- PHY-side USB signals (UTMI)
    -- clock from UTMI PHY:
    -- 48 MHz with "usb_rx_phy_48MHz.vhd" (recommended)
    -- 60 MHz with "usb_rx_phy_60MHz.vhd"
    signal PHY_CLK :       std_logic;
    signal PHY_DATAIN :    std_logic_vector(7 downto 0);
    signal PHY_DATAOUT :   std_logic_vector(7 downto 0);
    signal PHY_TXVALID :   std_logic;
    signal PHY_TXREADY :   std_logic;
    signal PHY_RXACTIVE :  std_logic;
    signal PHY_RXVALID :   std_logic;
    signal PHY_RXERROR :   std_logic;
    signal PHY_LINESTATE : std_logic_vector(1 downto 0);
    signal PHY_OPMODE :    std_logic_vector(1 downto 0);
    signal PHY_XCVRSELECT: std_logic;
    signal PHY_TERMSELECT: std_logic;
    signal PHY_RESET :     std_logic;
    signal PHY_DATABUS16_8:std_logic;

    -- transciever hardware 3-state signals
    signal S_rxd: std_logic;
    signal S_rxdp, S_rxdn: std_logic;
    signal S_txdp, S_txdn, S_txoe: std_logic;

    -- registers for transmit logic
    signal R_usb_txval :    std_logic;
    signal R_usb_txdat :    std_logic_vector(7 downto 0);
    -- registers for receive logic
    signal R_rx_byte: std_logic_vector(7 downto 0);
    signal R_rx_full: std_logic;
    signal S_rx_available: std_logic;
    signal R_rxrdy: std_logic := '1';
    signal R_rxrdy_tick: std_logic_vector(2 downto 0);
    signal R_break, S_break: std_logic := '0';
begin
    bus_out(31 downto 11) <= "---------------------";
    bus_out(9 downto 8) <= '-' & R_rx_full;
    bus_out(7 downto 0) <= R_rx_byte;
    usb_rxrdy <= R_rxrdy_tick(R_rxrdy_tick'high); -- works but loses chars
    -- usb_rxrdy <= not R_rx_full; -- works but loses chars
    break <= R_break;
    S_rx_available <= '0' when conv_integer(usb_rxlen) = 0 else '1';

    bus_out(10) <= not usb_txrdy; -- TX busy
    G_not_bypass: if not C_bypass generate
      usb_txval <= R_usb_txval;
      usb_txdat <= R_usb_txdat;
    end generate G_not_bypass;
    G_yes_bypass: if C_bypass generate
      usb_txval <= usb_rxval;
      usb_txdat <= usb_rxdat;
    end generate G_yes_bypass;
    usb_devreset <= reset;

    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' and bus_write = '1' and byte_sel(0) = '1' and usb_txrdy = '1' then
              R_usb_txdat <= bus_in(7 downto 0);
              R_usb_txval <= '1';
            else
              R_usb_txval <= '0';
	    end if;

--            if ce = '1' and bus_write = '0' and byte_sel(0) = '1' and R_rx_full = '1' then
--              R_rx_full <= '0';
--            else
--              if usb_rxval = '1' and R_rx_full = '0' then
--                R_rx_byte <= usb_rxdat;
--                R_rx_full <= '1';
--              end if;
--            end if;

            if R_rx_full = '1' then
              if ce = '1' and bus_write = '0' and byte_sel(0) = '1' then
                R_rx_full <= '0';
              end if;
              R_rxrdy_tick <= (others => '0');
            else -- R_rx_full = '0'
              if usb_rxval = '1' then -- rxval should follow rxrdy
                R_rx_byte <= usb_rxdat;
                R_rx_full <= '1';
                R_rxrdy_tick <= (others => '0');
              else
                -- try to fetch a single byte by sending
                -- 1-clock pulse at rxrdy
                if R_rxrdy_tick(R_rxrdy_tick'high) = '0' then
                  R_rxrdy_tick <= R_rxrdy_tick + 1;
                else
                  R_rxrdy_tick <= (others => '0');
                end if;
              end if;
            end if;

	    -- serial break register to offload signal timing
	    R_break <= S_break;
	    
	end if;
    end process;

    -- Direct interface to serial data transfer component
    usb_serial_inst : entity work.usb_serial
    generic map
    (
            VENDORID        => X"fb9a",
            PRODUCTID       => X"fb9a",
            VERSIONBCD      => X"0031",
            VENDORSTR       => "EMARD",
            PRODUCTSTR      => "f32c",
            SERIALSTR       => "20190101",
            HSSUPPORT       => false,
            SELFPOWERED     => false,
            RXBUFSIZE_BITS  => RXBUFSIZE_BITS,
            TXBUFSIZE_BITS  => TXBUFSIZE_BITS
    )
    port map
    (
            CLK             => CLK,
            RESET           => usb_devreset,
            USBRST          => usb_busreset,
            HIGHSPEED       => usb_highspeed,
            SUSPEND         => usb_suspend,
            ONLINE          => usb_online,
            BREAK           => S_break,
            RXVAL           => usb_rxval,
            RXDAT           => usb_rxdat,
            RXRDY           => usb_rxrdy,
            RXLEN           => usb_rxlen,
            TXVAL           => usb_txval,
            TXDAT           => usb_txdat,
            TXRDY           => usb_txrdy,
            TXROOM          => usb_txroom,
            TXCORK          => usb_txcork,
            PHY_CLK         => usb_clk,
            PHY_DATAIN      => PHY_DATAIN,
            PHY_DATAOUT     => PHY_DATAOUT,
            PHY_TXVALID     => PHY_TXVALID,
            PHY_TXREADY     => PHY_TXREADY,
            PHY_RXACTIVE    => PHY_RXACTIVE,
            PHY_RXVALID     => PHY_RXVALID,
            PHY_RXERROR     => PHY_RXERROR,
            PHY_LINESTATE   => PHY_LINESTATE,
            PHY_OPMODE      => PHY_OPMODE,
            PHY_XCVRSELECT  => PHY_XCVRSELECT,
            PHY_TERMSELECT  => PHY_TERMSELECT,
            PHY_RESET       => PHY_RESET
    );

    -- Configure USB PHY
    PHY_DATABUS16_8 <= '0'; -- 8 bit mode
    
    -- USP1.1 PHY
    usb11_phy: entity work.usb_phy
    generic map
    (
      usb_rst_det => true
    )
    port map
    (
      clk => usb_clk, -- 48 MHz or 60 MHz
      rst => '1', -- 1-don't reset, 0-hold reset
      phy_tx_mode => '1', -- 1-differential, 0-single-ended
      -- usb_rst => S_usb_rst, -- USB host requests reset, sending signal to usb-serial core
      -- UTMI interface to usb-serial core
      TxValid_i => PHY_TXVALID,
      DataOut_i => PHY_DATAOUT, -- 8-bit TX
      TxReady_o => PHY_TXREADY,
      RxValid_o => PHY_RXVALID,
      DataIn_o => PHY_DATAIN, -- 8-bit RX
      RxActive_o => PHY_RXACTIVE,
      RxError_o => PHY_RXERROR,
      LineState_o => PHY_LINESTATE, -- 2-bit
      -- debug interface
      --sync_err_o => S_sync_err,
      --bit_stuff_err_o => S_bit_stuff_err,
      --byte_err_o => S_byte_err,
      -- transciever interface to hardware
      rxd => S_rxd, -- differential input from D+
      rxdp => S_rxdp, -- single-ended input from D+
      rxdn => S_rxdn, -- single-ended input from D-
      txdp => S_txdp, -- single-ended output to D+
      txdn => S_txdn, -- single-ended output to D-
      txoe => S_txoe  -- 3-state control: 0-output, 1-input
    );
    -- transciever soft-core
    --usb_fpga_pu_dp <= '1'; -- D+ pullup for USB1.1 device mode
    --usb_fpga_pu_dn <= 'Z'; -- D- no pullup for USB1.1 device mode
    S_rxd <= usb_diff_dp; -- differential input reads D+
    --S_rxd <= usb_dp; -- single-ended input reads D+ may work as well
    S_rxdp <= usb_dp; -- single-ended input reads D+
    S_rxdn <= usb_dn; -- single-ended input reads D-
    usb_dp <= S_txdp when S_txoe = '0' else 'Z';
    usb_dn <= S_txdn when S_txoe = '0' else 'Z';

end Behavioral;
