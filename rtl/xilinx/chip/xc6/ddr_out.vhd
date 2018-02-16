-- Emard
-- LICENSE=BSD

library IEEE;
use IEEE.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity ddr_out is
  port
  (
    iclkp: in std_logic; -- normal clock
    iclkn: in std_logic; -- inverted clock
    ireset: in std_logic := '0';
    idata: in std_logic_vector(1 downto 0);
    odata: out std_logic
  );
end ddr_out;

architecture Structure of ddr_out is
begin
  ODDR_inst: ODDR2
  generic map
  (
    DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC"
  )
  port map
  (
    C0 => iclkp, -- 1-bit clock input
    C1 => iclkn, -- 1-bit clock input inverted
    CE => '1', -- 1-bit clock enable input
    D0 => idata(0), -- 1-bit data input (output at positive edge)
    D1 => idata(1), -- 1-bit data input (output at negative edge)
    R => ireset,  -- 1-bit reset input
    S => '0',  -- 1-bit set input
    Q => odata -- 1-bit DDR output
  );
end Structure;
