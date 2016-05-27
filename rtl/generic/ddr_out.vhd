-- LICENSE=BSD

-- non-functional placeholder module for boards
-- that don't need DDR for digital video output

-- nothing functional inside; it's here 
-- just for vhdl compiler to pass

library IEEE;
use IEEE.std_logic_1164.all;

entity ddr_out is
    port (
        iclkp: in std_logic;
        iclkn: in std_logic;
        --clkout: out std_logic := '0';
        ireset: in std_logic;
        --sclk: out std_logic := '0';
        idata: in std_logic_vector(1 downto 0);
        odata: out std_logic := '0'
    );
end ddr_out;

architecture Structure of ddr_out is
begin
end Structure;
