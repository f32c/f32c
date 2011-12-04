
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity bptrace is
    port (
	din: in std_logic_vector(1 downto 0); 
	dout: out std_logic_vector(1 downto 0);
	rdaddr, wraddr: in std_logic_vector(12 downto 0); 
	re, we, clk: in std_logic
    );
end bptrace;

architecture Structure of bptrace is
    type bptrace_type is array(0 to 8191) of std_logic_vector(1 downto 0);
    signal bptrace: bptrace_type;
begin
    bptrace(to_integer(unsigned(wraddr))) <= din when
	rising_edge(clk) and we = '1';
    dout <= bptrace(to_integer(unsigned(rdaddr))) when
	rising_edge(clk) and re = '1';
end Structure;
