--
-- Copyright (c) 2011 - 2014 Marko Zec, University of Zagreb
-- All rights reserved.
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
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

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

