-- Copyright (c) 2015 Marko Zec, University of Zagreb
-- Copyright (c) 2016 Emard
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Workaround to refresh SRAM chips by
-- constantly changing address on the bus

-- Buggy ISSI IS66WV51216DBLL PSRAM silicon from 2015 needs this!

-- Affected chips are mounted on Red ULX2S boards sold on autumn 2015
-- On PCB, chip is constantly enabled by connecting /EN signal to the GND
-- in this configuration the year 2015 chip con't refresh by itself so
-- it needs a little help.

-- Earlier ULX2S boards (Green, Blue) don't need this fix as they
-- have good old chips (but the same part number) which treat deselecting
-- UBL and LBL idential as deselecting EN so normally they will 
-- self-refresh on f32c without this workaround.

-- This workaround can be applied to good chips as well,
-- it will do nothing but waste some LUTs and RAM cycles.

entity sram_refresh is
generic (
  C_clk_freq: integer; -- MHz cpu clock frequency
  -- DRAM page size is apparently 512 bytes, our bus width is 4B
  -- 1MB contains 2048 pages to refresh, needs 11 bits to address pages
  C_addr_bits: integer := 11; -- address bits to circulate
  -- Refresh all 2048 pages every 32 ms, per IS42S16100E specs
  C_refresh_cycle_ms: integer := 32 -- milliseconds
);
port (
  clk: in std_logic;
  refresh_addr: out std_logic_vector(C_addr_bits-1 downto 0);
  refresh_strobe: out std_logic;
  refresh_data_ready: in std_logic
);
end sram_refresh;

architecture Behavioral of sram_refresh is
    signal R_refresh_strobe: std_logic;
    signal R_refresh_addr: std_logic_vector(C_addr_bits-1 downto 0);
    signal R_refresh_cnt: integer;
begin
    process(clk)
    begin
	if rising_edge(clk) then
	    if refresh_data_ready = '1' then
		R_refresh_addr <= R_refresh_addr + 1;
		-- Refresh all 2048 pages every 32 ms, per IS42S16100E specs
		R_refresh_cnt <= C_clk_freq * 1000000 / C_refresh_cycle_ms / 2**C_addr_bits;
	    end if;
	    if R_refresh_cnt /= 0 then
		R_refresh_cnt <= R_refresh_cnt - 1;
		R_refresh_strobe <= '0';
	    else
		R_refresh_strobe <= not refresh_data_ready;
	    end if;
	end if;
    end process;
    refresh_strobe <= R_refresh_strobe;
    refresh_addr <= R_refresh_addr;
end Behavioral;
