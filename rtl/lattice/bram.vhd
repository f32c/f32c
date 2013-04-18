--
-- Copyright 2008, 2010, 2011 University of Zagreb, Croatia.
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

-- $Id: bram.vhd 116 2011-03-28 12:43:12Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


entity bram is
	generic(
		C_mem_size: string
	);
	port(
		clk: in std_logic;
		imem_addr_strobe: in std_logic;
		imem_addr: in std_logic_vector(31 downto 2);
		imem_data_out: out std_logic_vector(31 downto 0);
		dmem_addr_strobe: in std_logic;
		dmem_write: in std_logic;
		dmem_byte_sel: in std_logic_vector(3 downto 0);
		dmem_addr: in std_logic_vector(31 downto 2);
		dmem_data_in: in std_logic_vector(31 downto 0);
		dmem_data_out: out std_logic_vector(31 downto 0)
	);
end bram;

architecture Behavioral of bram is
	signal dmem_data_read, dmem_write_out: std_logic_vector(31 downto 0);
	signal dmem_bram_cs: std_logic;
begin
	
	dmem_data_out <= dmem_data_read; -- shut up compiler errors
	dmem_write_out <= dmem_data_in;
	dmem_bram_cs <= dmem_addr_strobe;

	G_16k:
	if C_mem_size = "16k" generate
	ram_16_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0880906011088A01825001E00074FF07E120800905EF80080D08A100860303A000B0410000012000",
		INITVAL_01 => "0x000000A4D10000B15A1F00013020A703C1008AE102003060501A0F6072110B253020E0062221FE05"
	)
	port map (
		DIA0 => dmem_write_out(0), DIA1 => dmem_write_out(1),
		DIA2 => dmem_write_out(2), DIA3 => dmem_write_out(3),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(0), DOA1 => dmem_data_read(1),
		DOA2 => dmem_data_read(2), DOA3 => dmem_data_read(3),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(0), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(0), DOB1 => imem_data_out(1),
		DOB2 => imem_data_out(2), DOB3 => imem_data_out(3),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_1: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x1C20D00622000001C0001E030004FF19E200400101EFF0000F000001CA000000004022020F001E00",
		INITVAL_01 => "0x000000C6000400A0540A1E42B05E2004A2000052044000000015EF001E100582009C4D00C021FE00"
	)
	port map (
		DIA0 => dmem_write_out(4), DIA1 => dmem_write_out(5),
		DIA2 => dmem_write_out(6), DIA3 => dmem_write_out(7),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(4), DOA1 => dmem_data_read(5),
		DOA2 => dmem_data_read(6), DOA3 => dmem_data_read(7),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(0), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(4), DOB1 => imem_data_out(5),
		DOB2 => imem_data_out(6), DOB3 => imem_data_out(7),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_2: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0200F04008000001E0000000000000180000100001E0F0000F000000200000080100880001000200",
		INITVAL_01 => "0x000021C6A00000F01E0F0200F10200100000000000000004001E2F001E0001E0001E0F000001E010"
	)
	port map (
		DIA0 => dmem_write_out(8), DIA1 => dmem_write_out(9),
		DIA2 => dmem_write_out(10), DIA3 => dmem_write_out(11),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(8), DOA1 => dmem_data_read(9),
		DOA2 => dmem_data_read(10), DOA3 => dmem_data_read(11),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(1), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(8), DOB1 => imem_data_out(9),
		DOB2 => imem_data_out(10), DOB3 => imem_data_out(11),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_3: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0000F04011010001E0880000000A00180200A80001E0F0100F0100000000000001C0EF0100000000",
		INITVAL_01 => "0x0000006C000000F05E0F0003F04050060100000302000000001E0F001E0003E1001E0F000001E050"
	)
	port map (
		DIA0 => dmem_write_out(12), DIA1 => dmem_write_out(13),
		DIA2 => dmem_write_out(14), DIA3 => dmem_write_out(15),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(12), DOA1 => dmem_data_read(13),
		DOA2 => dmem_data_read(14), DOA3 => dmem_data_read(15),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(1), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(12), DOB1 => imem_data_out(13),
		DOB2 => imem_data_out(14), DOB3 => imem_data_out(15),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_4: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0A0090A0001081001244088000149A04800184010E660088000C6540B0FE1B2CB0A0400A80B00680",
		INITVAL_01 => "0x0000001E65004000E0900400001436040201CC020000012600006A0092D3148A0128020047006C29"
	)
	port map (
		DIA0 => dmem_write_out(16), DIA1 => dmem_write_out(17),
		DIA2 => dmem_write_out(18), DIA3 => dmem_write_out(19),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(16), DOA1 => dmem_data_read(17),
		DOA2 => dmem_data_read(18), DOA3 => dmem_data_read(19),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(2), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(16), DOB1 => imem_data_out(17),
		DOB2 => imem_data_out(18), DOB3 => imem_data_out(19),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_5: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0C00800000120600520011000084340000408006000081400C0C0AA0C2000000014C60000000C000",
		INITVAL_01 => "0x000000446A014080C4741C064080C61C0400D804000020A0000C04804A6611042130080900000008"
	)
	port map (
		DIA0 => dmem_write_out(20), DIA1 => dmem_write_out(21),
		DIA2 => dmem_write_out(22), DIA3 => dmem_write_out(23),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(20), DOA1 => dmem_data_read(21),
		DOA2 => dmem_data_read(22), DOA3 => dmem_data_read(23),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(2), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(20), DOB1 => imem_data_out(21),
		DOB2 => imem_data_out(22), DOB3 => imem_data_out(23),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_6: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0B004010000804006000110800263000801000040884400004000400A8C4088CC06000198DC01AC0",
		INITVAL_01 => "0x000000183410000006011B00501A040100008880010071A88009A401E84400807108840904808804"
	)
	port map (
		DIA0 => dmem_write_out(24), DIA1 => dmem_write_out(25),
		DIA2 => dmem_write_out(26), DIA3 => dmem_write_out(27),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(24), DOA1 => dmem_data_read(25),
		DOA2 => dmem_data_read(26), DOA3 => dmem_data_read(27),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(3), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(24), DOB1 => imem_data_out(25),
		DOB2 => imem_data_out(26), DOB3 => imem_data_out(27),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_7: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0400100000030000268A06600020330040100800044211140107028044320443300000066A303030",
		INITVAL_01 => "0x0000000C320140100231140010100100000024000000104400030210441200401044020242004401"
	)
	port map (
		DIA0 => dmem_write_out(28), DIA1 => dmem_write_out(29),
		DIA2 => dmem_write_out(30), DIA3 => dmem_write_out(31),
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(28), DOA1 => dmem_data_read(29),
		DOA2 => dmem_data_read(30), DOA3 => dmem_data_read(31),
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open,
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0',
		ADA2 => dmem_addr(2), ADA3 => dmem_addr(3),
		ADA4 => dmem_addr(4), ADA5 => dmem_addr(5),
		ADA6 => dmem_addr(6), ADA7 => dmem_addr(7),
		ADA8 => dmem_addr(8), ADA9 => dmem_addr(9),
		ADA10 => dmem_addr(10), ADA11 => dmem_addr(11),
		ADA12 => dmem_addr(12), ADA13 => dmem_addr(13),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_write,
		CSA0 => not dmem_byte_sel(3), CSA1 => '0', CSA2 => '0',
		RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(28), DOB1 => imem_data_out(29),
		DOB2 => imem_data_out(30), DOB3 => imem_data_out(31),
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0',
		ADB2 => imem_addr(2), ADB3 => imem_addr(3),
		ADB4 => imem_addr(4), ADB5 => imem_addr(5),
		ADB6 => imem_addr(6), ADB7 => imem_addr(7),
		ADB8 => imem_addr(8), ADB9 => imem_addr(9),
		ADB10 => imem_addr(10), ADB11 => imem_addr(11),
		ADB12 => imem_addr(12), ADB13 => imem_addr(13),
		CEB => imem_addr_strobe, CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);
	end generate; -- 16k

end Behavioral;
