--
-- Copyright (c) 2013 - 2023 Marko Zec
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- to calculate log2 bit size

entity sio is
    generic (
	C_clk_freq: integer; -- MHz clock frequency
	C_big_endian: boolean := false;
	C_init_baudrate: integer := 115200;
	C_fixed_baudrate: boolean := false;
	C_break_detect: boolean := false;
	C_break_detect_delay_ms: integer := 200;
	C_break_resets_baudrate: boolean := false;
	C_rx_fifo_bits: natural := 5;
	C_rx_overruns: boolean := true;
	C_tx_only: boolean := false
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
-- 15..12  RX overruns saturating counter
--     11  reserved
--     10  set if tx busy
--      9  reserved
--      8  set if rx_byte is unread, reset on read
--   7..0  rx_byte
--
-- CPU -> SIO data word:
-- 31..16  clock divisor (or unused)
--  15..8  RX overruns reset (any value written clears RX overruns counter)
--   7..0  tx_byte
--
architecture Behavioral of sio is
    function F_baud_init(f: natural; b: natural) return std_logic_vector is
	variable val: natural;
    begin
    if b <= 200000 then
	val := b * 2**10 / 1000 * 2**10 / f / 1000;
    elsif b <= 2000000 then
	val := b / 10 * 2**10 / 100 * 2**10 / f / 1000;
    else -- OK up to 3000000 bauds at min. 50 MHz clock frequency
	val := b / 100 * 2**10 / 100 * 2**10 / f / 100;
    end if;
    return std_logic_vector(to_unsigned(val, 16));
    end function F_baud_init;

    -- break detection math
    constant C_break_detect_bits: integer := integer(ceil((log2(real(C_break_detect_delay_ms * C_clk_freq * 1000 * 8/7)))+1.0E-16));
    constant C_break_detect_count: integer := 7 * 2**(C_break_detect_bits-3); -- number of clock ticks for break detection
    constant C_break_detect_delay_ticks: integer := C_break_detect_delay_ms * C_clk_freq * 1000;
    constant C_break_detect_start: std_logic_vector(C_break_detect_bits-1 downto 0) :=
      std_logic_vector(to_unsigned(C_break_detect_count-C_break_detect_delay_ticks, C_break_detect_bits)); 
      -- counter resets to this value (fine tuning parameter for break detect delay) 

    -- baud * 16 impulse generator
    signal R_baudrate: std_logic_vector(15 downto 0) := F_baud_init(C_clk_freq, C_init_baudrate);
    signal R_baudgen: std_logic_vector(16 downto 0);

    -- transmit logic
    signal R_tx_tickcnt: std_logic_vector(3 downto 0);
    signal R_tx_phase: std_logic_vector(3 downto 0);
    signal R_tx_ser: std_logic_vector(8 downto 0) := (others => '1');
    signal tx_running: std_logic;

    -- receive logic
    signal R_rxd, R_break: std_logic;
    signal R_rx_tickcnt: std_logic_vector(3 downto 0);
    signal R_rx_des: std_logic_vector(7 downto 0);
    signal R_rx_phase: std_logic_vector(3 downto 0);
    signal R_rx_break_tickcnt: std_logic_vector(C_break_detect_bits-1 downto 0) := C_break_detect_start;
    signal R_rx_full: std_logic;
    signal R_rx_byte: std_logic_vector(7 downto 0);
    signal R_rx_overruns: std_logic_vector(3 downto 0);

    type rx_fifo_type is array(0 to 2 ** C_rx_fifo_bits - 1) of
      std_logic_vector(7 downto 0);
    signal M_rx_fifo: rx_fifo_type;
    signal R_rx_rd_i, R_rx_wr_i: std_logic_vector(C_rx_fifo_bits - 1 downto 0);

begin

    --
    -- rx / tx phases:
    --	"0000" idle
    --	"0001" start bit
    --	"0010".."1001" data bits
    --	"1010" stop bit
    --

    tx_running <= '1' when R_tx_phase /= x"0" else '0';
    bus_out(31 downto 16) <= (others => '-');
    bus_out(15 downto 9) <= R_rx_overruns & '-' & tx_running & '-';
    bus_out(8) <= R_rx_full when not C_tx_only else '0';
    bus_out(7 downto 0) <= R_rx_byte when not C_tx_only else (others => '-');
    txd <= R_tx_ser(0);
    break <= R_break;

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
		if bus_write = '1' then
		    if byte_sel(0) = '1' then
			if R_tx_phase = x"0" then
			    R_tx_phase <= x"1";
			    R_tx_ser <= bus_in(7 downto 0) & '0';
			end if;
		    end if;
		    if C_rx_overruns and byte_sel(1) = '1' then
			R_rx_overruns <= (others => '0');
		    end if;
		else -- bus_write = '0'
		    if byte_sel(0) = '1' and R_rx_full = '1' then
			R_rx_rd_i <= R_rx_rd_i + 1;
		    end if;
		end if;
	    end if;

	    -- baud generator
	    R_baudgen <= ('0' & R_baudgen(15 downto 0)) + ('0' & R_baudrate);

	    -- tx logic
	    if R_tx_phase /= x"0" and R_baudgen(16) = '1' then
		R_tx_tickcnt <= R_tx_tickcnt + 1;
		if R_tx_tickcnt = x"f" then
		    R_tx_ser <= '1' & R_tx_ser(8 downto 1);
		    R_tx_phase <= R_tx_phase + 1;
		    if R_tx_phase = x"a" then
			R_tx_phase <= x"0";
		    end if;
		end if;
	    end if;

	    -- rx logic
	    R_rxd <= rxd;
	    if R_baudgen(16) = '1' and not C_tx_only then
		if R_rx_phase = x"0" then
		    if R_rxd = '0' then
			-- start bit, delay further sampling for ~0.5 T
			if R_rx_tickcnt = x"8" then
			    R_rx_phase <= R_rx_phase + 1;
			    R_rx_tickcnt <= x"0";
			else
			    R_rx_tickcnt <= R_rx_tickcnt + 1;
			end if;
		    else
			R_rx_tickcnt <= x"0";
		    end if;
		else
		    R_rx_tickcnt <= R_rx_tickcnt + 1;
		    if R_rx_tickcnt = x"f" then
			R_rx_des <= R_rxd & R_rx_des(7 downto 1);
			R_rx_phase <= R_rx_phase + 1;
			if R_rx_phase = x"9" then
			    R_rx_phase <= x"0";
			    M_rx_fifo(conv_integer(R_rx_wr_i)) <= R_rx_des;
			    if R_rx_wr_i + 1 /= R_rx_rd_i then
				R_rx_wr_i <= R_rx_wr_i + 1;
			    elsif C_rx_overruns and R_rx_overruns /= x"f" then
				R_rx_overruns <= R_rx_overruns + 1;
			    end if;
			end if;
		    end if;
		end if;
	    end if;
	    if not C_tx_only then
		if R_rx_rd_i = R_rx_wr_i then
		    R_rx_full <= '0';
		else
		    R_rx_full <= '1';
		    R_rx_byte <= M_rx_fifo(conv_integer(R_rx_rd_i));
		end if;
	    end if;

	    -- break detect logic
	    if C_break_detect and R_rxd = '0' then
		if R_rx_break_tickcnt(C_break_detect_bits-1 downto C_break_detect_bits-4) /= x"f" then
		    R_rx_break_tickcnt <= R_rx_break_tickcnt + 1;
		end if;
	    elsif C_break_detect then
		if R_rx_break_tickcnt(C_break_detect_bits-1 downto C_break_detect_bits-3) = "111" then
		    R_break <= '1';
		    R_rx_break_tickcnt <= R_rx_break_tickcnt - 1;
		    if C_break_resets_baudrate then
			R_baudrate <= F_baud_init(C_clk_freq, C_init_baudrate);
		    end if;
		else
		    R_break <= '0';
		    R_rx_break_tickcnt <= C_break_detect_start;
		end if;
	    end if;
	end if;
    end process;
end Behavioral;
