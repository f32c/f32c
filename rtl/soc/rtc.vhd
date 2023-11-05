--
-- Copyright (c) 2023. Marko Zec
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

entity rtc is
    generic (
	C_clk_freq_hz: natural := 0;
	C_clk_freq_mhz: natural := 0;
	C_adjustable: boolean := false;
	C_boottime: boolean := true
    );
    port (
	ce, clk: in std_logic;
	bus_addr: in std_logic_vector(3 downto 2);
	byte_sel: in std_logic_vector(3 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_write: in std_logic
    );
end rtc;

architecture x of rtc is
    function F_eff_hz(hz: natural; mhz: natural) return natural is
	variable eff_hz: natural;
    begin
	assert (not(hz = 0 and mhz = 0) and not(hz /= 0 and mhz /= 0)) report
	  "Must specify either C_clk_freq_hz or C_clk_freq_mhz"
	  severity failure;

	if mhz /= 0 then
	    if mhz = 33 then
		eff_hz := 33333333;
	    elsif mhz = 66 or mhz = 67 then
		eff_hz := 66666667;
	    elsif mhz = 74 then
		eff_hz := 74250000;
	    elsif mhz = 84 then
		eff_hz := 84375000;
	    elsif mhz = 93 then
		eff_hz := 92812500;
	    elsif mhz = 94 then
		eff_hz := 93750000;
	    elsif mhz = 96 then
		eff_hz := 96428571;
	    elsif mhz = 109 then
		eff_hz := 109090909;
	    elsif mhz = 112 or mhz = 113 then
		eff_hz := 112500000;
	    elsif mhz = 124 then
		eff_hz := 123750000;
	    elsif mhz = 133 then
		eff_hz := 133333333;
	    elsif mhz = 166 or mhz = 167 then
		eff_hz := 166666667;
	    elsif mhz = 233 then
		eff_hz := 233333333;
	    elsif mhz = 266 or mhz = 267 then
		eff_hz := 266666667;
	    else
		eff_hz := mhz * 1000000;
	    end if;
	else
	    eff_hz := hz;
	end if;

	return eff_hz;
    end F_eff_hz;
    constant C_eff_freq_hz: natural := F_eff_hz(C_clk_freq_hz, C_clk_freq_mhz);

    type T_ns_incr_list is array(0 to 7) of natural;
    constant C_ns_incr_list: T_ns_incr_list := (
	1, 2, 5, 10, 20, 50, 100, 200
    );

    function F_ns_incr_index(hz: natural) return natural is
    begin
	if hz > 1000000000 then
	    return 0; --   1 ns
	elsif hz > 500000000 then
	    return 1; --   2 ns
	elsif hz > 200000000 then
	    return 2; --   5 ns
	elsif hz > 100000000 then
	    return 3; --  10 ns
	elsif hz > 50000000 then
	    return 4; --  20 ns
	elsif hz > 20000000 then
	    return 5; --  50 ns
	elsif hz > 10000000 then
	    return 6; -- 100 ns
	else
	    return 7; -- 200 ns
	end if;
    end F_ns_incr_index;
    constant C_ns_incr_index: natural := F_ns_incr_index(C_eff_freq_hz);
    constant C_ns_incr_index_vec: std_logic_vector(3 downto 0) :=
      conv_std_logic_vector(C_ns_incr_index, 4);
    constant C_ns_incr: natural := C_ns_incr_list(C_ns_incr_index);

    signal R_uptime_s: std_logic_vector(31 downto 0);
    signal R_uptime_ns: std_logic_vector(29 downto 0);
    signal R_boottime_s: std_logic_vector(31 downto 0);
    signal R_prescaler_cnt: std_logic_vector(24 downto 0);
    signal R_prescaler_incr: std_logic_vector(23 downto 0) :=
      conv_std_logic_vector(integer(1000000000.0 / real(C_ns_incr) /
      real(C_eff_freq_hz) * real(2 ** 24)), 24);

begin
    process(clk)
    begin
	if rising_edge(clk) then
	    R_prescaler_cnt <= ('0' & R_prescaler_cnt(23 downto 0))
	      + ('0' & R_prescaler_incr);
	    if R_prescaler_cnt(24) = '1' then
		R_uptime_ns <= R_uptime_ns + C_ns_incr;
		if R_uptime_ns = 1000000000 - C_ns_incr then
		    R_uptime_ns <= (others => '0');
		    R_uptime_s <= R_uptime_s + 1;
		end if;
	    end if;
	    if ce = '1' and bus_write = '1' then
		if C_adjustable and bus_addr = "10" and
		  bus_in(27 downto 24) = C_ns_incr_index_vec then
		    R_prescaler_incr <= bus_in(23 downto 0);
		end if;
		if C_boottime and bus_addr = "11" then
		    R_boottime_s <= bus_in;
		end if;
	    end if;
	end if;
    end process;

    with bus_addr select bus_out <=
      R_uptime_s when "00",
      "00" & R_uptime_ns when "01",
      x"0" & C_ns_incr_index_vec & R_prescaler_incr when "10",
      R_boottime_s when others;
end x;
