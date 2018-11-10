--
-- Copyright (c) 2013. Marko Zec, University of Zagreb
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

entity spi is
    generic (
	C_fixed_speed: boolean := true;
	C_turbo_mode: boolean := false
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	spi_sck, spi_mosi, spi_cen: out std_logic;
	spi_miso: in std_logic
    );
end spi;

--
-- SPI -> CPU data word:
--  31..9  unused & undefined
--      8  set if rx_byte is available, cleared on writing tx_byte
--   7..0  rx_byte
--
-- CPU -> SPI data word:
-- 31..16  unused
--  15..8  clock divisor (writing deactivates ce and generates one clock pulse)
--   7..0  tx_byte (writing activates ce)
--
architecture Behavioral of spi is
    signal R_bit_cnt: std_logic_vector(3 downto 0);
    signal R_spi_byte_in, R_spi_byte_out: std_logic_vector(7 downto 0);
    signal R_clk_div: std_logic_vector(7 downto 0) := x"80";
    signal R_clk_acc: std_logic_vector(7 downto 0);
    signal R_spi_cen: std_logic := '1'; -- SPI disabled by default
    signal clk_acc_next: std_logic_vector(7 downto 0);
    signal R_clk_prev: std_logic;
begin
    bus_out(31 downto 9) <= (others => '-');
    bus_out(8) <= R_bit_cnt(3);
    bus_out(7 downto 0) <= R_spi_byte_in;

    spi_cen <= R_spi_cen;

    G_not_turbo_mode:
    if not C_turbo_mode generate
    spi_sck <= R_clk_acc(7);
    spi_mosi <= R_spi_byte_out(7);

    G_yes_fixed_speed:
    if C_fixed_speed generate
	clk_acc_next <= R_clk_acc xor x"80";
    end generate G_yes_fixed_speed;

    G_not_fixed_speed:
    if not C_fixed_speed generate
	clk_acc_next <= R_clk_acc + R_clk_div;
    end generate G_not_fixed_speed;

    process(clk)
    begin
	if rising_edge(clk) then
	    R_clk_prev <= R_clk_acc(7);
	end if;
    end process;

    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' and bus_write = '1' then
		if byte_sel(1) = '1' then
		    if not C_fixed_speed then
			R_clk_div <= bus_in(15 downto 8);
		    end if;
		    R_clk_acc <= (others => '0');
		    R_spi_cen <= '1';
		    R_bit_cnt <= x"8"; -- spi inactive
		elsif byte_sel(0) = '1' then
		    R_spi_byte_out <= bus_in(7 downto 0);
		    R_bit_cnt <= x"0"; -- spi active
		    R_spi_cen <= '0';
		end if;
	    else -- not write
	    	-- tx / rx logic
		if R_bit_cnt(3) = '0' then -- spi active
		    -- one CPU clock cycle before the CPU cycle when SPI clock makes falling edge
		    if clk_acc_next(7) = '0' and R_clk_acc(7) = '1' then
		    	-- sample input and shift input reg
		    	R_spi_byte_in <= R_spi_byte_in(6 downto 0) & spi_miso;
		    	-- shift output reg (must be separate from input to avoid CPU bus mux)
		    	R_spi_byte_out <= R_spi_byte_out(6 downto 0) & '0';
		    	R_bit_cnt <= R_bit_cnt + 1;
		    end if;
		    R_clk_acc <= clk_acc_next;
		end if;
	    end if; -- not write
	end if; -- rising edge
    end process;
    end generate G_not_turbo_mode;

    G_yes_turbo_mode:
    if C_turbo_mode generate
    spi_sck <= (not clk) and not R_bit_cnt(3);
    spi_mosi <= R_spi_byte_out(7);
    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' and bus_write = '1' then
		if byte_sel(1) = '1' then
		    R_clk_acc <= (others => '0');
		    R_spi_cen <= '1';
		    R_bit_cnt <= x"8";
		elsif byte_sel(0) = '1' then
		    R_spi_byte_out <= bus_in(7 downto 0);
		    R_bit_cnt <= x"0";
		    R_spi_cen <= '0';
		end if;
	    else -- not write, rising cpu edge (but falling spi edge)
	    	-- tx / rx logic
	    	if R_bit_cnt(3) = '0' then -- spi active
		    R_spi_byte_in <= R_spi_byte_in(6 downto 0) & spi_miso;
		    R_spi_byte_out <= R_spi_byte_out(6 downto 0) & '0';
		    R_bit_cnt <= R_bit_cnt + 1;
		    R_clk_acc <= clk_acc_next;
		end if;
	    end if; -- not write, rising cpu edge (but falling spi edge)
	end if; -- rising edge
    end process;
    end generate G_yes_turbo_mode;
end Behavioral;

