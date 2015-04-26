--
-- Copyright (c) 2008 Marko Zec, University of Zagreb
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

library UNISIM;
use UNISIM.VComponents.all;

entity reg1w2r is
   generic(
	C_register_technology: string := "xilinx_ram16x1d";
	C_debug: boolean := false
   );
   port(
	rd1_addr, rd2_addr, rdd_addr, wr_addr: in std_logic_vector(4 downto 0);
	rd1_data, rd2_data, rdd_data: out std_logic_vector(31 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_enable: in std_logic;
	clk: in std_logic
    );
end reg1w2r;

architecture Behavioral of reg1w2r is
    -- for xilinx_ram16x1d:
    signal we_upper, we_lower: std_logic;
    signal rd1_upper, rd1_lower: std_logic_vector(31 downto 0);
    signal rd2_upper, rd2_lower: std_logic_vector(31 downto 0);
    signal rdd_upper, rdd_lower: std_logic_vector(31 downto 0);
    -- for xilinx_ram32x1s:
    signal r1_eaddr, r2_eaddr, rd_eaddr: std_logic_vector(4 downto 0);
    signal rd1_tmp, rd2_tmp, rdd_tmp: std_logic_vector(31 downto 0);
    -- for xilinx_ramb16:
    signal r1_xaddr, r2_xaddr, rd_xaddr, wr_xaddr: std_logic_vector(8 downto 0);

begin

    --
    -- The fastest achievable, hence the default register file implementation.
    --
    G_xilinx_ram16x1d:
    if C_register_technology = "xilinx_ram16x1d" generate
    begin
    we_lower <= wr_enable and not wr_addr(4);
    we_upper <= wr_enable and wr_addr(4);

    iter: for i in 0 to 31 generate
    begin
	reg_set_upper_1: RAM16X1D
	port map (
	    SPO => open, DPO => rd1_upper(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rd1_addr(0), dpra1 =>rd1_addr(1),
	    dpra2 => rd1_addr(2), dpra3 => rd1_addr(3),
	    wclk => clk, we => we_upper
	);

	reg_set_upper_2: RAM16X1D
	port map (
	    SPO => open, DPO => rd2_upper(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rd2_addr(0), dpra1 =>rd2_addr(1),
	    dpra2 => rd2_addr(2), dpra3 => rd2_addr(3),
	    wclk => clk, we => we_upper
	);

	reg_set_upper_d: RAM16X1D
	port map (
	    SPO => open, DPO => rdd_upper(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rdd_addr(0), dpra1 =>rdd_addr(1),
	    dpra2 => rdd_addr(2), dpra3 => rdd_addr(3),
	    wclk => clk, we => we_upper
	);
				
	reg_set_lower_1: RAM16X1D
	port map (
	    SPO => open, DPO => rd1_lower(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rd1_addr(0), dpra1 =>rd1_addr(1),
	    dpra2 => rd1_addr(2), dpra3 => rd1_addr(3),
	    wclk => clk, we => we_lower
	);

	reg_set_lower_2: RAM16X1D
	port map (
	    SPO => open, DPO => rd2_lower(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rd2_addr(0), dpra1 =>rd2_addr(1),
	    dpra2 => rd2_addr(2), dpra3 => rd2_addr(3),
	    wclk => clk, we => we_lower
	);

	reg_set_lower_d: RAM16X1D
	port map (
	    SPO => open, DPO => rdd_lower(i), a0 => wr_addr(0),
	    a1 =>wr_addr(1), a2 => wr_addr(2), a3 => wr_addr(3),
	    d => wr_data(i), dpra0 => rdd_addr(0), dpra1 =>rdd_addr(1),
	    dpra2 => rdd_addr(2), dpra3 => rdd_addr(3),
	    wclk => clk, we => we_lower
	);
				
	rd1_data(i) <= rd1_lower(i) when rd1_addr(4) = '0' else rd1_upper(i);
	rd2_data(i) <= rd2_lower(i) when rd2_addr(4) = '0' else rd2_upper(i);
	rdd_data(i) <= rdd_lower(i) when rdd_addr(4) = '0' else rdd_upper(i);

    end generate; -- for ...
    end generate; -- xilinx_ram16x1d
	
	
    --
    -- Consumes 61 slices / 182 LUTs less than an xilinx_ram16x1d implementation
    -- while limiting Fmax to around 110 MHz on Spartan3A.
    --
    G_xilinx_ram32x1s:
    if C_register_technology = "xilinx_ram32x1s" generate
    begin
	
    r1_eaddr <= rd1_addr when clk = '1' else wr_addr;
    r2_eaddr <= rd2_addr when clk = '1' else wr_addr;
    rd_eaddr <= rdd_addr when clk = '1' else wr_addr;
	
    iter: for i in 0 to 31 generate
    begin
	reg_set_1: RAM32X1S
	port map (
	    O => rd1_tmp(i), A0 => r1_eaddr(0), A1 => r1_eaddr(1),
	    A2 => r1_eaddr(2), A3 =>r1_eaddr(3), A4 => r1_eaddr(4),
	    D => wr_data(i), wclk => clk, WE => wr_enable
	);
	
	reg_set_2: RAM32X1S
	port map (
	    O => rd2_tmp(i), A0 => r2_eaddr(0), A1 => r2_eaddr(1),
	    A2 => r2_eaddr(2), A3 =>r2_eaddr(3), A4 => r2_eaddr(4),
	    D => wr_data(i), wclk => clk, WE => wr_enable
	);

	reg_set_d: RAM32X1S
	port map (
	    O => rdd_tmp(i), A0 => rd_eaddr(0), A1 => rd_eaddr(1),
	    A2 => rd_eaddr(2), A3 =>rd_eaddr(3), A4 => rd_eaddr(4),
	    D => wr_data(i), wclk => clk, WE => wr_enable
	);
    end generate;
	
    process(clk)
    begin
	if falling_edge(clk) then
	    rd1_data <= rd1_tmp;
	    rd2_data <= rd2_tmp;
	    rdd_data <= rdd_tmp;
	end if;
    end process;

    end generate; -- xilinx_ram32x1s


    --
    -- OK up to 120 MHz on Spartan3A
    --
    xilinx_ramb16:
    if C_register_technology = "xilinx_ramb16" generate
    begin

    r1_xaddr <= "0000" & rd1_addr;
    r2_xaddr <= "0000" & rd2_addr;
    rd_xaddr <= "0000" & rdd_addr;
    wr_xaddr <= "0000" & wr_addr;

    reg_set_1: RAMB16_S36_S36
    port map (
	DIA => wr_data, DIB => x"ffffffff",	DOA => open, DOB => rd1_data,
	ADDRA => wr_xaddr, ADDRB => r1_xaddr,
	CLKA => clk, CLKB => not clk, ENA => '1', ENB => '1', SSRA => '0',
	SSRB => '0', WEA => wr_enable, WEB => '0', DIPA => x"f", DIPB => x"f"
    );

    reg_set_2: RAMB16_S36_S36
    port map (
	DIA => wr_data, DIB => x"ffffffff",	DOA => open, DOB => rd2_data,
	ADDRA => wr_xaddr, ADDRB => r2_xaddr,
	CLKA => clk, CLKB => not clk, ENA => '1', ENB => '1', SSRA => '0',
	SSRB => '0', WEA => wr_enable, WEB => '0', DIPA => x"f", DIPB => x"f"
    );

    reg_set_d: RAMB16_S36_S36
    port map (
	DIA => wr_data, DIB => x"ffffffff",	DOA => open, DOB => rdd_data,
	ADDRA => wr_xaddr, ADDRB => rd_xaddr,
	CLKA => clk, CLKB => not clk, ENA => '1', ENB => '1', SSRA => '0',
	SSRB => '0', WEA => wr_enable, WEB => '0', DIPA => x"f", DIPB => x"f"
    );

    end generate; -- xilinx_ramb16
	
end Behavioral;
