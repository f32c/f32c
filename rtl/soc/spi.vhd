--
-- Copyright (c) 2013. Marko Zec
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

entity spi is
    generic (
	C_fixed_speed: boolean := true
    );
    port (
	-- CPU bus
	ce, clk: in std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	-- SPI master
	spi_sck: out std_logic;
	spi_cen: out std_logic_vector(3 downto 0);
	spi_mosi, spi_miso: inout std_logic
    );
end spi;

--
-- SPI -> CPU data word:
--  31..24 clock divisor
--  23..18 unused & undefined
--  17..16 slave selector
--  15...9 unused & undefined
--       8 set if rx_byte is available, cleared on writing tx_byte
--   7...0 rx_byte
--
-- CPU -> SPI data word:
--  31..24 clock divisor
--  23..18 unused & undefined
--  17..16 slave selector
--  15...8 writing any data deactivates cen and generates one clock pulse
--    7..0  tx_byte (writing activates cen)
--
architecture x of spi is
    signal R_bit_cnt: std_logic_vector(3 downto 0);
    signal R_spi_byte_in, R_spi_byte_out: std_logic_vector(7 downto 0);
    signal R_clk_div: std_logic_vector(7 downto 0) := x"80";
    signal R_clk_acc: std_logic_vector(7 downto 0);
    signal R_spi_cen: std_logic_vector(3 downto 0) := (others => '1');
    signal R_spi_cen_next: std_logic_vector(3 downto 0) := "1110";
    signal R_mosi_hiz: boolean := true;
    signal R_miso_hiz: boolean := true;
    signal R_selector: std_logic_vector(1 downto 0);

    signal clk_acc_next: std_logic_vector(7 downto 0);

begin
    bus_out(31 downto 24) <= R_clk_div;
    bus_out(23 downto 16) <= x"0" & "00" & R_selector;
    bus_out(15 downto 8) <= x"0" & "000" & R_bit_cnt(3); -- transfer done;
    bus_out(7 downto 0) <= R_spi_byte_in;

    spi_cen <= R_spi_cen;
    spi_sck <= R_clk_acc(7);
    spi_mosi <= 'Z' when R_mosi_hiz else R_spi_byte_out(7);
    spi_miso <= 'Z' when R_miso_hiz else R_spi_byte_out(6);

    clk_acc_next <= R_clk_acc + R_clk_div;

    process(clk)
    begin
	if rising_edge(clk) then
	    -- bus interface logic
	    if ce = '1' and bus_write = '1' then
		if not C_fixed_speed and byte_sel(3) = '1' then
		    R_clk_div <= bus_in(31 downto 24);
		end if;
		if byte_sel(2) = '1' then
		    R_selector <= bus_in(17 downto 16);
		    R_spi_cen_next <= (others => '1');
		    R_spi_cen_next(conv_integer(bus_in(17 downto 16))) <= '0';
		end if;
		if byte_sel(1) = '1' then
		    R_clk_acc <= (others => '0');
		    R_spi_cen <= (others => '1');
		    R_miso_hiz <= true;
		    R_mosi_hiz <= true;
		    R_bit_cnt <= x"8"; -- spi inactive
		elsif byte_sel(0) = '1' then
		    R_spi_cen <= R_spi_cen_next;
		    R_mosi_hiz <= false;
		    R_spi_byte_out <= bus_in(7 downto 0);
		    R_bit_cnt <= x"0"; -- spi active
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
end x;
