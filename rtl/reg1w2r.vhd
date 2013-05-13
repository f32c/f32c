-- $Id$

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

    -- Prevent XST from inferring block RAMs
    attribute ram_style: string;
    attribute ram_style of R1: signal is "distributed";
    attribute ram_style of R2: signal is "distributed";
    attribute ram_style of RD: signal is "distributed";

begin
    process(clk)
    begin
	if rising_edge(clk) then
	    if wr_enable = '1' then
		R1(conv_integer(wr_addr)) <= wr_data;
		R2(conv_integer(wr_addr)) <= wr_data;
	    end if;
	    if C_debug and wr_enable = '1' then
		RD(conv_integer(wr_addr)) <= wr_data;
	    end if;
	end if;
    end process;

    rd1_data <= R1(conv_integer(rd1_addr));
    rd2_data <= R2(conv_integer(rd2_addr));
    rdd_data <= RD(conv_integer(rdd_addr)) when C_debug else x"00000000";
end Behavioral;
