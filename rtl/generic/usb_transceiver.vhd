-- AUTHOR=EMARD
-- LICENSE=BSD

-- Minimalistic USB transciever
-- 27 ohm series resistors, 3.6V protection zeners and 1.5k pullup D+ to 3.3V
-- This is a hack. Hormally a real usb transciever like TUSB1106 should be used.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity usb_transceiver is
  port
  (
    tx_dp, tx_dn, tx_oen:  in std_logic;
    rx_dp, rx_dn: out std_logic;
    dp, dn: inout std_logic -- to physical D+ D- pins
  );
end;

architecture combinatorial of  usb_transceiver is
begin
  dp <= tx_dp when tx_oen = '0' else 'Z';
  dn <= tx_dn when tx_oen = '0' else 'Z';
  rx_dp <= dp;
  rx_dn <= dn;
end combinatorial;
