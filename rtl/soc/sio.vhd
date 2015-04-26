--
-- Copyright (c) 2013 - 2015 Marko Zec, University of Zagreb
-- All rights reserved.
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
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sio is
    generic (
	C_clk_freq: integer;
	C_big_endian: boolean := false;
	C_init_baudrate: integer := 115200;
	C_fixed_baudrate: boolean := false;
	C_tx_only: boolean := false;
	C_bypass: boolean := false
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	break: out std_logic;
	rxd: in std_logic;
	txd: out std_logic
    );
end sio;

--
-- SIO -> CPU data word:
-- 31..11  unused
--     10  set if tx busy
--      9  reserved
--      8  set if rx_byte is unread, reset on read
--   7..0  rx_byte
--
-- CPU -> SIO data word:
-- 31..16  clock divisor (or unused)
--  15..8  unused
--   7..0  tx_byte
--
architecture Behavioral of sio is
    -- baud * 16 impulse generator
    signal R_baudrate: std_logic_vector(15 downto 0) :=
      std_logic_vector(to_unsigned(
	C_init_baudrate * 2**10 / 1000 * 2**10 / C_clk_freq / 1000, 16));
    signal R_baudgen: std_logic_vector(16 downto 0);

    -- transmit logic
    signal tx_tickcnt: std_logic_vector(3 downto 0);
    signal tx_phase: std_logic_vector(3 downto 0);
    signal tx_running: std_logic;
    signal tx_ser: std_logic_vector(8 downto 0) := (others => '1');

    -- receive logic
    signal rx_tickcnt: std_logic_vector(3 downto 0);
    signal rx_running: std_logic;
    signal rx_des: std_logic_vector(7 downto 0);
    signal rx_phase: std_logic_vector(3 downto 0);
    signal rx_byte: std_logic_vector(7 downto 0);
    signal rx_full: std_logic;
    signal rx_break_tickcnt: std_logic_vector(24 downto 0);
begin

    G_bypass:
    if C_bypass generate
    process(clk)
    begin
	if rising_edge(clk) then
	    rx_running <= rxd;
	    if ce = '1' and bus_write = '1' and byte_sel(0) = '1' then
		tx_running <= bus_in(0);
	    end if;
	end if;
    end process;
    bus_out <= "-------------------------------" & rx_running;
    txd <= tx_running;
    end generate;

    G_sio:
    if not C_bypass generate
    --
    -- rx / tx phases:
    --	"0000" idle
    --	"0001" start bit
    --	"0010".."1001" data bits
    --	"1010" stop bit
    --

    tx_running <= '1' when tx_phase /= x"0" else '0';
    bus_out(31 downto 11) <= "---------------------";
    bus_out(10) <= tx_running;
    bus_out(9 downto 8) <= '-' & rx_full when not C_tx_only else "--";
    bus_out(7 downto 0) <= rx_byte when not C_tx_only else "--------";
    txd <= tx_ser(0);

    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' then
		if not C_fixed_baudrate and bus_write = '1' and
		  byte_sel(2) = '1' then
		    if C_big_endian then
			R_baudrate <=
			  bus_in(23 downto 16) & bus_in(31 downto 24);
		    else
			R_baudrate <= bus_in(31 downto 16);
		    end if;
		end if;
		if bus_write = '1' and byte_sel(0) = '1' then
		    if tx_phase = x"0" then
			tx_phase <= x"1";
			tx_ser <= bus_in(7 downto 0) & '0';
		    end if;
		elsif bus_write = '0' and byte_sel(0) = '1' then
		    rx_full <= '0';
		end if;
	    end if;

	    -- baud generator
	    R_baudgen <= ('0' & R_baudgen(15 downto 0)) + ('0' & R_baudrate);

	    -- tx logic
	    if tx_phase /= x"0" and R_baudgen(16) = '1' then
		tx_tickcnt <= tx_tickcnt + 1;
		if tx_tickcnt = x"f" then
		    tx_ser <= '1' & tx_ser(8 downto 1);
		    tx_phase <= tx_phase + 1;
		    if tx_phase = x"a" then
			tx_phase <= x"0";
		    end if;
		end if;
	    end if;

	    -- rx logic
	    if R_baudgen(16) = '1' and not C_tx_only then
		if rx_phase = x"0" then
		    if rxd = '0' then
			-- start bit, delay further sampling for ~0.5 T
			if rx_tickcnt = x"8" then
			    rx_phase <= rx_phase + 1;
			    rx_tickcnt <= x"0";
			else
			    rx_tickcnt <= rx_tickcnt + 1;
			end if;
		    else
			rx_tickcnt <= x"0";
		    end if;
		else
		    rx_tickcnt <= rx_tickcnt + 1;
		    if rx_tickcnt = x"f" then
			rx_des <= rxd & rx_des(7 downto 1);
			rx_phase <= rx_phase + 1;
			if rx_phase = x"9" then
			    rx_phase <= x"0";
			    rx_full <= '1';
			    rx_byte <= rx_des;
			end if;
		    end if;
		end if;
	    end if;

	    -- break detect logic
	    if rxd = '0' then
		if rx_break_tickcnt(23 downto 20) /= x"f" then
		    rx_break_tickcnt <= rx_break_tickcnt + 1;
		end if;
	    else
		if rx_break_tickcnt(23 downto 20) = x"f" then
		    break <= '1';
		end if;
		if rx_break_tickcnt(23 downto 20) /= x"f" then
		    rx_break_tickcnt(23) <= '0';
		    break <= '0';
		end if;
		rx_break_tickcnt(22 downto 0) <=
		    rx_break_tickcnt(22 downto 0) - 1;
	    end if;
	end if;
    end process;
    end generate;
end Behavioral;

