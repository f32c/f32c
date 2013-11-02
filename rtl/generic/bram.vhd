--
-- Copyright 2013 Marko Zec, University of Zagreb
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

-- $Id$


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bram is
    generic(
	C_mem_size: integer
    );
    port(
	clk: in std_logic;
	imem_addr_strobe: in std_logic;
	imem_data_ready: out std_logic;
	imem_addr: in std_logic_vector(31 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	dmem_addr_strobe: in std_logic;
	dmem_data_ready: out std_logic;
	dmem_write: in std_logic;
	dmem_byte_sel: in std_logic_vector(3 downto 0);
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0)
    );
end bram;

architecture x of bram is
    type bram_type is array(0 to (C_mem_size * 256 - 1))
      of std_logic_vector(7 downto 0);
    signal bram_0: bram_type := (
	x"00", x"00", x"f8", x"09", x"00", x"f8", x"00", x"10", 
	x"21", x"24", x"08", x"25", x"00", x"00", x"0d", x"01", 
	x"03", x"00", x"53", x"ec", x"00", x"01", x"05", x"04", 
	x"fd", x"00", x"04", x"00", x"f8", x"ff", x"ff", x"29", 
	x"02", x"21", x"3a", x"21", x"ff", x"ff", x"2b", x"02", 
	x"21", x"10", x"00", x"00", x"24", x"02", x"21", x"ff", 
	x"c3", x"ff", x"ff", x"2a", x"03", x"00", x"3b", x"0f", 
	x"3b", x"f0", x"03", x"00", x"05", x"01", x"ea", x"00", 
	x"07", x"04", x"de", x"00", x"d1", x"00", x"14", x"ec", 
	x"db", x"00", x"61", x"03", x"d0", x"52", x"e0", x"41", 
	x"03", x"25", x"c9", x"25", x"01", x"0f", x"f9", x"03", 
	x"06", x"ff", x"f8", x"a9", x"00", x"05", x"00", x"03", 
	x"c7", x"00", x"21", x"28", x"05", x"04", x"00", x"21", 
	x"28", x"21", x"07", x"2a", x"f8", x"21", x"ba", x"21", 
	x"29", x"f8", x"b6", x"01", x"b4", x"2a", x"b2", x"00", 
	x"00", x"29", x"01", x"0d", x"32", x"65", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_1: bram_type := (
	x"00", x"00", x"01", x"00", x"00", x"01", x"80", x"00", 
	x"f8", x"e8", x"00", x"e8", x"00", x"08", x"00", x"00", 
	x"00", x"00", x"00", x"01", x"00", x"00", x"80", x"00", 
	x"ff", x"00", x"80", x"00", x"ff", x"00", x"ff", x"00", 
	x"00", x"10", x"00", x"18", x"00", x"ff", x"00", x"00", 
	x"10", x"00", x"00", x"48", x"50", x"00", x"20", x"00", 
	x"54", x"00", x"00", x"c8", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"22", x"80", x"80", x"00", x"ff", x"00", 
	x"00", x"80", x"ff", x"00", x"ff", x"00", x"00", x"01", 
	x"ff", x"51", x"00", x"00", x"ff", x"00", x"ff", x"00", 
	x"00", x"10", x"ff", x"10", x"00", x"00", x"ff", x"00", 
	x"00", x"ff", x"01", x"ff", x"00", x"00", x"02", x"00", 
	x"ff", x"00", x"30", x"00", x"00", x"00", x"00", x"10", 
	x"00", x"38", x"00", x"50", x"01", x"28", x"ff", x"30", 
	x"00", x"01", x"ff", x"00", x"ff", x"20", x"ff", x"00", 
	x"00", x"00", x"00", x"0a", x"63", x"3e", x"02", x"00", 
	others => (others => '0')
    );
    signal bram_2: bram_type := (
	x"00", x"08", x"03", x"60", x"0b", x"00", x"04", x"05", 
	x"00", x"64", x"60", x"a5", x"0b", x"0c", x"09", x"0d", 
	x"0e", x"0f", x"18", x"65", x"a4", x"a5", x"03", x"66", 
	x"c0", x"00", x"04", x"a4", x"80", x"06", x"03", x"00", 
	x"07", x"00", x"00", x"00", x"06", x"03", x"00", x"07", 
	x"00", x"61", x"00", x"02", x"4c", x"40", x"00", x"04", 
	x"02", x"59", x"4a", x"59", x"20", x"00", x"00", x"84", 
	x"00", x"84", x"05", x"04", x"04", x"8a", x"40", x"00", 
	x"61", x"04", x"98", x"00", x"89", x"00", x"00", x"65", 
	x"89", x"02", x"82", x"40", x"82", x"00", x"84", x"99", 
	x"20", x"4a", x"84", x"8a", x"63", x"6d", x"59", x"24", 
	x"80", x"4a", x"03", x"60", x"00", x"00", x"03", x"59", 
	x"20", x"00", x"42", x"00", x"c6", x"6e", x"00", x"42", 
	x"00", x"e2", x"66", x"c3", x"0a", x"40", x"40", x"60", 
	x"00", x"e2", x"40", x"79", x"20", x"67", x"80", x"00", 
	x"a2", x"00", x"a5", x"66", x"2f", x"20", x"00", x"00", 
	others => (others => '0')
    );
    signal bram_3: bram_type := (
	x"00", x"3c", x"8d", x"10", x"3c", x"ad", x"3c", x"3c", 
	x"00", x"00", x"00", x"03", x"3c", x"3c", x"24", x"24", 
	x"24", x"3c", x"24", x"25", x"80", x"24", x"80", x"30", 
	x"14", x"00", x"a0", x"80", x"14", x"24", x"24", x"08", 
	x"24", x"00", x"08", x"00", x"24", x"24", x"08", x"24", 
	x"00", x"04", x"00", x"40", x"00", x"11", x"00", x"24", 
	x"00", x"30", x"31", x"01", x"13", x"00", x"08", x"38", 
	x"08", x"38", x"00", x"a0", x"80", x"30", x"11", x"00", 
	x"04", x"80", x"10", x"00", x"14", x"00", x"08", x"25", 
	x"10", x"00", x"28", x"14", x"24", x"08", x"24", x"28", 
	x"17", x"00", x"24", x"00", x"24", x"14", x"24", x"2f", 
	x"10", x"24", x"8d", x"14", x"00", x"08", x"24", x"2d", 
	x"13", x"00", x"00", x"08", x"24", x"14", x"00", x"00", 
	x"08", x"00", x"14", x"00", x"8d", x"00", x"15", x"00", 
	x"08", x"ad", x"11", x"30", x"13", x"00", x"10", x"00", 
	x"a0", x"08", x"24", x"33", x"6c", x"00", x"00", x"00", 
	others => (others => '0')
    );

    -- Lattice Diamond attributes
    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bram_0: signal is "no_rw_check";
    attribute syn_ramstyle of bram_1: signal is "no_rw_check";
    attribute syn_ramstyle of bram_2: signal is "no_rw_check";
    attribute syn_ramstyle of bram_3: signal is "no_rw_check";

    -- Xilinx XST attributes
    attribute ram_style: string;
    attribute ram_style of bram_0: signal is "no_rw_check";
    attribute ram_style of bram_1: signal is "no_rw_check";
    attribute ram_style of bram_2: signal is "no_rw_check";
    attribute ram_style of bram_3: signal is "no_rw_check";

    -- Altera Quartus attributes
    attribute ramstyle: string;
    attribute ramstyle of bram_0: signal is "no_rw_check";
    attribute ramstyle of bram_1: signal is "no_rw_check";
    attribute ramstyle of bram_2: signal is "no_rw_check";
    attribute ramstyle of bram_3: signal is "no_rw_check";

    signal ibram_0, ibram_1, ibram_2, ibram_3: std_logic_vector(7 downto 0);
    signal dbram_0, dbram_1, dbram_2, dbram_3: std_logic_vector(7 downto 0);

begin

    imem_data_ready <= '1';
    dmem_data_ready <= '1';

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' then
		if dmem_write = '1' and dmem_byte_sel(0) = '1' then
		    bram_0(conv_integer(dmem_addr)) <=
		      dmem_data_in(7 downto 0);
		end if;
		dbram_0 <= bram_0(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_0 <= bram_0(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(1) = '1' then
		if dmem_write = '1' then
		    bram_1(conv_integer(dmem_addr)) <=
		      dmem_data_in(15 downto 8);
		end if;
		dbram_1 <= bram_1(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_1 <= bram_1(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(2) = '1' then
		if dmem_write = '1' then
		    bram_2(conv_integer(dmem_addr)) <=
		      dmem_data_in(23 downto 16);
		end if;
		dbram_2 <= bram_2(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_2 <= bram_2(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_byte_sel(3) = '1' then
		if dmem_write = '1' then
		    bram_3(conv_integer(dmem_addr)) <=
		      dmem_data_in(31 downto 24);
		end if;
		dbram_3 <= bram_3(conv_integer(dmem_addr));
	    end if;
	    if imem_addr_strobe = '1' then
		ibram_3 <= bram_3(conv_integer(imem_addr));
	    end if;
	end if;
    end process;
end x;
