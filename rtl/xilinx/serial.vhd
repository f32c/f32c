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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity serial_debug is
   generic (
		clk_divisor: std_logic_vector(15 downto 0)
			-- := x"1458" -- 9600 bps
			-- := x"0a2c" -- 19200 bps
			-- := x"0516" -- 38400 bps
			-- := x"0364" -- 57600 bps
			:= x"01b2" -- 115200 bps
			-- := x"00d9" -- 230400 bps
	);
	port (
		clk_50m: in std_logic;
		rs232_txd: out std_logic;
		trace_addr: out std_logic_vector(5 downto 0);
		trace_data: in std_logic_vector(31 downto 0)
	);
end serial_debug;

architecture Behavioral of serial_debug is
	signal clk_50m_g: std_logic;
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
begin

	dmem: RAMB16_S9
		generic map(
			-- the content below is programatically generated via bram2ser.tcl
			INIT_00 => x"2020202020202020202020202020202020202020202020202020202020485B1B",
			INIT_01 => x"727A28203024200A0D4B5B1B737265747369676572206C6172656E6547202020",
			INIT_02 => x"90203A29307328203631242020C088203A29307428203824202020C080203A29",
			INIT_03 => x"C081203A29746128203124200A0D4B5B1BC098203A29387428203432242020C0",
			INIT_04 => x"32242020C091203A29317328203731242020C089203A29317428203924202020",
			INIT_05 => x"3031242020C082203A29307628203224200A0D4B5B1BC099203A293974282035",
			INIT_06 => x"306B28203632242020C092203A29327328203831242020C08A203A2932742820",
			INIT_07 => x"29337428203131242020C083203A29317628203324200A0D4B5B1BC09A203A29",
			INIT_08 => x"C09B203A29316B28203732242020C093203A29337328203931242020C08B203A",
			INIT_09 => x"20C08C203A29347428203231242020C084203A29306128203424200A0D4B5B1B",
			INIT_0A => x"0A0D4B5B1BC09C203A29706728203832242020C094203A293473282030322420",
			INIT_0B => x"203132242020C08D203A29357428203331242020C085203A2931612820352420",
			INIT_0C => x"28203624200A0D4B5B1BC09D203A29707328203932242020C095203A29357328",
			INIT_0D => x"3A29367328203232242020C08E203A29367428203431242020C086203A293261",
			INIT_0E => x"203A29336128203724200A0D4B5B1BC09E203A29387328203033242020C09620",
			INIT_0F => x"2020C097203A29377328203332242020C08F203A29377428203531242020C087",
			INIT_10 => x"203A65737561432020200A0D4B5B1B0A0D4B5B1BC09F203A2961722820313324",
			INIT_11 => x"2020C0BD203A43504520202020202020C0BE203A73757461745320202020C0BF",
			INIT_12 => x"202020C0BB203A49482020202020200A0D4B5B1BC0BC203A7264644156646142",
			INIT_13 => x"20202020202020202020200A0D4B5B1B0A0D4B5B1BC0BA203A4F4C2020202020",
			INIT_14 => x"6E696C6570695020202020202020202020202020202020202020202020202020",
			INIT_15 => x"20202020202020202020202020204843544546202020202020200A0D4B5B1B65",
			INIT_16 => x"2020202045545543455845202020202020202020202020202045444F43454420",
			INIT_17 => x"3A43502020202020200A0D4B5B1B5353454343412059524F4D454D2020202020",
			INIT_18 => x"20C0A2203A43502020202020202020C0A1203A43502020202020202020C0A020",
			INIT_19 => x"2020C0A4203A7463757274736E690A0D4B5B1BC0A3203A435020202020202020",
			INIT_1A => x"74736E692020C0A6203A7463757274736E692020C0A5203A7463757274736E69",
			INIT_1B => x"202020202020202020202020202020202020200A0D4B5B1BC0A7203A74637572",
			INIT_1C => x"6461202020C0AA203A316765725F6666652020C0A8203A316765725F66666520",
			INIT_1D => x"2020202020202020202020202020202020200A0D4B5B1BC0AD203A7862757364",
			INIT_1E => x"20202020C0AB203A326765725F6666652020C0A9203A326765725F6666652020",
			INIT_1F => x"20202020202020202020202020202020200A0D4B5B1BC0AE203A6369676F6C20",
			INIT_20 => x"3A32756C615F6666652020202020202020202020202020202020202020202020",
			INIT_21 => x"2020C0B0203A73656C63794320200A0D4B5B1B0A0D4B5B1B0A0D4B5B1BC0AC20",
			INIT_22 => x"542020202020C0B2203A736568636E6172422020C0B1203A7463757274736E49",
			INIT_23 => x"FF4A5B1B6C35323F5B1B0A0D4B5B1BC0B3203A6E656B61"
		)
		port map(
			DI => x"ff", DIP => "1", ADDR => bram_addr, DO => bram_out,
			CLK => clk_50m_g, EN => '1', SSR => '0', WE => '0'
		);

	rs232clk_bufg: BUFG
		port map (I => clk_50m, O => clk_50m_g);

	rs232_txd <= txd;
	trace_addr <= trace_addr_next;
	
	process(clk_50m_g)
	begin
		if rising_edge(clk_50m_g) then
		
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
