
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bram is
    generic(
	C_mem_size: string
    );
    port(
	clk: in std_logic;
	imem_addr: in std_logic_vector(31 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	imem_addr_strobe: in std_logic;
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_byte_we: in std_logic_vector(3 downto 0);
	dmem_addr_strobe: in std_logic
    );
end bram;

architecture x of bram is
    type bram_type is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal bram_0: bram_type := (
	x"00", x"8c", x"05", x"21", x"8c", x"00", x"68", x"21", 
	x"00", x"0d", x"3a", x"78", x"01", x"05", x"07", x"17", 
	x"80", x"05", x"04", x"fd", x"00", x"04", x"01", x"00", 
	x"f8", x"00", x"08", x"05", x"03", x"00", x"01", x"fa", 
	x"00", x"04", x"ec", x"00", x"09", x"21", x"05", x"04", 
	x"fd", x"00", x"ef", x"04", x"05", x"8c", x"21", x"21", 
	x"05", x"01", x"fd", x"00", x"04", x"05", x"61", x"e2", 
	x"00", x"05", x"8c", x"03", x"00", x"43", x"e0", x"41", 
	x"03", x"d0", x"30", x"c9", x"05", x"25", x"ff", x"21", 
	x"55", x"08", x"03", x"00", x"55", x"ff", x"06", x"ff", 
	x"05", x"01", x"01", x"2b", x"ff", x"01", x"07", x"09", 
	x"05", x"2a", x"03", x"00", x"00", x"01", x"30", x"01", 
	x"0d", x"32", x"65", x"01", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_1: bram_type := (
	x"00", x"01", x"00", x"40", x"01", x"80", x"00", x"f8", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"01", x"80", x"00", x"ff", x"00", x"80", x"00", x"00", 
	x"ff", x"00", x"80", x"80", x"c5", x"80", x"00", x"ff", 
	x"00", x"80", x"ff", x"00", x"00", x"30", x"80", x"00", 
	x"ff", x"00", x"ff", x"80", x"00", x"01", x"28", x"10", 
	x"80", x"00", x"ff", x"00", x"80", x"00", x"00", x"ff", 
	x"00", x"00", x"01", x"00", x"19", x"00", x"ff", x"00", 
	x"00", x"ff", x"00", x"ff", x"00", x"18", x"00", x"28", 
	x"00", x"00", x"00", x"00", x"00", x"ff", x"00", x"00", 
	x"00", x"00", x"00", x"78", x"ff", x"00", x"00", x"00", 
	x"00", x"78", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"0a", x"63", x"3e", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_2: bram_type := (
	x"02", x"43", x"60", x"40", x"00", x"1d", x"00", x"00", 
	x"0e", x"07", x"0d", x"0c", x"0b", x"0a", x"09", x"00", 
	x"c2", x"05", x"a4", x"80", x"00", x"03", x"42", x"43", 
	x"60", x"00", x"03", x"0f", x"03", x"18", x"e6", x"c0", 
	x"00", x"02", x"47", x"00", x"4d", x"00", x"03", x"79", 
	x"20", x"00", x"4c", x"02", x"00", x"00", x"00", x"00", 
	x"0f", x"e4", x"80", x"00", x"04", x"87", x"98", x"a1", 
	x"00", x"00", x"00", x"00", x"03", x"00", x"84", x"99", 
	x"20", x"84", x"84", x"84", x"4b", x"83", x"64", x"84", 
	x"00", x"a5", x"4a", x"00", x"00", x"66", x"49", x"64", 
	x"80", x"59", x"98", x"18", x"e5", x"59", x"20", x"44", 
	x"80", x"45", x"e0", x"00", x"c3", x"c6", x"00", x"42", 
	x"66", x"2f", x"20", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_3: bram_type := (
	x"3c", x"8c", x"10", x"00", x"ad", x"3c", x"08", x"00", 
	x"3c", x"24", x"24", x"24", x"24", x"24", x"24", x"08", 
	x"25", x"80", x"30", x"14", x"00", x"a0", x"24", x"80", 
	x"14", x"00", x"8c", x"80", x"00", x"a0", x"31", x"10", 
	x"00", x"80", x"10", x"00", x"10", x"00", x"80", x"30", 
	x"17", x"00", x"14", x"a0", x"08", x"ad", x"00", x"00", 
	x"80", x"31", x"10", x"00", x"80", x"14", x"28", x"04", 
	x"00", x"08", x"ad", x"17", x"00", x"08", x"24", x"28", 
	x"17", x"24", x"24", x"24", x"14", x"00", x"30", x"00", 
	x"08", x"24", x"14", x"00", x"08", x"30", x"14", x"30", 
	x"10", x"30", x"38", x"00", x"25", x"30", x"13", x"28", 
	x"14", x"00", x"11", x"00", x"a0", x"24", x"08", x"24", 
	x"33", x"6c", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );

    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bram_0: signal is "no_rw_check";
    attribute syn_ramstyle of bram_1: signal is "no_rw_check";
    attribute syn_ramstyle of bram_2: signal is "no_rw_check";
    attribute syn_ramstyle of bram_3: signal is "no_rw_check";

    signal ibram_0, ibram_1, ibram_2, ibram_3: std_logic_vector(7 downto 0);
    signal dbram_0, dbram_1, dbram_2, dbram_3: std_logic_vector(7 downto 0);

begin

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    process(clk)
    begin
	if falling_edge(clk) and imem_addr_strobe = '1' then
	    ibram_0 <= bram_0(conv_integer(imem_addr));
	    ibram_1 <= bram_1(conv_integer(imem_addr));
	    ibram_2 <= bram_2(conv_integer(imem_addr));
	    ibram_3 <= bram_3(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dbram_0 <= bram_0(conv_integer(dmem_addr));
	    if dmem_byte_we(0) = '1' then
		bram_0(conv_integer(dmem_addr)) <= dmem_data_in(7 downto 0);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dbram_1 <= bram_1(conv_integer(dmem_addr));
	    if dmem_byte_we(1) = '1' then
		bram_1(conv_integer(dmem_addr)) <= dmem_data_in(15 downto 8);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dbram_2 <= bram_2(conv_integer(dmem_addr));
	    if dmem_byte_we(2) = '1' then
		bram_2(conv_integer(dmem_addr)) <= dmem_data_in(23 downto 16);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dbram_3 <= bram_3(conv_integer(dmem_addr));
	    if dmem_byte_we(3) = '1' then
		bram_3(conv_integer(dmem_addr)) <= dmem_data_in(31 downto 24);
	    end if;
	end if;
    end process;
end x;
