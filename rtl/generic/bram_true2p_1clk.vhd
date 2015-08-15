-- Generated by Quartus II Template

-- File->New File->VHDL File
-- Edit->Insert Template->VHDL->Full designs->RAMs and ROMs->True dual port RAM (singled clock)

-- True Dual-Port RAM with single clock
-- Read-during-write on port A or B should return newly written data on real device

library ieee;
use ieee.std_logic_1164.all;

entity bram_true2p_1clk is
	generic 
	(
		data_width : natural := 8;
		addr_width : natural := 6
	);
	port 
	(
		clk		: in std_logic;
		addr_a	: in natural range 0 to 2**addr_width - 1;
		addr_b	: in natural range 0 to 2**addr_width - 1;
		we_a	: in std_logic := '1';
		we_b	: in std_logic := '1';
		data_in_a	: in std_logic_vector((data_width-1) downto 0);
		data_in_b	: in std_logic_vector((data_width-1) downto 0);
		data_out_a		: out std_logic_vector((data_width -1) downto 0);
		data_out_b		: out std_logic_vector((data_width -1) downto 0)
	);
end bram_true2p_1clk;

architecture rtl of bram_true2p_1clk is
	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector((data_width-1) downto 0);
	type memory_t is array(2**addr_width-1 downto 0) of word_t;

	-- Declare the RAM 
	shared variable ram : memory_t;
begin
	-- Port A
	process(clk)
	begin
	if(rising_edge(clk)) then 
		if(we_a = '1') then
			ram(addr_a) := data_in_a;
		end if;
		data_out_a <= ram(addr_a);
	end if;
	end process;

	-- Port B 
	process(clk)
	begin
	if(rising_edge(clk)) then 
		if(we_b = '1') then
			ram(addr_b) := data_in_b;
		end if;
  	    data_out_b <= ram(addr_b);
	end if;
	end process;
end rtl;
