--
-- Copyright (c) 2011, 2016 Marko Zec, University of Zagreb
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


entity reg1w2r is
    generic(
	C_synchronous_read: boolean := false;
	C_debug: boolean := false
    );
    port(
	rd1_addr, rd2_addr, rdd_addr, wr_addr: in std_logic_vector(4 downto 0);
	rd1_data, rd2_data, rdd_data: out std_logic_vector(31 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_enable: in std_logic;
	rd_clk, wr_clk: in std_logic
    );
end reg1w2r;

architecture Behavioral of reg1w2r is
    signal we_upper, we_lower: std_logic;
    signal rd1_upper, rd1_lower: std_logic_vector(31 downto 0);
    signal rd2_upper, rd2_lower: std_logic_vector(31 downto 0);
    signal rdd_upper, rdd_lower: std_logic_vector(31 downto 0);
    signal rd1_d, rd2_d, rdd_d: std_logic_vector(31 downto 0);
begin

    we_lower <= wr_enable and not wr_addr(4);
    we_upper <= wr_enable and wr_addr(4);

    iter_1: for i in 0 to 3 generate
    begin
	reg_set_upper_1a: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rd1_upper(i * 8 + 0), DO1 => rd1_upper(i * 8 + 1),
		DO2 => rd1_upper(i * 8 + 2), DO3 => rd1_upper(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
		RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_upper_1b: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rd1_upper(i * 8 + 4), DO1 => rd1_upper(i * 8 + 5),
		DO2 => rd1_upper(i * 8 + 6), DO3 => rd1_upper(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
		RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_lower_1a: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rd1_lower(i * 8 + 0), DO1 => rd1_lower(i * 8 + 1),
		DO2 => rd1_lower(i * 8 + 2), DO3 => rd1_lower(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
		RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	reg_set_lower_1b: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rd1_lower(i * 8 + 4), DO1 => rd1_lower(i * 8 + 5),
		DO2 => rd1_lower(i * 8 + 6), DO3 => rd1_lower(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
		RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	rd1_d(i * 8 + 0) <=	rd1_lower(i * 8 + 0) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 0);
	rd1_d(i * 8 + 1) <= rd1_lower(i * 8 + 1) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 1);
	rd1_d(i * 8 + 2) <= rd1_lower(i * 8 + 2) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 2);
	rd1_d(i * 8 + 3) <= rd1_lower(i * 8 + 3) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 3);
	rd1_d(i * 8 + 4) <= rd1_lower(i * 8 + 4) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 4);
	rd1_d(i * 8 + 5) <= rd1_lower(i * 8 + 5) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 5);
	rd1_d(i * 8 + 6) <= rd1_lower(i * 8 + 6) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 6);
	rd1_d(i * 8 + 7) <= rd1_lower(i * 8 + 7) when rd1_addr(4) = '0'
	  else rd1_upper(i * 8 + 7);
    end generate;

    iter_2: for i in 0 to 3 generate
    begin
	reg_set_upper_2a: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rd2_upper(i * 8 + 0), DO1 => rd2_upper(i * 8 + 1),
		DO2 => rd2_upper(i * 8 + 2), DO3 => rd2_upper(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
		RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_upper_2b: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rd2_upper(i * 8 + 4), DO1 => rd2_upper(i * 8 + 5),
		DO2 => rd2_upper(i * 8 + 6), DO3 => rd2_upper(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
		RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_lower_2a: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rd2_lower(i * 8 + 0), DO1 => rd2_lower(i * 8 + 1),
		DO2 => rd2_lower(i * 8 + 2), DO3 => rd2_lower(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
		RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	reg_set_lower_2b: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rd2_lower(i * 8 + 4), DO1 => rd2_lower(i * 8 + 5),
		DO2 => rd2_lower(i * 8 + 6), DO3 => rd2_lower(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
		RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	rd2_d(i * 8 + 0) <= rd2_lower(i * 8 + 0) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 0);
	rd2_d(i * 8 + 1) <= rd2_lower(i * 8 + 1) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 1);
	rd2_d(i * 8 + 2) <= rd2_lower(i * 8 + 2) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 2);
	rd2_d(i * 8 + 3) <= rd2_lower(i * 8 + 3) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 3);
	rd2_d(i * 8 + 4) <= rd2_lower(i * 8 + 4) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 4);
	rd2_d(i * 8 + 5) <= rd2_lower(i * 8 + 5) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 5);
	rd2_d(i * 8 + 6) <= rd2_lower(i * 8 + 6) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 6);
	rd2_d(i * 8 + 7) <= rd2_lower(i * 8 + 7) when rd2_addr(4) = '0'
	  else rd2_upper(i * 8 + 7);
    end generate;

    iter_3: for i in 0 to 3 generate
    begin
	reg_set_upper_da: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rdd_upper(i * 8 + 0), DO1 => rdd_upper(i * 8 + 1),
		DO2 => rdd_upper(i * 8 + 2), DO3 => rdd_upper(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
		RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_upper_db: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rdd_upper(i * 8 + 4), DO1 => rdd_upper(i * 8 + 5),
		DO2 => rdd_upper(i * 8 + 6), DO3 => rdd_upper(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
		RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
		WCK => wr_clk, WRE => we_upper
	);
				
	reg_set_lower_da: DPR16X4A
	port map (
		DI0 => wr_data(i * 8 + 0), DI1 => wr_data(i * 8 + 1),
		DI2 => wr_data(i * 8 + 2), DI3 => wr_data(i * 8 + 3),
		DO0 => rdd_lower(i * 8 + 0), DO1 => rdd_lower(i * 8 + 1),
		DO2 => rdd_lower(i * 8 + 2), DO3 => rdd_lower(i * 8 + 3),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
		RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	reg_set_lower_db: DPR16X4B
	port map (
		DI0 => wr_data(i * 8 + 4), DI1 => wr_data(i * 8 + 5),
		DI2 => wr_data(i * 8 + 6), DI3 => wr_data(i * 8 + 7),
		DO0 => rdd_lower(i * 8 + 4), DO1 => rdd_lower(i * 8 + 5),
		DO2 => rdd_lower(i * 8 + 6), DO3 => rdd_lower(i * 8 + 7),
		WAD0 => wr_addr(0), WAD1 => wr_addr(1),
		WAD2 => wr_addr(2), WAD3 => wr_addr(3),
		RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
		RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
		WCK => wr_clk, WRE => we_lower
	);
				
	rdd_d(i * 8 + 0) <= rdd_lower(i * 8 + 0) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 0);
	rdd_d(i * 8 + 1) <= rdd_lower(i * 8 + 1) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 1);
	rdd_d(i * 8 + 2) <= rdd_lower(i * 8 + 2) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 2);
	rdd_d(i * 8 + 3) <= rdd_lower(i * 8 + 3) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 3);
	rdd_d(i * 8 + 4) <= rdd_lower(i * 8 + 4) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 4);
	rdd_d(i * 8 + 5) <= rdd_lower(i * 8 + 5) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 5);
	rdd_d(i * 8 + 6) <= rdd_lower(i * 8 + 6) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 6);
	rdd_d(i * 8 + 7) <= rdd_lower(i * 8 + 7) when rdd_addr(4) = '0'
	  else rdd_upper(i * 8 + 7);
    end generate;

    process(rd_clk, rd1_d, rd2_d, rdd_d)
    begin
	if falling_edge(rd_clk) or not C_synchronous_read then
	    rd1_data <= rd1_d;
	    rd2_data <= rd2_d;
	    rdd_data <= rdd_d;
	end if;
    end process;
end Behavioral;
