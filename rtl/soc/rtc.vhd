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
	C_boottime: boolean := true;
	C_adjustable: boolean := false
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
    signal R_uptime_s: std_logic_vector(31 downto 0);
    signal R_uptime_ns: std_logic_vector(29 downto 0);
    signal R_boottime_s: std_logic_vector(31 downto 0);
    signal R_prescaler_incr: std_logic_vector(23 downto 0) := x"800000";
    signal R_prescaler_cnt: std_logic_vector(24 downto 0);

begin
    assert (not(C_clk_freq_hz = 0 and C_clk_freq_mhz = 0) and
      not(C_clk_freq_hz /= 0 and C_clk_freq_mhz /= 0)) report
      "Must specify either C_clk_freq_hz or C_clk_freq_mhz" severity failure;

    process(clk)
    begin
	if rising_edge(clk) then
	    R_prescaler_cnt <= ('0' & R_prescaler_cnt(23 downto 0))
	      + ('0' & R_prescaler_incr);
	    if R_prescaler_cnt(24) = '1' then
		R_uptime_ns <= R_uptime_ns + 25;
		if R_uptime_ns = 1000000000 - 25 then
		    R_uptime_ns <= (others => '0');
		    R_uptime_s <= R_uptime_s + 1;
		end if;
	    end if;
	    if ce = '1' and bus_write = '1' then
		if C_boottime and bus_addr = "11" then
		    R_boottime_s <= bus_in;
		end if;
	    end if;
	end if;
    end process;

    with bus_addr select bus_out <=
      R_uptime_s when "00",
      "00" & R_uptime_ns when "01",
      x"00" & R_prescaler_incr when "10",
      R_boottime_s when others;
end x;
