--
-- Copyright (c) 2015 Marko Zec, University of Zagreb
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

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
    signal write_enable: boolean;
    signal we_0, we_1, we_2: std_logic_vector(3 downto 0);
    signal imem_out_0: std_logic_vector(31 downto 0);
    signal imem_out_1: std_logic_vector(31 downto 0);
    signal imem_out_2: std_logic_vector(31 downto 0);
    signal dmem_out_0: std_logic_vector(31 downto 0);
    signal dmem_out_1: std_logic_vector(31 downto 0);
    signal dmem_out_2: std_logic_vector(31 downto 0);
begin

    G_rom_protection:
    if C_write_protect_bootloader generate
    with C_mem_size select write_enable <=
	dmem_addr(10 downto 10) /= 0 and dmem_write = '1' when 2,
	dmem_addr(11 downto 10) /= 0 and dmem_write = '1' when 4,
	dmem_addr(12 downto 10) /= 0 and dmem_write = '1' when 6,
	dmem_addr(12 downto 10) /= 0 and dmem_write = '1' when 8,
	dmem_write = '1' when others;
    end generate;
    G_flat_ram:
    if not C_write_protect_bootloader generate
	write_enable <= dmem_write = '1';
    end generate;

    we_0 <= dmem_byte_sel when write_enable and dmem_addr(12 downto 11) = "00"
	else x"0";
    we_1 <= dmem_byte_sel when dmem_write = '1' and dmem_addr(12 downto 11) = "01"
	else x"0";
    we_2 <= dmem_byte_sel when dmem_write = '1' and dmem_addr(12) = '1' else x"0";

    dmem_data_out <= dmem_out_0 when dmem_addr(12 downto 11) = "00"
	else dmem_out_1 when dmem_addr(12 downto 11) = "01"
	else dmem_out_2;
    imem_data_out <= imem_out_0 when imem_addr(12 downto 11) = "00"
	else imem_out_1 when imem_addr(12 downto 11) = "01"
	else imem_out_2;

    bram_0: RAMB16BWE_S36_S36
    generic map (
	INIT_00 => x"0151222301412423013126230121282300912A2300812C2300112E23FE010113",
	INIT_01 => x"0030089308000E37203E33B77672133700000793000005930000081300000013",
	INIT_02 => x"00000A1301F0091300D00493053004130400009300500F9300100F1306000E93",
	INIT_03 => x"000518630147653340875713B0E00023FE02CCE301D61293B0100603A0D30713",
	INIT_04 => x"00050993FFF007130FF0061300200513FC071CE3FDDFF06F23338713FFF00A13",
	INIT_05 => x"4137D2930FF2F693415002B300D03AB301C7F6B3C01027F302075E634085DA13",
	INIT_06 => x"0080006FF0D008230F06C6930080006F00F6C6930152D6630FF2F2930FF7FA93",
	INIT_07 => x"00000793008A186302075C63B0000A03FA02DCE301FA9293B0100A83F1400823",
	INIT_08 => x"FE06CCE301D79693B0100783F94958E300000793F49A0AE3F9DFF06F00000713",
	INIT_09 => x"FE0A0A13014ED66300479A93F6D8F0E3FF6A0693F79FF06F00000793B1400023",
	INIT_0A => x"03E71C63001707130152E7B3FC9A02930140D6630157E7B3FD0A07930100006F",
	INIT_0B => x"00080067000000930091613300887133000104B7080004370359E063FF978A93",
	INIT_0C => x"00D505330017969301171863F95FF06F0052861300179293FAF8C0E3FA5FF06F",
	INIT_0D => x"EE5FF06F00078813EE0816E3000706130007859300C71C63EECFDEE3F85FF06F",
	INIT_0E => x"00000000EC9FF06F0015859300F58023ECA75AE3EC0A5CE301F71A13EEE650E3",
	INIT_0F => x"0000000000000000000000000000000000000000000000000000000000000000"
    )
    port map (
	doa => imem_out_0, dob => dmem_out_0,
	addra => imem_addr(10 downto 2), addrb => dmem_addr(10 downto 2),
	clka => not clk, clkb => not clk, ssra => '0', ssrb => '0',
	dia => x"00000000", dib => dmem_data_in, dipa => x"0", dipb => x"0",
	ena => '1', enb => '1', wea => x"0", web => we_0
    );

    bram_1: RAMB16BWE_S36_S36
    port map (
	doa => imem_out_1, dob => dmem_out_1,
	addra => imem_addr(10 downto 2), addrb => dmem_addr(10 downto 2),
	clka => not clk, clkb => not clk, ssra => '0', ssrb => '0',
	dia => x"00000000", dib => dmem_data_in, dipa => x"0", dipb => x"0",
	ena => '1', enb => '1', wea => x"0", web => we_1
    );

    bram_2: RAMB16BWE_S36_S36
    port map (
	doa => imem_out_2, dob => dmem_out_2,
	addra => imem_addr(10 downto 2), addrb => dmem_addr(10 downto 2),
	clka => not clk, clkb => not clk, ssra => '0', ssrb => '0',
	dia => x"00000000", dib => dmem_data_in, dipa => x"0", dipb => x"0",
	ena => '1', enb => '1', wea => x"0", web => we_2
    );

end x;
