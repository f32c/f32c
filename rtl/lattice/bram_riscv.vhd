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
	INITVAL_00 => "0x00C0001A130100001AB70403E0DC370666603CB7000000141300000016130001704C231FE0700E13",
	INITVAL_01 => "0x1E610000231FC09138E3000401F2931E41000083140DE110930000001213002F0018130080001893",
	INITVAL_02 => "0x000000109300000010131FADF1E06F0662E010931FEF00121300409034631FC0812CE3080881B093",
	INITVAL_03 => "0x01EF001293022800006F0000801613004000006F00020014931FEF00109301EF00129300C800006F",
	INITVAL_04 => "0x01EF0012130000900C63002B80F2331801005073004081BC63000200169300020014931FEF001093",
	INITVAL_05 => "0x002000006F000F9092130001F0AC6301EFF0FE1301EF80E093082380BE130000001213000800006F",
	INITVAL_06 => "0x1E400012031F409014E3000101F2131E410000831E220010230808A0B213000800006F01E0909213",
	INITVAL_07 => "0x000480F0131E4100100300E2C0B4631E400118E31FE39000931EC0F010E31F4D901E13004081AC63",
	INITVAL_08 => "0x1FC09012130022D0AC6300048030131E80F014E31FE3901E131F05F1E06F1E620000231FC08038E3",
	INITVAL_09 => "0x1FEF811213002090D03300018110931FA0901213000800006F1F899012130022C1AC63000800006F",
	INITVAL_0a => "0x002EB1CC631FEF801E130000B0006700000000930000100E370001B1D0631FE98000930040903063",
	INITVAL_0b => "0x0020A114B3000180301300009030631FED8112131E41F1E06F000000101300059112930001803293",
	INITVAL_0c => "0x000181E0931DE191B4E31DE9F1E06F00008112931DC0B008E3000080141300238134631FC9F1E06F",
	INITVAL_0d => "0x000191F093002800006F00000010131DADF1E06F0001A014130020A000231DE581A8E31DC0010CE3",
	INITVAL_0e => "0x0000001093000000101300000100671FC0912CE30001903213000191B29300228010330000810863",
	INITVAL_0f => "0x0027C010B30000C1101300238116B30020C1783300228018B30000B018630001A0F613008000006F",
	INITVAL_10 => "0x0023D0D2B300019032130001A1B4930024D1D43300019132930001A0B413002F90BA13002FA13A93",
	INITVAL_11 => "0x0000000000000000000000000000000000000000000000000000000100671F80E020E30025A0DC33",
	INITVAL_12 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_13 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_14 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_15 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_16 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_17 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_18 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_19 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1a => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1b => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1c => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1d => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1e => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000",
	INITVAL_1f => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x066330663306633066F31E6330663F066330663307E3F0663F066F306633066330663306E7706633",
	INITVAL_01 => "0x066330663F066730663307E3F06633066F30663F066331E633066730E633066331E63F0663307E33",
	INITVAL_02 => "0x0000000000000000000000000000000000000000000000000000000000000000000E330663306633",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x0206E13C1601C18042610C2611221602C370D29912C16132961226902CE905C98122190363B02221",
	INITVAL_01 => "0x162B316C161226E0323612C16024EE13C691C266162610C2990C26906C96026910C26602C1E02C2E",
	INITVAL_02 => "0x0000000000000000000000000000000000000000000000000000000000000000000CE31629312219",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x110AC010F613490112090126F01E9012C981D6A8120B015090110081346801890112CC1BAEE15667",
	INITVAL_01 => "0x110BC198B01100613284100801404601409094A015089010990DE000F008130890126012C8A1E00C",
	INITVAL_02 => "0x000000000000000000000000000000000000000000000000000000000000000000000E132AA134DD",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x0E0580000D000F000A04008570EA00000721A0000000000000000F00029D012F0100000006100020",
	INITVAL_01 => "0x0108B000700008903A081E00F000D81FAF80009F102181E0811C00001C0110C80000D000A1001E01",
	INITVAL_02 => "0x00000000000000000000000000000000000000000000000000000000000000000010160C2DE12A59",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x100C013E980120001409012FF1100001280100000008000000000FE01288012001C000000E600077",
	INITVAL_01 => "0x1988C116A000009132881200F15480112F81708F150981E098170B00368911289012C013A8F13E08",
	INITVAL_02 => "0x00000000000000000000000000000000000000000000000000000000000000000000EA1B2AD1349A",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x08220060D0000110508001E1F1E6081E0B10042F1F00005EF8000D21E008020411A0F00003600010",
	INITVAL_01 => "0x0E0300401000000022200300D0205002290000390020D020511DE00002901E010112280044006A20",
	INITVAL_02 => "0x000000000000000000000000000000000000000000000000000000000000000000000506214022FF",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x004721ECA2054020200F0200F1E2001E0100400F1E20201EF6000D31E4E007C02000140D0030000F",
	INITVAL_01 => "0x02011020040000E000100020D002FE01EF01C01E0200F0400003E00000F21E20D018101C2041F03E",
	INITVAL_02 => "0x00000000000000000000000000000000000000000000000000000000000000000000C10200100011",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
	INITVAL_00 => "0x01E0F1FEF01FE0F1E80000000008000000C0000F0020001E00000F31E0F41FE0F14000000230000F",
	INITVAL_01 => "0x00000000000000F000000000E000EE01CE01C00F0000F1E00001E00000F01E00F01E001E00F1FEFF",
	INITVAL_02 => "0x00000000000000000000000000000000000000000000000000000000000000000000F00000000000",
	INITVAL_03 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
