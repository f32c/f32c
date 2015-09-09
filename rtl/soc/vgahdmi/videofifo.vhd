--
-- Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
-- Copyright (c) 2015 Davor Jadrijevic
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

-- asynchronous FIFO adapter from system memory
-- running at CPU clock (around 100 MHz) with
-- unpredictable access time to
-- to video system, running at pixel clock (25 MHz)
-- which must have constant data rate

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity videofifo is
    generic (
        C_synclen: integer := 3; -- bits in cpu-to-pixel clock synchronizer
        C_width: integer := 4 -- bits width of fifo address
        -- defines the length of the FIFO: 4 * 2^C_length bytes
        -- default value of 4: length = 16 * 32 bits = 16 * 4 bytes = 64 bytes
    );
    port (
	clk, clk_pixel: in std_logic;
	addr_strobe: out std_logic;
	addr_out: out std_logic_vector(19 downto 2);
	base_addr: in std_logic_vector(19 downto 2);
	-- debug_rd_addr: out std_logic_vector(19 downto 2);
	data_ready: in std_logic;
	data_in: in std_logic_vector(31 downto 0);
	data_out: out std_logic_vector(31 downto 0);
	start: in std_logic; -- value 0 will reset fifo RAM to base address, value 1 allows start of reading
	fetch_next: in std_logic -- fetch next value (current data consumed)
    );
end videofifo;

architecture behavioral of videofifo is
    -- Types
    constant C_length: integer := 2**C_width; -- 1 sll C_width - shift logical left
    type pixbuf_dpram_type is array(0 to C_length-1) of std_logic_vector(31 downto 0);

    -- Internal state
    signal R_pixbuf: pixbuf_dpram_type;
    signal R_sram_addr: std_logic_vector(19 downto 2);
    signal R_pixbuf_rd_addr, R_pixbuf_wr_addr, S_pixbuf_wr_addr_next: std_logic_vector(C_width-1 downto 0);
    signal need_refill: boolean;
    signal toggle_read_complete: std_logic;
    signal clksync: std_logic_vector(C_synclen-1 downto 0);
    signal clean_start, clean_fetch: std_logic;
begin
    S_pixbuf_wr_addr_next <= R_pixbuf_wr_addr + 1;

    -- clk-to-clk_pixel synchronizer:
    -- clk_pixel rising edge is detected using shift register
    -- edge detection happens after delay (clk * synclen)
    -- then rd is set high for one clk cycle
    -- intiating fetch of new data from RAM fifo
    process(clk_pixel)
    begin
      if rising_edge(clk_pixel) and fetch_next = '1' then
        toggle_read_complete <= not toggle_read_complete;
      end if;
    end process;

    -- start signal which resets fifo
    -- can be clock asynchronous and may
    -- lead to unclean or partial fifo reset which results
    -- in early fetch and visually whole picure flickers
    -- by shifting one byte left
    -- input start is passed it through a flip-flop
    -- it generates clean_start and we got rid of the flicker
    process(clk)
    begin
      if rising_edge(clk) then
        clean_start <= start;
        -- synchronize clk_pixel to clk with shift register
        clksync <= clksync(C_synclen-2 downto 0) & toggle_read_complete;
      end if;
    end process;

    -- XOR: difference in 2 consecutive clksync values
    -- create a short pulse that lasts one CPU clk period.
    -- This signal is request to fetch new data
    clean_fetch <= clksync(C_synclen-2) xor clksync(C_synclen-1);

    --
    -- Refill the circular buffer with fresh data from SRAM-a
    --
    process(clk)
    begin
	if rising_edge(clk) then
          if clean_start = '0' then
            R_sram_addr <= base_addr;
            R_pixbuf_wr_addr <= (others => '0');
          else
	    if data_ready = '1' and need_refill then -- BRAM must use this
	    -- if data_ready = '1' then -- may work with SDRAM?
              R_pixbuf(TO_INTEGER(UNSIGNED(R_pixbuf_wr_addr))) <= data_in;
              R_sram_addr <= R_sram_addr + 1;
              R_pixbuf_wr_addr <= S_pixbuf_wr_addr_next;
	    end if;
          end if;
	end if;
    end process;

    need_refill <= clean_start = '1' and S_pixbuf_wr_addr_next /= R_pixbuf_rd_addr;
    addr_strobe <= '1' when need_refill else '0';
    addr_out <= R_sram_addr;
    
    -- Dequeue pixel data from the circular buffer
    -- by incrementing R_pixbuf_rd_addr on rising edge of clk
    --
    process(clk)
      begin
        if rising_edge(clk) then
          if clean_start = '0' then
            R_pixbuf_rd_addr <= (others => '0');
          else
            if clean_fetch = '1' then
              R_pixbuf_rd_addr <= R_pixbuf_rd_addr + 1;
	    end if;
          end if;
        end if;
      end process;
    data_out <= R_pixbuf(TO_INTEGER(UNSIGNED(R_pixbuf_rd_addr)));
    -- debug_rd_addr(5 downto 2) <= R_pixbuf_rd_addr;
    -- debug_rd_addr(19 downto 6) <= (others => '0');
end;
