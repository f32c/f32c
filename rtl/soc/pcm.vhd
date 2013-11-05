--
-- Copyright 2013 Marko Zec, University of Zagreb
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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;

entity pcm is
    port (
	clk: in std_logic;
	io_ce, io_bus_write: in std_logic;
	io_addr: in std_logic_vector(1 downto 0);
	io_byte_sel: in std_logic_vector(3 downto 0);
	io_bus_in: in std_logic_vector(31 downto 0);
	io_bus_out: out std_logic_vector(31 downto 0);
	addr_strobe: out std_logic;
	data_ready: in std_logic;
	addr_out: out std_logic_vector(19 downto 2);
	data_in: in std_logic_vector(31 downto 0);
	out_l, out_r: out std_logic
    );
end pcm;

architecture Behavioral of pcm is
    signal R_dma_first_addr, R_dma_last_addr: std_logic_vector(19 downto 2);
    signal R_dma_cur_addr: std_logic_vector(19 downto 2);
    signal R_dma_trigger_acc, R_dma_trigger_incr: std_logic_vector(23 downto 0);
    signal R_dma_data: std_logic_vector(31 downto 0);
    signal R_dma_needs_refill: boolean;

begin

    process(clk, R_dma_trigger_acc, R_dma_trigger_incr)
	variable dma_trigger_next: std_logic_vector(23 downto 0);
    begin
	dma_trigger_next := R_dma_trigger_acc + R_dma_trigger_incr;

	if rising_edge(clk) then
	    -- Periodically request new data
	    R_dma_trigger_acc <= dma_trigger_next;
	    if R_dma_trigger_acc(23) = '0' and dma_trigger_next(23) = '1' then
		R_dma_needs_refill <= true;
	    end if;

	    -- Refill data from main memory
	    if data_ready = '1' then
		R_dma_needs_refill <= false;
		R_dma_data <= data_in;
		if R_dma_cur_addr = R_dma_last_addr then
		    R_dma_cur_addr <= R_dma_first_addr;
		else
		    R_dma_cur_addr <= R_dma_cur_addr + 1;
		end if;
	    end if;

	    -- Write to control registers when requested
	    if io_ce = '1' and  io_bus_write = '1' then
		R_dma_cur_addr <= R_dma_first_addr;
		if io_addr = "00" then	-- DMA region first addr
		    R_dma_first_addr <= io_bus_in(19 downto 2);
		end if;
		if io_addr = "01" then	-- DMA region last addr
		    R_dma_last_addr <= io_bus_in(19 downto 2);
		end if;
		if io_addr = "10" then	-- DMA frequency control
		    R_dma_trigger_incr <= io_bus_in(23 downto 0);
		end if;
	    end if;
	end if;
    end process;

    addr_out <= R_dma_cur_addr;
    addr_strobe <= '1' when R_dma_needs_refill else '0';

    io_bus_out <= "------------" & R_dma_cur_addr & "--";

end Behavioral;

