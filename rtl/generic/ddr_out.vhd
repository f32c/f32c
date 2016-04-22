-- LICENSE=BSD

-- non-functional placeholder module for boards
-- that don't need DDR for digital video output

-- nothing functional inside; it's here 
-- just for vhdl compiler to pass

library IEEE;
use IEEE.std_logic_1164.all;

entity ddr_out is
    port (
        clkop: in std_logic; 
        clkos: in std_logic; 
        clkout: out std_logic := '0'; 
        reset: in std_logic; 
        sclk: out std_logic := '0'; 
        dataout: in std_logic_vector(1 downto 0); 
        dout: out std_logic_vector(0 downto 0) := (others => '0')
    );
end ddr_out;

architecture Structure of ddr_out is
begin
end Structure;
