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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Xilinx libraries
library UNISIM;
use UNISIM.VComponents.all;

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
	
	-- 32-bit wide memory with wait state insertion on byte / half word writes
	small_mem:
	if mem_type = "small" generate
	begin
	
	dmem_data_ready <= not dmem_must_wait;
	
	-- We need a read followed by a write cycle if storing a byte or half a word, so
	-- insert a wait state in such cases
	dmem_must_wait <= '1' when dmem_wait_cycle = '0' and dmem_byte_we /= "0000" and
		dmem_byte_we /= "1111" and dmem_addr_strobe = '1' else '0';
	
	process(clk, dmem_must_wait)
	begin
		if rising_edge(clk) then
			if dmem_wait_cycle = '0' and dmem_must_wait = '1' then
				dmem_wait_cycle <= '1';
			else
				dmem_wait_cycle <= '0';
			end if;
		end if;
	end process;
	
	dmem_we <= '1' when dmem_byte_we /= "0000" and dmem_must_wait = '0' else '0';
	dmem_write_out(7 downto 0) <= dmem_data_in(7 downto 0) when
		dmem_byte_we(0) = '1' else dmem_data_read(7 downto 0);
	dmem_write_out(15 downto 8) <= dmem_data_in(15 downto 8) when
		dmem_byte_we(1) = '1' else dmem_data_read(15 downto 8);
	dmem_write_out(23 downto 16) <= dmem_data_in(23 downto 16) when
		dmem_byte_we(2) = '1' else dmem_data_read(23 downto 16);
	dmem_write_out(31 downto 24) <= dmem_data_in(31 downto 24) when
		dmem_byte_we(3) = '1' else dmem_data_read(31 downto 24);
	
	dmem_bram_cs <= dmem_addr_strobe;
	dmem: RAMB16_S36_S36
		generic map(
			INIT_00 => x"0000000000000000000000001000fffb3c1be0000c000008379c81f03c1c0000",
			INIT_01 => x"304200f08f8280340040402110400006af838030af828038000310278f838038",
			INIT_02 => x"8f828034af828034344200803042000f8f828034af8280340800001734420008",
			INIT_03 => x"344200803042000faf8280340800002134420008304200f0af62000810600005",
			INIT_04 => x"004310238f6200043444f0803c0202fa8f630004af6500088f858034af828034",
			INIT_05 => x"080000333442000c30a200f030a2000f11000005000000001440fffc0044102a",
			INIT_06 => x"344468c03c0204788f630004af6500088f858034af828034344200c0af828034",
			INIT_07 => x"30a200f030a2000f11000005000000001440fffc0044102a004310238f620004",
			INIT_08 => x"8f630004af6500088f858034af82803434420020af8280340800004534420002",
			INIT_09 => x"3c02017d000038211440fffc0044102a004310238f620004344484003c0217d7",
			INIT_0A => x"8f6200048f630004af64000830a400f030a4000f110000022409000434467840",
			INIT_0B => x"08000062308200f03082000f11000004000000001440fffc0046102a00431023",
			INIT_0C => x"1440fffc0046102a004310238f6200048f630004af6500083445002034450002",
			INIT_0D => x"3442000430a200f030a2000f110000050000000014e9ffe724e7000100000000",
			INIT_0E => x"3c0208f08f630004af6200088f828034af82803434420040af82803408000074",
			INIT_0F => x"0000000003e00008000000001440fffc0044102a004310238f6200043444d180"
		)
		port map(
			DIA => dmem_write_out, DIB => x"ffffffff",
			DOA => dmem_data_read, DOB => imem_data_out,
			ADDRA => dmem_addr(10 downto 2),	ADDRB => imem_addr(10 downto 2),
			CLKA => not clk, CLKB => not clk, ENA => dmem_bram_cs, ENB => '1', SSRA => '0',
			SSRB => '0', WEA => dmem_we, WEB => '0', DIPA => x"f", DIPB => x"f"
		);

	end generate; -- small_mem
	
	big_mem:
	if mem_type /= "small" generate
	begin
	
	dmem_data_ready <= '1';
	dmem_write_out <= dmem_data_in;
	dmem_bram_cs <= dmem_addr_strobe;
		
	dmem_0: RAMB16_S9_S9
		generic map(
			INIT_00 => x"800f342108f008053434800f34341708f034210630382738000000fb0008f000",
			INIT_01 => x"f00f0500fc2a2304c07804083434c034330cf00f0500fc2a230480fa04083434",
			INIT_02 => x"62f00f0400fc2a23040408f00f0204407d21fc2a230400d70408343420344502",
			INIT_03 => x"000800fc2a230480f00408343440347404f00f0500e70100fc2a230404082002"
		)
		port map(
			DIA => dmem_write_out(7 downto 0), DIB => x"ff",
			DOA => dmem_data_read(7 downto 0), DOB => imem_data_out(7 downto 0),
			ADDRA => dmem_addr(12 downto 2),	ADDRB => imem_addr(12 downto 2),
			CLKA => not clk, CLKB => not clk, ENA => dmem_bram_cs, ENB => '1', SSRA => '0',
			SSRB => '0', WEA => dmem_byte_we(0), WEB => '0', DIPA => "1", DIPB => "1"
		);
	dmem_1: RAMB16_S9_S9
		generic map(
			INIT_00 => x"000080000000000080800000808000000080400080801080000000ffe0008100",
			INIT_01 => x"00000000ff1010006804000080800080000000000000ff101000f00200008080",
			INIT_02 => x"0000000000ff101000000000000000780138ff10100084170000808000800000",
			INIT_03 => x"000000ff101000d108000080800080000000000000ff0000ff10100000000000"
		)
		port map(
			DIA => dmem_write_out(15 downto 8), DIB => x"ff",
			DOA => dmem_data_read(15 downto 8), DOB => imem_data_out(15 downto 8),
			ADDRA => dmem_addr(12 downto 2),	ADDRB => imem_addr(12 downto 2),
			CLKA => not clk, CLKB => not clk, ENA => dmem_bram_cs, ENB => '1', SSRA => '0',
			SSRB => '0', WEA => dmem_byte_we(1), WEB => '0', DIPA => "1", DIPB => "1"
		);
	dmem_2: RAMB16_S9_S9
		generic map(
			INIT_00 => x"424282004242626082824242828200424282404083820383000000001b009c1c",
			INIT_01 => x"a2a200004044436244026365858242820042a2a2000040444362440263658582",
			INIT_02 => x"0082820000404643626364a4a400094602004044436244026365858242820042",
			INIT_03 => x"00e0004044436244026362828242820042a2a20000e9e7004046436263654545"
		)
		port map(
			DIA => dmem_write_out(23 downto 16), DIB => x"ff",
			DOA => dmem_data_read(23 downto 16), DOB => imem_data_out(23 downto 16),
			ADDRA => dmem_addr(12 downto 2),	ADDRB => imem_addr(12 downto 2),
			CLKA => not clk, CLKB => not clk, ENA => dmem_bram_cs, ENB => '1', SSRA => '0',
			SSRB => '0', WEA => dmem_byte_we(2), WEB => '0', DIPA => "1", DIPB => "1"
		);
	dmem_3: RAMB16_S9_S9
		generic map(
			INIT_00 => x"3430af083430af108faf34308faf0834308f0010afaf008f000000103c0c373c",
			INIT_01 => x"303011001400008f343c8faf8faf34af0834303011001400008f343c8faf8faf",
			INIT_02 => x"08303011001400008f8faf30301124343c001400008f343c8faf8faf34af0834",
			INIT_03 => x"0003001400008f343c8faf8faf34af0834303011001424001400008f8faf3434"
		)
		port map(
			DIA => dmem_write_out(31 downto 24), DIB => x"ff",
			DOA => dmem_data_read(31 downto 24), DOB => imem_data_out(31 downto 24),
			ADDRA => dmem_addr(12 downto 2),	ADDRB => imem_addr(12 downto 2),
			CLKA => not clk, CLKB => not clk, ENA => dmem_bram_cs, ENB => '1', SSRA => '0',
			SSRB => '0', WEA => dmem_byte_we(3), WEB => '0', DIPA => "1", DIPB => "1"
		);
		
	end generate; -- big_mem
end Behavioral;
