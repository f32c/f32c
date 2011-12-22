
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
    type mem_type is array(0 to 4095) of std_logic_vector(7 downto 0);
    signal mem_0: mem_type := (
        others => (others => '0')
    );
    signal mem_1: mem_type := (
        others => (others => '0')
    );
    signal mem_2: mem_type := (
        others => (others => '0')
    );
    signal mem_3: mem_type := (
        others => (others => '0')
    );

    attribute syn_ramstyle: string;
    attribute syn_ramstyle of mem_0: signal is "no_rw_check";
    attribute syn_ramstyle of mem_1: signal is "no_rw_check";
    attribute syn_ramstyle of mem_2: signal is "no_rw_check";
    attribute syn_ramstyle of mem_3: signal is "no_rw_check";

    signal imem_0, imem_1, imem_2, imem_3: std_logic_vector(7 downto 0);
    signal dmem_0, dmem_1, dmem_2, dmem_3: std_logic_vector(7 downto 0);

begin

    dmem_data_out <= dmem_3 & dmem_2 & dmem_1 & dmem_0;
    imem_data_out <= imem_3 & imem_2 & imem_1 & imem_0;

    process(clk)
    begin
	if falling_edge(clk) and imem_addr_strobe = '1' then
	    imem_0 <= mem_0(conv_integer(imem_addr));
	    imem_1 <= mem_1(conv_integer(imem_addr));
	    imem_2 <= mem_2(conv_integer(imem_addr));
	    imem_3 <= mem_3(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dmem_0 <= mem_0(conv_integer(dmem_addr));
	    if dmem_byte_we(0) = '1' then
		mem_0(conv_integer(dmem_addr)) <= dmem_data_in(7 downto 0);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dmem_1 <= mem_1(conv_integer(dmem_addr));
	    if dmem_byte_we(1) = '1' then
		mem_1(conv_integer(dmem_addr)) <= dmem_data_in(15 downto 8);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dmem_2 <= mem_2(conv_integer(dmem_addr));
	    if dmem_byte_we(2) = '1' then
		mem_2(conv_integer(dmem_addr)) <= dmem_data_in(23 downto 16);
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) and dmem_addr_strobe = '1' then
	    dmem_3 <= mem_3(conv_integer(dmem_addr));
	    if dmem_byte_we(3) = '1' then
		mem_3(conv_integer(dmem_addr)) <= dmem_data_in(31 downto 24);
	    end if;
	end if;
    end process;

    -- XXX ?
    imem_data_ready <= '1';
    dmem_data_ready <= '1';
end x;
