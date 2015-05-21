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


entity bram_rv32 is
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
end bram_rv32;

architecture x of bram_rv32 is
    type bram_type is array(0 to (C_mem_size * 256 - 1))
      of std_logic_vector(7 downto 0);

    type boot_block_type is array(0 to 1023) of std_logic_vector(7 downto 0);

    constant boot_block : boot_block_type := (
	x"13", x"01", x"01", x"fe", x"23", x"2e", x"11", x"00", 
	x"23", x"2c", x"81", x"00", x"23", x"2a", x"91", x"00", 
	x"23", x"28", x"21", x"01", x"23", x"26", x"31", x"01", 
	x"23", x"24", x"41", x"01", x"23", x"22", x"51", x"01", 
	x"23", x"20", x"61", x"01", x"13", x"00", x"00", x"00", 
	x"13", x"08", x"00", x"00", x"93", x"05", x"00", x"00", 
	x"93", x"07", x"00", x"00", x"b7", x"13", x"72", x"76", 
	x"37", x"3e", x"3e", x"20", x"b7", x"0e", x"00", x"08", 
	x"93", x"08", x"30", x"00", x"13", x"0f", x"00", x"06", 
	x"93", x"0f", x"10", x"00", x"93", x"00", x"50", x"00", 
	x"13", x"04", x"00", x"04", x"93", x"04", x"30", x"05", 
	x"13", x"09", x"d0", x"00", x"93", x"09", x"f0", x"01", 
	x"93", x"0a", x"00", x"00", x"13", x"87", x"d3", x"a0", 
	x"03", x"06", x"10", x"b0", x"93", x"12", x"d6", x"01", 
	x"e3", x"cc", x"02", x"fe", x"23", x"00", x"e0", x"b0", 
	x"13", x"57", x"87", x"40", x"33", x"63", x"57", x"01", 
	x"63", x"18", x"03", x"00", x"93", x"0a", x"f0", x"ff", 
	x"13", x"07", x"3e", x"23", x"6f", x"f0", x"df", x"fd", 
	x"e3", x"1c", x"07", x"fc", x"13", x"07", x"f0", x"ff", 
	x"13", x"05", x"20", x"00", x"13", x"06", x"f0", x"0f", 
	x"13", x"03", x"05", x"00", x"13", x"0a", x"07", x"00", 
	x"93", x"da", x"85", x"40", x"63", x"5e", x"07", x"02", 
	x"f3", x"27", x"10", x"c0", x"b3", x"f6", x"d7", x"01", 
	x"33", x"3b", x"d0", x"00", x"b3", x"02", x"60", x"41", 
	x"93", x"f6", x"f2", x"0f", x"93", x"d2", x"37", x"41", 
	x"13", x"fb", x"f7", x"0f", x"93", x"f2", x"f2", x"0f", 
	x"63", x"d6", x"62", x"01", x"93", x"c6", x"f6", x"00", 
	x"6f", x"00", x"80", x"00", x"93", x"c6", x"06", x"0f", 
	x"23", x"08", x"d0", x"f0", x"6f", x"00", x"80", x"00", 
	x"23", x"08", x"50", x"f1", x"03", x"0b", x"10", x"b0", 
	x"93", x"12", x"fb", x"01", x"e3", x"dc", x"02", x"fa", 
	x"83", x"0a", x"00", x"b0", x"63", x"52", x"07", x"04", 
	x"63", x"98", x"9a", x"00", x"93", x"07", x"00", x"00", 
	x"13", x"07", x"00", x"00", x"6f", x"f0", x"df", x"f9", 
	x"63", x"98", x"4a", x"01", x"6f", x"00", x"c0", x"0d", 
	x"93", x"07", x"00", x"00", x"6f", x"f0", x"df", x"f8", 
	x"e3", x"80", x"2a", x"f5", x"93", x"07", x"00", x"00", 
	x"e3", x"d0", x"59", x"f9", x"83", x"07", x"10", x"b0", 
	x"93", x"96", x"d7", x"01", x"e3", x"cc", x"06", x"fe", 
	x"23", x"00", x"50", x"b1", x"6f", x"f0", x"df", x"fd", 
	x"93", x"86", x"6a", x"ff", x"e3", x"f8", x"d8", x"f4", 
	x"13", x"9b", x"47", x"00", x"63", x"56", x"5f", x"01", 
	x"93", x"8a", x"0a", x"fe", x"6f", x"00", x"00", x"01", 
	x"93", x"87", x"0a", x"fd", x"b3", x"e7", x"67", x"01", 
	x"63", x"56", x"54", x"01", x"93", x"82", x"9a", x"fc", 
	x"b3", x"e7", x"62", x"01", x"13", x"07", x"17", x"00", 
	x"63", x"1c", x"f7", x"03", x"13", x"8b", x"97", x"ff", 
	x"63", x"60", x"63", x"03", x"37", x"04", x"00", x"08", 
	x"b7", x"04", x"01", x"00", x"33", x"71", x"88", x"00", 
	x"33", x"61", x"91", x"00", x"93", x"00", x"00", x"00", 
	x"67", x"00", x"08", x"00", x"6f", x"f0", x"5f", x"f8", 
	x"e3", x"c0", x"f8", x"f8", x"93", x"92", x"17", x"00", 
	x"13", x"86", x"52", x"00", x"6f", x"f0", x"5f", x"f7", 
	x"63", x"18", x"17", x"01", x"93", x"96", x"17", x"00", 
	x"33", x"05", x"d5", x"00", x"6f", x"f0", x"5f", x"f6", 
	x"e3", x"d8", x"c0", x"ee", x"63", x"1c", x"c7", x"00", 
	x"93", x"85", x"07", x"00", x"13", x"06", x"07", x"00", 
	x"e3", x"10", x"08", x"ee", x"13", x"88", x"07", x"00", 
	x"6f", x"f0", x"9f", x"ed", x"e3", x"5a", x"e6", x"ec", 
	x"93", x"1a", x"f7", x"01", x"e3", x"d6", x"0a", x"ec", 
	x"e3", x"54", x"a7", x"ec", x"23", x"80", x"f5", x"00", 
	x"93", x"85", x"15", x"00", x"6f", x"f0", x"df", x"eb", 
	x"13", x"05", x"00", x"09", x"93", x"05", x"00", x"00", 
	x"93", x"06", x"00", x"00", x"93", x"07", x"00", x"00", 
	x"93", x"08", x"05", x"00", x"93", x"02", x"00", x"0a", 
	x"13", x"03", x"10", x"0b", x"93", x"03", x"10", x"09", 
	x"13", x"0e", x"00", x"08", x"93", x"0e", x"10", x"08", 
	x"73", x"27", x"10", x"c0", x"13", x"56", x"87", x"01", 
	x"23", x"08", x"c0", x"f0", x"03", x"08", x"10", x"b0", 
	x"13", x"1f", x"f8", x"01", x"e3", x"56", x"0f", x"fe", 
	x"83", x"0f", x"00", x"b0", x"13", x"f7", x"ff", x"0f", 
	x"63", x"16", x"a7", x"00", x"93", x"85", x"06", x"00", 
	x"6f", x"f0", x"9f", x"fd", x"63", x"ec", x"e8", x"00", 
	x"63", x"04", x"c7", x"03", x"63", x"16", x"d7", x"0d", 
	x"13", x"86", x"07", x"00", x"13", x"07", x"40", x"00", 
	x"6f", x"00", x"00", x"06", x"63", x"02", x"57", x"06", 
	x"63", x"00", x"67", x"0a", x"63", x"1a", x"77", x"0a", 
	x"93", x"87", x"06", x"00", x"6f", x"f0", x"df", x"fa", 
	x"13", x"07", x"40", x"00", x"93", x"96", x"86", x"00", 
	x"03", x"08", x"10", x"b0", x"13", x"1f", x"f8", x"01", 
	x"e3", x"5c", x"0f", x"fe", x"83", x"0f", x"00", x"b0", 
	x"13", x"f6", x"ff", x"0f", x"13", x"07", x"f7", x"ff", 
	x"b3", x"06", x"d6", x"00", x"e3", x"10", x"07", x"fe", 
	x"6f", x"f0", x"1f", x"f8", x"03", x"0f", x"10", x"b0", 
	x"93", x"1f", x"df", x"01", x"e3", x"cc", x"0f", x"fe", 
	x"23", x"00", x"00", x"b1", x"13", x"07", x"f7", x"ff", 
	x"13", x"16", x"86", x"00", x"e3", x"02", x"07", x"f6", 
	x"13", x"58", x"86", x"01", x"6f", x"f0", x"1f", x"fe", 
	x"93", x"07", x"00", x"00", x"13", x"06", x"00", x"00", 
	x"e3", x"08", x"b6", x"f4", x"13", x"98", x"17", x"00", 
	x"93", x"d7", x"f7", x"01", x"b3", x"ef", x"07", x"01", 
	x"03", x"0f", x"10", x"b0", x"13", x"17", x"ff", x"01", 
	x"e3", x"5c", x"07", x"fe", x"03", x"08", x"00", x"b0", 
	x"33", x"0f", x"d6", x"00", x"93", x"77", x"f8", x"0f", 
	x"23", x"00", x"0f", x"01", x"b3", x"87", x"f7", x"01", 
	x"13", x"06", x"16", x"00", x"6f", x"f0", x"df", x"fc", 
	x"37", x"04", x"00", x"08", x"b7", x"04", x"01", x"00", 
	x"33", x"f1", x"86", x"00", x"33", x"61", x"91", x"00", 
	x"93", x"00", x"00", x"00", x"67", x"80", x"06", x"00", 
	x"67", x"00", x"00", x"00", x"6f", x"f0", x"df", x"ef", 
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
