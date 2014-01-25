--
-- Copyright 2008 - 2014 Marko Zec, University of Zagreb.
--
-- Neither this file nor any parts of it may be used unless an explicit
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id$

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity alu is
    generic (
	C_sign_extend: boolean
    );
    port(
	x, y: in std_logic_vector(31 downto 0);
	funct: in std_logic_vector(1 downto 0);
	seb_seh_cycle: in boolean;
	seb_seh_select: in std_logic;
	addsubx: out std_logic_vector(32 downto 0);
	logic: out std_logic_vector(31 downto 0);
	equal: out boolean
    );
end alu;

architecture Behavioral of alu is
    signal ex, ey: std_logic_vector(32 downto 0);
begin

    ex <= '0' & x;
    ey <= '0' & y;

    addsubx <= ex + ey when funct(1) = '0' else ex - ey;

    process(x, y, funct, seb_seh_cycle, seb_seh_select)
	variable x_logic: std_logic_vector(31 downto 0);
    begin
	case funct is
	when "00" =>	x_logic := x and y;
	when "01" =>	x_logic := x or y;
	when "10" =>	x_logic := x xor y;
	when others => 	x_logic := not(x or y);
	end case;

	if C_sign_extend and seb_seh_cycle then
	    if seb_seh_select = '1' then
		logic <=
		  x_logic(15) & x_logic(15) & x_logic(15) & x_logic(15) & 
		  x_logic(15) & x_logic(15) & x_logic(15) & x_logic(15) & 
		  x_logic(15) & x_logic(15) & x_logic(15) & x_logic(15) & 
		  x_logic(15) & x_logic(15) & x_logic(15) & x_logic(15) &
		  x_logic(15 downto 0);
	    else
		logic <=
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) & 
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) & 
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) & 
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) & 
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) & 
		  x_logic(7) & x_logic(7) & x_logic(7) & x_logic(7) &
		  x_logic(7 downto 0);
	    end if;
	else
	    logic <= x_logic;
	end if;
    end process;

    equal <= x = y;

end Behavioral;

