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
		INITVAL_00 => "0x0182102E6102A040000200804000FA00205000030106C03E8001A0D0B05010023056210006C00000",
		INITVAL_01 => "0x1921100CBF00006014D004221042E0070D000E2106E211F00000204000FD008050422C0000800021",
		INITVAL_02 => "0x00000000000023E0CA6C0C4530660D0420F000BB0080F00021000020420F0000304ACA03E0F00800",
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
		INITVAL_00 => "0x0001800000000000000000000000FF000000006D00001000010000000001002200205800001000E0",
		INITVAL_01 => "0x1FE00000FF0D200000FF02030050FF000FF00028000301FE0000000000FF00000020000000010010",
		INITVAL_02 => "0x0000000000000200E46F0DE6F0640A05000000FF0000000020000000300000000060FF0000000069",
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
		INITVAL_00 => "0x100000C05809262000600C480000001106C0DA0E0DC600000401200014E710802006A000EA300A1B",
		INITVAL_01 => "0x090001104C00C200324800000000420004800000000000C04308463000C01CC6F1C00003E8003AE0",
		INITVAL_02 => "0x00000000000000001A610DE430C60A000000004A0C6000CC6000080180000006019AA008A0E14406",
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
		INITVAL_00 => "0x0200002828028A3000141061400011062831460011EAD01024048080482406000000000788C0783C",
		INITVAL_01 => "0x0481105A240001705A2400000000240102402E000100002880048A30001406283000080480007800",
		INITVAL_02 => "0x000000000000000014640E8200406600008000100480815800000140000800014002140603104800",
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
		INITVAL_00 => "0x1226F00CA002210100710E2800280D08A1C01001182710A8020880A02A03118F01BA80006B101800",
		INITVAL_01 => "0x00000000000000000000000000000000000000000000003C5C0463D03E0B09E010041F0065A1FE40"
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
		INITVAL_00 => "0x1820B0000D0442E07A02064F00000F000220000200416020000000F0000000C18000551042200C00",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000006660CA300400B00002000200002C02000"
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
		INITVAL_00 => "0x1E00F1200F0008F01E08000F00000F000000000001000000000000F0000D00201000010200800200",
		INITVAL_01 => "0x0000000000000000000000000000000000000000000000002F1FE2A1000F00000000800000F00009"
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
		INITVAL_00 => "0x1E00F0C00F0262F01E02006F00000F000100008100200000000000F000060000000000004150000E",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000004760CC300400F00002000100003F00006"
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
		INITVAL_00 => "0x1008C0C098000020100000003046000DE001E0D0000081240004000118DE1C004120A7084300E65B",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000D11E63A0000A0606000000000D00BC26"
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
		INITVAL_00 => "0x080840041400004008000006408C0C1CCE00301E1006508C060D00010C600CC000000E1000A01401",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000060C860000040C066010C000CCA080A0"
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
		INITVAL_00 => "0x082D400ED40000410870100400860402608080C0000480860406801026301FA840904400000198CC",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000A40800601000090C0008080081400240"
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
		INITVAL_00 => "0x0422200222000020041000018054010700004030020120340110201070A011402040220600007033",
		INITVAL_01 => "0x000000000000000000000000000000000000000000000000060E42600001040A0002000020106620"
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
