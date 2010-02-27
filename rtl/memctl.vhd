--
-- Copyright 2008 University of Zagreb, Croatia.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id: memctl.vhd,v 1.5 2008/04/18 13:55:24 marko Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity memctl is
	port(
		mem_size: in std_logic;
		mem_offset: in std_logic_vector(1 downto 0);
		mem_data: in std_logic_vector(31 downto 0);
		mem_read_sign_extend: in std_logic;
		data_in_shifted: out std_logic_vector(31 downto 0)
	);
end memctl;

architecture Behavioral of memctl is
	signal shifted_data: std_logic_vector(31 downto 0);
begin

	-- shift and sign extend inbound data in accordance with address and data size
	
	process(mem_offset, mem_data)
	begin
		case mem_offset(1 downto 0) is
			when "00" => shifted_data(7 downto 0) <= mem_data(7 downto 0);
			when "01" => shifted_data(7 downto 0) <= mem_data(15 downto 8);
			when "10" => shifted_data(7 downto 0) <= mem_data(23 downto 16);
			when others => shifted_data(7 downto 0) <= mem_data(31 downto 24);
		end case;
	end process;
	
	process(mem_size, mem_offset, mem_data, mem_read_sign_extend, shifted_data)
	begin
		if mem_size = '1' then -- half word
			if mem_offset(1) = '1' then
				shifted_data(15 downto 8) <= mem_data(31 downto 24);
			else
				shifted_data(15 downto 8) <= mem_data(15 downto 8);
			end if;
		else -- byte
			if mem_read_sign_extend = '1' and shifted_data(7) = '1' then
				shifted_data(15 downto 8) <= x"ff";
			else
				shifted_data(15 downto 8) <= x"00";
			end if;
		end if;
	end process;
	
	process(mem_read_sign_extend, shifted_data)
	begin
		if mem_read_sign_extend = '1' and shifted_data(15) = '1' then
			shifted_data(31 downto 16) <= x"ffff";
		else
			shifted_data(31 downto 16) <= x"0000";
		end if;
	end process;
	
	data_in_shifted <= shifted_data;
	
end Behavioral;
