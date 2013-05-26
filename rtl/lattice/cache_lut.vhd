--
-- Copyright 2013 University of Zagreb, Croatia.
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

-- $Id: reg1w2r.vhd 821 2012-01-24 11:40:59Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


entity cache_lut is
    port(
	rd_addr: in std_logic_vector(5 downto 0);
	rd_data: out std_logic_vector(31 downto 0);
	rd_tag: out std_logic_vector(15 downto 0);
	wr_addr: in std_logic_vector(5 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_tag: in std_logic_vector(15 downto 0);
	wr_enable: in std_logic;
	clk: in std_logic
    );
end cache_lut;

architecture Behavioral of cache_lut is

begin

    block_iter: for b in 0 to 3 generate
	signal wr_e: std_logic;
	signal rd_d: std_logic_vector(31 downto 0);
	signal rd_t: std_logic_vector(15 downto 0);
    begin

	wr_e <= wr_enable when b = conv_integer(wr_addr(5 downto 4)) else '0';
	rd_data <= rd_d when b = conv_integer(wr_addr(5 downto 4))
	  else (others => 'Z');
	rd_tag <= rd_t when b = conv_integer(wr_addr(5 downto 4))
	  else (others => 'Z');

	data_iter: for i in 0 to 3 generate
	data_a: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rd_d(i * 8 + 0), DO1 => rd_d(i * 8 + 1),
		DO2 => rd_d(i * 8 + 2), DO3 => rd_d(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd_addr(0), RAD1 => rd_addr(1),
		RAD2 => rd_addr(2), RAD3 => rd_addr(3),
		WCK => clk, WRE => wr_e
	);
	data_b: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rd_d(i * 8 + 4), DO1 => rd_d(i * 8 + 5),
		DO2 => rd_d(i * 8 + 6), DO3 => rd_d(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd_addr(0), RAD1 => rd_addr(1),
		RAD2 => rd_addr(2), RAD3 => rd_addr(3),
		WCK => clk, WRE => wr_e
	);
	end generate data_iter;

	tag_iter: for i in 0 to 1 generate
	tag_a: DPR16X4A
	port map (
		DI0 => wr_tag(i * 8 + 0), DI1 => wr_tag(i * 8 + 1),
		DI2 => wr_tag(i * 8 + 2), DI3 => wr_tag(i * 8 + 3),
		DO0 => rd_t(i * 8 + 0), DO1 => rd_t(i * 8 + 1),
		DO2 => rd_t(i * 8 + 2), DO3 => rd_t(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd_addr(0), RAD1 => rd_addr(1),
		RAD2 => rd_addr(2), RAD3 => rd_addr(3),
		WCK => clk, WRE => wr_e
	);
	tag_b: DPR16X4B
	port map (
		DI0 => wr_tag(i * 8 + 4), DI1 => wr_tag(i * 8 + 5),
		DI2 => wr_tag(i * 8 + 6), DI3 => wr_tag(i * 8 + 7),
		DO0 => rd_t(i * 8 + 4), DO1 => rd_t(i * 8 + 5),
		DO2 => rd_t(i * 8 + 6), DO3 => rd_t(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd_addr(0), RAD1 => rd_addr(1),
		RAD2 => rd_addr(2), RAD3 => rd_addr(3),
		WCK => clk, WRE => wr_e
	);
	end generate tag_iter;
    end generate block_iter;
end Behavioral;
