--
-- Copyright 2011 - 2014 Marko Zec, University of Zagreb.
--
-- Neither this file nor any parts of it may be used unless an explicit 
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id$

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity loadalign is
    generic (
	C_big_endian: boolean
    );
    port (
	mem_read_sign_extend_pipelined: in std_logic;
	mem_addr_offset: in std_logic_vector(1 downto 0);
	mem_size_pipelined: in std_logic_vector(1 downto 0);
	mem_align_in: in std_logic_vector(31 downto 0);
	mem_align_out: out std_logic_vector(31 downto 0)
    );
end loadalign;

architecture Behavioral of loadalign is
begin

    process(mem_align_in, mem_read_sign_extend_pipelined,
      mem_addr_offset, mem_size_pipelined)
	variable mem_align_tmp_h: std_logic_vector(15 downto 0);
	variable mem_align_tmp_b: std_logic_vector(7 downto 0);
    begin

	-- byte
	if C_big_endian then
	    case mem_addr_offset is
		when "11" => mem_align_tmp_b := mem_align_in(7 downto 0);
		when "10" => mem_align_tmp_b := mem_align_in(15 downto 8);
		when "01" => mem_align_tmp_b := mem_align_in(23 downto 16);
		when others => mem_align_tmp_b := mem_align_in(31 downto 24);
	    end case;
	else
	    case mem_addr_offset is
		when "00" => mem_align_tmp_b := mem_align_in(7 downto 0);
		when "01" => mem_align_tmp_b := mem_align_in(15 downto 8);
		when "10" => mem_align_tmp_b := mem_align_in(23 downto 16);
		when others => mem_align_tmp_b := mem_align_in(31 downto 24);
	    end case;
	end if;

	-- half-word
	if C_big_endian then
	    case mem_addr_offset is
		when "10" => mem_align_tmp_h := mem_align_in(15 downto 0);
		when "00" => mem_align_tmp_h := mem_align_in(31 downto 16);
		when others => mem_align_tmp_h := "----------------";
	    end case;
	else
	    case mem_addr_offset is
		when "00" => mem_align_tmp_h := mem_align_in(15 downto 0);
		when "10" => mem_align_tmp_h := mem_align_in(31 downto 16);
		when others => mem_align_tmp_h := "----------------";
	    end case;
	end if;

	if mem_size_pipelined(1) = '1' then
	    -- word load
	    if mem_addr_offset = "00" then
		if C_big_endian then
		    mem_align_out <= mem_align_in;
		else
		    mem_align_out <=
		      mem_align_in(31 downto 8) & mem_align_tmp_b;
		end if;
	    else
		mem_align_out <= "--------------------------------";
	    end if;
	else
	    if mem_size_pipelined(0) = '0' then
		-- byte load
		if mem_read_sign_extend_pipelined = '1' then
		    if mem_align_tmp_b(7) = '1' then
			mem_align_out <=
			  x"ffffff" & mem_align_tmp_b(7 downto 0);
		    else
			mem_align_out <=
			  x"000000" & mem_align_tmp_b(7 downto 0);
		    end if;
		else
		    mem_align_out <=
		      x"000000" & mem_align_tmp_b(7 downto 0);
		end if;
	    else
		-- half word load
		if mem_addr_offset(0) = '1' then
		    mem_align_out <= "--------------------------------";
		elsif mem_read_sign_extend_pipelined = '1' then
		    if mem_align_tmp_h(15) = '1' then
			mem_align_out <=
			  x"ffff" & mem_align_tmp_h(15 downto 0);
		    else
			mem_align_out <=
			  x"0000" & mem_align_tmp_h(15 downto 0);
		    end if;
		else
		    mem_align_out <=
		      x"0000" & mem_align_tmp_h(15 downto 0);
		end if;
	    end if;
	end if;
    end process;
end Behavioral;

