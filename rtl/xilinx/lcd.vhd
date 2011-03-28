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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity lcd_debug is
	generic (
		reg_trace: string;
		bus_trace: string;
		imem_trace: string;
		dmem_trace: string
	);
	port (
		slowclk: in std_logic;
		lcd_db: out std_logic_vector(7 downto 0);
		lcd_e, lcd_rs, lcd_rw: out std_logic;
		rot_a, rot_b, rot_center, btn_south, btn_north, btn_east, btn_west: in std_logic;
		sw: std_logic_vector(3 downto 0);
		buffered_keys: out std_logic_vector(8 downto 0);
		left, right: out std_logic;
		trace_selector: out std_logic;
		trace_addr: out std_logic_vector(4 downto 0);
		trace_data: in std_logic_vector(31 downto 0);
		trace_mem_addr: out std_logic_vector(19 downto 2);
		trace_mem_data: in std_logic_vector(31 downto 0)
	);
end lcd_debug;

architecture Behavioral of lcd_debug is
	signal hpos: std_logic_vector(4 downto 0);
	signal vpos: std_logic;
	signal mode: std_logic_vector(1 downto 0);
	signal mode_noswitch: std_logic;
	signal prev_rot_center: std_logic;
	signal imem_addr: std_logic_vector(19 downto 2);
	signal dmem_addr: std_logic_vector(19 downto 2);
	signal reg_addr: std_logic_vector(4 downto 0);
	signal bus_addr: std_logic_vector(3 downto 0);
	signal generic_addr: std_logic_vector(19 downto 0);
	signal out_word: std_logic_vector(31 downto 0);
	signal rot_left, rot_right: std_logic;
	signal keys_in, keys_out: std_logic_vector(8 downto 0);
	signal init_cnt: std_logic_vector(7 downto 0);
begin

	-- fetch input from buttons and rotary knob
	keys_in <= rot_center & sw & btn_west & btn_south & btn_east & btn_north;
	rotary: entity rotary
		port map(rot_a, rot_b, rot_left, rot_right, keys_in, keys_out, slowclk);
	buffered_keys <= keys_out;
	left <= rot_left;
	right <= rot_right;
	
	-- change mode: reg, buf, imem or dmem
	process(slowclk)
	begin
		if rising_edge(slowclk) then
			if keys_out(8) = '0' and prev_rot_center = '1' and mode_noswitch = '0' then
				mode <= mode + 1;
			end if;
			if mode(1) = '1' then
				mode <= "00";
			end if;
			prev_rot_center <= keys_out(8);
		end if;
	end process;
	
	-- update target addresses
	process(slowclk)
		variable prev_left, prev_right: std_logic;
		variable delta : integer;
	begin
		if rising_edge(slowclk) and btn_south = '0' then
			if prev_rot_center = '0' then
				mode_noswitch <= '0';
			end if;
			if keys_out(8) = '0' then
				delta := 1;
			else
				delta := 256;
			end if;
			case mode is
				when "00" =>
					if rot_left = '1' and prev_left = '0' then
						reg_addr <= reg_addr - delta;
						mode_noswitch <= '1';
					elsif rot_right = '1' and prev_right = '0' then
						reg_addr <= reg_addr + delta;
						mode_noswitch <= '1';
					end if;
				when "01" =>
					if rot_left = '1' and prev_left = '0' then
						bus_addr <= bus_addr - delta;
						mode_noswitch <= '1';
					elsif rot_right = '1' and prev_right = '0' then
						bus_addr <= bus_addr + delta;
						mode_noswitch <= '1';
					end if;
				when "10" =>
					if rot_left = '1' and prev_left = '0' then
						imem_addr <= imem_addr - delta;
						mode_noswitch <= '1';
					elsif rot_right = '1' and prev_right = '0' then
						imem_addr <= imem_addr + delta;
						mode_noswitch <= '1';
					end if;
				when "11" =>
					if rot_left = '1' and prev_left = '0' then
						dmem_addr <= dmem_addr - delta;
						mode_noswitch <= '1';
					elsif rot_right = '1' and prev_right = '0' then
						dmem_addr <= dmem_addr + delta;
						mode_noswitch <= '1';
					end if;
				when others => null;
			end case;
			prev_left := rot_left;
			prev_right := rot_right;
		end if;
	end process;
	
	-- compute address for displaying
	process(slowclk)
	begin
		if rising_edge(slowclk) then
			case mode is
				when "00" =>
					generic_addr <= "000000000000000" & (reg_addr + vpos);
					trace_addr <= reg_addr + vpos;
					trace_selector <= '0';
				when "01" =>
					generic_addr <= "0000000000000000" & (bus_addr + vpos);
					trace_addr <= '0' & (bus_addr + vpos);
					trace_selector <= '1';
				when "10" =>
					generic_addr <= (imem_addr + vpos) & "00";
					trace_mem_addr <= imem_addr + vpos;
					trace_selector <= '0';
				when "11" =>
					generic_addr <= (dmem_addr + vpos) & "00";
					trace_mem_addr <= dmem_addr + vpos;
					trace_selector <= '1';
				when others => null;
			end case;
		end if;
	end process;
	
	
	-- fetch data for displaying - XXX does it need to be latched?
	process(slowclk)
	begin
		if rising_edge(slowclk) then
			if mode(1) = '0' then
				out_word <= trace_data;
			else
				out_word <= trace_mem_data;
			end if;
		end if;
	end process;
	
	-- refresh display
	lcd_rw <= '0';
	lcd_e <= slowclk;
	process(slowclk)
		variable byte : std_logic_vector(7 downto 0);
		variable nibble : std_logic;
	begin
		if rising_edge(slowclk) then
			nibble := '0';
			byte := x"10";
			if init_cnt(7) = '0' then
				init_cnt <= init_cnt + 1;
				lcd_rs <= '0'; -- send control data
				if init_cnt(6) = '0' then
					lcd_db <= "00111000"; -- 8-bit ifc, 2-line mode
				else
					lcd_db <= "00001100"; -- display on	
				end if;
			elsif hpos(4) = '1' then
				hpos <= "00000";
				vpos <= not vpos;
				lcd_rs <= '0'; -- send control data
				lcd_db <= "1" & not vpos & "000000"; -- CRLF
			else
				hpos <= hpos + 1;
				lcd_rs <= '1'; -- send display data
				case hpos(3 downto 0) is
					when "0000" =>
						case mode is
							when "00" => byte := x"72"; -- "r"egister
							when "01" => byte := x"62"; -- "b"us
							when "10" => byte := x"69"; -- "i"nstruction memory
							when "11" => byte := x"64"; -- "d"ata memory
							when others => null;
						end case;
						nibble := '0';
					when "0010" =>
						byte(3 downto 0) := generic_addr(19 downto 16);
						nibble := '1';
					when "0011" =>
						byte(3 downto 0) := generic_addr(15 downto 12);
						nibble := '1';
					when "0100" =>
						byte(3 downto 0) := generic_addr(11 downto 8);
						nibble := '1';
					when "0101" =>
						byte(3 downto 0) := generic_addr(7 downto 4);
						nibble := '1';
					when "0110" =>
						byte(3 downto 0) := generic_addr(3 downto 0);
						nibble := '1';
					when "1000" =>
						byte(3 downto 0) := out_word(31 downto 28);
						nibble := '1';
					when "1001" =>
						byte(3 downto 0) := out_word(27 downto 24);
						nibble := '1';
					when "1010" =>
						byte(3 downto 0) := out_word(23 downto 20);
						nibble := '1';
					when "1011" =>
						byte(3 downto 0) := out_word(19 downto 16);
						nibble := '1';
					when "1100" =>
						byte(3 downto 0) := out_word(15 downto 12);
						nibble := '1';
					when "1101" =>
						byte(3 downto 0) := out_word(11 downto 8);
						nibble := '1';
					when "1110" =>
						byte(3 downto 0) := out_word(7 downto 4);
						nibble := '1';
					when "1111" =>
						byte(3 downto 0) := out_word(3 downto 0);
						nibble := '1';
					when others =>
				end case;
				if nibble = '1' then
					if byte(3 downto 0) > 9 then
						lcd_db <= "0110" & (byte(3 downto 0) - "1001");
					else
						lcd_db <= "0011" & byte(3 downto 0);
					end if;
				else
					lcd_db <= byte;
				end if;
			end if;
		end if;
	end process;
end Behavioral;
