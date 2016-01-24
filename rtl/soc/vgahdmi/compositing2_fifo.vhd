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
-- compositeed into 2D bitmap picture with sprites
-- sprites features;

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
-- each line is linked list of bitmap content, should have at least one member.
-- for 640x480 there will be 480 vectors, each 32-bit

-- struct compositing_line
-- {
--   struct compositing_line *next; // 32-bit continuation of the same structure, NULL if no more
--   int16_t x; // x-offset where to start on screen (can be negative)
--   uint16_t n; // number of pixels following (4 pixels minimum)
--   uint8_t *pixel; // 32-bit pointer to array of pixels (lower 2 bits discarded, 4-byte aligned)
-- };
-- struct compositing_line *lines[480]; // 32-bit memory address of start of each line

-- there can be large number of compositing_line objects linked one to each other.
-- Only limitation is the RAM bandwidth, if the full content
-- can't be read from RAM in time of one video scan line,
-- the rest of the list will be discarded, compositing will
-- then display incomplete and flickery lines

-- states
-- 0: C_read_line_start: read line start, increment ptr to start
--    addr <= R_line_start
--    R_line_next <= data(addr)
--    R_line_start <= R_line_start + 1
--    when restart R_line_start <= base
-- 1: C_read_next: at line start, read next line pointer and store
--    addr <= R_line_next
--    R_line_next <= data(addr)
--    addr <= addr + 1
-- 2: C_read_position: read start on screen and no. of pixels in single 32-bit read and store it
--    R_position & R_px_count <= data(addr)
--    addr <= addr + 1
-- 3. read pointer to data and jump there
--    addr <= data(addr)
-- 4: C_read_data: read all pixels and composite'm when done go to 
--    pixel_data <= data(addr)
--    addr <= addr + 1
--      when all pixels done: if R_line_next = 0 then state<=0 else state<=1

-- for simplicity, use alternate 2-line buffering
-- one line is displayed while other line is fetched

-- destructive reading of displayed data automatically
-- erases to background actually displayed pixels so the
-- BRAM is clean for the next line

-- we need to composit on every full line
-- 2K buffer will 3 composited lines
-- one line is currently displayed and erased
-- another 2 lines can be filled up when during displaying

-- RAM fetch cycle should take at least 4 CPU clocks
-- to be able to shift 32-bit word into 8-bit bram


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all; -- to calculate log2 bit size
use ieee.numeric_std.all;

entity compositing2_fifo is
    generic (
        C_synclen: integer := 3; -- bits in cpu-to-pixel clock synchronizer
        -- (0: disable rewind and be ordinary sequential fifo)
        -- (>0: fifo will be loaded from RAM in full steps
        -- number of pixels per horizontal line
        -- C_position_clipping = false -- handles only small out of screen positions
        -- C_position_clipping = true -- handles large out of screen gracefully (LUT eater)
        C_position_clipping: boolean := false; 
        C_step: integer := 640; -- pixels per line
        C_data_width: integer range 8 to 32 := 8; -- bits per pixel
        -- fifo buffer size (number of address bits that refer to pixels)
        -- compositing: 11 (2^11 = 2048 bytes for 640x480 8bpp)
        C_addr_width: integer := 11 -- bits width of fifo address
    );
    port (
	clk, clk_pixel: in std_logic;
	addr_strobe: out std_logic;
	addr_out: out std_logic_vector(29 downto 2);
	base_addr: in std_logic_vector(29 downto 2);
	-- debug_rd_addr: out std_logic_vector(29 downto 2);
	data_ready: in std_logic;
	data_in: in std_logic_vector(31 downto 0);
	data_out: out std_logic_vector(C_data_width-1 downto 0);
	active: in std_logic; -- rising edge sensitive will reset fifo RAM to base address, value 1 allows start of reading
	frame: out std_logic; -- output CPU clock synchronous start edge detection (1 CPU-clock wide pulse for FB interrupt)
	-- rewind is useful to re-read text line, saving RAM bandwidth.
	-- rewind is possible at any time but is be normally issued
	-- during H-blank period - connected to hsync signal.
	rewind: in std_logic := '0'; -- rising edge sets output data pointer to the start of last full step
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
    signal R_pixbuf_wr_addr, S_pixbuf_wr_addr_next: std_logic_vector(C_addr_width-1 downto C_shift_addr_width);
    signal R_pixbuf_rd_addr, R_pixbuf_out_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal S_pixbuf_out_mem_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal S_pixbuf_in_mem_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal R_bram_in_addr: std_logic_vector(C_addr_width-1 downto 0);
    signal R_delay_fetch: integer range 0 to 2*C_step;
    signal S_bram_write, S_data_write: std_logic;
    signal S_need_refill: std_logic;
    signal R_need_refill_cpu: std_logic := '0';
    --signal S_data_opaque: std_logic;
    --signal S_fetch_compositing_offset: std_logic := '0';
    signal S_compositing_erase: std_logic := '0';
    --signal R_compositing_active_offset: std_logic_vector(15 downto 0) := (others => '0');
    --signal R_compositing_second_offset: std_logic_vector(15 downto 0) := (others => '0');
    --signal R_compositing_countdown: integer range 0 to C_compositing_length := 0;
    signal S_offset_visible: std_logic := '1';
    signal R_shifting_counter: std_logic_vector(C_shift_addr_width downto 0) := (others => '0'); -- counts shift cycles and adds address
    signal R_data_in_shift: std_logic_vector(31 downto 0); -- data in shift buffer to bram
    signal S_bram_data_in: std_logic_vector(C_data_width-1 downto 0);
    -- compositing 2
    signal R_line_start, R_seg_next: std_logic_vector(29 downto 2);
    signal R_state: integer range 0 to 4;
    signal R_position, R_word_count: std_logic_vector(15 downto 0);
    signal S_position, S_pixel_count: std_logic_vector(15 downto 0);
    signal S_pixels_remaining: std_logic_vector(15 downto 0);
    constant C_state_read_line_start: integer := 0;
    -- indicates which line in buffer (containing 2 lines) is written (compositing from RAM)
    -- and which line is read (by display output)
    signal R_line_rd, R_line_wr: std_logic := '0'; -- simple 1-bit index of line
    
    -- signal need_refill: boolean;
    signal toggle_read_complete: std_logic;
    signal clksync, startsync, rewindsync: std_logic_vector(C_synclen-1 downto 0);
    -- clean start: '1' will reset fifo to its base address
    --              '0' will allow fifo normal sequential operation
    signal clean_start, clean_fetch: std_logic;
    -- clean rewind: '1' will rewind fifo to its last full step
    --               '0' will allow fifo normal sequential operation
    signal clean_rewind: std_logic;
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
        -- synchronize clk_pixel to clk with shift register
        clksync <= clksync(C_synclen-2 downto 0) & toggle_read_complete;
        startsync <= startsync(C_synclen-2 downto 0) & active;
        rewindsync <= rewindsync(C_synclen-2 downto 0) & rewind;
      end if;
    end process;

    -- XOR: difference in 2 consecutive clksync values
    -- create a short pulse that lasts one CPU clk period.
    -- This signal is request to fetch new data
    clean_fetch <= clksync(C_synclen-2) xor clksync(C_synclen-1);

    -- clean start produced from a delay thru clock synchronous shift register
    -- clean_start <= startsync(C_synclen-1); -- level
    clean_start <= startsync(C_synclen-2) and not startsync(C_synclen-1); -- rising edge

    -- at start of frame generate pulse of 1 CPU clock
    -- rising edge detection of start signal
    -- useful for VSYNC frame interrupt
    frame <= clean_start; -- must be rising edge for CPU interrupt, not level

    S_position <= data_in(15 downto 0);
    S_pixel_count <= data_in(31 downto 16);
    S_pixels_remaining <= S_pixel_count + S_position; -- used if S_position is negative
    -- Refill the circular buffer with fresh data from external RAM
    -- h-compositing of thin sprites on the fly
    process(clk)
    begin
        if rising_edge(clk) then
          if clean_start = '1' then
            R_sram_addr <= R_line_start;
            R_state <= 0;
            R_line_wr <= '0';
            R_pixbuf_wr_addr <= (others => '0');
          else
            if data_ready = '1' and S_need_refill = '1'
            then -- BRAM must use this
                case R_state is
                  when 0 => -- read pointer to line start
                    -- R_sram_addr points to one of array of start addresses
                    R_sram_addr <= data_in(29 downto 2); -- read address of first segment start
                    R_state <= 1;
                  when 1 => -- read next line segment
                    R_seg_next <= data_in(29 downto 2); -- read next segment start address
                    R_sram_addr <= R_sram_addr + 1; -- next sequential read
                    R_state <= 2;
                  when 2 => -- read position and pixel count
                    if C_position_clipping = false then
                      -- simple variant: no arithmetic clipping
                      -- use a bigger bram and wirite to unused
                      -- area, thus make a short range clipping
                      R_position <= S_position; -- compositing position (pixels)
                      -- addr pad for 8bpp is "00"
                      R_word_count <= C_addr_pad & S_pixel_count(15 downto C_shift_addr_width); -- number of 32-bit words (n*4 pixels)
                      R_sram_addr <= R_sram_addr + 1;  -- next sequential read (data)
                    else
                      -- C_position_clipping = true
                      if S_position(15) = '0' then
                        -- S_position is positive
                        if S_position < C_step then
                          R_position <= S_position; -- compositing position (pixels)
                          R_word_count <= C_addr_pad & S_pixel_count(15 downto C_shift_addr_width); -- number of 32-bit words (n*4 pixels)
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
                        -- S_position is negative
                        if S_pixels_remaining(15) = '0' then
                          -- few pixels still remaining from compositing line
                          R_position <= (others => '0');
                          R_word_count <= C_addr_pad & S_pixels_remaining(15 downto C_shift_addr_width);
                          -- skip forward (convert negative position into positive)
                          R_sram_addr <= R_sram_addr + (x"0001" - ("11" & S_position(15 downto 2)));
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
                  when others => -- read pixels and prepare to exit
                    -- data to compositing (written from another process)
                    -- pixeldata = data_in(31 downto 16);
                    -- check range if within the line
                    if R_word_count = 1 then
                      -- word count decrements
                      -- last element in segment is now being composited
                      -- from this state
                      -- we can either jump to next segment or
                      -- if no more segments then complete the line
                      if R_seg_next = 0 then
                        -- no more segments, line completed
                        R_state <= 0;
                        R_line_wr <= not R_line_wr; -- + 1;
                        R_sram_addr <= R_line_start; -- jump to start of the next line
                      else
                        -- next segment
                        R_state <= 1;
                        R_sram_addr <= R_seg_next; -- jump to next compositing segment
                      end if;
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

    -- need refill signal must be CPU synchronous
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
    
    S_need_refill <= R_need_refill_cpu;
    
    -- addr_strobe must be cpu CLK synchronous!
    addr_strobe <= S_need_refill;
    addr_out <= R_sram_addr;

    -- Dequeue pixel data from the circular buffer
    -- by incrementing R_pixbuf_rd_addr on rising edge of clk
    process(clk_pixel)
      begin
        if rising_edge(clk_pixel) then
          if active = '0' then
            R_pixbuf_rd_addr <= (others => '0');  -- this will read data from RAM
            R_line_rd <= '0'; -- reset line to read from
            R_line_start <= base_addr;
          else
            if fetch_next = '1' then
              if R_pixbuf_rd_addr = C_step-1 then -- next line in buffer
                -- this is executed once at the end of line (right of screen)
                R_pixbuf_rd_addr <= (others => '0');
                R_line_rd <= not R_line_rd; -- + 1;
                R_line_start <= R_line_start + 1;
              else
                R_pixbuf_rd_addr <= R_pixbuf_rd_addr + 1; -- R_pixbuf_out_addr + 1 ??
              end if;
	    end if;
          end if;
        end if;
      end process;

    -- writing to line memory
    --we_with_compositing: if C_compositing_length /= 0 generate
      -- signal used in Refill process that every 17th word
      -- fetched is offset word, not bitmap 
      --S_fetch_compositing_offset <= '1' when R_compositing_countdown = 0 else '0';
      -- compositing must erase stale data after use
      -- needs clean memory for compositing fresh data
      -- (erasing is done when clean_fetch signal is detected)
      -- rewind can not work together with compositing (data erased)
      -- at the same time read out data and erase
      -- a registered, non-pass-through BRAM block
      -- is required for this to work
      S_compositing_erase <= fetch_next;
      -- sprite with large negative offset is invisble
      -- S_offset_visible <= '0' when R_compositing_active_offset(15 downto 14) = "10" else '1';
      -- write signal with handling transparency:
      -- if word to be written is 0 then don't write, allow it to
      -- "see through" lower priority sprites
      S_data_write <= '1' when data_ready='1'
                           and R_state = 4 -- write only during state 4 - bitmap data reading
                          else '0';
      -- calculate the compositing address where pixel data go (byte address)
      S_pixbuf_in_mem_addr <= R_line_wr & R_position(C_addr_width-2 downto 0);
    --end generate;

    -- data_in is always 32-bits
    -- buffer can have less than 32 bits
    buffer_direct: if C_data_width = 32 generate
      S_bram_data_in <= data_in;
      S_bram_write <= S_data_write;
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
      -- fixme: here transparency doesn't work?
      S_bram_write <= '1' when S_bram_data_in /= color_transparent
                           and R_shifting_counter(C_shift_addr_width) = '0'
                 else '0';
      S_bram_data_in <= R_data_in_shift(C_data_width-1 downto 0);
    end generate;

    -- calculate address for reading from line memory
    S_pixbuf_out_mem_addr <= R_line_rd & R_pixbuf_rd_addr(C_addr_width-2 downto 0);

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
end;

-- todo

-- [ ] advanced bandwidth saving:
--     don't fetch low priority or clipped out content.
--     compisite highest priority pixels first.
--     read back composited data or have extra bram that
--     will memorize opacity
--     and skip fetching of any
--     lower priority which will appear "under" already
--     composited pixels and thus result in no visual difference

-- [ ] allow content to have 0 pixels currently this is not possible
--     minimum content is 4 pixels (32-bit word)

-- [ ] first 2 horizonal lines show wrong content from bottom
--     could be left as-is, fixed from CPU C code as 2 lines are delayed

-- [x] first 3 vertical lines are transparent while they shoudn't be
--     solution: during shifiting, use 1 bit less for bram write address

-- [x] gracefully handle low bandwidth - if some lines
--     can't be fetched in time, resume to correct line
--     to minimize visual degradation of the picture
--     some improvement for 2 chasing pointers

-- [ ] font and text data fetching during video blank
