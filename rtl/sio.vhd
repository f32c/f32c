--
-- Copyright 2011 University of Zagreb, Croatia.
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

-- $Id: $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sio is
	generic (
		C_fixed_baudrate: boolean := true;
		C_debug: boolean
	);
	port (
		ce, clk: in std_logic;
		byte_we: in std_logic_vector(3 downto 0);
		bus_in: in std_logic_vector(31 downto 0);
		bus_out: out std_logic_vector(31 downto 0);
		rxd: in std_logic;
		txd: out std_logic
	);
end sio;

--
-- SIO -> CPU data word:
-- 31..24  rx_fifo_byte_2 (or unused)
-- 23..16  rx_fifo_byte_1 (or unused)
-- 15..8   rx_fifo_byte_0
--  7..6   reserved (unused)
--  5..4   CPU freq MHz code (00:25, 01:50, 10:75, 11:100)
--     3   set if tx busy
--     2   set if rx fifo overrun occured, reset on read
--  1..0   # of bytes in rx fifo, reset to 0 on read
--
-- CPU -> SIO data word:
-- 31..16  clock divisor (or unused)
-- 15..8   reserved (unused)
--  7..0   tx char
--
architecture Behavioral of sio is
	signal clkdiv: std_logic_vector(15 downto 0);
	signal tx_clkcnt, rx_clkcnt: std_logic_vector(15 downto 0);
	signal tx_running, rx_running: std_logic;
	signal tx_ser, rx_des: std_logic_vector(8 downto 0);
	signal tx_phase, rx_phase: std_logic_vector(3 downto 0);
	signal rx_fifo: std_logic_vector(23 downto 0);
	signal rx_cnt: std_logic_vector(1 downto 0);
	signal rx_overruns: std_logic;
begin
	fixed_baudrate:
	if C_fixed_baudrate generate
	begin
	-- 115200 bps with 25 MHz or 75 MHz system clock
	clkdiv <= x"00d9" when C_debug else x"028b";
	end generate;

	-- XXX only 25 MHz and 75 MHz CPU freq encodings are supported ATM
	bus_out <= rx_fifo & "0000" & tx_running & rx_overruns & rx_cnt when C_debug
		else rx_fifo & "0010" & tx_running & rx_overruns & rx_cnt;
	txd <= tx_ser(0);
	tx_running <= '0' when tx_phase = "0000" else '1';

	process(clk)
	begin
		if (rising_edge(clk)) then
			-- bus interface logic
			if (ce = '1') then
				if (not C_fixed_baudrate and byte_we(3 downto 2) = "11") then
					clkdiv <= bus_in(31 downto 16);
				end if;
				if (byte_we(0) = '1') then
					tx_phase <= "0001";
					tx_ser <= bus_in(7 downto 0) & '0';
				else
					rx_cnt <= "00";
					rx_overruns <= '0';
				end if;
			end if;

			-- tx logic
			--    tx phases:
			--	"0000" idle
			--	"0001" start bit
			--	"0010".."1001" data bits
			--	"1010" stop bit
			--
			if (tx_phase /= "0000") then
				tx_clkcnt <= tx_clkcnt + 1;
				if (tx_clkcnt = clkdiv) then
					tx_clkcnt <= x"0000";
					tx_ser <= '1' & tx_ser(8 downto 1);
					tx_phase <= tx_phase + 1;
					if (tx_phase = "1011") then
						tx_phase <= "0000";
					end if;
				end if;
			end if;
		end if;
	end process;
end Behavioral;

