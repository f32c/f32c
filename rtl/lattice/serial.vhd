--
-- Copyright 2010 University of Zagreb, Croatia.
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

-- $Id: serial.vhd 116 2011-03-28 12:43:12Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;

entity serial_debug is
	generic (
		clk_divisor: std_logic_vector(15 downto 0)
			-- := x"1458" -- 9600 bps
			-- := x"0a2c" -- 19200 bps
			-- := x"0516" -- 38400 bps
			-- := x"0364" -- 57600 bps
			-- := x"01b2" -- 115200 bps
			:= x"00d9" -- 230400 bps
	);
	port (
		clk: in std_logic;
		rs232_txd: out std_logic;
		trace_addr: out std_logic_vector(5 downto 0);
		trace_data: in std_logic_vector(31 downto 0)
	);
end serial_debug;

architecture Behavioral of serial_debug is
	signal rs232_tick_cnt: std_logic_vector(15 downto 0);
	signal txd: std_logic;
	signal txbitcnt: std_logic_vector(3 downto 0);
	signal txchar, nextchar: std_logic_vector(7 downto 0);
	signal char_tx_done: boolean;
	signal trace_phase: std_logic_vector(3 downto 0);
	signal trace_word: std_logic_vector(31 downto 0);
	signal trace_addr_next: std_logic_vector(5 downto 0);
	signal bram_out: std_logic_vector(7 downto 0);
	signal bram_addr: std_logic_vector(10 downto 0);

	-- #Paths to register_c are ignored
	-- define_false_path -to register_c
	-- define_false_path -to trace_word

begin

	rs232_txd <= txd;
	trace_addr <= trace_addr_next;
	
	debug_rom: DP16KB
	generic map (
		INITVAL_00 => "0x0402004020040200402004020040200402004020040200402004020040200402004020040480B61B",
		INITVAL_01 => "0x0E47A05020060240400A01A4B0B61B0E6720CA740E6690CE650E4200D8610E4650DC6508E2004020",
		INITVAL_02 => "0x1202007429060730502006C3104820040C0110200742906074050200702404020040C01002007429",
		INITVAL_03 => "0x180810403A052740C22804031048200140D0965B036C0130200742907074050200683204820040C0",
		INITVAL_04 => "0x0642404020180910403A052310E628040370622404020180890403A052310E828040390482004020",
		INITVAL_05 => "0x0603104820040C010420074290607605020064240400A01A4B0B61B180990403A052390E82804035",
		INITVAL_06 => "0x0606B0502006C3204820040C0124200742906473050200703104820040C011420074290647405020",
		INITVAL_07 => "0x052330E828040310622404020180830403A052310EC2804033048200140D0965B036C01342007429",
		INITVAL_08 => "0x1809B0403A052310D628040370642404020180930403A052330E6280403906224040201808B0403A",
		INITVAL_09 => "0x040C0118200742906874050200643104820040C010820074290606105020068240400A01A4B0B61B",
		INITVAL_0A => "0x0140D0965B036C013820074290E067050200703204820040C0128200742906873050200603204820",
		INITVAL_0B => "0x0403106424040201808D0403A052350E828040330622404020180850403A052310C2280403504820",
		INITVAL_0C => "0x0502006C240400A01A4B0B61B1809D0403A052700E628040390642404020180950403A052350E628",
		INITVAL_0D => "0x0742906C73050200643204820040C011C200742906C74050200683104820040C010C200742906461",
		INITVAL_0E => "0x0403A052330C22804037048200140D0965B036C013C200742907073050200603304820040C012C20",
		INITVAL_0F => "0x04020180970403A052370E6280403306424040201808F0403A052370E82804035062240402018087",
		INITVAL_10 => "0x0403A0CA730EA6108620040200140D0965B0360A01A4B0B61B1809F0403A052610E4280403106624",
		INITVAL_11 => "0x04020180BD0403A0865008A20040200402004020180BE0403A0E6750E8610E8530402004020180BF",
		INITVAL_12 => "0x04020040C017620074490902004020040200400A01A4B0B61B180BC0403A0E4640C8410AC640C242",
		INITVAL_13 => "0x04020040200402004020040200400A01A4B0B61B0140D0965B036C0174200744F098200402004020",
		INITVAL_14 => "0x0DC690D8650E0690A020040200402004020040200402004020040200402004020040200402004020",
		INITVAL_15 => "0x04020040200402004020040200402004020090430A84508C200402004020040200140D0965B03665",
		INITVAL_16 => "0x040200402008A540AA4308A5808A20040200402004020040200402004020040450884F0864508820",
		INITVAL_17 => "0x074430A02004020040200400A01A4B0B61B0A65308A4308641040590A44F09A4509A200402004020",
		INITVAL_18 => "0x040C014420074430A020040200402004020040C014220074430A020040200402004020040C014020",
		INITVAL_19 => "0x04020180A40403A0E8630EA720E8730DC690140D0965B036C014620074430A020040200402004020",
		INITVAL_1A => "0x0E8730DC6904020180A60403A0E8630EA720E8730DC6904020180A50403A0E8630EA720E8730DC69",
		INITVAL_1B => "0x0402004020040200402004020040200402004020040200400A01A4B0B61B180A70403A0E8630EA72",
		INITVAL_1C => "0x0C86104020040C015420074310CE650E45F0CC660CA20040C015020074310CE650E45F0CC660CA20",
		INITVAL_1D => "0x0402004020040200402004020040200402004020040200140D0965B036C015A20074780C4750E664",
		INITVAL_1E => "0x0402004020180AB0403A064670CA720BE660CC6504020180A90403A064670CA720BE660CC6504020",
		INITVAL_1F => "0x04020040200402004020040200402004020040200400A01A4B0B61B180AE0403A0C6690CE6F0D820",
		INITVAL_20 => "0x074320EA6C0C25F0CC660CA200402004020040200402004020040200402004020040200402004020",
		INITVAL_21 => "0x04020040200402004020040200140D0965B036C015E20074740EA6F0BE6D0CA6D0C820040C015820",
		INITVAL_22 => "0x04020040200402004020040200402004020040200402004020040200402004020040200402004020",
		INITVAL_23 => "0x0B61B180B00403A0DC690BE6D0CA6D0C820040200402004020040200402004020040200402004020",
		INITVAL_24 => "0x0403A0E6650D8630F243040200140D0965B0360A01A4B0B61B180B90403A0B0580B0200400A01A4B",
		INITVAL_25 => "0x04020180B60403A0E6650D0630DC610E44204020180B50403A0E8630EA720E8730DC4904020180B4",
		INITVAL_26 => "0x1F8FC1FCFE1FEFF0945B0366C06A3207E5B0360A01A4B0B61B180B70403A0DC650D6610A82004020",
	    -- CSDECODE_B => "111", CSDECODE_A => "000",
	    WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
	    GSR => "DISABLED", RESETMODE => "SYNC", 
	    REGMODE_B => "NOREG", REGMODE_A => "NOREG",
	    DATA_WIDTH_B => 9, DATA_WIDTH_A=> 9
	)
	port map (
	    DIA0 => '0', DIA1 => '0', DIA2 => '0', DIA3 => '0',
	    DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
	    DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0', 
	    DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15 => '0',
	    DIA16 => '0', DIA17 => '0', 
	    DOA0 => bram_out(0), DOA1 => bram_out(1), DOA2 => bram_out(2), DOA3 => bram_out(3),
	    DOA4 => bram_out(4), DOA5 => bram_out(5), DOA6 => bram_out(6), DOA7 => bram_out(7),
	    DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
	    DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
	    DOA16 => open, DOA17 => open, 
	    ADA0 => '0', ADA1 => '0', ADA2 => '0', ADA3 => bram_addr(0),
	    ADA4 => bram_addr(1), ADA5 => bram_addr(2), ADA6 => bram_addr(3), ADA7 => bram_addr(4),
	    ADA8 => bram_addr(5), ADA9 => bram_addr(6), ADA10 => bram_addr(7), ADA11 => bram_addr(8), 
	    ADA12 => bram_addr(9), ADA13 => bram_addr(10),
	    CEA => '1', CLKA => clk, WEA => '0',
	    CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0', 

	    DIB0 => '0', DIB1 => '0', DIB2 => '0', DIB3 => '0',
	    DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0',
	    DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => '0', 
	    DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0',
	    DIB16 => '0', DIB17 => '0', 
	    DOB0 => open, DOB1 => open, DOB2 => open, DOB3 => open,
	    DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
	    DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open,
	    DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
	    DOB16 => open, DOB17 => open,
	    ADB0 => '0', ADB1 => '0', ADB2 => '0', ADB3 => '0',
	    ADB4 => '0', ADB5 => '0', ADB6 => '0', ADB7 => '0',
	    ADB8 => '0', ADB9 => '0', ADB10 => '0', ADB11 => '0', 
	    ADB12 => '0', ADB13 => '0',
	    CEB => '0', CLKB => '0', WEB => '0',
	    CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0'
	);

	process(clk)
	begin
		if rising_edge(clk) then
		
			-- TX a char, bit by bit
			char_tx_done <= false;
			rs232_tick_cnt <= rs232_tick_cnt - 1;
			if rs232_tick_cnt = "0000" then
				rs232_tick_cnt <= clk_divisor;
				txbitcnt <= txbitcnt + 1;
				txd <= txchar(0);
				txchar <= '1' & txchar(7 downto 1);
				if txbitcnt = "1010" then
					txbitcnt <= "0000";
					txd <= '0'; -- start bit
					txchar <= nextchar;
					char_tx_done <= true;
				end if;
			end if;
			
			-- Fetch new char
			if char_tx_done then
				if trace_phase /= "0000" then
					-- print out trace word in hex one nibble at a time
					trace_phase <= trace_phase - 1;
					if trace_word(31 downto 28) < "1010" then
						nextchar <= "00110000" + trace_word(31 downto 28);
					else
						nextchar <= "01010111" + trace_word(31 downto 28);
					end if;
					trace_word(31 downto 4) <= trace_word(27 downto 0);
				else
					bram_addr <= bram_addr + 1;
					if bram_out(7 downto 6) = "10" then
						-- set new trace addr
						trace_addr_next <= bram_out(5 downto 0);
						nextchar <= x"00";
					elsif bram_out(7 downto 5) = "110" then
						-- fetch new trace word and start printing it out
						trace_word <= trace_data;
						trace_phase <= "1000";
						nextchar <= x"00";
					elsif bram_out(7 downto 5) = "111" then
						-- goto bram address 0
						bram_addr <= "00000000000";
						nextchar <= x"00";
					else
						-- ordinary ASCII character - print it out
						nextchar <= bram_out;
					end if;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
