-- $Id: reg1w2r.vhd 255 2011-04-28 19:59:44Z marko $

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity reg1w2r is
    generic(
	C_register_technology: string := "generic";
	C_debug: boolean := false
    );
    port(
	rd1_addr, rd2_addr, rdd_addr, wr_addr: in std_logic_vector(4 downto 0);
	rd1_data, rd2_data, rdd_data: out std_logic_vector(31 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_enable: in std_logic;
	clk: in std_logic
    );
end reg1w2r;

architecture Behavioral of reg1w2r is
    type reg_type is array(0 to 31) of std_logic_vector(31 downto 0);
    signal R1, R2, RD: reg_type;
begin
    R1(to_integer(unsigned(wr_addr))) <= wr_data when
	rising_edge(clk) and wr_enable = '1';
    R2(to_integer(unsigned(wr_addr))) <= wr_data when
	rising_edge(clk) and wr_enable = '1';
    RD(to_integer(unsigned(wr_addr))) <= wr_data when
	rising_edge(clk) and wr_enable = '1' and C_debug;

    rd1_data <= R1(to_integer(unsigned(rd1_addr)));
    rd2_data <= R2(to_integer(unsigned(rd2_addr)));
    rdd_data <= RD(to_integer(unsigned(rdd_addr))) when C_debug;
end Behavioral;
