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
	INITVAL_00 => "0x0480300003140021001004802000FF04E9C108C001000000050781C000010481D080000000000000",
	INITVAL_01 => "0x158CA000000780610000048050000107807100100480A1FEFF15804100F0048041FEFE1580310040",
	INITVAL_02 => "0x078190004004A291FEFC04A29000040220A0000D11A28000000780910000028C71FEFD048C600004",
	INITVAL_03 => "0x1401810010004200A0210100000019140021001004A51000010260000004002591802404802000FF",
	INITVAL_04 => "0x04EBD1FEE00780B1000F02A451FEE804A4A00001000000000002A271FEF0004200A0210100000019",
	INITVAL_05 => "0x048050040001800000650000004021002801D02115EB00001415EB10001815EBF0001C06A6C10000",
	INITVAL_06 => "0x000110F400122C4002F2122C200002122D01FEFF122D800003122D10000006AAE1000C0780D1000F",
	INITVAL_07 => "0x02EE60000504806000AA122DF002F300622100210288300009002F01102104803000550001819400",
	INITVAL_08 => "0x0043000018000000000001800000850043000018020A000004054050000202C27000030480702000",
	INITVAL_09 => "0x0624B000011000A100211400910010000000902104A051FC00018000006500000080120480400400",
	INITVAL_0a => "0x000000000001800000850780E1000F02A8D000040480D000201000C100200780E1000F0226000008",
	INITVAL_0b => "0x006A51D025002E000008000001F021002E41D0240780500010078041000006ACF100000780E1000F",
	INITVAL_0c => "0x000801002115EB00001404EBD1FEE004EBD00020006E00000811EB00001411EB10001811EBF0001C",
	INITVAL_0d => "0x048050000B01800002220000004021000A011021018000022915EB10001815EBF0001C0000004021",
	INITVAL_0e => "0x01800002220040005021000000402101800002220001005402000000402101800002220001005802",
	INITVAL_0f => "0x0042006021078051000F11EB00001411EBF0001C04805000FF018000022200000040210000004021",
	INITVAL_10 => "0x07803100100780510000000001F02104EBD000200100000206068A510000000000402111EB100018",
	INITVAL_11 => "0x0780D010000780C0403E0780B066660000008021028A31FEFC048A500004158A000000178A000000",
	INITVAL_12 => "0x060C700004100061002104A6A0140D000000302104818000530480F000030480E00001048090000D",
	INITVAL_13 => "0x048031FEFF000000000002E200000400243190250000A0A4031400A100200000000000028E01FEFD",
	INITVAL_14 => "0x0000000000008610001B0480700002048031FEFF04806000FF02A401FEF304A8A0C6320100000096",
	INITVAL_15 => "0x0604A000FF00002198C304804000FF000000402102240000020004D0A02400000000000800209000",
	INITVAL_16 => "0x140041001007084000F0070840000F01000000B7000000000002240000030062A0A02A06639000FF",
	INITVAL_17 => "0x00000000000289800005100041002000861000110000000000026201FEEB06099000011000410021",
	INITVAL_18 => "0x000000202102E201FEDF0509900020020891FECF000050440301000000B700000030210000002021",
	INITVAL_19 => "0x000020A2000288900005140041002001000000A60000000000028401FEFD06042000041000210021",
	INITVAL_1a => "0x01000000DC048821FED002840000030508200061048070000201000000A8048031FEFF04806000FF",
	INITVAL_1b => "0x0286E0001104863000010008A02025048841FEC90004A0202502E20000030509900041048841FEE0",
	INITVAL_1c => "0x0020000008002041D02407805000100780410000048441FEFF026200000705A59000030484A1FEF9",
	INITVAL_1d => "0x01000000A6048C6000050000206040000000000002240000030588A00003048441FEFF006A51D025",
	INITVAL_1e => "0x000C30A02A0286600006000E20702101000000EF000020204000000000000286F000040000002021",
	INITVAL_1f => "0x026201FEA60607900001022401FEA8000600602101000000A60004008021000400502102A0000002",
	INITVAL_20 => "0x04802000FF020C000019048A50000101000000A6140A2000000000000000020801FEA4000670402A",
	INITVAL_21 => "0x0000A0840204807000FF048C61FEFF000000A021020601FEFD06283002001188C100301408210030",
	INITVAL_22 => "0x048A500004158AA00000002280A02502A6000003060CB0000314087100300000C09C00020C00000D",
	INITVAL_23 => "0x158A4000000022804025048C61FEFF010000020F0000000000022A01FEFD0628D002001188C10030",
	INITVAL_24 => "0x006E00000806042000FF020601FEFD0604300200118821003014085100300000000000006E000008",
	INITVAL_25 => "0x0000000000020A01FEFD060650020011883100301408210030048020008004884000010000000000",
	INITVAL_26 => "0x0000000000000000000000000000000000000000000000000000000000000000000000006E000008",
	INITVAL_27 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_28 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_29 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_2a => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_2b => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
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
	INITVAL_00 => "0x0B431122500042F060CF00A11090C001E8100019002900284F0184D000D4000101E0E0060F00A200",
	INITVAL_01 => "0x03E4C1E411042120422216411130C1028001088C0B0140000F00AF4000F80220100A201005808430",
	INITVAL_02 => "0x00A0101611000F7006AF1E6F1048000162F1E6261E0450600D082D10661D01C6118800000100C018",
	INITVAL_03 => "0x0C2810C21214C1F000410CA00066F5108001EE39022590A61018031050FF00A0601A4103E0F06E11",
	INITVAL_04 => "0x0000000000000000000801A000001011ED00000800AFF01A00080530600D05EF11A0001F2160004A",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x014F20045001E0F0000000C22022101C0E001E21024110002F09E00000F0000011FEF4002FC00000",
	INITVAL_01 => "0x040111E42204422004200042204212042E200211040220200001000044000041200C100208100000",
	INITVAL_02 => "0x0002101C0203E0B0002F1F8F2004000020F1FE391E0020040F004020A000006621E0000202200021",
	INITVAL_03 => "0x140A2144200402E0800214040000F2004101E00F0202C0404E1BA06014FF0002A01E0205A2C01622",
	INITVAL_04 => "0x0000000000000000000001E030700001EF006600004F001E03000200060001EF21E0331E20A000A2",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x000100100A1420F0000004008000001E0F001E00000000000001E00000F0000001E0F00000400000",
	INITVAL_01 => "0x0000000200030011401C0020802000000F00000010088000000000000000000081C0020000000000",
	INITVAL_02 => "0x0000001E00000000000001800000080000F01E301E0080400F000A800000100301E0000008002000",
	INITVAL_03 => "0x1E0F000080000800000000000000F8010001E00F0000F0000F01E00000F00200001E0001E0F04080",
	INITVAL_04 => "0x0000000000000000000001E1000000000F100000000F101E1000000000E0040F01E20000000000F0",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x000080100C0E00F000880002E000081F0F001E5010A08000C001E00010F0010081F0F80100800040",
	INITVAL_01 => "0x070000002200420044020002800002100F0000001C0FE010880008001080010841E0400000000001",
	INITVAL_02 => "0x0008001E0810000000500180200A040000F01E601E00C0B00F0100100000004341E000110F001020",
	INITVAL_03 => "0x1E0F3008200A0300200100030000FE01C081E00F0001F0200F01E00000F00A08001E0803E0F04011",
	INITVAL_04 => "0x0000000000000000000001E0810000000F011000004F001E080005001040080F51E08800000000F2",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x0CCF20603802820102ED0A000002FC1B65A00E0010002020921329A1127614C57148430642C018D0",
	INITVAL_01 => "0x00A0F0A00000000000000A000002F0000DD0001F0A0040A8FE000ED1B8E0174900A0040000000A77",
	INITVAL_02 => "0x010410009408840000A91444001A02002730C0A006003154000ECA011EE91B8B006A0006A0D00A01",
	INITVAL_03 => "0x012000000006C20040F000C2001445008540809A1C6A414094004020E0360524000022000990A000",
	INITVAL_04 => "0x0000000000000000000000053044400040304A0009060000DC0B48016EC014E60006C20405004007",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x1C0D211E01038CD1BAA000008176B61604400420024000A05002420040CC18000000000000900210",
	INITVAL_01 => "0x040BB0000000000020010000A016B0116BB1D6BB15C0E000C0000080000608000000000600314020",
	INITVAL_02 => "0x01206004900108000823080000880000C0000880000240000E180600200000000154AA0000B0140B",
	INITVAL_03 => "0x04E460084018CE000060018000904A00000084540CC8808498010480000001000008400049800000",
	INITVAL_04 => "0x0000000000000000000E01468100801C8641100E144C001488154261900C000C00D088018A014086",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x0E81308240002110225C098011FEF50F85500A28004800A61418A511B8441984C0984C0804711840",
	INITVAL_01 => "0x058FF098001840C000C00980019EF001E7707EFF062011985C018C5080C1020000B804040C201464",
	INITVAL_02 => "0x0080400600010880023300040020000084408A5808071000040005008844198C0088CC198071080F",
	INITVAL_03 => "0x060101000500808000401080003843022CC086D40880400E841084809044008080080000E8001000",
	INITVAL_04 => "0x000000000000000000030000C008400600018003182480021C098150000000840002C00804800000",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x0249002020012991323304000154A304612002001400A042020642110612146230542A0542200620",
	INITVAL_01 => "0x0068804000000000000004000014A0014220108800000066330003105031070A0040020000002412",
	INITVAL_02 => "0x00280002381463000203060200200400022042200401001401070200442206630024AB0660200608",
	INITVAL_03 => "0x026100000100200000100040002420000330422202402002220041204022002A0002380022100000",
	INITVAL_04 => "0x000000000000000000000023814420006131140014020002380540107401004200268A0422014010",
	INITVAL_05 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
