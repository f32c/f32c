-- Emard
-- LICENSE=BSD

library IEEE;
use IEEE.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity ddr_out is
  port
  (
    iclkp: in std_logic; -- only this is used
    iclkn: in std_logic; -- not needed for xilinx
    ireset: in std_logic := '0';
    idata: in std_logic_vector(1 downto 0);
    odata: out std_logic
  );
end ddr_out;

architecture Structure of ddr_out is
begin
  ODDR_inst: ODDR
  generic map
  (
    DDR_CLK_EDGE => "SAME_EDGE", -- input sampling: "OPPOSITE_EDGE" or "SAME_EDGE"
    INIT => '0', -- Initial value for Q port ('1' or '0')
    SRTYPE => "SYNC" -- Reset Type ("ASYNC" or "SYNC")
  )
  port map
  (
    C => iclkp, -- 1-bit clock input
    CE => '1', -- 1-bit clock enable input
    D1 => idata(0), -- 1-bit data input (output at positive edge)
    D2 => idata(1), -- 1-bit data input (output at negative edge)
    R => ireset, -- 1-bit reset input
    S => '0',  -- 1-bit set input
    Q => odata -- 1-bit DDR output
  );
end Structure;
