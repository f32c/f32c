--
-- Copyright (c) 2013 Marko Zec, University of Zagreb
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
	addr_out: out std_logic_vector(29 downto 2);
	data_in: in std_logic_vector(31 downto 0);
	out_pcm_l, out_pcm_r: out signed(15 downto 0);
	out_l, out_r: out std_logic
    );
end pcm;

architecture Behavioral of pcm is
    signal R_dma_first_addr, R_dma_last_addr: std_logic_vector(29 downto 2);
    signal R_dma_cur_addr: std_logic_vector(29 downto 2);
    signal R_dma_trigger_acc, R_dma_trigger_incr: std_logic_vector(23 downto 0);
    signal R_dma_needs_refill: boolean;
    signal R_dma_data_l, R_dma_data_r: signed(15 downto 0);
    signal R_vol_l, R_vol_r: signed(15 downto 0);
    signal R_pcm_data_l, R_pcm_data_r: signed(15 downto 0);
    signal R_pcm_unsigned_data_l, R_pcm_unsigned_data_r: std_logic_vector(15 downto 0);
    signal R_dac_acc_l, R_dac_acc_r: std_logic_vector(16 downto 0);

begin

    process(clk, R_dma_trigger_acc, R_dma_trigger_incr, R_vol_l, R_vol_r,
      R_dma_data_l, R_dma_data_r)
	variable dma_trigger_next: std_logic_vector(23 downto 0);
	variable mul_l, mul_r: signed(31 downto 0);
    begin
	dma_trigger_next := R_dma_trigger_acc + R_dma_trigger_incr;

	mul_l := R_dma_data_l * R_vol_l;
	mul_r := R_dma_data_r * R_vol_r;

	if rising_edge(clk) then
	    -- Periodically request new data
	    R_dma_trigger_acc <= dma_trigger_next;
	    if R_dma_trigger_acc(23) = '0' and dma_trigger_next(23) = '1' then
		R_dma_needs_refill <= true;
	    end if;

	    -- Refill data from main memory
	    -- input data: 2 channels, 16-bit signed value per channel
	    -- DMA reads 32-bit -> 2 channels at once
	    -- LSB 16 bits = left channel
	    -- MSB 16 bits = right channel
	    if data_ready = '1' then
		R_dma_needs_refill <= false;
		R_dma_data_l <= signed(data_in(15 downto 0));
		R_dma_data_r <= signed(data_in(31 downto 16));
		if R_dma_cur_addr = R_dma_last_addr then
		    R_dma_cur_addr <= R_dma_first_addr;
		else
		    R_dma_cur_addr <= R_dma_cur_addr + 1;
		end if;
	    end if;

	    -- Apply volume settings: hardware multiplication
	    -- volume should be in 16-bit signed format
	    -- sign allows phase inversion
	    -- when multiplying 2 signed 16 bit values (1 bit sign + 15 bit values)
	    -- result is 31-bit (1 bit sign + 30 bit value)
	    R_pcm_data_l <= mul_l(30 downto 15);
	    R_pcm_data_r <= mul_r(30 downto 15);

	    -- Write to control registers when requested
	    if io_ce = '1' and  io_bus_write = '1' then
		if io_addr = "00" then	-- DMA region first addr
		    R_dma_first_addr <= io_bus_in(29 downto 2);
		end if;
		if io_addr = "01" then	-- DMA region last addr
		    R_dma_last_addr <= io_bus_in(29 downto 2);
		end if;
		if io_addr = "10" then	-- DMA frequency control
		    R_dma_trigger_incr <= io_bus_in(23 downto 0);
		end if;
		if io_addr = "11" then	-- Volume control
		    R_vol_l <= signed(io_bus_in(15 downto 0));
		    R_vol_r <= signed(io_bus_in(31 downto 16));
		else
		    R_dma_cur_addr <= R_dma_first_addr;
		end if;
	    end if;

	    -- PCM data from RAM normally should have average 0 (removed DC offset)
            -- for purpose of PCM generation here is
            -- conversion to unsigned std_logic_vector
            -- by inverting MSB bit (effectively adding 0x8000)
            R_pcm_unsigned_data_l <= std_logic_vector( (not R_pcm_data_l(15)) & R_pcm_data_l(14 downto 0) );
            R_pcm_unsigned_data_r <= std_logic_vector( (not R_pcm_data_r(15)) & R_pcm_data_r(14 downto 0) );
	    -- Output 1-bit DAC
	    R_dac_acc_l <= (R_dac_acc_l(16) & R_pcm_unsigned_data_l) + R_dac_acc_l;
	    R_dac_acc_r <= (R_dac_acc_r(16) & R_pcm_unsigned_data_r) + R_dac_acc_r;
	end if;
    end process;

    addr_out <= R_dma_cur_addr;
    addr_strobe <= '1' when R_dma_needs_refill else '0';

    io_bus_out <= "--" & R_dma_cur_addr & "--";

    out_l <= R_dac_acc_l(16);
    out_r <= R_dac_acc_r(16);
    
    -- signed values should be passed to output of this module
    out_pcm_l <= R_pcm_data_l;
    out_pcm_r <= R_pcm_data_r;

end Behavioral;
