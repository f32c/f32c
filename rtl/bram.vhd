
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
	imem_data_ready: out std_logic;
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_byte_we: in std_logic_vector(3 downto 0);
	dmem_addr_strobe: in std_logic;
	dmem_data_ready: out std_logic
    );
end bram;

architecture x of bram is
    type bram_type is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal bram_0: bram_type := (
	x"00", x"68", x"00", x"21", x"2b", x"23", x"80", x"4c", 
	x"58", x"0c", x"0d", x"80", x"1e", x"68", x"08", x"03", 
	x"00", x"05", x"01", x"fa", x"00", x"04", x"04", x"02", 
	x"00", x"04", x"15", x"61", x"17", x"21", x"0c", x"21", 
	x"00", x"08", x"00", x"2b", x"21", x"05", x"04", x"fd", 
	x"00", x"04", x"01", x"00", x"f8", x"21", x"36", x"21", 
	x"07", x"d0", x"37", x"e0", x"21", x"21", x"21", x"d0", 
	x"0a", x"06", x"00", x"bf", x"06", x"11", x"c9", x"00", 
	x"04", x"0f", x"1f", x"ca", x"25", x"03", x"00", x"0e", 
	x"21", x"02", x"00", x"21", x"00", x"0e", x"04", x"bb", 
	x"00", x"0e", x"21", x"0d", x"33", x"53", x"62", x"6c", 
	x"65", x"3e", x"01", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_1: bram_type := (
	x"00", x"01", x"00", x"58", x"10", x"20", x"01", x"01", 
	x"00", x"00", x"00", x"01", x"00", x"01", x"80", x"6d", 
	x"80", x"80", x"00", x"ff", x"00", x"00", x"80", x"00", 
	x"00", x"80", x"00", x"00", x"00", x"18", x"00", x"10", 
	x"80", x"00", x"00", x"00", x"10", x"80", x"00", x"ff", 
	x"00", x"80", x"00", x"00", x"ff", x"30", x"00", x"28", 
	x"00", x"ff", x"00", x"ff", x"28", x"30", x"10", x"ff", 
	x"00", x"00", x"69", x"ff", x"00", x"00", x"ff", x"69", 
	x"00", x"00", x"00", x"ff", x"30", x"00", x"00", x"00", 
	x"18", x"00", x"00", x"20", x"00", x"00", x"00", x"ff", 
	x"00", x"00", x"28", x"0a", x"32", x"6f", x"6f", x"6f", 
	x"72", x"20", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_2: bram_type := (
	x"05", x"a3", x"07", x"a0", x"03", x"02", x"84", x"e7", 
	x"0a", x"00", x"09", x"04", x"00", x"60", x"0e", x"0e", 
	x"0d", x"0c", x"88", x"00", x"00", x"80", x"02", x"60", 
	x"00", x"02", x"49", x"58", x"60", x"00", x"80", x"e0", 
	x"1d", x"80", x"1f", x"00", x"e0", x"0f", x"e6", x"c0", 
	x"00", x"03", x"42", x"43", x"60", x"00", x"00", x"00", 
	x"00", x"48", x"00", x"42", x"00", x"00", x"00", x"48", 
	x"19", x"20", x"06", x"4c", x"88", x"00", x"48", x"06", 
	x"a2", x"0e", x"45", x"a0", x"cd", x"60", x"00", x"00", 
	x"c0", x"80", x"00", x"60", x"66", x"00", x"63", x"4a", 
	x"00", x"00", x"00", x"0a", x"63", x"43", x"6f", x"61", 
	x"0d", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_3: bram_type := (
	x"3c", x"8c", x"3c", x"00", x"00", x"00", x"30", x"24", 
	x"24", x"08", x"24", x"24", x"08", x"ad", x"8c", x"00", 
	x"a0", x"80", x"31", x"11", x"00", x"14", x"80", x"14", 
	x"00", x"a0", x"14", x"28", x"14", x"00", x"10", x"00", 
	x"3c", x"00", x"24", x"08", x"00", x"80", x"31", x"14", 
	x"00", x"a0", x"24", x"80", x"14", x"00", x"08", x"00", 
	x"17", x"24", x"08", x"24", x"00", x"00", x"00", x"24", 
	x"2d", x"17", x"00", x"24", x"2d", x"11", x"24", x"00", 
	x"24", x"31", x"30", x"14", x"01", x"14", x"00", x"08", 
	x"00", x"14", x"00", x"00", x"ac", x"08", x"24", x"10", 
	x"00", x"08", x"00", x"66", x"20", x"20", x"74", x"64", 
	x"0a", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
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

    -- XXX ?
    imem_data_ready <= '1';
    dmem_data_ready <= '1';
end x;
