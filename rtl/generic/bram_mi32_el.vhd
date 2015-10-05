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


entity bram_mi32_el is
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
end bram_mi32_el;

architecture x of bram_mi32_el is
    type bram_type is array(0 to (C_mem_size * 256 - 1))
      of std_logic_vector(7 downto 0);

    type boot_block_type is array(0 to 1023) of std_logic_vector(7 downto 0);

    constant boot_block : boot_block_type := (
x"00", x"00", x"00", x"00", x"21", x"40", x"00", x"00",
x"21", x"30", x"00", x"00", x"21", x"10", x"00", x"00",
x"6D", x"33", x"0A", x"3C", x"3E", x"20", x"0B", x"3C",
x"00", x"08", x"0C", x"3C", x"01", x"00", x"0D", x"24",
x"03", x"00", x"0E", x"24", x"53", x"00", x"0F", x"24",
x"0D", x"00", x"18", x"24", x"21", x"C8", x"00", x"00",
x"0D", x"0A", x"43", x"25", x"01", x"FB", x"05", x"80",
x"04", x"00", x"A7", x"30", x"FD", x"FF", x"E0", x"14",
x"00", x"00", x"00", x"00", x"00", x"FB", x"03", x"A0",
x"03", x"1A", x"03", x"00", x"25", x"48", x"79", x"00",
x"04", x"00", x"20", x"15", x"00", x"00", x"00", x"00",
x"FF", x"FF", x"19", x"24", x"0D", x"00", x"00", x"08",
x"32", x"6C", x"63", x"25", x"F3", x"FF", x"60", x"14",
x"FF", x"00", x"05", x"24", x"FF", x"FF", x"03", x"24",
x"02", x"00", x"07", x"24", x"1B", x"00", x"61", x"04",
x"00", x"00", x"00", x"00", x"00", x"48", x"02", x"40",
x"24", x"C8", x"4C", x"00", x"02", x"00", x"20", x"13",
x"21", x"20", x"00", x"00", x"FF", x"00", x"04", x"24",
x"C3", x"CC", x"02", x"00", x"FF", x"00", x"49", x"30",
x"FF", x"00", x"39", x"33", x"2A", x"48", x"29", x"03",
x"03", x"00", x"20", x"11", x"00", x"00", x"00", x"00",
x"2D", x"00", x"00", x"08", x"0F", x"00", x"84", x"38",
x"F0", x"00", x"84", x"38", x"10", x"FF", x"04", x"A0",
x"01", x"FB", x"04", x"80", x"01", x"00", x"99", x"30",
x"EC", x"FF", x"20", x"13", x"00", x"00", x"00", x"00",
x"00", x"FB", x"04", x"80", x"18", x"00", x"61", x"04",
x"F6", x"FF", x"89", x"24", x"05", x"00", x"8F", x"14",
x"FF", x"FF", x"19", x"24", x"21", x"10", x"00", x"00",
x"21", x"18", x"00", x"00", x"2D", x"00", x"00", x"08",
x"03", x"22", x"06", x"00", x"05", x"00", x"99", x"14",
x"00", x"00", x"00", x"00", x"8D", x"00", x"00", x"08",
x"00", x"00", x"00", x"00", x"1D", x"00", x"00", x"08",
x"21", x"10", x"00", x"00", x"CA", x"FF", x"98", x"10",
x"21", x"C8", x"00", x"00", x"20", x"00", x"82", x"28",
x"D8", x"FF", x"40", x"14", x"21", x"10", x"00", x"00",
x"01", x"FB", x"09", x"80", x"04", x"00", x"22", x"31",
x"FD", x"FF", x"40", x"14", x"00", x"00", x"00", x"00",
x"1D", x"00", x"00", x"08", x"00", x"FB", x"04", x"A0",
x"04", x"00", x"39", x"2D", x"05", x"00", x"20", x"13",
x"00", x"49", x"02", x"00", x"FF", x"00", x"05", x"24",
x"FF", x"FF", x"03", x"24", x"1F", x"00", x"00", x"08",
x"02", x"00", x"07", x"24", x"61", x"00", x"82", x"28",
x"03", x"00", x"40", x"14", x"D0", x"FF", x"82", x"24",
x"5B", x"00", x"00", x"08", x"E0", x"FF", x"84", x"24",
x"41", x"00", x"99", x"28", x"03", x"00", x"20", x"17",
x"25", x"10", x"49", x"00", x"C9", x"FF", x"84", x"24",
x"25", x"10", x"89", x"00", x"01", x"00", x"63", x"24",
x"16", x"00", x"6D", x"14", x"F9", x"FF", x"59", x"24",
x"03", x"00", x"24", x"2F", x"0E", x"00", x"80", x"10",
x"04", x"00", x"49", x"28", x"00", x"80", x"04", x"3C",
x"00", x"10", x"05", x"3C", x"24", x"E8", x"04", x"01",
x"04", x"00", x"A0", x"13", x"00", x"40", x"02", x"24",
x"00", x"00", x"40", x"BC", x"FE", x"FF", x"40", x"14",
x"FC", x"FF", x"42", x"24", x"21", x"F8", x"00", x"00",
x"08", x"00", x"00", x"01", x"25", x"E8", x"A5", x"03",
x"1D", x"00", x"00", x"08", x"21", x"10", x"00", x"00",
x"08", x"00", x"20", x"11", x"00", x"00", x"00", x"00",
x"21", x"28", x"42", x"00", x"79", x"00", x"00", x"08",
x"05", x"00", x"A5", x"24", x"05", x"00", x"6E", x"14",
x"06", x"00", x"A9", x"28", x"21", x"10", x"42", x"00",
x"21", x"38", x"E2", x"00", x"1D", x"00", x"00", x"08",
x"21", x"10", x"00", x"00", x"A1", x"FF", x"20", x"15",
x"00", x"00", x"00", x"00", x"06", x"00", x"65", x"14",
x"2A", x"C8", x"A3", x"00", x"02", x"00", x"00", x"15",
x"21", x"30", x"40", x"00", x"21", x"40", x"40", x"00",
x"1D", x"00", x"00", x"08", x"21", x"28", x"60", x"00",
x"98", x"FF", x"20", x"13", x"01", x"00", x"64", x"30",
x"96", x"FF", x"80", x"10", x"2A", x"48", x"67", x"00",
x"94", x"FF", x"20", x"11", x"00", x"00", x"00", x"00",
x"00", x"00", x"C2", x"A0", x"1D", x"00", x"00", x"08",
x"01", x"00", x"C6", x"24", x"21", x"30", x"00", x"00",
x"21", x"18", x"00", x"00", x"21", x"20", x"00", x"00",
x"90", x"00", x"07", x"24", x"A0", x"00", x"08", x"24",
x"B1", x"00", x"09", x"24", x"91", x"00", x"0A", x"24",
x"80", x"00", x"0B", x"24", x"81", x"00", x"0C", x"24",
x"00", x"48", x"02", x"40", x"02", x"2E", x"02", x"00",
x"10", x"FF", x"05", x"A0", x"01", x"FB", x"0D", x"80",
x"01", x"00", x"AE", x"31", x"FA", x"FF", x"C0", x"11",
x"00", x"00", x"00", x"00", x"00", x"FB", x"0F", x"80",
x"FF", x"00", x"F8", x"31", x"11", x"00", x"07", x"13",
x"91", x"00", x"19", x"2F", x"07", x"00", x"20", x"13",
x"00", x"00", x"00", x"00", x"0F", x"00", x"0B", x"13",
x"04", x"00", x"0F", x"24", x"3E", x"00", x"0C", x"17",
x"21", x"28", x"80", x"00", x"C7", x"00", x"00", x"08",
x"04", x"00", x"02", x"24", x"1F", x"00", x"08", x"13",
x"21", x"10", x"00", x"00", x"2D", x"00", x"09", x"13",
x"00", x"00", x"00", x"00", x"36", x"00", x"0A", x"17",
x"00", x"00", x"00", x"00", x"96", x"00", x"00", x"08",
x"21", x"20", x"60", x"00", x"96", x"00", x"00", x"08",
x"21", x"30", x"60", x"00", x"00", x"1A", x"03", x"00",
x"01", x"FB", x"18", x"80", x"01", x"00", x"19", x"33",
x"FD", x"FF", x"20", x"13", x"00", x"00", x"00", x"00",
x"00", x"FB", x"0D", x"80", x"FF", x"00", x"AE", x"31",
x"FF", x"FF", x"EF", x"25", x"F7", x"FF", x"E0", x"15",
x"21", x"18", x"C3", x"01", x"96", x"00", x"00", x"08",
x"00", x"00", x"00", x"00", x"01", x"FB", x"0E", x"80",
x"04", x"00", x"CF", x"31", x"FD", x"FF", x"E0", x"15",
x"00", x"00", x"00", x"00", x"00", x"FB", x"0D", x"A0",
x"FF", x"FF", x"42", x"24", x"D0", x"FF", x"40", x"10",
x"00", x"2A", x"05", x"00", x"BF", x"00", x"00", x"08",
x"03", x"6E", x"05", x"00", x"21", x"20", x"00", x"00",
x"CB", x"FF", x"46", x"10", x"C2", x"2F", x"04", x"00",
x"21", x"20", x"84", x"00", x"25", x"C0", x"85", x"00",
x"01", x"FB", x"19", x"80", x"01", x"00", x"2D", x"33",
x"FD", x"FF", x"A0", x"11", x"00", x"00", x"00", x"00",
x"00", x"FB", x"0F", x"80", x"21", x"70", x"43", x"00",
x"FF", x"00", x"E5", x"31", x"00", x"00", x"CF", x"A1",
x"21", x"20", x"B8", x"00", x"CA", x"00", x"00", x"08",
x"01", x"00", x"42", x"24", x"00", x"80", x"04", x"3C",
x"00", x"10", x"05", x"3C", x"24", x"E8", x"64", x"00",
x"04", x"00", x"A0", x"13", x"00", x"40", x"02", x"24",
x"00", x"00", x"40", x"BC", x"FE", x"FF", x"40", x"14",
x"FC", x"FF", x"42", x"24", x"21", x"F8", x"00", x"00",
x"08", x"00", x"60", x"00", x"25", x"E8", x"A5", x"03",
x"08", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
x"96", x"00", x"00", x"08", x"00", x"00", x"00", x"00",
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
