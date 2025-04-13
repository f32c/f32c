--
-- Copyright (c) 2025 Marko Zec
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

--
-- Detector of a sequence of short break pulses (cca. 50 ms) observed on
-- the input, typically an asynchronous serial line from a controlling
-- terminal.  The output "sel" will report zero for a single pulse, one for
-- two consecutive pulses, and so on.  The output may be used as a
-- selector for a mux, for example.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity sbrk_cnt is
    generic (
	C_clk_freq_hz: natural;
	C_pulse_len_min_ms: natural := 40;
	C_pulse_len_max_ms: natural := 60
    );
    port (
	clk: in std_logic;
	reset: in std_logic := '0';
	rxd: in std_logic;
	sel: out std_logic_vector(3 downto 0)
    );
end sbrk_cnt;

architecture x of sbrk_cnt is
    constant C_pulse_ticks_min: natural :=
      C_clk_freq_hz / 1000 * C_pulse_len_min_ms;
    constant C_pulse_ticks_max: natural :=
      C_clk_freq_hz / 1000 * C_pulse_len_max_ms;

    signal R_rxd: std_logic_vector(2 downto 0);
    signal R_pulse_valid: boolean;
    signal R_pulse_ticks: natural range 0 to C_pulse_ticks_max;
    signal R_pulse_cnt: std_logic_vector(3 downto 0);
    signal R_sel: std_logic_vector(3 downto 0);

begin
    process(clk)
    begin
	if rising_edge(clk) then
	    R_rxd <= R_rxd(1 downto 0) & rxd;
	    if R_pulse_ticks /= C_pulse_ticks_max then
		R_pulse_ticks <= R_pulse_ticks + 1;
	    else
		R_pulse_valid <= false;
		R_pulse_cnt <= (others => '0');
	    end if;
	    if R_pulse_ticks = C_pulse_ticks_min
	      and R_rxd(2 downto 1) = "00" then
		R_pulse_valid <= true;
	    end if;

	    if R_rxd(2 downto 1) = "01" and R_pulse_valid then
		R_sel <= R_pulse_cnt;
		R_pulse_cnt <= R_pulse_cnt + 1;
	    end if;

	    if R_rxd(2) /= R_rxd(1) then
		R_pulse_ticks <= 0;
		R_pulse_valid <= false;
	    end if;

	    if reset = '1' then
		R_sel <= (others => '0');
		R_pulse_valid <= false;
	    end if;
	end if;
    end process;

    sel <= R_sel;
end x;
