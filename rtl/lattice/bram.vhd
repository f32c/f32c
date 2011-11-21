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
		imem_addr: in std_logic_vector(31 downto 2);
		imem_data_out: out std_logic_vector(31 downto 0);
		imem_addr_strobe: in std_logic;
		imem_data_ready: out std_logic;
		dmem_addr: in std_logic_vector(31 downto 2);
		dmem_data_in: in std_logic_vector(31 downto 0);
		dmem_data_out: out std_logic_vector(31 downto 0);
		dmem_byte_we: in std_logic_vector(3 downto 0);
		dmem_addr_strobe: in std_logic;
		dmem_data_ready: out std_logic
	);
end bram;

architecture Behavioral of bram is
	signal dmem_wait_cycle, dmem_must_wait, dmem_we: std_logic;
	signal dmem_data_read, dmem_write_out: std_logic_vector(31 downto 0);
	signal dmem_bram_cs: std_logic;
begin
	
	imem_data_ready <= '1';
	dmem_data_out <= dmem_data_read; -- shut up compiler errors
	
	dmem_data_ready <= '1';
	dmem_write_out <= dmem_data_in;
	dmem_bram_cs <= dmem_addr_strobe;

	G_8k:
	if C_mem_size = "8k" generate
	ram_8_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE=> "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 9, DATA_WIDTH_A => 9,
		INITVAL_00 => "0x0420C042170C2150080000404008001F40100A00006080D01E1000D01858098800462B042000D000",
		INITVAL_01 => "0x000C90220617E0000C0A1A021042211C0371A00704236042F800001008001FA0400A210560001000",
		INITVAL_02 => "0x00000000000000107C650D8620A63301A2101C001760401C00042000042101C00006251941F01E04",
		INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DIA0 => dmem_write_out(0), DIA1 => dmem_write_out(1),
		DIA2 => dmem_write_out(2), DIA3 => dmem_write_out(3),
		DIA4 => dmem_write_out(4), DIA5 => dmem_write_out(5),
		DIA6 => dmem_write_out(6), DIA7 => dmem_write_out(7),
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(0), DOA1 => dmem_data_read(1),
		DOA2 => dmem_data_read(2), DOA3 => dmem_data_read(3),
		DOA4 => dmem_data_read(4), DOA5 => dmem_data_read(5),
		DOA6 => dmem_data_read(6), DOA7 => dmem_data_read(7),
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0', ADA2 => '0', 
		ADA3 => dmem_addr(2), ADA4 => dmem_addr(3),
		ADA5 => dmem_addr(4), ADA6 => dmem_addr(5),
		ADA7 => dmem_addr(6), ADA8 => dmem_addr(7),
		ADA9 => dmem_addr(8), ADA10 => dmem_addr(9),
		ADA11 => dmem_addr(10), ADA12 => dmem_addr(11),
		ADA13 => dmem_addr(12),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(0),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(0), DOB1 => imem_data_out(1),
		DOB2 => imem_data_out(2), DOB3 => imem_data_out(3),
		DOB4 => imem_data_out(4), DOB5 => imem_data_out(5),
		DOB6 => imem_data_out(6), DOB7 => imem_data_out(7),
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0', ADB2 => '0', 
		ADB3 => imem_addr(2), ADB4 => imem_addr(3),
		ADB5 => imem_addr(4), ADB6 => imem_addr(5),
		ADB7 => imem_addr(6), ADB8 => imem_addr(7),
		ADB9 => imem_addr(8), ADB10 => imem_addr(9),
		ADB11 => imem_addr(10), ADB12 => imem_addr(11),
		ADB13 => imem_addr(12),
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_8_1: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A=> "NOREG",
		DATA_WIDTH_B => 9, DATA_WIDTH_A => 9,
		INITVAL_00 => "0x0200003000000001000000080000001FE00100800DA8000200002000000000201040100B00000200",
		INITVAL_01 => "0x0D2FF000001FE69000001FE10060281FE001FE0005000060FF00000100001FE00100100000000080",
		INITVAL_02 => "0x000000000000000040720DE6F0DE3201428000001FE0000000040000001800000000301FE0000000",
		INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DIA0 => dmem_write_out(8), DIA1 => dmem_write_out(9),
		DIA2 => dmem_write_out(10), DIA3 => dmem_write_out(11),
		DIA4 => dmem_write_out(12), DIA5 => dmem_write_out(13),
		DIA6 => dmem_write_out(14), DIA7 => dmem_write_out(15),
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(8), DOA1 => dmem_data_read(9),
		DOA2 => dmem_data_read(10), DOA3 => dmem_data_read(11),
		DOA4 => dmem_data_read(12), DOA5 => dmem_data_read(13),
		DOA6 => dmem_data_read(14), DOA7 => dmem_data_read(15),
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0', ADA2 => '0', 
		ADA3 => dmem_addr(2), ADA4 => dmem_addr(3),
		ADA5 => dmem_addr(4), ADA6 => dmem_addr(5),
		ADA7 => dmem_addr(6), ADA8 => dmem_addr(7),
		ADA9 => dmem_addr(8), ADA10 => dmem_addr(9),
		ADA11 => dmem_addr(10), ADA12 => dmem_addr(11),
		ADA13 => dmem_addr(12),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(1),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(8), DOB1 => imem_data_out(9),
		DOB2 => imem_data_out(10), DOB3 => imem_data_out(11),
		DOB4 => imem_data_out(12), DOB5 => imem_data_out(13),
		DOB6 => imem_data_out(14), DOB7 => imem_data_out(15),
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0', ADB2 => '0', 
		ADB3 => imem_addr(2), ADB4 => imem_addr(3),
		ADB5 => imem_addr(4), ADB6 => imem_addr(5),
		ADB7 => imem_addr(6), ADB8 => imem_addr(7),
		ADB9 => imem_addr(8), ADB10 => imem_addr(9),
		ADB11 => imem_addr(10), ADB12 => imem_addr(11),
		ADB13 => imem_addr(12),
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_8_2: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 9, DATA_WIDTH_A => 9,
		INITVAL_00 => "0x1C080000600B049004000C00210000000880180D01C0E0C000008090000A1CE84004031400714605",
		INITVAL_01 => "0x00C480008809806040190900000000084000900000000000600864200600180E601EE00001F1001D",
		INITVAL_02 => "0x0000000000000000000D0C26F08663014000000009463000660C000100C0000000C0CD1404501CA2",
		INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DIA0 => dmem_write_out(16), DIA1 => dmem_write_out(17),
		DIA2 => dmem_write_out(18), DIA3 => dmem_write_out(19),
		DIA4 => dmem_write_out(20), DIA5 => dmem_write_out(21),
		DIA6 => dmem_write_out(22), DIA7 => dmem_write_out(23),
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(16), DOA1 => dmem_data_read(17),
		DOA2 => dmem_data_read(18), DOA3 => dmem_data_read(19),
		DOA4 => dmem_data_read(20), DOA5 => dmem_data_read(21),
		DOA6 => dmem_data_read(22), DOA7 => dmem_data_read(23),
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0', ADA2 => '0', 
		ADA3 => dmem_addr(2), ADA4 => dmem_addr(3),
		ADA5 => dmem_addr(4), ADA6 => dmem_addr(5),
		ADA7 => dmem_addr(6), ADA8 => dmem_addr(7),
		ADA9 => dmem_addr(8), ADA10 => dmem_addr(9),
		ADA11 => dmem_addr(10), ADA12 => dmem_addr(11),
		ADA13 => dmem_addr(12),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(2),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(16), DOB1 => imem_data_out(17),
		DOB2 => imem_data_out(18), DOB3 => imem_data_out(19),
		DOB4 => imem_data_out(20), DOB5 => imem_data_out(21),
		DOB6 => imem_data_out(22), DOB7 => imem_data_out(23),
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0', ADB2 => '0', 
		ADB3 => imem_addr(2), ADB4 => imem_addr(3),
		ADB5 => imem_addr(4), ADB6 => imem_addr(5),
		ADB7 => imem_addr(6), ADB8 => imem_addr(7),
		ADB9 => imem_addr(8), ADB10 => imem_addr(9),
		ADB11 => imem_addr(10), ADB12 => imem_addr(11),
		ADB13 => imem_addr(12),
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_8_3: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 9, DATA_WIDTH_A => 9,
		INITVAL_00 => "0x00010000140501414000028800280002231100A00008C15A08048240102404830000000003C1183C",
		INITVAL_01 => "0x000240222D0480002E2D04800000000480804817000080001410024140000283110000010240003C",
		INITVAL_02 => "0x0000000000000000000A0C874040200CC000100002024010AC000000280001000028010283006224",
		INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DIA0 => dmem_write_out(24), DIA1 => dmem_write_out(25),
		DIA2 => dmem_write_out(26), DIA3 => dmem_write_out(27),
		DIA4 => dmem_write_out(28), DIA5 => dmem_write_out(29),
		DIA6 => dmem_write_out(30), DIA7 => dmem_write_out(31),
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0',
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
		DIA16 => '0', DIA17 => '0', 
		DOA0 => dmem_data_read(24), DOA1 => dmem_data_read(25),
		DOA2 => dmem_data_read(26), DOA3 => dmem_data_read(27),
		DOA4 => dmem_data_read(28), DOA5 => dmem_data_read(29),
		DOA6 => dmem_data_read(30), DOA7 => dmem_data_read(31),
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
		DOA16 => open, DOA17 => open, 
		ADA0 => '0', ADA1 => '0', ADA2 => '0', 
		ADA3 => dmem_addr(2), ADA4 => dmem_addr(3),
		ADA5 => dmem_addr(4), ADA6 => dmem_addr(5),
		ADA7 => dmem_addr(6), ADA8 => dmem_addr(7),
		ADA9 => dmem_addr(8), ADA10 => dmem_addr(9),
		ADA11 => dmem_addr(10), ADA12 => dmem_addr(11),
		ADA13 => dmem_addr(12),
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(3),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

		DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0', 
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0', 
		DIB16 => '0', DIB17 => '0',
		DOB0 => imem_data_out(24), DOB1 => imem_data_out(25),
		DOB2 => imem_data_out(26), DOB3 => imem_data_out(27),
		DOB4 => imem_data_out(28), DOB5 => imem_data_out(29),
		DOB6 => imem_data_out(30), DOB7 => imem_data_out(31),
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
		DOB16 => open, DOB17 => open, 
		ADB0 => '0', ADB1 => '0', ADB2 => '0', 
		ADB3 => imem_addr(2), ADB4 => imem_addr(3),
		ADB5 => imem_addr(4), ADB6 => imem_addr(5),
		ADB7 => imem_addr(6), ADB8 => imem_addr(7),
		ADB9 => imem_addr(8), ADB10 => imem_addr(9),
		ADB11 => imem_addr(10), ADB12 => imem_addr(11),
		ADB13 => imem_addr(12),
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);
	end generate; -- 8k

	G_16k:
	if C_mem_size = "16k" generate
	ram_16_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x012161E06A0021100E0702C18002401A851160800381702A4004840142500708E01AC81803B02080",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000002E5184331A2E0168E0020211C03515EF4"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(0),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_1: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x01810160001A4221C6D00462F000001E00204000040210C200000001E00000061100050902204060",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000360CC530040016000040020000218200"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(0),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_2: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x13E001F2001E0081E0F01000F000001E000000000008000000000001E0001A010020000220010010",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000021FEF2150001E00000008000001E000"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(1),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_3: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0DE001EC001E2321E0F00403F000801E081000080201000080010001E0880D00000000000210A000",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000270CC63004001E00004001000031E000"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(1),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_4: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0D00818C091000004080000000643000CF001E0D000001122000400010CD1DC000920A0E82300E35",
		INITVAL_01 => "0x0000000000000000000000000000000000000000000000000D03E331400014606000000000D00AE2"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(2),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_5: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x00808080210800008040000060880019C0E002811D0060A8000C0800100000060000001D000140A0",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000000CC460000008C060C08C0006C1480A"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(2),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_6: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0081D0807D08000090470100400800082001080C00004108000804002200018D80888408000018CC",
		INITVAL_01 => "0x0000000000000000000000000000000000000000000000000A088000C0800088C000401004108014"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(3),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	ram_16_7: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x0041204012040000402100001104A0026800040300201042A0030100268A010A0044020460000683",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000000CE220C0000240A000100001002632"
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
		CEA => dmem_bram_cs, CLKA => not clk, WEA => dmem_byte_we(3),
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

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
		CEB => '1', CLKB => not clk, WEB => '0', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);
	end generate; -- 16k

end Behavioral;
