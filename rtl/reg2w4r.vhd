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

-- $Id: reg2w4r.vhd,v 1.3 2008/04/23 09:52:27 marko Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity reg2w4r is
   port(
		rd1_addr, rd2_addr, rd3_addr, rd4_addr, rdd_addr: in std_logic_vector(4 downto 0);
		wr1_addr, wr2_addr: in STD_LOGIC_VECTOR(4 downto 0);
      rd1_data, rd2_data, rd3_data, rd4_data, rdd_data: out STD_LOGIC_VECTOR(31 downto 0);
      wr1_data, wr2_data: in STD_LOGIC_VECTOR(31 downto 0);
		wr1_enable, wr2_enable: in std_logic;
		clk, clkx2: in STD_LOGIC
	);
end reg2w4r;

architecture Behavioral of reg2w4r is
 	signal we_upper, we_lower: std_logic;
	signal wr_datamux: std_logic_vector(31 downto 0);
	signal wr_addrmux: std_logic_vector(4 downto 0);
	signal rd1_upper, rd1_lower: std_logic_vector(31 downto 0);
	signal rd2_upper, rd2_lower: std_logic_vector(31 downto 0);
	signal rd3_upper, rd3_lower: std_logic_vector(31 downto 0);
	signal rd4_upper, rd4_lower: std_logic_vector(31 downto 0);
	signal rdd_upper, rdd_lower: std_logic_vector(31 downto 0);
	signal phase: std_logic;
begin

	process(clkx2)
	begin
		if falling_edge(clkx2) then
			phase <= clk;
		end if;
		if rising_edge(clkx2) then
			if phase = '0' then
				wr_addrmux <= wr1_addr;
				wr_datamux <= wr1_data;
				we_lower <= wr1_enable and not wr1_addr(4);
				we_upper <= wr1_enable and wr1_addr(4);
			else
				wr_addrmux <= wr2_addr;
				wr_datamux <= wr2_data;
				we_lower <= wr2_enable and not wr2_addr(4);
				we_upper <= wr2_enable and wr2_addr(4);
			end if;
		end if;
	end process;

	iter: for i in 0 to 31 generate
	begin
		reg_set_upper_1: RAM16X1D
			port map (SPO => open, DPO => rd1_upper(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd1_addr(0), dpra1 =>rd1_addr(1),
				dpra2 => rd1_addr(2), dpra3 => rd1_addr(3), wclk => clkx2, we => we_upper);
		reg_set_upper_2: RAM16X1D
			port map (SPO => open, DPO => rd2_upper(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd2_addr(0), dpra1 =>rd2_addr(1),
				dpra2 => rd2_addr(2), dpra3 => rd2_addr(3), wclk => clkx2, we => we_upper);
		reg_set_upper_3: RAM16X1D
			port map (SPO => open, DPO => rd3_upper(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd3_addr(0), dpra1 =>rd3_addr(1),
				dpra2 => rd3_addr(2), dpra3 => rd3_addr(3), wclk => clkx2, we => we_upper);
		reg_set_upper_4: RAM16X1D
			port map (SPO => open, DPO => rd4_upper(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd4_addr(0), dpra1 =>rd4_addr(1),
				dpra2 => rd4_addr(2), dpra3 => rd4_addr(3), wclk => clkx2, we => we_upper);
		reg_set_upper_d: RAM16X1D
			port map (SPO => open, DPO => rdd_upper(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rdd_addr(0), dpra1 =>rdd_addr(1),
				dpra2 => rdd_addr(2), dpra3 => rdd_addr(3), wclk => clkx2, we => we_upper);				
				
		reg_set_lower_1: RAM16X1D
			port map (SPO => open, DPO => rd1_lower(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd1_addr(0), dpra1 =>rd1_addr(1),
				dpra2 => rd1_addr(2), dpra3 => rd1_addr(3), wclk => clkx2, we => we_lower);
		reg_set_lower_2: RAM16X1D
			port map (SPO => open, DPO => rd2_lower(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd2_addr(0), dpra1 =>rd2_addr(1),
				dpra2 => rd2_addr(2), dpra3 => rd2_addr(3), wclk => clkx2, we => we_lower);
		reg_set_lower_3: RAM16X1D
			port map (SPO => open, DPO => rd3_lower(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd3_addr(0), dpra1 =>rd3_addr(1),
				dpra2 => rd3_addr(2), dpra3 => rd3_addr(3), wclk => clkx2, we => we_lower);
		reg_set_lower_4: RAM16X1D
			port map (SPO => open, DPO => rd4_lower(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rd4_addr(0), dpra1 =>rd4_addr(1),
				dpra2 => rd4_addr(2), dpra3 => rd4_addr(3), wclk => clkx2, we => we_lower);
		reg_set_lower_d: RAM16X1D
			port map (SPO => open, DPO => rdd_lower(i), a0 => wr_addrmux(0),
				a1 =>wr_addrmux(1), a2 => wr_addrmux(2), a3 => wr_addrmux(3),
				d => wr_datamux(i), dpra0 => rdd_addr(0), dpra1 =>rdd_addr(1),
				dpra2 => rdd_addr(2), dpra3 => rdd_addr(3), wclk => clkx2, we => we_lower);
				
		rd1_data(i) <= rd1_lower(i) when rd1_addr(4) = '0' else rd1_upper(i);
		rd2_data(i) <= rd2_lower(i) when rd2_addr(4) = '0' else rd2_upper(i);
		rd3_data(i) <= rd3_lower(i) when rd3_addr(4) = '0' else rd3_upper(i);
		rd4_data(i) <= rd4_lower(i) when rd4_addr(4) = '0' else rd4_upper(i);
		rdd_data(i) <= rdd_lower(i) when rdd_addr(4) = '0' else rdd_upper(i);
   end generate;

end Behavioral;
