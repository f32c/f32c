--
-- Copyright 2008, 2010 University of Zagreb, Croatia.
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
		mem_type: string := "big"
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

	ram_0: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B=> "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE=> "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A=> "NOREG",
		DATA_WIDTH_B=> 9, DATA_WIDTH_A=> 9,
		INITVAL_00 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
		CEA => '1', CLKA => not clk, WEA => dmem_byte_we(0),
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

	ram_1: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B=> "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE=> "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A=> "NOREG",
		DATA_WIDTH_B=> 9, DATA_WIDTH_A=> 9,
		INITVAL_00 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
		CEA => '1', CLKA => not clk, WEA => dmem_byte_we(1),
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

	ram_2: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B=> "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE=> "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A=> "NOREG",
		DATA_WIDTH_B=> 9, DATA_WIDTH_A=> 9,
		INITVAL_00 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
		CEA => '1', CLKA => not clk, WEA => dmem_byte_we(2),
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

	ram_3: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A => "000",
		WRITEMODE_B=> "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE=> "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A=> "NOREG",
		DATA_WIDTH_B=> 9, DATA_WIDTH_A=> 9,
		INITVAL_00 => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000"
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
		CEA => '1', CLKA => not clk, WEA => dmem_byte_we(3),
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

end Behavioral;
