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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


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

architecture Behavioral of bram is
	signal dmem_data_read, dmem_write_out: std_logic_vector(31 downto 0);
	signal dmem_bram_cs, we: std_logic;
	signal byte_en: std_logic_vector(3 downto 0);
	signal addr: std_logic_vector(10 downto 2);
begin
	
	dmem_data_out <= dmem_data_read; -- shut up compiler errors
	dmem_write_out <= dmem_data_in;
	dmem_bram_cs <= dmem_addr_strobe;
	dmem_data_ready <= '1';

	G_2k:
	if C_mem_size = 2 generate
	we <= dmem_addr_strobe and dmem_write;
	byte_en <= "1111" when we = '0' else dmem_byte_sel;
	addr <= dmem_addr(10 downto 2) when dmem_addr_strobe = '1'
	    else imem_addr(10 downto 2);
	imem_data_ready <= not dmem_addr_strobe;
	imem_data_out <= dmem_data_read;
	ram_2_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 18, DATA_WIDTH_A => 18,
		INITVAL_00 => "0x080081000004A080000403A201FEFD17A000000004A291FEFF078081000004809010000000000000",
		INITVAL_01 => "0x04E9C10A7001000000110781C00001006A81D0230781D100100000808640062080000F0000000000",
		INITVAL_02 => "0x140021001015EB00001015EB10001415EB20001815EBF0001C04802000FF04EBD1FEE00000000000",
		INITVAL_03 => "0x078061000004805000010780710010048091FEFF15804100F0048041FEFE15803100400480300003",
		INITVAL_04 => "0x04C101FEFC04C1000004022090000E11C08000000781010000028C71FEFD048C600004158C900000",
		INITVAL_05 => "0x010000002A1401210010000000000002220000040022B0902404A2A0000104812000FF0780B00040",
		INITVAL_06 => "0x02A251FEE704A2900001000000000002C071FEEF0024009021010000002A14009100100024009021",
		INITVAL_07 => "0x1240E102FE1240D1000E1240B1000B124111000F124121000C048050040001800000700000004021",
		INITVAL_08 => "0x04819000AA12418102FF0028D1102102ACF000090024B120210480F00055000110C400000120A400",
		INITVAL_09 => "0x0000000000018000009000000000000204000003054220000202C5F000030481F0200002E1900005",
		INITVAL_0a => "0x1400310010000000302104804004000180000070048451FC000042005021018000023D0044004021",
		INITVAL_0b => "0x078081000F028E50000404805000201000710020078081000F020C00000806086000011000410021",
		INITVAL_0c => "0x000001F021004041D0240780500010078041000006A1010000078081000F00000000000180000090",
		INITVAL_0d => "0x04EBD00020006E00000811EB00001011EB10001411EB20001811EBF0001C006A51D0250040000008",
		INITVAL_0e => "0x000A011021018000023415EB10001815EBF0001C0000004021000801002115EB00001404EBD1FEE0",
		INITVAL_0f => "0x018000022D00010054020000004021018000022D0001005802048050000B018000022D0000004021",
		INITVAL_10 => "0x11EBF0001C04805000FF018000022D00000040210000004021018000022D00400050210000004021",
		INITVAL_11 => "0x04EBD000200100000211068A510000000000402111EB1000180042006021078051000F11EB000014",
		INITVAL_12 => "0x0000008021028A31FEFC048A500004158A000000178A00000007803100100780510000000001F021",
		INITVAL_13 => "0x000000302104818000530480F000030480E00001048090000D0780D010000780C0403E0780B06666",
		INITVAL_14 => "0x00243190250000A0A4031400A100200000000000028E01FEFD060C700004100061002104A6A0140D",
		INITVAL_15 => "0x048031FEFF04806000FF02A401FEF304A8A0C63201000000A1048031FEFF000000000002E2000004",
		INITVAL_16 => "0x000000402102240000020004D0A024000000000008002090000000000000008610001B0480700002",
		INITVAL_17 => "0x01000000C2000000000002240000030062A0A02A06639000FF0604A000FF00002198C304804000FF",
		INITVAL_18 => "0x00861000110000000000026201FEEB06099000011000410021140041001007084000F0070840000F",
		INITVAL_19 => "0x020891FECF000050440301000000C200000030210000002021000000000002898000051000410020",
		INITVAL_1a => "0x01000000B10000000000028401FEFD06042000041000210021000000202102E201FEDF0509900020",
		INITVAL_1b => "0x0508200061048070000201000000B3048031FEFF04806000FF000020A20002889000051400410020",
		INITVAL_1c => "0x048841FEC90004A0202502E20000030509900041048841FEE001000000E7048821FED00284000003",
		INITVAL_1d => "0x0780410000048441FEFF026200000705A59000030484A1FEF90286E0001104863000010008A02025",
		INITVAL_1e => "0x000000000002240000030588A00003048441FEFF006A51D0250020000008002041D0240780500010",
		INITVAL_1f => "0x01000000FA000020204000000000000286F00004000000202101000000B1048C6000050000206040",
		INITVAL_20 => "0x000600602101000000B10004008021000400502102A0000002000C30A02A0286600006000E207021",
		INITVAL_21 => "0x01000000B1140A2000000000000000020801FEA4000670402A026201FEA60607900001022401FEA8",
		INITVAL_22 => "0x000000A021020601FEFD06283002001188C10030140821003004802000FF020C000019048A500001",
		INITVAL_23 => "0x02A6000003060CB0000314087100300000C09C00020C00000D0000A0840204807000FF048C61FEFF",
		INITVAL_24 => "0x010000021A0000000000022A01FEFD0628D002001188C10030048A500004158AA00000002280A025",
		INITVAL_25 => "0x0604300200118821003014085100300000000000006E000008158A4000000022804025048C61FEFF",
		INITVAL_26 => "0x11883100301408210030048020008004884000010000000000006E00000806042000FF020601FEFD",
		INITVAL_27 => "0x060A300001020A00000700000020210000000000006E0000080000000000020A01FEFD0606500200",
		INITVAL_28 => "0x0000000000006E0000080000404040010000023E0000505042000440202100000000000206000002",
		INITVAL_29 => "0x000440A021000070CEC00222000006060C9000010220000010000C70802500000030210000002021",
		INITVAL_2a => "0x0028606025000050E0400000606042000040DEC2002630302100240020210006503021002420B02B",
		INITVAL_2b => "0x000000000000000000000000000000006E0000080000404040010000024A002AE050250000707042",
		INITVAL_2c => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
		INITVAL_2d => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
		INITVAL_2e => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
		INITVAL_2f => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DIA0 => dmem_write_out(0), DIA1 => dmem_write_out(1),
		DIA2 => dmem_write_out(2), DIA3 => dmem_write_out(3),
		DIA4 => dmem_write_out(4), DIA5 => dmem_write_out(5),
		DIA6 => dmem_write_out(6), DIA7 => dmem_write_out(7),
		DIA8 => '0',
		DIA9 => dmem_write_out(8), DIA10 => dmem_write_out(9),
		DIA11 => dmem_write_out(10), DIA12 => dmem_write_out(11),
		DIA13 => dmem_write_out(12), DIA14 => dmem_write_out(13),
		DIA15 => dmem_write_out(14), DIA16 => dmem_write_out(15),
		DIA17 => '0', 
		DOA0 => dmem_data_read(0), DOA1 => dmem_data_read(1),
		DOA2 => dmem_data_read(2), DOA3 => dmem_data_read(3),
		DOA4 => dmem_data_read(4), DOA5 => dmem_data_read(5),
		DOA6 => dmem_data_read(6), DOA7 => dmem_data_read(7),
		DOA8 => open,
		DOA9 => dmem_data_read(8), DOA10 => dmem_data_read(9),
		DOA11 => dmem_data_read(10), DOA12 => dmem_data_read(11),
		DOA13 => dmem_data_read(12), DOA14 => dmem_data_read(13),
		DOA15 => dmem_data_read(14), DOA16 => dmem_data_read(15),
		DOA17 => open, 
		ADA0 => byte_en(0), ADA1 => byte_en(1),
		ADA2 => '0', ADA3 => '0', ADA4 => '0',
		ADA5 => addr(2), ADA6 => addr(3),
		ADA7 => addr(4), ADA8 => addr(5),
		ADA9 => addr(6), ADA10 => addr(7),
		ADA11 => addr(8), ADA12 => addr(9),
		ADA13 => addr(10),
		CEA => '1', CLKA => not clk, WEA => we,
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',

		DIB0 => dmem_write_out(16), DIB1 => dmem_write_out(17),
		DIB2 => dmem_write_out(18), DIB3 => dmem_write_out(19),
		DIB4 => dmem_write_out(20), DIB5 => dmem_write_out(21),
		DIB6 => dmem_write_out(22), DIB7 => dmem_write_out(23),
		DIB8 => '0',
		DIB9 => dmem_write_out(24), DIB10 => dmem_write_out(25),
		DIB11 => dmem_write_out(26), DIB12 => dmem_write_out(27),
		DIB13 => dmem_write_out(28), DIB14 => dmem_write_out(29),
		DIB15 => dmem_write_out(30), DIB16 => dmem_write_out(31),
		DIB17 => '0', 
		DOB0 => dmem_data_read(16), DOB1 => dmem_data_read(17),
		DOB2 => dmem_data_read(18), DOB3 => dmem_data_read(19),
		DOB4 => dmem_data_read(20), DOB5 => dmem_data_read(21),
		DOB6 => dmem_data_read(22), DOB7 => dmem_data_read(23),
		DOB8 => open,
		DOB9 => dmem_data_read(24), DOB10 => dmem_data_read(25),
		DOB11 => dmem_data_read(26), DOB12 => dmem_data_read(27),
		DOB13 => dmem_data_read(28), DOB14 => dmem_data_read(29),
		DOB15 => dmem_data_read(30), DOB16 => dmem_data_read(31),
		DOB17 => open, 
		ADB0 => byte_en(2), ADB1 => byte_en(3),
		ADB2 => '0', ADB3 => '0', ADB4 => '1',
		ADB5 => addr(2), ADB6 => addr(3),
		ADB7 => addr(4), ADB8 => addr(5),
		ADB9 => addr(6), ADB10 => addr(7),
		ADB11 => addr(8), ADB12 => addr(9),
		ADB13 => addr(10),
		CEB => '1', CLKB => not clk, WEB => we,
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);
	end generate; -- 2k

	G_16k:
	if C_mem_size = 16 generate
	imem_data_ready <= '1';
	ram_16_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR => "ENABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 4, DATA_WIDTH_A => 4,
		INITVAL_00 => "0x1DCBF180010E20F0340114004082F0188E001A400020F01C030004819E0000213000F0008D01E000",
		INITVAL_01 => "0x1A41D056D10288C0224001004118580280001E001E8001F01100200002D1000030460515E1902A00",
		INITVAL_02 => "0x0403A1FE3F02440000B21FE3203E040A6001A81D026311A0E6038400000100201102F419ED103A11",
		INITVAL_03 => "0x14004022500063F0B04001E731221512A3100E030243F1E050020D4022F01E62102050020B10200F",
		INITVAL_04 => "0x02E10100D000001010FD000001005F140D000805066001A4FF03A0001E910200414C180221105461",
		INITVAL_05 => "0x000000000000000000000000000000000000000000008014520A0220221B0206100A110100E04202"
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
		INITVAL_00 => "0x1E000000721C00E0441204200040F41E00001E000001F1FE400221103EE00E20202800000F01E000",
		INITVAL_01 => "0x0402200022046110441E0401102220044100000900022000020240700432012000000015E2004A00",
		INITVAL_02 => "0x180021FECF04020000101FEF315E00040201E02004A000003605E0000202042020240103E2204422",
		INITVAL_03 => "0x1E800056040000F0402101E001E202184041DCD00C0BF1E002160F0044D2180C204002020E0042F0",
		INITVAL_04 => "0x00020000F006680000FF006300002F020F00600200030000FF05E0307E101600A0540A0562200402",
		INITVAL_05 => "0x000000000000000000000000000000000000000000000088240484C0442205800024220004308400"
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
		INITVAL_00 => "0x02000004001E00F1000800000100001E00001E000000F01E0000000000F00A00800600000F01E080",
		INITVAL_01 => "0x0340118010102000000F000000008011000000000000000000010201D01000000000000028000022",
		INITVAL_02 => "0x00000000C000000100001E0F301E00104001E00A100000100301E000000800200000000001000280",
		INITVAL_03 => "0x00000000000000F1008001E001E0001E0001E0F00000F00200000F0000F01E40800000000F000000",
		INITVAL_04 => "0x00000000F1000000000F020000000F020F1000000000E0040F01E10000000000F01E0F0000800008",
		INITVAL_05 => "0x000000000000000000000000000000000000000000000002880000F1008800E00000800000110000"
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
		INITVAL_00 => "0x11088100021E00F0808401000080001E00011E001008F11E8010000000F01000E10800100F01F000",
		INITVAL_01 => "0x0042004002100000500F00000000E01FC08110001000810008102001E40200000000100108012065",
		INITVAL_02 => "0x00005000C004050080001E0F601E0018A801E080020000002309E000108F00082006800000204022",
		INITVAL_03 => "0x00200020030000F1C0E011E001E0011E2001E0F00000F00A08000F0102F01E40102008000F011000",
		INITVAL_04 => "0x00010000F0110000000F010800002F000F010005000840080F0BE08100000000F05E0F0604200A03",
		INITVAL_05 => "0x0000000000000000000000000000000000000000000000402306E36022150AC00008110002004200"
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
		INITVAL_00 => "0x1DAB104A000B20700090004001742B0009800E690CA7908833040121E4D0180C81B0801100013090",
		INITVAL_01 => "0x0000000A000001F0000D1A00105E50008540100010A5710064060400A0000000005EF9130DF17E12",
		INITVAL_02 => "0x0000A13424000D00401706C0A00600074A000E6A010FE13ACB00650006501A050020501EA0000000",
		INITVAL_03 => "0x0040F00062000A40A0450880915C3A094090802004E030C494000020400912A00000840200908844",
		INITVAL_04 => "0x0600000005064240002006450008860000D18AA80167C014760003C04405004000E0900000000662",
		INITVAL_05 => "0x000000000000000000000000000000000000000000000080E70CA640605208E0900E00000400A800"
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
		INITVAL_00 => "0x00001020000440008004002020441002200038CC0000000000016BB160B01201A020000002004000",
		INITVAL_01 => "0x0020002000140BB010BB17CBB176A0000000200001C000188000000084040000404A110228C08011",
		INITVAL_02 => "0x000420680000840000600004800002080001D8060020000000014AA14000160A01640B1600000000",
		INITVAL_03 => "0x00006000C000884140000082508C6810829100841000000080000440002910000000900C02900088",
		INITVAL_04 => "0x154001C0A61100801C46090801D42C000A8114A20D8801800C00C88100CA014080C4740C0440186E",
		INITVAL_05 => "0x00000000000000000000000000000000000000000000E000A0100000C8640802C0180001C0000806"
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
		INITVAL_00 => "0x04422048C00AA06030011000102A4C0CC1E1884C188C4188C401EFF1E8700F0C31801000ADD0B840",
		INITVAL_01 => "0x1800C008C0018FF000F70E6FF1FE32004CC0B80C18840180000004C084C20180014C470841502800",
		INITVAL_02 => "0x100130600400200000440885510807020000800500844098CC0084C198C00F0401E4CF1E8C001820",
		INITVAL_03 => "0x1000401040002C40621C1883D0884008078090441088408040100400007800080000400803000088",
		INITVAL_04 => "0x00000060001804400600018000781410011188C10A000000440001C008041000000601010000A040",
		INITVAL_05 => "0x00000000000000000000000000000000000000000000301010020000220100010020000060800000"
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
		INITVAL_00 => "0x132991240002401000A00140100423044180622A06432144A2154AA1442004030060300841B04620",
		INITVAL_01 => "0x0000000400000AA000A2040881100000033066000622806238140200400000001042210520100400",
		INITVAL_02 => "0x000100660200200080020441200401000A00268200422046330022A1663004030100381040000000",
		INITVAL_03 => "0x0000100020002220000306412042200401204021044020401A000131001202000000180001311433",
		INITVAL_04 => "0x06200000131142200031070A00140200013104A0026A002022002381441201401002310000002010",
		INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000013020000000000001"
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
