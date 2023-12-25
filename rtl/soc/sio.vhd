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
use ieee.std_logic_arith.all;

entity sio is
    generic (
	C_clk_freq: natural; -- MHz clock frequency
	C_init_baudrate: natural := 115200;
	C_fixed_baudrate: boolean := false;
	C_break_detect: boolean := false;
	C_break_detect_delay_ms: natural := 200;
	C_break_resets_baudrate: boolean := false;
	C_rx_fifo_bits: natural := 5;
	C_rx_overruns: boolean := true;
	C_tx_only: boolean := false
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	bus_addr: in std_logic_vector(3 downto 2);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	break: out std_logic;
	rx_ready: out std_logic;
	rxd: in std_logic;
	txd: out std_logic
    );
end sio;

--
-- SIO register map:
--
-- 0x0:	RX/TX data
--	7..0	RD: rx byte, reading clears status bit #0 when RX queue empty
--	7..0	WR: tx byte, writing sets status bit #1
--
-- 0x4: status:
--	7..4	RX overruns saturating counter (clears by writing any value)
--	3..2	reserved
--	1	TX busy, clears automatically when TX completes
--      0	RX data available, clears automatically when RX queue empty
--
-- 0x8: baud:
--	15..0	clock divisor for 1:16 baud generator
--

architecture Behavioral of sio is
    type T_baud_list is array(0 to 16) of natural;
    constant C_baud_list: T_baud_list := (
	300,	600,	1200,	2400,	4800,	9600,	19200,	38400,
	57600,	115200,	230400,	460800,	921600,	1000000, 1500000, 3000000,
	0
    );

    function F_baud_index(constant b: natural) return natural is
	variable idx: natural;
    begin
    for i in 0 to 16 loop
	idx := i;
	exit when C_baud_list(i) = b;
    end loop;
    assert idx /= 16 report "unsupported baudrate: " & integer'image(b)
      severity failure;
    return idx;
    end F_baud_index;

    type T_baud_rom is array(0 to 15) of std_logic_vector(19 downto 0);
    function F_baud_calc(constant f: natural) return T_baud_rom is
	variable M_b_r: T_baud_rom;
    begin
    for i in 0 to 15 loop
	M_b_r(i) := conv_std_logic_vector(integer(16777216.0
	  * real(C_baud_list(i)) / 1000000.0 / real(C_clk_freq)), 20);
    end loop;
    return M_b_r;
    end F_baud_calc;
    signal M_baud_rom: T_baud_rom := F_baud_calc(C_clk_freq);

    constant C_break_tickcnt_max: natural :=
      C_clk_freq * 1000 * C_break_detect_delay_ms;

    -- baud * 16 impulse generator
    signal R_baud_index: std_logic_vector(3 downto 0) :=
      conv_std_logic_vector(F_baud_index(C_init_baudrate), 4);
    signal R_baudgen: std_logic_vector(20 downto 0);

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
    signal R_rx_available: std_logic;
    signal R_rx_byte: std_logic_vector(7 downto 0);
    signal R_rx_overruns: std_logic_vector(3 downto 0);
    signal R_rx_break_tickcnt: natural range 0 to C_break_tickcnt_max;

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

    txd <= R_tx_ser(0);

    tx_running <= '1' when R_tx_phase /= x"0" else '0';
    bus_out(31 downto 0) <= (others => '-');
    with bus_addr select bus_out(7 downto 0) <=
      R_rx_byte when "00",
      R_rx_overruns & "00" & tx_running & R_rx_available when "01",
      x"0" & R_baud_index when others;
    rx_ready <= R_rx_available;
    break <= R_break;

    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' then
		if bus_write = '1' then
		    if bus_addr = "00" then
			if R_tx_phase = x"0" then
			    R_tx_phase <= x"1";
			    R_tx_ser <= bus_in(7 downto 0) & '0';
			end if;
		    end if;
		    if C_rx_overruns and bus_addr = "01" then
			R_rx_overruns <= (others => '0');
		    end if;
		    if not C_fixed_baudrate and bus_addr = "10" then
			R_baud_index <= bus_in(3 downto 0);
		    end if;
		else -- bus_write = '0'
		    if bus_addr = "00" and R_rx_available = '1' then
			R_rx_rd_i <= R_rx_rd_i + 1;
		    end if;
		end if;
	    end if;

	    -- baud generator
	    R_baudgen <= ('0' & R_baudgen(19 downto 0))
	      + ('0' & M_baud_rom(conv_integer(R_baud_index)));

	    -- tx logic
	    if R_tx_phase /= x"0" and R_baudgen(20) = '1' then
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
	    if not C_tx_only and R_baudgen(20) = '1' then
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
		    R_rx_available <= '0';
		else
		    R_rx_available <= '1';
		    R_rx_byte <= M_rx_fifo(conv_integer(R_rx_rd_i));
		end if;
	    end if;

	    -- break detect logic
	    if C_break_detect then
		if R_rx_break_tickcnt = 0 then
		    R_break <= '1';
		    if C_break_resets_baudrate and not C_fixed_baudrate then
			R_baud_index <= conv_std_logic_vector(
			  F_baud_index(C_init_baudrate), 4);
		    end if;
		else
		    R_rx_break_tickcnt <= R_rx_break_tickcnt - 1;
		end if;
		if R_rxd = '1' then
		    R_rx_break_tickcnt <= C_break_tickcnt_max;
		    R_break <= '0';
		end if;
	    end if;
	end if;
    end process;
end Behavioral;
