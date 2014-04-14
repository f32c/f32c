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
	INITVAL_00 => "0x04E9C108E001000000080781C000010781D1001004C31008F0078110000004C10000000781000000",
	INITVAL_01 => "0x0480300003140021001015EB00001015EB10001415EB20001815EBF0001C04802000FF04EBD1FEE0",
	INITVAL_02 => "0x158D100000078061000004805000010780810010048111FEFF15804100F0048041FEFE1580310040",
	INITVAL_03 => "0x11C070000007810100000001109080028C81FEFA048C600010158D10000C158D100008158D100004",
	INITVAL_04 => "0x04C1000010022E90000D002AE0F0210026C0D021000EA0B02111C0E0000C11C0C0000811C0A00004",
	INITVAL_05 => "0x010000002B140031001004C39000010244000004004221202404803000FF078020004004C101FEF0",
	INITVAL_06 => "0x02C251FEDE04C3100001000000000002C081FEEA0062011021010000002B14012100100062011021",
	INITVAL_07 => "0x12406102FE124041000E124191000B124021000F124121000C0480500400018000006E0000004021",
	INITVAL_08 => "0x04805000AA1241F102FF0006411021028C8000090061912021048080005500002034000001218400",
	INITVAL_09 => "0x0000000000018000008E0045100018020E000004054270000202C4900003048090200002EE500005",
	INITVAL_0a => "0x1000C100211400B10010000000B02104A451FC00018000006E000000A01204804004000045100018",
	INITVAL_0b => "0x018000008E078101000F02ACF000030480F000201000E10020078101000F022A0000070628D00001",
	INITVAL_0c => "0x006A51D0250060000008000001F021006041D0240780500010078041000006C18100000000000000",
	INITVAL_0d => "0x15EB00001404EBD1FEE004EBD00020006E00000811EB00001011EB10001411EB20001811EBF0001C",
	INITVAL_0e => "0x018000022C0000004021000A011021018000023315EB10001815EBF0001C00000040210008010021",
	INITVAL_0f => "0x00400050210000004021018000022C00010054020000004021018000022C0001005802048050000B",
	INITVAL_10 => "0x078051000F11EB00001411EBF0001C04805000FF018000022C00000040210000004021018000022C",
	INITVAL_11 => "0x0780510000000001F02104EBD000200100000210068A510000000000402111EB1000180042006021",
	INITVAL_12 => "0x0780C0403E0780B066660000008021028A31FEFC048A500004158A000000178A0000000780310010",
	INITVAL_13 => "0x100061002104A6A0140D000000302104818000530480F000030480E00001048090000D0780D01000",
	INITVAL_14 => "0x000000000002E200000400243190250000A0A4031400A100200000000000028E01FEFD060C700004",
	INITVAL_15 => "0x008610001C0480700002048031FEFF04806000FF02A401FEF304A8A0C632010000009F048031FEFF",
	INITVAL_16 => "0x00002198C304804000FF000000402102240000020004D0A024000000000008002090000000000000",
	INITVAL_17 => "0x07084000F0070840000F01000000C0000000000002240000030062A0A02A06639000FF0604A000FF",
	INITVAL_18 => "0x100041002000861000110000000000026201FEEA0609900001100041002108400000201400410010",
	INITVAL_19 => "0x0509900020020891FECE000050440301000000C00000003021000000202100000000000289800005",
	INITVAL_1a => "0x140041002001000000AF0000000000028401FEFD06042000041000210021000000202102E201FEDE",
	INITVAL_1b => "0x02840000030508200061048070000201000000B1048031FEFF04806000FF000020A2000288900005",
	INITVAL_1c => "0x0008A02025048841FEC90004A0202502E20000030509900041048841FEE001000000E6048821FED0",
	INITVAL_1d => "0x07805000100780410000048441FEFF026200000705A59000030484A1FEF90286E000110486300001",
	INITVAL_1e => "0x0000206040000000000002240000030588A00003048441FEFF006A51D0250020000008002041D024",
	INITVAL_1f => "0x000E20702101000000F9000020204000000000000286F00004000000202101000000AF048C600005",
	INITVAL_20 => "0x022401FEA7000600602101000000AF0004008021000400502102A0000002000C30A02A0286600006",
	INITVAL_21 => "0x048A50000101000000AF140A2000000000000000020801FEA3000670402A026201FEA50607900001",
	INITVAL_22 => "0x048C61FEFF000000A021020601FEFD06283002001188C10030140821003004802000FF020C000019",
	INITVAL_23 => "0x002280A02502A6000003060CB0000314087100300000C09C00020C00000D0000A0840204807000FF",
	INITVAL_24 => "0x048C61FEFF01000002190000000000022A01FEFD0628D002001188C10030048A500004158AA00000",
	INITVAL_25 => "0x020601FEFD0604300200118821003014085100300000000000006E000008158A4000000022804025",
	INITVAL_26 => "0x060650020011883100301408210030048020008004884000010000000000006E00000806042000FF",
	INITVAL_27 => "0x00000000000000000000000000000000000000000000000000006E0000080000000000020A01FEFD",
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
	INITVAL_00 => "0x1DCBF180E11C20A036011601409E0001A11038840000A01884000101E0E006004118F00101000000",
	INITVAL_01 => "0x022C20382B1821311811080080088C0B014000001DE3001E71020101C40801C840460515E1902A00",
	INITVAL_02 => "0x01E00074FF07E1208000184FF064FF00853000D403A13062D01CC1C0800000200002811E8CF1821C",
	INITVAL_03 => "0x03200082F5000331EA84000F7072110B25302060062211FE0501E0D0821E01C30022050020A02200",
	INITVAL_04 => "0x000000100D000000208F1A000010051F20D000400A63001A2F1E2D0000F903E00074510E2F1024A6",
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
	INITVAL_00 => "0x1E000000621A00E044120420005E4F02022040000008F02000000011FEF400211022FE1C0011E000",
	INITVAL_01 => "0x0442004400044230222203C200221104022020001000204000042200C201010100000015E2004A00",
	INITVAL_02 => "0x1E0C0004FF19E2004000020FF1E69F00020040F0040250000006C2F0000100421004120021F04422",
	INITVAL_03 => "0x05E40004A0080001E402020F001E100582009CED00C0B1FE000540F0042D0580C044000420E00421",
	INITVAL_04 => "0x000000000F006380000F1E033000021E20F00600040030000F1E4F0066F101400144A0144A204020",
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
	INITVAL_00 => "0x02000004001E00F10008000000000F00088100000008F00000000001E0F0000000000F0800008000",
	INITVAL_01 => "0x1001A002C0020810000001E0000000100880000000000000000008E00020000000000000280000A2",
	INITVAL_02 => "0x00000000001800000080000F01E60F00082000F001480000080060F0000001001000000000002001",
	INITVAL_03 => "0x1000000000000001F008000F001E0001E0001E0F000001E0100000F0000F01E20100000000F00000",
	INITVAL_04 => "0x000000000F02000000001E200000001E20F02000000001C0201E0F100000000001E0F01E00010000",
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
	INITVAL_00 => "0x11088100021E00F10088010001200F000760A0000104F00000010081F0F8010000000F1000800000",
	INITVAL_01 => "0x0440204020004800002801E00000001C0FE0108001000110001105F00A000000000010010801201C",
	INITVAL_02 => "0x0000000A00180200A040000F01EC0F000C5100F010010000000464F0000811E00104031000000420",
	INITVAL_03 => "0x0601000200060001FC0E010F001E0003E1001E0F000001E0501000F0101F01E20022001000F01008",
	INITVAL_04 => "0x000000000F01080000001E088000021E00F010000A008080401EAF011000000001E4F01E60404050",
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
	INITVAL_00 => "0x0C89204A000A208000200069004620012EC15CCA0E0180C21102C58028430640105E2D180CD02200",
	INITVAL_01 => "0x00000000050000003E0001AD00022F0A0040A880000FF1C00D1960500041000100F2950BE4813022",
	INITVAL_02 => "0x088000149A048001A02002E36014030003A140070D4081FC9D196030A0030A0D00A0100A0F500000",
	INITVAL_03 => "0x040201E0060400A08A040A840134E3148A0128020047006C29080000440013250000080820012804",
	INITVAL_04 => "0x00000000000A6220800200625000480C0001B85A100B7180A70C003184200A02000E090000000036",
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
	INITVAL_00 => "0x00010020000460004012000340400103CA61C0000021C19ADD1A00002000000BB1760B1201106211",
	INITVAL_01 => "0x0000100010000A017608176BE176BB1400000010002C0002A800004000050005E0480E0026C02001",
	INITVAL_02 => "0x110000843400004080000C0000900000440000EC00C01000000000A154A0000B0140B2016B000000",
	INITVAL_03 => "0x1C0000C00C0004809400000420A866110421300809000000080000408002130000000900C0212000",
	INITVAL_04 => "0x0000001C0A0D080100E40C88801CA21800A110AA04CC801800180681100C140A010C2708C04080C6",
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
	INITVAL_00 => "0x04422048C00CC060700310062048C60C21101CEE1D804098CC1984C0984C080FF1FE470F0CC0D86C",
	INITVAL_01 => "0x040C0018041800C1FE001EE731FEFF0660319860198540181100005180420182014C470840406800",
	INITVAL_02 => "0x11080026300080100000088440AA8400E100004000A040884C19804098CC18078080F219EF41800C",
	INITVAL_03 => "0x01000080840001C08611198431A84400807108840904808804010040000710008000040080300020",
	INITVAL_04 => "0x00000006000180408030000C0006C1090010384C02A0000004080011804009000000300208000A04",
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
	INITVAL_00 => "0x132991240002401000A00142100432042000108810601054AA146230542A054AA154220403304623",
	INITVAL_01 => "0x00000000020000015400144201108800000066300061210613114020002000001042210520100400",
	INITVAL_02 => "0x0660002033004010004000422024020020014013104020442306601054B306020060800708200000",
	INITVAL_03 => "0x0000002002000120400006621044120040104402024200440114001070010420000001100010704A",
	INITVAL_04 => "0x0000000001070A2040030268A000A0040010702A0023A002020401311421040A0020130200000201",
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
