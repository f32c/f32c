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

-- $Id$

-- Provides buffered output from input keys, in order to minimize transient
-- noise.  Transform rot_a and rot_b direct input from the rotary key into
-- left or right signal.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity rotary is
	Port (
		ROT_A, ROT_B : in STD_LOGIC;
		rot_left, rot_right: out std_logic;
		btn_vector_in: in std_logic_vector(8 downto 0);
		btn_vector_out: out std_logic_vector(8 downto 0);
		CLK: in STD_LOGIC
	);
end rotary;

architecture Behavioral of rotary is
	signal rot_prev, rot_current: std_logic_vector(1 downto 0);
	signal left, right: std_logic;
	signal btn_vector_0, btn_vector_1, btn_vector_2: std_logic_vector(8 downto 0);
begin
	process(clk)
	begin
		if rising_edge(clk) then
			rot_prev <= rot_current;
			rot_current <= rot_a & rot_b;
			if rot_current = "00" and rot_prev = "10" and right = '0' then
				left <= '1';
			end if;
			if rot_current = "00" and rot_prev = "01" and left = '0' then
				right <= '1';
			end if;
			if rot_current = "11" then
				left <= '0';
				right <= '0';
			end if;
		end if;
	end process;
	
	rot_left <= left;
	rot_right <= right;
	
	process(clk)
	begin
		if rising_edge(clk) then
			btn_vector_out <= btn_vector_0 and btn_vector_1 and btn_vector_2;
			btn_vector_2 <= btn_vector_1;
			btn_vector_1 <= btn_vector_0;
			btn_vector_0 <= btn_vector_in;
		end if;
	end process;	
end Behavioral;

