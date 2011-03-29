--
-- Copyright 2011 University of Zagreb, Croatia.
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


entity reg1w2r is
	generic(
		C_register_technology: string := "lattice_DPR12X4B"
	);
	port(
		rd1_addr, rd2_addr, rdd_addr, wr_addr: in STD_LOGIC_VECTOR(4 downto 0);
		rd1_data, rd2_data, rdd_data: out STD_LOGIC_VECTOR(31 downto 0);
		wr_data: in STD_LOGIC_VECTOR(31 downto 0);
		wr_enable: in std_logic;
		clk: in STD_LOGIC
	);
end reg1w2r;

architecture Behavioral of reg1w2r is
 	signal we_upper, we_lower: std_logic;
	signal rd1_upper, rd1_lower: std_logic_vector(31 downto 0);
	signal rd2_upper, rd2_lower: std_logic_vector(31 downto 0);
	signal rdd_upper, rdd_lower: std_logic_vector(31 downto 0);
begin

	we_lower <= wr_enable and not wr_addr(4);
	we_upper <= wr_enable and wr_addr(4);

	iter: for i in 0 to 7 generate
	begin
		reg_set_upper_1: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rd1_upper(i), DO1 => rd1_upper(i + 8),
				DO2 => rd1_upper(i + 16), DO3 => rd1_upper(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
				RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
				WCK => clk, WRE => we_upper
			);
				
		reg_set_upper_2: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rd2_upper(i), DO1 => rd2_upper(i + 8),
				DO2 => rd2_upper(i + 16), DO3 => rd2_upper(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
				RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
				WCK => clk, WRE => we_upper
			);
				
		reg_set_upper_d: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rdd_upper(i), DO1 => rdd_upper(i + 8),
				DO2 => rdd_upper(i + 16), DO3 => rdd_upper(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
				RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
				WCK => clk, WRE => we_upper
			);

		reg_set_lower_1: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rd1_lower(i), DO1 => rd1_lower(i + 8),
				DO2 => rd1_lower(i + 16), DO3 => rd1_lower(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rd1_addr(0), RAD1 => rd1_addr(1),
				RAD2 => rd1_addr(2), RAD3 => rd1_addr(3),
				WCK => clk, WRE => we_lower
			);
				
		reg_set_lower_2: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rd2_lower(i), DO1 => rd2_lower(i + 8),
				DO2 => rd2_lower(i + 16), DO3 => rd2_lower(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rd2_addr(0), RAD1 => rd2_addr(1),
				RAD2 => rd2_addr(2), RAD3 => rd2_addr(3),
				WCK => clk, WRE => we_lower
			);
				
		reg_set_lower_d: DPR16X4B
			port map (
				DI0 => wr_data(i), DI1 => wr_data(i + 8),
				DI2 => wr_data(i + 16), DI3 => wr_data(i + 24),
				DO0 => rdd_lower(i), DO1 => rdd_lower(i + 8),
				DO2 => rdd_lower(i + 16), DO3 => rdd_lower(i + 24),
				WAD0 => wr_addr(0), WAD1 => wr_addr(1),
				WAD2 => wr_addr(2), WAD3 => wr_addr(3),
				RAD0 => rdd_addr(0), RAD1 => rdd_addr(1),
				RAD2 => rdd_addr(2), RAD3 => rdd_addr(3),
				WCK => clk, WRE => we_lower
			);
				
		rd1_data(i) <= rd1_lower(i) when rd1_addr(4) = '0' else rd1_upper(i);
		rd2_data(i) <= rd2_lower(i) when rd2_addr(4) = '0' else rd2_upper(i);
		rdd_data(i) <= rdd_lower(i) when rdd_addr(4) = '0' else rdd_upper(i);
	end generate;
	
end Behavioral;
