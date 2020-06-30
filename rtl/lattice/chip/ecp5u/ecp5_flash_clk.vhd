-- Emard
-- LICENSE=BSD

-- contains vendor-specific module 
-- to output config flash spi clock.
-- flash clk must be routed using this
-- module (not ordinary GPIO)
-- additionaly flash_csn line must be passed to this model

library IEEE;
use IEEE.std_logic_1164.all;

--library ecp5u;
--use ecp5u.components.all;

entity ecp5_flash_clk is
  port
  (
    flash_clk, flash_csn: in std_logic
  );
end;

architecture Structure of ecp5_flash_clk is
    COMPONENT USRMCLK
    PORT
    (
      USRMCLKI: IN STD_ULOGIC;
      USRMCLKTS: IN STD_ULOGIC
    );
    END COMPONENT;
    attribute syn_noprune: boolean;
    attribute syn_noprune of USRMCLK: component is true;
begin
    ecp5_flash_mux: USRMCLK
    port map
    (
      USRMCLKI => flash_clk,
      USRMCLKTS => flash_csn
    );
end Structure;
