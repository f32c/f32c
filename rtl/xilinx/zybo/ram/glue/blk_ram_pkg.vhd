

-- IP VLNV: xilinx.com:ip:blk_mem_gen:8.2
-- IP Revision: 3

-- The following code must appear in the VHDL architecture header.

library ieee;
use ieee.std_logic_1164.all;

package blk_ram_pkg is

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
	COMPONENT blk_ram
	  PORT (
	    clka : IN STD_LOGIC;
	    wea : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
	    addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
	    dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	    douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	    clkb : IN STD_LOGIC;
	    web : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
	    addrb : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
	    dinb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	    doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	  );
	END COMPONENT;

-- COMP_TAG_END ------ End COMPONENT Declaration ------------
end package blk_ram_pkg;

-- eof
