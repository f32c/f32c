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
use IEEE.NUMERIC_STD.ALL;
use work.font_block_pack.all;
use work.font8x8_xark.all;
use work.font8x16_xark.all;

entity VGA_textmode_bram is
    generic(
	C_mem_size:	integer:= 4;		-- 4 or 8 KB (8KB is required for color)
	C_label: string := "VGA";
	C_monochrome: boolean := true;
	C_font_height: integer := 16;	-- font height 8 or 16 (8 line font is line doubled to 16)
	C_font_depth: integer:= 7		-- 7=128 or 8=256 character glyphs in character set
    );
    port(
	clk: in std_logic;
	imem_addr: in std_logic_vector(15 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	dmem_write: in std_logic;
	dmem_byte_sel: in std_logic_vector(3 downto 0);
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0)
    );
end VGA_textmode_bram;

architecture x of VGA_textmode_bram is

    type bram_type is array(0 to (C_mem_size*256)-1) of std_logic_vector(7 downto 0);

    --
    -- Xilinx ISE 14.7 for Spartan-3 will abort with error about loop
    -- iteration limit >64 exceeded.  We need 128 iterations here.
    -- If building with makefile, edit file xilinx.opt file and
    -- append this line (give sufficiently large limit):
    -- -loop_iteration_limit 2048
    -- In ISE GUI, open the Design tab, right click on Synthesize - XST,
    -- choose Process Properties, choose Property display level: Advanced,
    -- scroll down to the "Other XST Command Line Options" field and
    -- enter: -loop_iteration_limit 2048
    --

    function font_block_to_bram(font8: font8_block_type; font16: font16_block_type; len: integer; addr: integer; n: integer)
      return bram_type is
	variable y: bram_type;
	variable i, l: integer;
    begin
	if C_monochrome then
		y := (others => x"00");
	else
		if (n MOD 2) = 1 then
			y := (others => x"1F");
		else
			y := (others => x"00");
		end if;
	end if;
	i := n;
	if C_monochrome then
		while (i < C_label'length) loop
			y(i/4) := std_logic_vector(to_unsigned(character'pos(C_label(i+1)), 8));
		i := i + 4;
		end loop;
	else
		while (i < C_label'length*2) loop
			if (n MOD 2) = 0 then
				y(i/4) := std_logic_vector(to_unsigned(character'pos(C_label((i/2)+1)), 8));
			end if;
		i := i + 4;
		end loop;
	end if;

	i := n;
	while(i < len) loop
		if C_font_height = 8 then
			y((addr+i)/4) := font8(i);
		else
			y((addr+i)/4) := font16(i);
		end if;
	    i := i + 4;
	end loop;
	return y;
    end font_block_to_bram;

    signal bram_0: bram_type := font_block_to_bram(font8x8_block, font8x16_block, C_font_height*(2**C_font_depth), (C_mem_size*1024)-(C_font_height*(2**C_font_depth)), 0);
    signal bram_1: bram_type := font_block_to_bram(font8x8_block, font8x16_block, C_font_height*(2**C_font_depth), (C_mem_size*1024)-(C_font_height*(2**C_font_depth)), 1);
    signal bram_2: bram_type := font_block_to_bram(font8x8_block, font8x16_block, C_font_height*(2**C_font_depth), (C_mem_size*1024)-(C_font_height*(2**C_font_depth)), 2);
    signal bram_3: bram_type := font_block_to_bram(font8x8_block, font8x16_block, C_font_height*(2**C_font_depth), (C_mem_size*1024)-(C_font_height*(2**C_font_depth)), 3);

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

	write_enable <= dmem_write = '1';

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(0) = '1' and write_enable then
		bram_0(to_integer(unsigned(dmem_addr))) <= dmem_data_in(7 downto 0);
	    end if;
	    dbram_0 <= bram_0(to_integer(unsigned(dmem_addr)));
	    ibram_0 <= bram_0(to_integer(unsigned(imem_addr)));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(1) = '1' and write_enable then
		bram_1(to_integer(unsigned(dmem_addr))) <= dmem_data_in(15 downto 8);
	    end if;
	    dbram_1 <= bram_1(to_integer(unsigned(dmem_addr)));
	    ibram_1 <= bram_1(to_integer(unsigned(imem_addr)));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(2) = '1' and write_enable then
		bram_2(to_integer(unsigned(dmem_addr))) <= dmem_data_in(23 downto 16);
	    end if;
	    dbram_2 <= bram_2(to_integer(unsigned(dmem_addr)));
	    ibram_2 <= bram_2(to_integer(unsigned(imem_addr)));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(3) = '1' and write_enable then
		bram_3(to_integer(unsigned(dmem_addr))) <= dmem_data_in(31 downto 24);
	    end if;
	    dbram_3 <= bram_3(to_integer(unsigned(dmem_addr)));
	    ibram_3 <= bram_3(to_integer(unsigned(imem_addr)));
	end if;
    end process;
end x;
