--
-- Copyright (c) 2013 - 2015 Marko Zec, University of Zagreb
-- Copyright (c) 2015 Davor Jadrijevic
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


entity bram_mi32_eb is
    generic(
	C_write_protect_bootloader: boolean := true;
	C_mem_size: integer
    );
    port(
	clk: in std_logic;
	imem_addr: in std_logic_vector(31 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	dmem_write: in std_logic;
	dmem_byte_sel: in std_logic_vector(3 downto 0);
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0)
    );
end bram_mi32_eb;

architecture x of bram_mi32_eb is
    type bram_type is array(0 to (C_mem_size * 256 - 1))
      of std_logic_vector(7 downto 0);

    type boot_block_type is array(0 to 1023) of std_logic_vector(7 downto 0);

    constant boot_block : boot_block_type := (
	x"00", x"00", x"00", x"00", x"00", x"00", x"40", x"21", 
	x"00", x"00", x"30", x"21", x"3c", x"0a", x"33", x"6d", 
	x"3c", x"0b", x"20", x"3e", x"3c", x"0c", x"08", x"00", 
	x"24", x"0d", x"00", x"01", x"24", x"0e", x"00", x"03", 
	x"24", x"0f", x"00", x"53", x"24", x"18", x"00", x"0d", 
	x"00", x"00", x"c8", x"21", x"25", x"43", x"0a", x"0d", 
	x"80", x"05", x"fb", x"01", x"30", x"a7", x"00", x"04", 
	x"14", x"e0", x"ff", x"fd", x"00", x"00", x"00", x"00", 
	x"a0", x"03", x"fb", x"00", x"00", x"03", x"1a", x"03", 
	x"00", x"79", x"48", x"25", x"15", x"20", x"00", x"04", 
	x"00", x"00", x"00", x"00", x"24", x"19", x"ff", x"ff", 
	x"08", x"00", x"00", x"0c", x"25", x"63", x"62", x"32", 
	x"14", x"60", x"ff", x"f3", x"24", x"05", x"00", x"ff", 
	x"24", x"03", x"ff", x"ff", x"24", x"07", x"00", x"02", 
	x"04", x"61", x"00", x"1b", x"00", x"00", x"00", x"00", 
	x"40", x"02", x"48", x"00", x"00", x"4c", x"c8", x"24", 
	x"13", x"20", x"00", x"02", x"00", x"00", x"20", x"21", 
	x"24", x"04", x"00", x"ff", x"00", x"02", x"cc", x"c3", 
	x"30", x"49", x"00", x"ff", x"33", x"39", x"00", x"ff", 
	x"03", x"29", x"48", x"2a", x"11", x"20", x"00", x"03", 
	x"00", x"00", x"00", x"00", x"08", x"00", x"00", x"2c", 
	x"38", x"84", x"00", x"0f", x"38", x"84", x"00", x"f0", 
	x"a0", x"04", x"ff", x"10", x"80", x"04", x"fb", x"01", 
	x"30", x"99", x"00", x"01", x"13", x"20", x"ff", x"ec", 
	x"00", x"00", x"00", x"00", x"80", x"04", x"fb", x"00", 
	x"04", x"61", x"00", x"18", x"24", x"89", x"ff", x"f6", 
	x"14", x"8f", x"00", x"05", x"24", x"19", x"ff", x"ff", 
	x"00", x"00", x"10", x"21", x"00", x"00", x"18", x"21", 
	x"08", x"00", x"00", x"2c", x"00", x"06", x"22", x"03", 
	x"14", x"99", x"00", x"05", x"00", x"00", x"00", x"00", 
	x"08", x"00", x"00", x"87", x"00", x"00", x"00", x"00", 
	x"08", x"00", x"00", x"1c", x"00", x"00", x"10", x"21", 
	x"10", x"98", x"ff", x"ca", x"00", x"00", x"c8", x"21", 
	x"28", x"82", x"00", x"20", x"14", x"40", x"ff", x"d8", 
	x"00", x"00", x"10", x"21", x"80", x"09", x"fb", x"01", 
	x"31", x"22", x"00", x"04", x"14", x"40", x"ff", x"fd", 
	x"00", x"00", x"00", x"00", x"08", x"00", x"00", x"1c", 
	x"a0", x"04", x"fb", x"00", x"2d", x"39", x"00", x"04", 
	x"13", x"20", x"00", x"05", x"00", x"02", x"49", x"00", 
	x"24", x"05", x"00", x"ff", x"24", x"03", x"ff", x"ff", 
	x"08", x"00", x"00", x"1e", x"24", x"07", x"00", x"02", 
	x"28", x"82", x"00", x"61", x"14", x"40", x"00", x"03", 
	x"24", x"82", x"ff", x"d0", x"08", x"00", x"00", x"5a", 
	x"24", x"84", x"ff", x"e0", x"28", x"99", x"00", x"41", 
	x"17", x"20", x"00", x"03", x"00", x"49", x"10", x"25", 
	x"24", x"84", x"ff", x"c9", x"00", x"89", x"10", x"25", 
	x"24", x"63", x"00", x"01", x"14", x"6d", x"00", x"11", 
	x"24", x"59", x"ff", x"f9", x"2f", x"24", x"00", x"03", 
	x"10", x"80", x"00", x"09", x"28", x"49", x"00", x"04", 
	x"3c", x"04", x"80", x"00", x"3c", x"05", x"00", x"10", 
	x"01", x"04", x"e8", x"24", x"00", x"00", x"f8", x"21", 
	x"01", x"00", x"00", x"08", x"03", x"a5", x"e8", x"25", 
	x"08", x"00", x"00", x"1c", x"00", x"00", x"10", x"21", 
	x"11", x"20", x"00", x"08", x"00", x"00", x"00", x"00", 
	x"00", x"42", x"28", x"21", x"08", x"00", x"00", x"73", 
	x"24", x"a5", x"00", x"05", x"14", x"6e", x"00", x"05", 
	x"28", x"a9", x"00", x"06", x"00", x"42", x"10", x"21", 
	x"00", x"e2", x"38", x"21", x"08", x"00", x"00", x"1c", 
	x"00", x"00", x"10", x"21", x"15", x"20", x"ff", x"a6", 
	x"00", x"00", x"00", x"00", x"14", x"65", x"00", x"06", 
	x"00", x"a3", x"c8", x"2a", x"15", x"00", x"00", x"02", 
	x"00", x"40", x"30", x"21", x"00", x"40", x"40", x"21", 
	x"08", x"00", x"00", x"1c", x"00", x"60", x"28", x"21", 
	x"13", x"20", x"ff", x"9d", x"30", x"64", x"00", x"01", 
	x"10", x"80", x"ff", x"9b", x"00", x"67", x"48", x"2a", 
	x"11", x"20", x"ff", x"99", x"00", x"00", x"00", x"00", 
	x"a0", x"c2", x"00", x"00", x"08", x"00", x"00", x"1c", 
	x"24", x"c6", x"00", x"01", x"00", x"00", x"30", x"21", 
	x"00", x"00", x"18", x"21", x"00", x"00", x"20", x"21", 
	x"24", x"07", x"00", x"90", x"24", x"08", x"00", x"a0", 
	x"24", x"09", x"00", x"b1", x"24", x"0a", x"00", x"91", 
	x"24", x"0b", x"00", x"80", x"24", x"0c", x"00", x"81", 
	x"40", x"02", x"48", x"00", x"00", x"02", x"2e", x"02", 
	x"a0", x"05", x"ff", x"10", x"80", x"0d", x"fb", x"01", 
	x"31", x"ae", x"00", x"01", x"11", x"c0", x"ff", x"fa", 
	x"00", x"00", x"00", x"00", x"80", x"0f", x"fb", x"00", 
	x"31", x"f8", x"00", x"ff", x"13", x"07", x"00", x"11", 
	x"2f", x"19", x"00", x"91", x"13", x"20", x"00", x"07", 
	x"00", x"00", x"00", x"00", x"13", x"0b", x"00", x"0f", 
	x"24", x"0f", x"00", x"04", x"17", x"0c", x"00", x"37", 
	x"00", x"80", x"28", x"21", x"08", x"00", x"00", x"c1", 
	x"24", x"02", x"00", x"04", x"13", x"08", x"00", x"1f", 
	x"00", x"00", x"10", x"21", x"13", x"09", x"00", x"2b", 
	x"00", x"00", x"00", x"00", x"17", x"0a", x"00", x"2f", 
	x"00", x"00", x"00", x"00", x"08", x"00", x"00", x"90", 
	x"00", x"60", x"20", x"21", x"08", x"00", x"00", x"90", 
	x"00", x"60", x"30", x"21", x"00", x"03", x"1a", x"00", 
	x"80", x"18", x"fb", x"01", x"33", x"19", x"00", x"01", 
	x"13", x"20", x"ff", x"fd", x"00", x"00", x"00", x"00", 
	x"80", x"0d", x"fb", x"00", x"31", x"ae", x"00", x"ff", 
	x"25", x"ef", x"ff", x"ff", x"15", x"e0", x"ff", x"f7", 
	x"01", x"c3", x"18", x"21", x"08", x"00", x"00", x"90", 
	x"00", x"00", x"00", x"00", x"80", x"0e", x"fb", x"01", 
	x"31", x"cf", x"00", x"04", x"15", x"e0", x"ff", x"fd", 
	x"00", x"00", x"00", x"00", x"a0", x"0d", x"fb", x"00", 
	x"24", x"42", x"ff", x"ff", x"10", x"40", x"ff", x"d0", 
	x"00", x"05", x"2a", x"00", x"08", x"00", x"00", x"b9", 
	x"00", x"05", x"6e", x"03", x"00", x"00", x"20", x"21", 
	x"10", x"46", x"ff", x"cb", x"00", x"00", x"00", x"00", 
	x"80", x"05", x"fb", x"01", x"30", x"b8", x"00", x"01", 
	x"13", x"00", x"ff", x"fd", x"00", x"00", x"00", x"00", 
	x"80", x"19", x"fb", x"00", x"00", x"43", x"70", x"21", 
	x"33", x"2d", x"00", x"ff", x"a1", x"d9", x"00", x"00", 
	x"00", x"8d", x"20", x"21", x"08", x"00", x"00", x"c4", 
	x"24", x"42", x"00", x"01", x"3c", x"04", x"80", x"00", 
	x"3c", x"05", x"00", x"10", x"00", x"64", x"e8", x"24", 
	x"00", x"00", x"f8", x"21", x"00", x"60", x"00", x"08", 
	x"03", x"a5", x"e8", x"25", x"00", x"00", x"00", x"08", 
	x"00", x"00", x"00", x"00", x"08", x"00", x"00", x"90", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", 
	others => (others => '0')
    );

    --
    -- Xilinx ISE 14.7 for Spartan-3 will abort with error about loop 
    -- iteration limit >64 exceeded.  We need 128 iterations here.
    -- If buiding with makefile, edit file xilinx.opt file and
    -- append this line (give sufficiently large limit):
    -- -loop_iteration_limit 2048
    -- In ISE GUI, open the Design tab, right click on Synthesize - XST,
    -- choose Process Properties, choose Property display level: Advanced,
    -- scroll down to the "Other XST Command Line Options" field and
    -- enter: -loop_iteration_limit 2048
    --

    function boot_block_to_bram(x: boot_block_type; n: integer)
      return bram_type is
	variable y: bram_type;
	variable i,l: integer;
    begin
	y := (others => x"00");
	i := n;
	l := x'length;
	while(i < l) loop
	    y(i/4) := x(i);
	    i := i + 4;
	end loop;
	return y;
    end boot_block_to_bram;

    signal bram_0: bram_type := boot_block_to_bram(boot_block, 0);
    signal bram_1: bram_type := boot_block_to_bram(boot_block, 1);
    signal bram_2: bram_type := boot_block_to_bram(boot_block, 2);
    signal bram_3: bram_type := boot_block_to_bram(boot_block, 3);

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

    signal write_enable: boolean;

begin

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    G_rom_protection:
    if C_write_protect_bootloader generate
    with C_mem_size select write_enable <=
	dmem_addr(10 downto 10) /= 0 and dmem_write = '1' when 2,
	dmem_addr(11 downto 10) /= 0 and dmem_write = '1' when 4,
	dmem_addr(12 downto 10) /= 0 and dmem_write = '1' when 8,
	dmem_addr(13 downto 10) /= 0 and dmem_write = '1' when 16,
	dmem_addr(14 downto 10) /= 0 and dmem_write = '1' when 32,
	dmem_addr(15 downto 10) /= 0 and dmem_write = '1' when 64,
	dmem_addr(16 downto 10) /= 0 and dmem_write = '1' when 128,
	dmem_addr(17 downto 10) /= 0 and dmem_write = '1' when 256,
	dmem_addr(18 downto 10) /= 0 and dmem_write = '1' when 512,
	dmem_addr(19 downto 10) /= 0 and dmem_write = '1' when 1024,
	dmem_write = '1' when others;
    end generate;
    G_flat_ram:
    if not C_write_protect_bootloader generate
	write_enable <= dmem_write = '1';
    end generate;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(0) = '1' and write_enable then
		bram_0(conv_integer(dmem_addr)) <= dmem_data_in(7 downto 0);
	    end if;
	    dbram_0 <= bram_0(conv_integer(dmem_addr));
	    ibram_0 <= bram_0(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(1) = '1' and write_enable then
		bram_1(conv_integer(dmem_addr)) <= dmem_data_in(15 downto 8);
	    end if;
	    dbram_1 <= bram_1(conv_integer(dmem_addr));
	    ibram_1 <= bram_1(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(2) = '1' and write_enable then
		bram_2(conv_integer(dmem_addr)) <= dmem_data_in(23 downto 16);
	    end if;
	    dbram_2 <= bram_2(conv_integer(dmem_addr));
	    ibram_2 <= bram_2(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(3) = '1' and write_enable then
		bram_3(conv_integer(dmem_addr)) <= dmem_data_in(31 downto 24);
	    end if;
	    dbram_3 <= bram_3(conv_integer(dmem_addr));
	    ibram_3 <= bram_3(conv_integer(imem_addr));
	end if;
    end process;
end x;
