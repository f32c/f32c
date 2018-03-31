-- Copyright (c) 2016 Davor Jadrijevic
-- All rights reserved.
-- Idea about full 2D compositing proposed by Marko Zec
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

-- features compositing v2 (full 2D acceleration)

-- displays linked list of horizontal lines
-- composited into 2D bitmap picture which
-- consists of horizonal line segments with
-- transparency and priorty. Groups of such
-- lines can form sprites

-- sprites features:

-- any number of sprites
-- any size
-- any geometry
-- transparency
-- priority
-- RAM space saving: same content can appear many times
-- RAM bandwidth saving: (less content displayed, less RAM bandwidth)
-- no need to move bitmap content across the video RAM,
-- no need to refresh "dirty" video RAM areas.

-- Sprites can move in horizontal or vertial direction just by
-- manipulating the offsets and pointers

-- video base points to first element of array of pointers to compositing lines
-- each line is linked list of bitmap content
-- each line should have at least one member.
-- for 640x480 there will be 480 vectors, each 32-bit
-- each content should have at least 4 pixels
-- each pixel can be either opque (coloured)
-- or transparent (a special color)

-- struct compositing_line
-- {
--   struct compositing_line *next; // 32-bit continuation of the same structure, NULL if no more
--   int16_t x; // x-offset where to start on screen (can be negative)
--   uint16_t n; // number of pixels following (4 pixels minimum)
--   uint8_t *pixel; // 32-bit pointer to array of pixels (lower 2 bits discarded, 4-byte aligned)
-- };
-- struct compositing_line *lines[480]; // 32-bit memory address of start of each line

-- there can be large number of compositing_line objects linked
-- one to each other.
-- Only limitation is the RAM bandwidth, if the full content
-- can't be read from RAM in time of one video scan line,
-- the rest of the list will be discarded, compositing will
-- then display some horizontal lines incomplete or flickery.

-- states executed in tight RAM read cycle loop
-- this is approximate explaination, read the code
-- to understand the real_thing :)
-- 0: C_read_line_start: read line start, increment ptr to start
--    addr <= R_line_start
--    R_line_start is updated during dequeue cycle
--    so if bandwidth can't supply it will jump over
--    over some content to minimize screen distortion
--    R_line_next <= data(addr)
--    when restart R_line_start <= base
-- 1: C_read_next: at line start, read next line pointer and store
--    addr <= R_line_next
--    R_line_next <= data(addr)
--    addr <= addr + 1
-- 2: C_read_position: read start on screen and no. of pixels in single 32-bit read and store it
--    R_position & R_px_count <= data(addr)
--    addr <= addr + 1
-- 3. read pointer to pixel data and jump to data
--    addr <= data(addr)
-- 4: C_read_data: read all pixels and composite'm 
--    pixel_data <= data(addr)
--    addr <= addr + 1
--    when all pixels done: if R_line_next = 0 then state<=0 else state<=1
-- RAM fetch cycle should take at least 4 CPU clocks
-- to be able to shift 32-bit word into 8bpp pixel bram

-- for simplicity, use alternate 2-line buffering
-- one line is displayed while other line is fetched
-- and composited

-- destructive reading of displayed data automatically
-- erases to background actually displayed pixels so the
-- BRAM is clean for the next line

-- debug example: to show 640x480 full screen of RGB vertical strips
-- every 2nd line will be empty because compositing timeout will occur as
-- there's no NULL pointer to indicate last segment
-- without RAM:
-- fetch_next <= vga_fetch_next,
-- active <= not vga_sync,
-- suggest_cache => suggest_cache,
-- data_ready => '1',
-- data_in => x"02800000" when suggest_cache='0' else x"031CE000",


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- to calculate log2 bit size
use ieee.numeric_std.all;

entity compositing2_fifo is
    generic (
        C_synclen: integer := 2; -- bits in cpu-to-pixel clock synchronizer
        C_fast_ram: boolean := true; -- set to true if RAM can be faster then shifting period (4 cycles for 8bpp) but beware of deadlock bug
        C_write_while_reading: boolean := true; -- true: normal, false: non-functiona, picture won't look correct without it :)
        -- C_position_clipping = false -- (default) handles only small out of screen positions
        -- C_position_clipping = true -- handles large out of screen gracefully (LUT eater)
        -- for average use it can be left disabled (false)
        C_position_clipping: boolean := false; 
        -- graceful bandwidth control: at the N pixels before the end of horizontal line
        -- prevent further compositing (instead of starting new segment, skip to next line)
        C_timeout: integer := 0; -- 0:disable, >=1 enable
        C_timeout_incomplete: boolean := false; -- true: allow timeout to abort incomplete segment (check if burst allows that)
        C_burst_max_bits: integer := 0; -- number of bits to describe max burst requested
        -- number of pixels per horizontal line
        C_width: integer := 640; -- pixels per line
        C_height: integer := 480; -- number of vertical lines
        C_vscroll: integer := 3; -- vertical scroll that fixes fifo delay
        C_data_width: integer range 8 to 32 := 8; -- bits per pixel
        C_length_subtract: integer := 0; -- todo: set to 0 to save LUTs but C library must change then
        -- fifo buffer size (number of address bits that refer to pixels)
        -- compositing: 11 (2^11 = 2048 bytes for 640x480 8bpp)
        C_addr_width: integer := 11 -- bits width of fifo address
    );
    port (
	clk, clk_pixel: in std_logic;
	addr_strobe: out std_logic; -- if using cache discard this strobe, and give strobe='1' to cache
	addr_out: out std_logic_vector(29 downto 2);
	suggest_burst: out std_logic_vector(C_burst_max_bits-1 downto 0) := (others => '0'); -- number of 32-bit words requrested
	suggest_cache: out std_logic; -- '1' during pulled content (state 4), most effective for cacheing
	base_addr: in std_logic_vector(29 downto 2);
	data_ready: in std_logic; -- RAM indicates data are ready for consuming
	data_in: in std_logic_vector(31 downto 0);
	read_ready: out std_logic; -- '1' when this module is ready to receive data from RAM
	data_out: out std_logic_vector(C_data_width-1 downto 0);
	active: in std_logic; -- rising edge sensitive will reset fifo RAM to base address, value 1 allows start of reading
	frame: out std_logic; -- output CPU clock synchronous start edge detection (1 CPU-clock wide pulse for FB interrupt)
        -- transparent and background color (default 0, black)
        color_transparent, color_background: in std_logic_vector(C_data_width-1 downto 0) := (others => '0');
	fetch_next: in std_logic -- edge sensitive fetch next value (current data consumed)
    );
end compositing2_fifo;

architecture behavioral of compositing2_fifo is
    -- function integer ceiling log2
    -- returns how many bits are needed to represent a number of states
    -- example ceil_log2(255) = 8,  ceil_log2(256) = 8, ceil_log2(257) = 9
    function ceil_log2(x: integer) return integer is
    begin
      return integer(ceil((log2(real(x)+1.0E-6))-1.0E-6));
    end ceil_log2;

    -- Constants
    constant C_data_log2_width: integer := ceil_log2(C_data_width);
    constant C_shift_addr_width: integer := 5-C_data_log2_width;
    constant C_shift_cycles: integer := 32/C_data_width; -- how many cpu cycles to shift from 32bit to reduced size bram
    -- constant C_addr_width: integer := C_width; -- more descriptive name in the code, keep generic compatible for now
    constant C_length: integer := 2**C_addr_width; -- 1 sll C_addr_width - shift logical left
    constant C_addr_pad: std_logic_vector(C_shift_addr_width-1 downto 0) := (others => '0'); -- warning fixme degenerate range (-1 downto 0) for 32bit
    constant C_data_pad: std_logic_vector(C_data_width-1 downto 0) := (others => '-'); -- when shifting

    -- Internal state
    signal R_sram_addr: std_logic_vector(29 downto 2);
    signal R_pixbuf_rd_addr, R_pixbuf_out_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal S_pixbuf_out_mem_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal S_pixbuf_in_mem_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal R_bram_in_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal S_bram_write, S_data_write: std_logic;
    signal S_need_refill: std_logic;
    signal R_need_refill_cpu: std_logic := '0';
    signal S_compositing_erase: std_logic := '0';
    signal S_offset_visible: std_logic := '1';
    -- for C_fast_ram=true, R_shifting_counter must start with MSB='1' otherwise it will start in deadlock mode
    signal R_shifting_counter: std_logic_vector(C_shift_addr_width downto 0) := (others => '1'); -- counts shift cycles and adds address
    signal R_data_in_shift: std_logic_vector(31 downto 0); -- data in shift buffer to bram
    signal S_bram_data_in: std_logic_vector(C_data_width-1 downto 0);
    -- compositing 2
    signal R_line_start, R_seg_next: std_logic_vector(29 downto 2);
    -- constant vertical circula scroll to fix few lines of fifo delay
    signal R_vertical_scroll, S_vertical_scroll_next: integer range 0 to C_height-1; -- y-position scroll fix
    signal S_vertical_scrolled: std_logic_vector(29 downto 2);
    signal R_state: integer range 0 to 4;
    signal R_position: std_logic_vector(15 downto 0);
    signal R_word_count: std_logic_vector(15 downto 0) := (others => '0');
    signal S_pixels_remaining: std_logic_vector(15 downto 0);
    signal R_suggest_cache: std_logic := '0';
    signal R_timeout: std_logic := '0';
    signal R_read_ready: std_logic := '0';
    signal S_burst_limited: std_logic_vector(15 downto 0) := x"0001";
    -- indicates which line in buffer (containing 2 lines) is written (compositing from RAM)
    -- and which line is read (by display output)
    signal R_line_rd, R_line_wr: std_logic := '0'; -- simple 1-bit index of line

    signal startsync: std_logic_vector(C_synclen-1 downto 0);
    -- clean start: '1' will reset fifo to its base address
    --              '0' will allow fifo normal sequential operation
    signal clean_start: std_logic;
begin
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
        -- synchronize clk_pixel to clk with shift register
        startsync <= active & startsync(C_synclen-1 downto 1);
      end if;
    end process;

    -- clean start produced from a delay thru clock synchronous shift register
    -- clean_start <= startsync(C_synclen-1); -- level
    clean_start <= startsync(1) and not startsync(0); -- rising edge

    -- at start of frame generate pulse of 1 CPU clock
    -- rising edge detection of start signal
    -- useful for VSYNC frame interrupt
    frame <= clean_start; -- must be rising edge for CPU interrupt, not level

    S_pixels_remaining <= data_in(31 downto 16) + data_in(15 downto 0); -- used if data_in(15 downto 0) is negative
    -- Refill the circular buffer with fresh data from external RAM
    -- h-compositing of thin sprites on the fly
    process(clk)
    begin
        if rising_edge(clk) then
          if clean_start = '1' then
            R_sram_addr <= R_line_start;
            R_state <= 0;
            R_line_wr <= '0';
          else
            if data_ready = '1' and S_need_refill = '1'
            then -- BRAM must use this
                case R_state is
                  when 0 => -- read pointer to line start
                    -- R_sram_addr points to one of array of start addresses
                    if conv_integer(data_in) = 0 then
                      -- NULL pointer: this line is empty, jump to next line
                      R_line_wr <= not R_line_wr; -- + 1;
                      R_sram_addr <= R_line_start; -- jump to start of the next line
                    else
                      R_sram_addr <= data_in(29 downto 2); -- read address of first segment start
                      R_state <= 1;
                    end if;
                  when 1 => -- read next line segment
                    R_seg_next <= data_in(29 downto 2); -- read next segment start address
                    R_sram_addr <= R_sram_addr + 1; -- next sequential read
                    R_state <= 2;
                  when 2 => -- read position and pixel count
                    if C_position_clipping = false then
                      -- simple variant: no arithmetic clipping
                      -- use a bigger bram and wirite to unused
                      -- area, thus make a short range clipping
                      R_position <= data_in(15 downto 0); -- compositing position (pixels)
                      -- addr pad for 8bpp is "00"
                      R_word_count <= (C_addr_pad & data_in(31 downto 16+C_shift_addr_width))-C_length_subtract; -- number of 32-bit words (n*4 pixels)
                      R_sram_addr <= R_sram_addr + 1;  -- next sequential read (data)
                    else
                      -- C_position_clipping = true
                      if data_in(15) = '0' then
                        -- data_in(15 downto 0) is positive
                        if data_in(15 downto 0) < C_width then
                          R_position <= data_in(15 downto 0); -- compositing position (pixels)
                          R_word_count <= (C_addr_pad & data_in(31 downto 16+C_shift_addr_width))-C_length_subtract; -- number of 32-bit words (n*4 pixels)
                          R_sram_addr <= R_sram_addr + 1;  -- next sequential read (data)
                        else
                          -- out of visible compositing range, skip to the next segment or line
                          if R_seg_next = 0 then
                            R_state <= 0;
                            R_line_wr <= not R_line_wr; -- + 1;
                            R_sram_addr <= R_line_start; -- jump to start of the next line
                          else
                            R_state <= 1;
                            R_sram_addr <= R_seg_next; -- jump to next compositing segment
                          end if;
                        end if;
                      else
                        -- data_in(15 downto 0) is negative
                        if S_pixels_remaining(15) = '0' then
                          -- few pixels still remaining from compositing line
                          R_position <= (others => '0');
                          R_word_count <= (C_addr_pad & S_pixels_remaining(15 downto C_shift_addr_width))-C_length_subtract;
                          -- skip forward (convert negative position into positive)
                          R_sram_addr <= R_sram_addr + (x"0001" - ("11" & data_in(15 downto 2)));
                        else
                          -- out of visible compositing range, skip to the next segment or line
                          if R_seg_next = 0 then
                            R_state <= 0;
                            R_line_wr <= not R_line_wr; -- + 1;
                            R_sram_addr <= R_line_start; -- jump to start of the next line
                          else
                            R_state <= 1;
                            R_sram_addr <= R_seg_next; -- jump to next compositing segment
                          end if;
                        end if;
                      end if; -- C_position negative?
                    end if; -- C_position_clipping
                    R_state <= 3;
                  when 3 => -- read pointer to data and jump there
                    R_sram_addr <= data_in(29 downto 2);
                    R_state <= 4;
                    R_suggest_cache <= '1'; -- suggest cacheing bitmap content
                  when others => -- read pixels and prepare to exit
                    -- data to compositing (written from another process)
                    -- pixeldata = data_in(31 downto 16);
                    -- check range if within the line
                    if R_word_count = 0 or (R_timeout = '1' and C_timeout_incomplete) then
                      -- word count decrements
                      -- last element in segment is now being composited
                      -- from this state
                      -- we can either jump to next segment or
                      -- if no more segments then complete the line
                      if R_seg_next = 0 or R_timeout = '1' then
                        -- no more segments, line completed
                        R_word_count <= (others => '0');
                        R_state <= 0;
                        R_line_wr <= not R_line_wr; -- + 1;
                        R_sram_addr <= R_line_start; -- jump to start of the next line
                      else
                        -- next segment
                        R_state <= 1;
                        R_sram_addr <= R_seg_next; -- jump to next compositing segment
                      end if;
                      R_suggest_cache <= '0'; -- suggest no cacheing of metadata
                    else
                      R_position <= R_position + C_shift_cycles; -- 4 pixel skip (1 word)
                      R_sram_addr <= R_sram_addr + 1;  -- next sequential read
                      R_word_count <= R_word_count - 1; -- 4 pixels less to process
                    end if;
                end case;
            end if;
          end if;
        end if;
    end process;

    -- experimental read ready signaling,
    -- currently only used when connecting directly to axi
    read_ready <= R_shifting_counter(C_shift_addr_width); -- works for the burst
    --read_ready <= S_need_refill and R_shifting_counter(C_shift_addr_width); -- this works only for no burst but strange: works only long bitmap lines, short sprites dont' work

    suggest_cache <= R_suggest_cache;
    G_yes_burst: if C_burst_max_bits > 0 generate
      suggest_burst <= R_word_count(C_burst_max_bits-1 downto 0) when R_state=0 or R_state=4
                  else std_logic_vector(to_unsigned(3-R_state, C_burst_max_bits)); -- value 2 means 3 words to burst
    end generate;

    -- need refill signal must be CPU synchronous
    -- attention: R_need_refill_cpu is clk_pixel synchronos
    -- R_need_refill_cpu will come with a delay,
    -- a possible problem is that un-needed data may be requested
    -- using address_strobe
    process(clk) begin
      if rising_edge(clk) then
        if R_line_wr = R_line_rd
        then
            R_need_refill_cpu <= '0';
        else
            R_need_refill_cpu <= '1';
        end if;
      end if;
    end process;

    permanent_strobe: if C_data_width = 32 generate
    S_need_refill <= R_need_refill_cpu;
    end generate;

    intermittent_strobe: if C_data_width < 32 generate
      no_fast_ram: if C_fast_ram = false generate
        S_need_refill <= R_need_refill_cpu;
      end generate; -- no_fast_ram
      yes_fast_ram: if C_fast_ram = true generate
        -- warning this is workaround and can cause deadlock
        S_need_refill <= '1' when R_need_refill_cpu='1' and
            (
              -- conservative request delay:
              -- effectively this does
              --R_shifting_counter >= C_shift_cycles-1
              -- it prevents too early request of new data from cache or fast RAM
              -- before shifting process has completed.
              -- if new data arrive too early it will be unconditionally accepted
              -- and data which entered shifting process will be overwritten.
              -- XXX FIXME:
              -- ready signal can be missed and this will lead to deadlock
              -- and screen will freeze.
              conv_integer(not R_shifting_counter(C_shift_addr_width-1 downto 0)) = 0 -- during last shift cycle we can start new data
              or
              R_shifting_counter(C_shift_addr_width) = '1' -- past last shift cycle, shift fully complete, start new data
            )
            else '0';
      end generate; -- yes_fast_ram
    end generate;

    -- addr_strobe must be cpu CLK synchronous!
    addr_strobe <= S_need_refill;
    addr_out <= R_sram_addr;

    -- sprite with large negative offset is invisble
    -- S_offset_visible <= '0' when R_compositing_active_offset(15 downto 14) = "10" else '1';
    -- write to buffer during state 4 (fetching of pixel data)
    S_data_write <= '1' when data_ready='1'
                         and S_need_refill='1' -- only if we have requested data (ignore stray ready)
                         and R_state = 4 -- write only during state 4 - bitmap data reading
                         -- below conditions in () are already in the S_need_refill:
                         --and R_shifting_counter >= C_shift_cycles-1
                         and
                           (
                             conv_integer(not R_shifting_counter(C_shift_addr_width-1 downto 0)) = 0 -- during last shift cycle we can start new data
                             or
                             R_shifting_counter(C_shift_addr_width) = '1' -- past last shift cycle, shift fully complete, start new data
                           )
                        else '0';
    -- calculate the compositing address where pixel data go (byte address for 8bpp)
    S_pixbuf_in_mem_addr <= R_line_wr & R_position(C_addr_width-2 downto 0);

    -- data_in is always 32-bits
    -- buffer can have less than 32 bits
    buffer_direct: if C_data_width = 32 generate
      S_bram_data_in <= data_in;
      S_bram_write <= S_data_write when data_in /= color_transparent else '0';
      R_bram_in_addr <= S_pixbuf_in_mem_addr; -- not a register but pass-thru signal
    end generate;

    buffer_shifting: if C_data_width < 32 generate
      -- buffer_shifting: if false generate
      -- for less than 32 bits e.g. 8:
      -- it will start 4-cycle writing from 32-bit 
      -- from data_in to compositing bram
      -- writing to buffer randomly (compositing)
      process(clk) begin
        if rising_edge(clk) then
          if S_data_write = '1' then
            -- new data arrived: unconditionaly start them
            -- this may overwrite data currently being shifted, but
            -- assumed is slow RAM with the incoming S_data_write rate
            -- slow enough to be completely shifted.
            -- usually SRAM or SDRAM can't fetch faster than 4 CPU cycles
            -- so it fits to shift 8 bit per pixel output
            -- for lower than 8 we won't have time to shift
            -- in that case: FIXME :-)
            -- currently it is fixed by masking out addr_stobe
            -- until shifting is finished
            R_data_in_shift <= data_in; -- store data in temporary shift register
            --R_data_in_shift <= x"aa5511ff";
            -- for later storing into compositing bram)
            R_shifting_counter <= (others => '0'); -- start shift counter
            -- the starting address for storage
            R_bram_in_addr <= S_pixbuf_in_mem_addr;
          else
            if R_shifting_counter(C_shift_addr_width) = '0' then
              -- shift the data and increment address
              R_data_in_shift <= C_data_pad & R_data_in_shift(31 downto C_data_width); -- shift next data
              R_shifting_counter <= R_shifting_counter + 1; -- increment counter, when msb is 1 shifting stops
              -- C_addr_width-2 wraparound within the same compositing line
              -- MSB selects line (2 lines in buffer)
              R_bram_in_addr(C_addr_width-2 downto 0) <= R_bram_in_addr(C_addr_width-2 downto 0) + 1; -- next data to next address
            end if;
          end if;
        end if; -- rising edge(clk)
      end process;

      -- bram will be written when MSB of the shifting counter is 0
      -- MSB=1 allows shifting to stop when complete
      -- this provides signal to bram to store data
      -- write signal with handling transparency:
      -- if pixel to be written is of transparent color (default 0 = black)
      -- then don't write, allow it to
      -- "see through" lower priority sprites
      S_bram_write <= '1' when S_bram_data_in /= color_transparent
                           and R_shifting_counter(C_shift_addr_width) = '0'
                 else '0';
      S_bram_data_in <= R_data_in_shift(C_data_width-1 downto 0);
    end generate;

    linememory: entity work.bram_true2p_2clk
    generic map (
        dual_port => True, -- one port takes data from RAM, other port outputs to video
        pass_thru_a => False, -- false allows simultaneous reading and erasing of old data
        pass_thru_b => False, -- false allows simultaneous reading and erasing of old data
        data_width => C_data_width,
        addr_width => C_addr_width
    )
    port map (
        clk_a => clk,
        clk_b => clk_pixel,
        we_a => S_bram_write,
        we_b => S_compositing_erase, -- compositing must erase after use (rewind won't work with compositing)
        addr_a => R_bram_in_addr,
        addr_b => S_pixbuf_out_mem_addr,
        data_in_a => S_bram_data_in,
        data_in_b => color_background, -- erase value for compositing
        data_out_a => open,
        data_out_b => data_out
    );

    ---------------------------------------------------------
    -- clk_pixel synchronous readout of composited content --
    ---------------------------------------------------------

    -- calculate address for reading from line memory
    S_pixbuf_out_mem_addr <= R_line_rd & R_pixbuf_rd_addr(C_addr_width-2 downto 0);

    -- Dequeue pixel data from the circular buffer
    -- by incrementing R_pixbuf_rd_addr on rising edge of clk
    process(clk_pixel)
      begin
        if rising_edge(clk_pixel) then
          if active = '0' then
            R_pixbuf_rd_addr <= (others => '0');  -- this will read data from RAM
            R_line_rd <= '0'; -- reset line to read from
            R_vertical_scroll <= C_vscroll; -- vertical scroll to fix fifo delay
          else
            if fetch_next = '1' then
              if R_pixbuf_rd_addr = C_width-1 then -- next line in buffer
                -- this is executed once at the end of line (right of screen)
                R_pixbuf_rd_addr <= (others => '0');
                R_line_rd <= not R_line_rd; -- + 1;
                R_vertical_scroll <= S_vertical_scroll_next;
                R_line_start <= S_vertical_scrolled;
              else
                R_pixbuf_rd_addr <= R_pixbuf_rd_addr + 1;
              end if;
	    end if;
          end if;
        end if;
      end process;

    S_vertical_scrolled <= base_addr+R_vertical_scroll;
    S_vertical_scroll_next <= 0 when R_vertical_scroll = C_height-1
                                else R_vertical_scroll+1;

    -- compositing must erase stale data after use.
    -- immediately after data is read by "fetch_next" signal,
    -- "linememory" BRAM must be erased to "color_background"
    -- in order to be ready for
    -- compositing new incoming data.
    -- (erasing is done with the same "fetch_next" signal)
    -- a registered, non-pass-through BRAM block
    -- is required for this to work
    S_compositing_erase <= fetch_next when C_write_while_reading else '0';

    -- at a configurable amount of pixels end of line and
    -- before "R_line_rd" changes this process will generate
    -- timeout signal in order to cancel further compositing
    -- This may reduce picture distortion in case of bandwidth
    -- shortage
    G_timeout: if C_timeout > 0 generate
      process(clk_pixel)
        begin
          if rising_edge(clk_pixel) then
            if R_pixbuf_rd_addr = 0 then
              R_timeout <= '0';
            end if;
            if R_pixbuf_rd_addr = C_width-C_timeout then
              R_timeout <= '1';
            end if;
          end if;
        end process;
    end generate;

end;

-- todo

-- [ ] advanced bandwidth saving:
--     don't fetch low priority or clipped out content.
--     composite highest priority pixels first.
--     read back composited data or have extra bram that
--     will memorize opacity
--     and skip fetching of any
--     lower priority which will appear "under" already
--     composited pixels and thus result in no visual difference

-- [ ] allow content to have 0 pixels currently this is not possible
--     minimum content is 4 pixels (32-bit word)

-- [ ] allow empty line (NULL pointer to content)

-- [x] 2 horizonal lines on top should be on the bottom
--     this is because of FIFO system delays output for 2 lines
--     could be left as-is, fixed with vertical scroll.

-- [x] around vertical lines 3-5, lines skipped or duplicated? (see slash char in c2_font)

-- [x] first 3 vertical lines are transparent while they shoudn't be
--     solution: during shifiting, use 1 bit less for bram write address

-- [x] gracefully handle low bandwidth - if some lines
--     can't be fetched in time, resume to correct line
--     to minimize visual degradation of the picture
--     some improvement for 2 chasing pointers

-- [ ] 16bpp test: does it work correctly?
--     In 16bpp mode it looks like pixel step is still 8bpp

-- [x] cache support (save bandwidth when displaying font using tiled sprites)

-- [x] axi burst: why do we need read_ready delay hack, is ready wrong timed
--     no need for ready delay, ready seems correctly timed

-- [ ] axi burst: why ready and-masked with S_need_refill doesn't work, 
--     is S_need_refill wrong timed
--     are some un-needed data requested e.g., after the end of line/frame...?

-- [ ] axi burst: can we get along without R_word_count /= 0
       -- or when R_word_count = 0 prevent addr_strobe ?
       -- mostly yes but when uploading c2_sprites and then c2_font
       -- screen freezes without R_word_count /= 0
       -- with R_word_count /= 0 works fine

-- [ ] 24bpp: how can it be easily done (bandwidth saving instead of fetching 32bit

-- [ ] FIFO for max burst length to avoid de-asserting read_ready and intermittent strobe

-- [ ] burst: upload c2_sprites, c2_font and screen blanks, unrecoverable
