
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
	imem_addr_strobe: in std_logic;
	imem_addr: in std_logic_vector(31 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	dmem_addr_strobe: in std_logic;
	dmem_write: in std_logic;
	dmem_byte_sel: in std_logic_vector(3 downto 0);
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0)
    );
end bram;

architecture x of bram is
    type bram_type is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal bram_0: bram_type := (
	x"00", x"00", x"00", x"c4", x"04", x"21", x"c4", x"80", 
	x"21", x"00", x"00", x"0d", x"3a", x"73", x"01", x"05", 
	x"07", x"19", x"b8", x"05", x"04", x"fd", x"00", x"04", 
	x"01", x"00", x"f8", x"00", x"00", x"24", x"02", x"21", 
	x"ff", x"c3", x"ff", x"ff", x"2a", x"02", x"0f", x"f0", 
	x"00", x"05", x"01", x"f0", x"00", x"04", x"e2", x"00", 
	x"0a", x"21", x"05", x"04", x"fd", x"00", x"04", x"e4", 
	x"00", x"07", x"c4", x"21", x"21", x"05", x"01", x"fd", 
	x"00", x"04", x"05", x"00", x"d7", x"00", x"07", x"c4", 
	x"00", x"61", x"03", x"d0", x"51", x"e0", x"41", x"03", 
	x"25", x"c9", x"25", x"04", x"ff", x"21", x"63", x"08", 
	x"03", x"00", x"63", x"ff", x"06", x"ff", x"05", x"01", 
	x"01", x"2b", x"ff", x"01", x"07", x"09", x"05", x"2a", 
	x"03", x"00", x"00", x"01", x"3d", x"01", x"0d", x"32", 
	x"65", x"01", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_1: bram_type := (
	x"00", x"80", x"00", x"01", x"00", x"48", x"01", x"00", 
	x"f8", x"00", x"08", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"01", x"80", x"00", x"ff", x"00", x"80", 
	x"00", x"00", x"ff", x"00", x"48", x"20", x"00", x"30", 
	x"00", x"cc", x"00", x"00", x"28", x"00", x"00", x"00", 
	x"80", x"80", x"00", x"ff", x"00", x"80", x"ff", x"00", 
	x"00", x"30", x"80", x"00", x"ff", x"00", x"80", x"ff", 
	x"00", x"00", x"01", x"28", x"18", x"80", x"00", x"ff", 
	x"00", x"80", x"00", x"00", x"ff", x"00", x"00", x"01", 
	x"41", x"00", x"00", x"ff", x"00", x"ff", x"00", x"00", 
	x"10", x"ff", x"10", x"00", x"00", x"40", x"00", x"00", 
	x"00", x"00", x"00", x"ff", x"00", x"00", x"00", x"00", 
	x"00", x"c8", x"ff", x"00", x"00", x"00", x"00", x"40", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"0a", x"63", 
	x"3e", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_2: bram_type := (
	x"00", x"1d", x"02", x"43", x"60", x"40", x"20", x"00", 
	x"00", x"0a", x"0b", x"07", x"0c", x"0d", x"0e", x"0f", 
	x"18", x"00", x"48", x"19", x"24", x"80", x"00", x"05", 
	x"08", x"05", x"a0", x"00", x"02", x"4b", x"80", x"00", 
	x"06", x"02", x"48", x"23", x"68", x"a0", x"c4", x"c4", 
	x"04", x"06", x"c8", x"00", x"00", x"19", x"27", x"00", 
	x"2c", x"00", x"02", x"45", x"a0", x"00", x"19", x"2d", 
	x"00", x"00", x"20", x"00", x"00", x"04", x"88", x"00", 
	x"00", x"04", x"87", x"00", x"a1", x"00", x"00", x"20", 
	x"02", x"82", x"40", x"82", x"00", x"84", x"99", x"20", 
	x"48", x"84", x"88", x"6e", x"44", x"84", x"00", x"05", 
	x"6f", x"00", x"00", x"46", x"78", x"48", x"00", x"79", 
	x"05", x"05", x"25", x"79", x"20", x"64", x"80", x"65", 
	x"00", x"00", x"c2", x"c6", x"00", x"63", x"66", x"2f", 
	x"20", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_3: bram_type := (
	x"00", x"3c", x"3c", x"8c", x"10", x"00", x"ad", x"08", 
	x"00", x"3c", x"3c", x"24", x"24", x"24", x"24", x"24", 
	x"24", x"08", x"25", x"80", x"33", x"14", x"00", x"a0", 
	x"25", x"81", x"14", x"00", x"40", x"00", x"10", x"00", 
	x"24", x"00", x"30", x"33", x"00", x"14", x"38", x"38", 
	x"a0", x"80", x"30", x"11", x"00", x"80", x"13", x"00", 
	x"13", x"00", x"80", x"30", x"14", x"00", x"a0", x"17", 
	x"00", x"08", x"ad", x"00", x"00", x"80", x"30", x"11", 
	x"00", x"80", x"14", x"00", x"04", x"00", x"08", x"ad", 
	x"00", x"28", x"14", x"24", x"08", x"24", x"28", x"17", 
	x"00", x"24", x"00", x"14", x"30", x"00", x"08", x"25", 
	x"14", x"00", x"08", x"30", x"14", x"30", x"11", x"30", 
	x"39", x"00", x"27", x"30", x"13", x"28", x"14", x"00", 
	x"11", x"00", x"a0", x"24", x"08", x"24", x"33", x"6c", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );

    -- Lattice Diamond attributes
    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bram_0: signal is "no_rw_check";
    attribute syn_ramstyle of bram_1: signal is "no_rw_check";
    attribute syn_ramstyle of bram_2: signal is "no_rw_check";
    attribute syn_ramstyle of bram_3: signal is "no_rw_check";

    -- Xilinx XST attributes
    attribute ram_style: string;
    attribute ram_style of bram_0: signal is "no_rw_check";
    attribute ram_style of bram_1: signal is "no_rw_check";
    attribute ram_style of bram_2: signal is "no_rw_check";
    attribute ram_style of bram_3: signal is "no_rw_check";

    -- Altera Quartus attributes
    attribute ramstyle: string;
    attribute ramstyle of bram_0: signal is "no_rw_check";
    attribute ramstyle of bram_1: signal is "no_rw_check";
    attribute ramstyle of bram_2: signal is "no_rw_check";
    attribute ramstyle of bram_3: signal is "no_rw_check";

    signal ibram_0, ibram_1, ibram_2, ibram_3: std_logic_vector(7 downto 0);
    signal dbram_0, dbram_1, dbram_2, dbram_3: std_logic_vector(7 downto 0);

begin

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' then
		if dmem_write = '1' and dmem_byte_sel(0) = '1' then
		    bram_0(conv_integer(dmem_addr)) <=
		      dmem_data_in(7 downto 0);
		end if;
		dbram_0 <= bram_0(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_0 <= bram_0(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(1) = '1' then
		if dmem_write = '1' then
		    bram_1(conv_integer(dmem_addr)) <=
		      dmem_data_in(15 downto 8);
		end if;
		dbram_1 <= bram_1(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_1 <= bram_1(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(2) = '1' then
		if dmem_write = '1' then
		    bram_2(conv_integer(dmem_addr)) <=
		      dmem_data_in(23 downto 16);
		end if;
		dbram_2 <= bram_2(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_2 <= bram_2(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(3) = '1' then
		if dmem_write = '1' then
		    bram_3(conv_integer(dmem_addr)) <=
		      dmem_data_in(31 downto 24);
		end if;
		dbram_3 <= bram_3(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_3 <= bram_3(conv_integer(imem_addr));
	    end if;
	end if;
    end process;
end x;
