-- VGA_textmode.vhd
--
-- VGA/DVI/HDMI color text mode with optional SRAM/SDRAM bitmap designed for f32c
--
-- Copyright (c) 2015 Ken Jordan
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sub-license, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all; -- to calculate log2 bit size
use work.video_mode_pack.all;

entity VGA_textmode is
  generic (
    C_vgatext_mode: integer;                        -- 0=640x480, 1=640x400, 2=800x600 (needs proper clk_pixel_i clock [25MHz or 40Mhz])
    C_vgatext_bits: integer;                        -- bits per R G B for output 1 to 8 (for 2^(n*3) colors)
    C_vgatext_bram_mem: integer;                    -- amount of BRAM for VGA_textmode use
    C_vgatext_external_mem: integer;                -- amount of external SRAM/SDRAM for bitmap or text FIFO
    C_vgatext_reset: boolean;                       -- reset registers to default with async reset
    C_vgatext_palette: boolean;                     -- true to enable 16 entry color look-up table (else 16 fixed VGA text colors)
    C_vgatext_text: boolean;                        -- enable text character generation
    C_vgatext_reg_read: boolean;                    -- true: allow reading vgatext BRAM via register interface
    C_vgatext_text_fifo: boolean;                   -- true to use videofifo for text+attribute buffer, else BRAM
    C_vgatext_font_bram8: boolean;                  -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
    C_vgatext_char_height: integer;                 -- font cell height (may be different than font height for more vertical spacing)
    C_vgatext_font_height: integer;                 -- font data height 8 or 16
    C_vgatext_font_depth: integer;                  -- font char bits (7=128, 8=256 characters)
    C_vgatext_font_linedouble: boolean;             -- double each line of font (e.g. 8x8 font fills 8x16 cell)
    C_vgatext_font_widthdouble: boolean;            -- double width of each pixel of font (font width 16 instead of 8 pixels)
    C_vgatext_monochrome: boolean;                  -- true to disable color+attribute byte in buffer (one color register for entire screen)
    C_vgatext_finescroll: boolean;                  -- true to enable text screen fine scroll
    C_vgatext_cursor: boolean;                      -- enable hardware text cursor
    C_vgatext_cursor_blink: boolean;                -- enable hardware text cursor blinking
    C_vgatext_bitmap: boolean;                      -- true for bitmap from SRAM/SDRAM
    C_vgatext_bitmap_depth: integer;                -- bitmap bits per pixel (1, 2, 4, 8)
    C_vgatext_bitmap_fifo_data_width: integer := 32;-- fifo output bits
    C_vgatext_bitmap_fifo: boolean                  -- true to use videofifo for bitmap, else uses SRAM port
  );
  port (
    reset_i:            in std_logic;                       -- reset registers
    clk_i:              in std_logic;                       -- system clock
    ce_i:               in std_logic;                       -- register access enable
    bus_write_i:        in std_logic;                       -- system bus write
    bus_addr_i:         in std_logic_vector(2 downto 0);    -- bus address (8 word registers)
    byte_sel_i:         in std_logic_vector(3 downto 0);    -- byte select within word
    bus_data_i:         in std_logic_vector(31 downto 0);   -- register data input
    bus_data_o:         out std_logic_vector(31 downto 0);  -- register data output

    clk_pixel_i:        in std_logic;                       -- pixel clock

    bram_addr_o:        out std_logic_vector(15 downto 2);  -- font (or text+color) BRAM address
    bram_data_i:        in std_logic_vector(31 downto 0);   -- font (or text+color) BRAM data
    text_active_o:      out std_logic;                      -- true when not on visible scan-line

    textfifo_addr_o:    out std_logic_vector(29 downto 2);  -- text+color buffer FIFO start address
    textfifo_data_i:    in std_logic_vector(31 downto 0);   -- data from text+color FIFO
    textfifo_strobe_o:  out std_logic;                      -- fetch next data from FIFO
    textfifo_rewind_o:  out std_logic;                      -- "rewind" FIFO to replay last text-line data

    bitmap_addr_o:      out std_logic_vector(29 downto 2);  -- bitmap buffer address (or start address with FIFO)
    bitmap_data_i:      in std_logic_vector(C_vgatext_bitmap_fifo_data_width-1 downto 0);   -- bitmap data from SRAM or FIFO
    bitmap_strobe_o:    out std_logic;                      -- request data (or request next word with FIFO)
    bitmap_rewind_o:    out std_logic;                      -- "rewind" FIFO to replay last scan-line data
    bitmap_ready_i:     in std_logic;                       -- bitmap data ready (not used with FIFO)
    bitmap_active_o:    out std_logic;                      -- true when not on visible scan-line

    hsync_o:            out std_logic;                      -- horizontal sync output (polarity depends on video mode)
    vsync_o:            out std_logic;                      -- vertical sync output (polarity depends on video mode)
    blank_o:            out std_logic;                      -- blanked output (true when not scanning visible area)
    red_o:              out std_logic_vector (7 downto 8-C_vgatext_bits); -- red color output
    green_o:            out std_logic_vector (7 downto 8-C_vgatext_bits); -- green color output
    blue_o:             out std_logic_vector (7 downto 8-C_vgatext_bits)  -- blue color output
  );
end VGA_textmode;

architecture Behavioral of VGA_textmode is
  -- local helper functions
  function bool_to_sl(flag: boolean)      -- boolean to std_logic_vector
    return std_logic is
  variable r: std_logic;
  begin
    if flag then
      r := '1';
    else
      r := '0';
    end if;
  return r;
  end bool_to_sl;

  function select_t_f(flag: boolean; trueval: integer; falseval: integer)  -- select values with boolean
    return integer is
  variable r: integer;
  begin
    if flag then
      r := trueval;
    else
      r := falseval;
    end if;
  return r;
  end select_t_f;

  function po2_to_slv4(size: integer)     -- power-of-two integer to std_logic_vector(3 downto 0)
    return std_logic_vector is
  variable r: std_logic_vector(3 downto 0);
  begin
    case size is
      when 1    =>  r := "0001";
      when 2    =>  r := "0010";
      when 4    =>  r := "0011";
      when 8    =>  r := "0100";
      when 16   =>  r := "0101";
      when 32   =>  r := "0110";
      when 64   =>  r := "0111";
      when others =>  r := "0000";
    end case;
  return r;
  end po2_to_slv4;

  function font_to_slv4(text_gen: boolean; height: integer; depth: integer) -- font info to std_logic_vector(3 downto 0)
    return std_logic_vector is
  variable r: std_logic_vector(3 downto 0);
  begin
    if text_gen AND height = 8 AND depth = 7 then
      r := "0010";
    elsif text_gen AND height = 8 AND depth = 8 then
      r := "0011";
    elsif text_gen AND height = 16 AND depth = 7 then
      r := "0100";
    elsif text_gen AND height = 16 AND depth = 8 then
      r := "0101";
    else
      r := "0000";
    end if;
  return r;
  end font_to_slv4;

  -- function integer ceiling log2
  -- returns how many bits are needed to represent a number of states
  -- example ceil_log2(255) = 8,  ceil_log2(256) = 8, ceil_log2(257) = 9
  function ceil_log2(x: integer)
    return integer is
  begin
    return integer(ceil((log2(real(x)+1.0E-6))-1.0E-6));
  end ceil_log2;

  -- useful constants
  constant total_width:       integer   := C_video_modes(C_vgatext_mode).h_front_porch + C_video_modes(C_vgatext_mode).h_sync_pulse +
                                            C_video_modes(C_vgatext_mode).h_back_porch + C_video_modes(C_vgatext_mode).visible_width;
  constant total_height:      integer   := C_video_modes(C_vgatext_mode).v_front_porch + C_video_modes(C_vgatext_mode).v_sync_pulse +
                                            C_video_modes(C_vgatext_mode).v_back_porch + C_video_modes(C_vgatext_mode).visible_height;
  constant visible_width:     integer   := C_video_modes(C_vgatext_mode).visible_width;
  constant visible_height:    integer   := C_video_modes(C_vgatext_mode).visible_height;

  constant char_width:        integer   := 8;
  constant bytes_per_char:    integer   := select_t_f(C_vgatext_monochrome, 1, 2);
  constant bytes_per_line:    integer   := (select_t_f(C_vgatext_finescroll, (4/bytes_per_char), 0)+(visible_width/char_width)) * bytes_per_char;
  constant font_size:         integer   := ((2**C_vgatext_font_depth) * C_vgatext_font_height)/1024;
  constant font_bits:         integer   := C_vgatext_font_depth + select_t_f(C_vgatext_font_height = 8, 3, 4);
  constant font_base_bit:     integer   := select_t_f(C_vgatext_font_bram8, 0, 2);

  -- this will calculate log2, number of bits that can address the pixel bit depth and fifo data
  constant C_vgatext_bitmap_depth_log2: integer := ceil_log2(C_vgatext_bitmap_depth);
  constant C_vgatext_bitmap_fifo_data_width_log2: integer := ceil_log2(C_vgatext_bitmap_fifo_data_width);
  constant C_vgatext_bitmap_strobe_point: signed(C_vgatext_bitmap_fifo_data_width_log2-C_vgatext_bitmap_depth_log2-1 downto 0) := (others => '1');

  -- constants for the VGA textmode register addresses (8 32-bit words)
  constant C_config_reg:      std_logic_vector  := "000";         -- 0xFFFFFB80
  constant C_config2_reg:     std_logic_vector  := "001";         -- 0xFFFFFB84
  constant C_cursor_reg:      std_logic_vector  := "010";         -- 0xFFFFFB88
  constant C_textaddr_reg:    std_logic_vector  := "011";         -- 0xFFFFFB8C
  constant C_bitmapaddr_reg:  std_logic_vector  := "100";         -- 0xFFFFFB90
  constant C_palette_reg:     std_logic_vector  := "101";         -- 0xFFFFFB94
  constant C_bramaddr_reg:    std_logic_vector  := "110";         -- 0xFFFFFB98
  constant C_bramdata_reg:    std_logic_vector  := "111";         -- 0xFFFFFB9C

  -- feature configure signals (effectively constants derived from generics)
  signal  bram_size:          std_logic_vector(3 downto 0)  := po2_to_slv4(C_vgatext_bram_mem);
  signal  font_info:          std_logic_vector(3 downto 0)  := font_to_slv4(C_vgatext_text, C_vgatext_font_height, C_vgatext_font_depth);
  signal  bm_depth:           std_logic_vector(3 downto 0)  := po2_to_slv4(C_vgatext_bitmap_depth);
  signal  vg_config:          std_logic                     := '1';
  signal  bg_config:          std_logic                     := bool_to_sl(C_vgatext_bitmap);
  signal  tg_config:          std_logic                     := bool_to_sl(C_vgatext_text);
  signal  tc_config:          std_logic                     := bool_to_sl(C_vgatext_cursor);
  signal  cb_config:          std_logic                     := bool_to_sl(C_vgatext_cursor_blink);
  signal  cp_config:          std_logic                     := bool_to_sl(C_vgatext_palette);
  signal  mt_config:          std_logic                     := bool_to_sl(C_vgatext_monochrome);
  signal  br_config:          std_logic                     := bool_to_sl(C_vgatext_reg_read);
  signal  fs_config:          std_logic                     := bool_to_sl(C_vgatext_finescroll);

  -- feature enable signals (constant '0' when feature not configured)
  signal  vg_enable:          std_logic   := '1';                 -- video generation
  signal  bg_enable:          std_logic   := '0';                 -- bitmap generation
  signal  tg_enable:          std_logic   := bool_to_sl(C_vgatext_text);  -- text generation
  signal  tc_enable:          std_logic   := bool_to_sl(C_vgatext_cursor);    -- text cursor generation
  signal  cb_enable:          std_logic   := bool_to_sl(C_vgatext_cursor_blink);  -- text cursor blink

  -- video generation signals
  signal  hcount:             signed(11 downto 0);                -- horizontal pixel counter (negative is off visible area)
  signal  shcount:            signed(11 downto 0);                -- scrolled horizontal pixel counter (negative is off visible area)
  signal  vcount:             signed(11 downto 0);                -- vertical pixel counter (negative is off visible area)
  signal  visible:            std_logic;                          -- 1 if in visible area
  signal  red:                std_logic_vector(7 downto 0);       -- red gun data
  signal  green:              std_logic_vector(7 downto 0);       -- green gun data
  signal  blue:               std_logic_vector(7 downto 0);       -- blue gun data
  signal  hsync:              std_logic;                          -- horizontal sync signal
  signal  vsync:              std_logic;                          -- vertical sync signal
  signal  vblank:             std_logic;                          -- true when outside of vertical visible area

  -- text generation signals
  signal  text_start_addr:    std_logic_vector(29 downto 2);      -- text start address
  signal  font_start_addr:    std_logic_vector(5 downto 0);       -- font base address (1K boundaries) address in BRAM
  signal  text_addr:          unsigned(29 downto 0);              -- address to fetch character+color attribute
  signal  text_line_addr:     unsigned(29 downto 0);              -- address to of start of character+color attribute line
  signal  char_y:             unsigned(4 downto 0);               -- current line of font cell
  signal  text_line:          unsigned(7 downto 0);               -- current text line
  signal  fine_scrollx:       unsigned(2 downto 0);               -- X fine scroll
  signal  fine_scrolly:       unsigned(3 downto 0);               -- Y fine scroll
  signal  font_data:          std_logic_vector(7 downto 0);       -- bit pattern shifting out for current font character line
  signal  font_data_next:     std_logic_vector(7 downto 0);       -- bit pattern for next font character line
  signal  mono_color:         std_logic_vector(7 downto 0) := x"1F"; -- background/foreground color for next character (or all characters)
  signal  text_color:         std_logic_vector(7 downto 0);       -- background/foreground color attribute for current character
  signal  text_color_next:    std_logic_vector(7 downto 0);       -- background/foreground color for next character (or all characters)

  -- text cursor generation signals
  signal  cursorx:            unsigned(7 downto 0);               -- cursor X position
  signal  cursory:            unsigned(7 downto 0);               -- cursor Y position
  signal  fcount:             unsigned(3 downto 0);               -- frame counter (incremented once per frame for blink)

  -- bitmap generation signals
  signal  bitmap_start_addr:  std_logic_vector(29 downto 2);  -- bitmap start address
  signal  bitmap_addr:        unsigned(29 downto 2);              -- current bitmap address
  signal  bitmap_color:       std_logic_vector(23 downto 0);      -- monochrome bitmap color register (xRRGGBB)
  signal  bitmap_data:        std_logic_vector(C_vgatext_bitmap_fifo_data_width-1 downto 0);      -- bit pattern shifting out for current bitmap word
  signal  bitmap_data_next:   std_logic_vector(31 downto 0);      -- bit pattern shifting out for current bitmap word
  signal  bitmap_strobe:      std_logic;                          -- request next bitmap word

  -- color palette
  type palette_t is array(0 to 15) of std_logic_vector(23 downto 0);
  signal palette_r: palette_t :=
  ( -- default VGA IRGB colors (x"RRGGBB")
    x"000000",    -- black
    x"0000AA",    -- blue
    x"00AA00",    -- green
    x"00AAAA",    -- cyan
    x"AA0000",    -- red
    x"AA00AA",    -- magenta
    x"AAAA00",    -- brown
    x"AAAAAA",    -- light gray
    x"555555",    -- dark gray
    x"5555FF",    -- light blue
    x"55FF55",    -- light green
    x"55FFFF",    -- light cyan
    x"FF5555",    -- light red
    x"FF55FF",    -- light magenta
    x"FFFF55",    -- yellow
    x"FFFFFF"     -- white
  );

  -- BRAM read register interface
  signal  bram_read_request:  std_logic;                      -- true when reg read requests for bram_read_addr to be read
  signal  bram_read_wait:     std_logic;                      -- true when waiting for bram read
  signal  bram_read_addr:     std_logic_vector(15 downto 2);  -- address to read
  signal  bram_read_value:    std_logic_vector(31 downto 0);  -- data read when wait goes to false

begin

  -- process to handle CPU register write requests
  reg_write: process(clk_i, reset_i)
  begin
    if C_vgatext_reset AND reset_i='1' then
      vg_enable <= '1';
      if C_vgatext_bitmap then
        bg_enable <= '0';
        bitmap_start_addr <= "00" & x"006000" & "00";
      end if;
      if C_vgatext_text then
        tg_enable <= '1';
        text_start_addr <= (others => '0');
        font_start_addr <= std_logic_vector(to_unsigned(C_vgatext_bram_mem - font_size, 6));
        if C_vgatext_cursor then
          tc_enable <= '1';
          cursorx <= (others => '0');
          cursory <= (others => '0');
          if C_vgatext_cursor_blink then
            cb_enable <= '1';
          end if;
        end if;
        if C_vgatext_monochrome then
          mono_color <= x"1F";
        end if;
        if C_vgatext_finescroll then
          fine_scrollx <= (others => '0');
          fine_scrolly <= (others => '0');
        end if;
      end if;
    elsif rising_edge(clk_i) then
      if C_vgatext_reg_read AND bram_read_request = '1' AND bram_read_wait = '1' then
        bram_read_request <= '0';
      end if;
      if ce_i = '1' and bus_write_i = '1' then
        case bus_addr_i is
--             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
-- Config:     |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
--             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
--             | BRAM mem size |Font size/type |VGC|BGC|TGC|TCC|CBC|CPC|MTC|BRC|VGE|BME|TME|TCE|CBE| - | - | - | Backgnd color | Foregnd color |
--             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
          when C_config_reg =>
            if C_vgatext_monochrome AND byte_sel_i(0) = '1' then
              mono_color <= bus_data_i(7 downto 0);
            end if;
            if byte_sel_i(1)='1' then
              vg_enable <= bus_data_i(15);
              if C_vgatext_bitmap then
                bg_enable <= bus_data_i(14);
              end if;
              if C_vgatext_text then
                tg_enable <= bus_data_i(13);
                if C_vgatext_cursor then
                  tc_enable <= bus_data_i(12);
                  if C_vgatext_cursor_blink then
                    cb_enable <= bus_data_i(11);
                  end if;
                end if;
              end if;
            end if;
  --             +---------------+-----------------------------------------------+---------------+-----------------------------------------------+
  -- Config2:    |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+-------------------------------+---------------+---------------+-------------------------------+
  -- (read)      |VBL|FSC|Y2 |X2 |              screen height                    |  Bitmap bpp   |                 screen width                  |
  -- (write)     | 0 | 0 |Y2 |X2 | 0   0   0   0   0   0   0   0   0   0   0   0 | 0   0   0   0 | 0   0   0   0   0   0   0   0   0   0   0   0 |
  --             +---------------+---------------+-------------------------------+---------------+---------------+-------------------------------+
          when C_config2_reg =>
            null;
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- Cursor:     |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+-----------------------+-------+-------------------------------+-------------------------------+
  -- (read)      |       text cell height        |   text font address   | 0   0 |       cursor Y position       |       cursor X position       |
  -- (write)     | Y fine scroll | X fine scroll |   text font address   | 0   0 |       cursor Y position       |       cursor X position       |
  --             +---------------+---------------+-----------------------+-------+-------------------------------+-------------------------------+
          when C_cursor_reg =>
            if C_vgatext_text AND C_vgatext_cursor AND byte_sel_i(0) = '1' then
              cursorx <= unsigned(bus_data_i(7 downto 0));
            end if;
            if C_vgatext_text AND C_vgatext_cursor AND byte_sel_i(1) = '1' then
              cursory <= unsigned(bus_data_i(15 downto 8));
            end if;
            if C_vgatext_text AND byte_sel_i(2) = '1' then
              font_start_addr <= bus_data_i(23 downto 18);
            end if;
            if C_vgatext_text AND C_vgatext_finescroll AND byte_sel_i(3) = '1' then
              fine_scrollx <= unsigned(bus_data_i(26 downto 24));
              fine_scrolly <= unsigned(bus_data_i(31 downto 28));
            end if;
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- TextAddr:   |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
  --             |MemTyp |                                                   TextAddr                                                    | 0   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
          when C_textaddr_reg =>
            if C_vgatext_text AND byte_sel_i = "1111" then
              text_start_addr(29 downto 2) <= bus_data_i(29 downto 2) ;
            end if;
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- BitmapAddr: |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
  --             |MemTyp |                                                   BitmapAddr                                                  | 0   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
          when C_bitmapaddr_reg =>
            if C_vgatext_text AND byte_sel_i = "1111" then
              bitmap_start_addr(29 downto 2) <= bus_data_i(29 downto 2);
            end if;
  --             +---------------+---------------+-------------------------------+-------------------------------+-------------------------------+
  -- SetPalette: |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---+-----------+---------------+-------------------------------+-------------------------------+-------------------------------+
  --             |BM | 0   0   0 |     index     |               red             |             green             |             blue              |
  --             +---+-----------+---------------+-------------------------------+-------------------------------+-------------------------------+
          when C_palette_reg =>
            if C_vgatext_palette AND byte_sel_i = "1111" AND bus_data_i(31) = '0' then
              palette_r(to_integer(unsigned(bus_data_i(27 downto 24))))(23 downto 24-C_vgatext_bits) <= bus_data_i(23 downto 24-C_vgatext_bits);
              palette_r(to_integer(unsigned(bus_data_i(27 downto 24))))(15 downto 16-C_vgatext_bits) <= bus_data_i(15 downto 16-C_vgatext_bits);
              palette_r(to_integer(unsigned(bus_data_i(27 downto 24))))(7 downto 8-C_vgatext_bits) <= bus_data_i(7 downto 8-C_vgatext_bits);
            end if;
            if C_vgatext_bitmap AND byte_sel_i = "1111" AND C_vgatext_bitmap_depth = 1 AND bus_data_i(31) = '1' then
              bitmap_color(23 downto 24-C_vgatext_bits) <= bus_data_i(23 downto 24-C_vgatext_bits);
              bitmap_color(15 downto 16-C_vgatext_bits) <= bus_data_i(15 downto 16-C_vgatext_bits);
              bitmap_color(7 downto 8-C_vgatext_bits) <= bus_data_i(7 downto 8-C_vgatext_bits);
            end if;
  --             +---+-----------+---------------+-------------------------------+-------------------------------+-----------------------+-------+
  -- BRAMAddr:   |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+-------------------------------+-------------------------------+-----------------------+---+---+
  -- (write)     | 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 |                           BRAMAddr                    | 0   0 |
  -- (read)      | 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 | 0   0   0   0   0   0   0   0   0   0   0   0   0   0 | 0 |WAI|
  --             +---------------+---------------+-------------------------------+-------------------------------+-----------------------+---+---+
          when C_bramaddr_reg =>
          if C_vgatext_reg_read AND byte_sel_i(1 downto 0) = "11" then
            bram_read_addr <= bus_data_i(15 downto 2);
            bram_read_request <= '1';
          end if;
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- handle CPU register read requests
  --             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
  -- Config:     |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
  --             | BRAM mem size |Font size/type |VGC|BGC|TGC|TCC|CBC|CPC|MTC|BRC|VGE|BME|TME|TCE|CBE| - | - | - | Backgnd color | Foregnd color |
  --             +---------------+---------------+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---------------+---------------+
     bus_data_o <= bram_size & font_info & vg_config & bg_config & tg_config & tc_config & cb_config & cp_config & mt_config & br_config &
          vg_enable & bg_enable & tg_enable & tc_enable & cb_enable & "000" & mono_color
      when bus_addr_i = C_config_reg
  --             +---------------+-----------------------------------------------+---------------+-----------------------------------------------+
  -- Config2:    |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---+---+---+---+-----------------------------------------------+---------------+-----------------------------------------------+
  -- (read)      |VBL|FSC|Y2 |X2 |              screen height                    |  Bitmap bpp   |                 screen width                  |
  -- (write)     | 0 | 0 |Y2 |X2 | 0   0   0   0   0   0   0   0   0   0   0   0 | 0   0   0   0 | 0   0   0   0   0   0   0   0   0   0   0   0 |
  --             +---+---+---+---+-----------------------------------------------+---------------+-----------------------------------------------+
    else vblank & fs_config & "00" & std_logic_vector(to_unsigned(visible_height,12)) & bm_depth & std_logic_vector(to_unsigned(visible_width,12))
      when bus_addr_i = C_config2_reg
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- Cursor:     |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+-----------------------+-------+-------------------------------+-------------------------------+
  -- (read)      |       text cell height        |   text font address   | 0   0 |       cursor Y position       |       cursor X position       |
  -- (write)     | Y fine scroll | X fine scroll |   text font address   | 0   0 |       cursor Y position       |       cursor X position       |
  --             +---------------+---------------+-----------------------+-------+-------------------------------+-------------------------------+
    else std_logic_vector(to_unsigned(C_vgatext_char_height,8)) & font_start_addr & "00" & std_logic_vector(cursory) & std_logic_vector(cursorx)
      when C_vgatext_text AND bus_addr_i = C_cursor_reg
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- TextAddr:   |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
  --             |MemTyp |                                                   TextAddr                                                    | 0   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
    else bool_to_sl(C_vgatext_text_fifo) & bool_to_sl(NOT C_vgatext_text_fifo) & text_start_addr(29 downto 2) & "00"
      when C_vgatext_text AND bus_addr_i = C_textaddr_reg
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- BitmapAddr: |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
  --             |MemTyp |                                                   BitmapAddr                                                  | 0   0 |
  --             +-------+-----------------------+-------------------------------+-------------------------------+-----------------------+-------+
    else "10" & bitmap_start_addr(29 downto 2) & "00"
      when C_vgatext_bitmap AND bus_addr_i = C_bitmapaddr_reg
  --             +---+-----------+---------------+-------------------------------+-------------------------------+-----------------------+-------+
  -- BRAMAddr:   |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +---------------+---------------+-------------------------------+-------------------------------+-----------------------+---+---+
  -- (write)     | 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 |                           BRAMAddr                    | 0   0 |
  -- (read)      | 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 | 0   0   0   0   0   0   0   0   0   0   0   0   0   0 | 0 |WAI|
  --             +---------------+---------------+-------------------------------+-------------------------------+-----------------------+---+---+
    else x"0000000" & "000" & (bram_read_wait OR bram_read_request)
      when C_vgatext_reg_read AND bus_addr_i = C_bramaddr_reg
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  -- BRAMData:   |31  30  29  28  27  26  25  24 |23  22  21  20  19  18  17  16 |15  14  13  12  11  10   9   8 | 7   6   5   4   3   2   1   0 |
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
  --             |                                                           BRAMData                                                            |
  --             +-------------------------------+-------------------------------+-------------------------------+-------------------------------+
    else bram_read_value
      when C_vgatext_reg_read AND bus_addr_i = C_bramdata_reg
    else (others => '0');

  -- display generation process
  display_proc: process(clk_pixel_i)
    variable fontpix: std_logic;
    variable forecolor: std_logic_vector(3 downto 0);
    variable backcolor: std_logic_vector(3 downto 0);
    variable mem_data: std_logic_vector(31 downto 0);
    variable char_data: std_logic_vector(7 downto 0);
    variable color_data: std_logic_vector(7 downto 0);
    variable byte_sel_i: std_logic_vector(1 downto 0);
    variable bitmap_pix: std_logic_vector(C_vgatext_bitmap_depth-1 downto 0);
  begin
    if rising_edge(clk_pixel_i) then
      if vg_enable = '1' then
        -- timing generation
        if hcount = (visible_width-1) then        -- are we at the end of a horizontal line?
          hcount <= to_signed(visible_width-total_width, hcount'length);   -- yes, reset hcount
          if C_vgatext_finescroll then
            shcount <= to_signed(visible_width-total_width, shcount'length) + to_signed(to_integer(fine_scrollx), shcount'length);
          end if;
          if vcount = (visible_height-1) then     -- are we at the bottom of the frame also?
            vcount <= to_signed(visible_height-total_height, vcount'length); -- yes, reset vcount
            if C_vgatext_text AND C_vgatext_cursor AND C_vgatext_cursor_blink then
              fcount <= fcount + 1;       -- increment fcount frame counter
            end if;
          else
            vcount <= vcount + 1;         -- increment vcount line counter
          end if;
        else
          hcount <= hcount + 1;           -- increment hcount pixel counter
          if C_vgatext_finescroll then
            shcount <= shcount + 1;
          end if;
        end if;

        -- if hcount is in the proper range, generate hsync output
        if hcount >= -(C_video_modes(C_vgatext_mode).h_back_porch+C_video_modes(C_vgatext_mode).h_sync_pulse) and hcount < -C_video_modes(C_vgatext_mode).h_back_porch then
          hsync <= C_video_modes(C_vgatext_mode).h_sync_polarity;
        else
          hsync <= NOT C_video_modes(C_vgatext_mode).h_sync_polarity;
        end if;

        -- if vcount is in the proper range, generate vsync output
        if vcount >= -(C_video_modes(C_vgatext_mode).v_back_porch+C_video_modes(C_vgatext_mode).v_sync_pulse) and vcount < -C_video_modes(C_vgatext_mode).v_back_porch then
          vsync <= C_video_modes(C_vgatext_mode).v_sync_polarity;
        else
          vsync <= NOT C_video_modes(C_vgatext_mode).v_sync_polarity;
        end if;

        -- set visible flag
        if hcount >= 0 AND vcount >= 0 then
          visible <= '1';
        else
          visible <= '0';
        end if;

        -- default black (e.g., for any remaining scan-lines after last text line)
        red <= (others => '0');
        green <= (others => '0');
        blue <= (others => '0');

        font_data <= font_data(6 downto 0) & "0";   -- shift font pixel data left (7 is new pixel)

        -- default strobe lines low
        if C_vgatext_text_fifo then
          textfifo_strobe_o <= '0';
          textfifo_rewind_o <= '0';
        end if;
        -- emard
        -- trying to avoid such default signal settings
        -- currently I removed this for special case
        -- when fifo width equals pixel depth in order
        -- not to break other code, in future
        -- bitmap_strobe <= '0'; should be removed
        if C_vgatext_bitmap_fifo_data_width /= C_vgatext_bitmap_depth then
          if C_vgatext_bitmap then
            bitmap_strobe <= '0';
          end if;
        end if;

        -- handle BRAM register based reads
        if C_vgatext_reg_read then
          if bram_read_wait = '1' then
            bram_read_value <= bram_data_i;
            bram_read_wait <= '0';
          elsif (vcount < 0 OR shcount(2) = '0') AND bram_read_request = '1' then
            bram_addr_o <= bram_read_addr;
            bram_read_wait <= '1';
          end if;
        end if;

        if vcount >= 0 then           -- if on a visible scan-line
          -- text character generation
          if tg_enable = '0' then
            font_data <= (others => '0');
            text_color <= (others => '0');
          end if;
          if tg_enable = '1' AND shcount >= -8 AND vcount < ((visible_height/C_vgatext_char_height)*C_vgatext_char_height) then
            case shcount(2 downto 0) is
              when "100" =>             -- put text address on bus (if not using text FIFO)
                if NOT C_vgatext_text_fifo then
                bram_addr_o   <= std_logic_vector(text_addr(15 downto 2));
                end if;
              when "101" =>             -- get word of text (and color attribute) data
                char_data := (others => '0');
                if C_vgatext_text_fifo then
                  mem_data := textfifo_data_i;
                else
                  mem_data := bram_data_i;
                end if;
                if C_vgatext_monochrome then
                  case text_addr(1 downto 0) is  -- extract proper byte for char (no color byte)
                    when "00" =>  char_data(C_vgatext_font_depth-1 downto 0) := mem_data( 0+C_vgatext_font_depth-1 downto 0);
                    when "01" =>  char_data(C_vgatext_font_depth-1 downto 0) := mem_data( 8+C_vgatext_font_depth-1 downto 8);
                    when "10" =>  char_data(C_vgatext_font_depth-1 downto 0) := mem_data(16+C_vgatext_font_depth-1 downto 16);
                    when "11" =>  char_data(C_vgatext_font_depth-1 downto 0) := mem_data(24+C_vgatext_font_depth-1 downto 24);
                      if C_vgatext_text_fifo then
                        textfifo_strobe_o <= '1';
                      end if;
                    when others => null;
                  end case;
                else
                  case text_addr(1) is     -- extract proper word with low byte for char, high byte for color
                    when '0' => char_data(C_vgatext_font_depth-1 downto 0) := mem_data( 0+C_vgatext_font_depth-1 downto 0);
                                text_color_next <= mem_data(15 downto 8);
                    when '1' => char_data(C_vgatext_font_depth-1 downto 0) := mem_data(16+C_vgatext_font_depth-1 downto 16);
                                text_color_next <= mem_data(31 downto 24);
                      if C_vgatext_text_fifo then
                        textfifo_strobe_o <= '1';
                      end if;
                    when others => null;
                  end case;
                end if;
                -- put font data address on BRAM bus (using variables so same cycle as is read)
                if C_vgatext_font_bram8 then
                  bram_addr_o(15 downto 10) <= "100000";  -- bit 15 indicates 8-bit font BRAM (if C_vgatext_font_bram8)
                else
                  bram_addr_o(15 downto 10) <= font_start_addr;
                end if;
                if C_vgatext_font_height = 8 then
                  if C_vgatext_font_bram8 then
                    bram_addr_o(C_vgatext_font_depth+4 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & std_logic_vector(char_y(select_t_f(C_vgatext_font_linedouble, 3, 2) downto select_t_f(C_vgatext_font_linedouble, 1, 0)));
                  else
                    bram_addr_o(C_vgatext_font_depth+2 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & char_y(select_t_f(C_vgatext_font_linedouble, 3, 2));
                  end if;
                else
                  if char_y < C_vgatext_font_height then
                    if C_vgatext_font_bram8 then
                      bram_addr_o(C_vgatext_font_depth+5 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & std_logic_vector(char_y(3 downto 0));
                    else
                      bram_addr_o(C_vgatext_font_depth+3 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & std_logic_vector(char_y(3 downto 2));
                    end if;
                  else
                    if C_vgatext_font_bram8 then
                      bram_addr_o(C_vgatext_font_depth+5 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & "1111";
                    else
                      bram_addr_o(C_vgatext_font_depth+3 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & "11";
                    end if;
                  end if;
                end if;
              when "110" =>               -- extract proper byte of font data from word read from BRAM
                if char_y < select_t_f(C_vgatext_font_linedouble, C_vgatext_font_height*2, C_vgatext_font_height) then
                  if C_vgatext_font_bram8 then
                    font_data_next <= bram_data_i(7 downto  0);
                  else
                    case char_y(select_t_f(C_vgatext_font_linedouble, 2, 1) downto select_t_f(C_vgatext_font_linedouble, 1, 0)) is
                      when "00" => font_data_next <= bram_data_i( 7 downto  0);
                      when "01" => font_data_next <= bram_data_i(15 downto  8);
                      when "10" => font_data_next <= bram_data_i(23 downto 16);
                      when "11" => font_data_next <= bram_data_i(31 downto 24);
                      when others => null;
                    end case;
                  end if;
                else
                  if C_vgatext_font_height = 8 then
                    font_data_next <= (others => '0');          -- use blank between characters
                  else
                    if C_vgatext_font_bram8 then
                      font_data_next <= bram_data_i(7 downto 0);  -- repeat last line of character
                    else
                      font_data_next <= bram_data_i(31 downto 24);  -- repeat last line of character
                    end if;
                  end if;
                end if;

              when "111" =>               -- switch to new character data for next pixel
                font_data <= font_data_next;                   -- use next font data byte
                text_color <= text_color_next;                 -- use next font color byte (screen color if monochrome)
                if shcount = visible_width-1 then              -- if last pixel of scan-line
                  if char_y = C_vgatext_char_height-1 then     -- if last line of char cell
                    char_y <= (others => '0');                 -- reset font line
                    if C_vgatext_cursor then
                      text_line <= text_line + 1;              -- update text line (if cursor configured)
                    end if;
                    if C_vgatext_text_fifo AND C_vgatext_finescroll then
                      textfifo_strobe_o <= '1';                -- consume extra word when scrolling
                    end if;
                    text_line_addr <= text_line_addr + bytes_per_line; -- back to line start address
                    text_addr <= text_line_addr + bytes_per_line; -- back to line start address
                  else
                    char_y <= char_y + 1;                      -- next char cell line
                    if C_vgatext_text_fifo then
                      textfifo_rewind_o <= '1';                -- rewind FIFO to reuse data for text line
                    end if;
                    text_addr <= text_line_addr;               -- back to line start address
                  end if;
                else
                  text_addr <= text_addr + bytes_per_char;     -- next char+attribute on line
                end if;
              when others => null;
            end case;
          end if;

          -- bitmap generation
          bitmap_pix := (others => '0');
          if C_vgatext_bitmap_fifo_data_width = C_vgatext_bitmap_depth then
            -- special case: fifo width equal to pixel width
            if bg_enable = '1' then
              bitmap_pix := bitmap_data_i;
              if hcount = -2 and vcount >= 0 then
                bitmap_strobe <= '1';
              end if;
              if hcount = visible_width-2 then
                bitmap_strobe <= '0';
              end if;
            end if; --. bg_enable
          else
            -- fifo width different than pixel depth
            if bg_enable = '1' then
              bitmap_pix := bitmap_data(C_vgatext_bitmap_depth-1 downto 0);
              -- shift current bitmap data right
              bitmap_data(C_vgatext_bitmap_fifo_data_width-1-C_vgatext_bitmap_depth downto 0) 
               <= bitmap_data(C_vgatext_bitmap_fifo_data_width-1 downto C_vgatext_bitmap_depth);
              if NOT C_vgatext_bitmap_fifo then
                if hcount = -64 AND vcount = 0 then -- fetch first word early from SRAM
                  bitmap_strobe <= '1';
                end if;
              end if;
              if hcount >= -1 AND hcount < visible_width-1 then -- one cycle before needed
                if hcount(C_vgatext_bitmap_fifo_data_width_log2-C_vgatext_bitmap_depth_log2-1 downto 0)
                    = C_vgatext_bitmap_strobe_point
                then
                  -- load new bitmap data at last pixel of current bitmap data
                  bitmap_strobe <= '1';
                  if C_vgatext_bitmap_fifo then
                    bitmap_data <= bitmap_data_i;
                  else
                    bitmap_data <= bitmap_data_next;
                    bitmap_addr <= bitmap_addr + 1;
                  end if;
                end if;
              end if;
            end if; -- bg_enable
          end if; -- end fifo width different than pixel depth

          -- prepare to output pixel
          fontpix := font_data(7);                -- current pixel from font
          backcolor := text_color(7 downto 4);    -- current foreground color for character
          forecolor := text_color(3 downto 0);    -- current background color for character

          -- text cursor check
          if tg_enable = '1' AND tc_enable = '1' AND cursorx = unsigned(hcount(10 downto 3)) AND cursory = text_line AND (cb_enable = '0' OR fcount(3) = '1') then
            fontpix := NOT fontpix;           -- invert cursor pixel
          end if;

          -- text output
          if tg_enable = '1' AND fontpix = '1' then
            -- font foreground color
            if C_vgatext_palette then                       -- 4-bpp 16-color palletized
              red   <= palette_r(to_integer(unsigned(forecolor)))(23 downto 16);
              green <= palette_r(to_integer(unsigned(forecolor)))(15 downto 8);
              blue  <= palette_r(to_integer(unsigned(forecolor)))(7 downto 0);
            else                                            -- 4-bpp 16-color IRGB
              red   <= forecolor(2) & forecolor(3) & forecolor(2) & forecolor(3) & forecolor(2) & forecolor(3) & forecolor(2) & forecolor(3);
              green <= forecolor(1) & forecolor(3) & forecolor(1) & forecolor(3) & forecolor(1) & forecolor(3) & forecolor(1) & forecolor(3);
              blue  <= forecolor(0) & forecolor(3) & forecolor(0) & forecolor(3) & forecolor(0) & forecolor(3) & forecolor(0) & forecolor(3);
            end if;
          else  -- font background color
            if C_vgatext_palette then
              red   <= palette_r(to_integer(unsigned(backcolor)))(23 downto 16);
              green <= palette_r(to_integer(unsigned(backcolor)))(15 downto 8);
              blue  <= palette_r(to_integer(unsigned(backcolor)))(7 downto 0);
            else
              red   <= backcolor(2) & backcolor(3) & backcolor(2) & backcolor(3) & backcolor(2) & backcolor(3) & backcolor(2) & backcolor(3);
              green <= backcolor(1) & backcolor(3) & backcolor(1) & backcolor(3) & backcolor(1) & backcolor(3) & backcolor(1) & backcolor(3);
              blue  <= backcolor(0) & backcolor(3) & backcolor(0) & backcolor(3) & backcolor(0) & backcolor(3) & backcolor(0) & backcolor(3);
            end if;
          end if;
          -- bitmap output
          if bg_enable = '1' AND fontpix = '0' AND unsigned(bitmap_pix) /= 0 then
            if C_vgatext_bitmap_depth = 8 then              -- 8-bpp 256-color direct RRR GGG BB
              red   <= bitmap_pix(7 downto 5) & bitmap_pix(7 downto 5) & bitmap_pix(7 downto 6);
              green <= bitmap_pix(4 downto 2) & bitmap_pix(4 downto 2) & bitmap_pix(4 downto 3);
              blue  <= bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0);
            elsif C_vgatext_bitmap_depth = 4 then
              if C_vgatext_palette then                     -- 4-bpp 16 color palletized
                red   <= palette_r(to_integer(unsigned(bitmap_pix)))(23 downto 16);
                green <= palette_r(to_integer(unsigned(bitmap_pix)))(15 downto 8);
                blue  <= palette_r(to_integer(unsigned(bitmap_pix)))(7 downto 0);
              else                                          -- 4-bpp 16 color IRGB
                red   <= bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3);
                green <= bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3);
                blue  <= bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3);
              end if;
            elsif C_vgatext_bitmap_depth = 2 then
              if C_vgatext_palette then                     -- 2-bpp 4-color palletized
                red   <= palette_r(to_integer(unsigned(bitmap_pix)))(23 downto 16);
                green <= palette_r(to_integer(unsigned(bitmap_pix)))(15 downto 8);
                blue  <= palette_r(to_integer(unsigned(bitmap_pix)))(7 downto 0);
              else                                          -- 2-bpp 4-color fixed black, blue, red, white
                if bitmap_pix(1) = '1'  then red   <= x"ff"; end if;
                if bitmap_pix    = "11" then green <= x"ff"; end if;
                if bitmap_pix(0) =  '1' then blue  <= x"ff"; end if;
              end if;
            else                                            -- 1-bpp monochrome bitmap color register
              red   <= bitmap_color(23 downto 16);
              green <= bitmap_color(15 downto 8);
              blue  <= bitmap_color(7 downto 0);
            end if;
          end if;
        else                                                -- non-visible scan-line, reset signals
          if C_vgatext_text then
            char_y <= "0" & fine_scrolly;                   -- start next frame at Y fine scroll line in char
            if C_vgatext_cursor then
              text_line <= (others => '0');                 -- start at text line 0 (only needed for cursor)
            end if;
            if C_vgatext_monochrome then
              text_color_next <= mono_color;
            end if;
            font_data <= (others => '0');                   -- make sure data cleared for next frame
            text_addr <= unsigned(text_start_addr(29 downto 2)) & "00";  -- reset to start of text data
            text_line_addr  <= unsigned(text_start_addr(29 downto 2)) & "00";  -- reset to start of text data
          end if;
          if C_vgatext_bitmap then
            bitmap_data <= (others => '0');                 -- make sure data cleared for next frame
            bitmap_addr <= unsigned(bitmap_start_addr(29 downto 2));  -- reset to start of bitmap data for SRAM
          end if;
        end if;
      end if;
    end if;
  end process;

  -- process for SRAM bitmap memory port
  G_bitmap_sram: if C_vgatext_bitmap AND NOT C_vgatext_bitmap_fifo generate
    bitmap_proc: process(clk_i)
    begin
      if rising_edge(clk_i) then
        if bitmap_ready_i = '1' then
          bitmap_data_next <= bitmap_data_i;  -- save new data (for next word)
          bitmap_strobe_o <= '0';
        elsif bitmap_strobe = '1' then
          bitmap_strobe_o <= '1';
        end if;
      end if;
    end process;
    bitmap_addr_o <= std_logic_vector(bitmap_addr);  -- output SRAM address for bitmap word
  end generate;

  -- text FIFO output
  G_text_fifo: if C_vgatext_text AND C_vgatext_text_fifo generate
    textfifo_addr_o <= text_start_addr(29 downto 2);             -- output SDRAM FIFO start address
  end generate;

  -- bitmap FIFO outputs
  G_bitmap_fifo: if C_vgatext_bitmap AND C_vgatext_bitmap_fifo generate
    bitmap_addr_o <= bitmap_start_addr(29 downto 2);          -- output SDRAM bitmap FIFO start address
    bitmap_strobe_o <= bitmap_strobe;
  end generate;

  -- no fine scroll
  G_no_fine_scroll: if NOT C_vgatext_finescroll generate
  shcount <= hcount;
  end generate;

  -- vertical blank indicator
  vblank  <= '1' when vcount < 0 else '0';
  text_active_o <= '0' when vcount < 0 else tg_enable;
  -- bitmap_active_o activates compositing_fifo early
  -- 3 scan ahead of time to start fetching
  -- to prepare line data on time
  bitmap_active_o <= '0' when vcount < -3 else bg_enable;

  -- output VGA/DVI/HDMI signals
  hsync_o <= hsync;
  vsync_o <= vsync;
  blank_o <= NOT visible;
  red_o   <= red(7 downto 8-C_vgatext_bits) when visible = '1' else (others => '0');
  green_o <= green(7 downto 8-C_vgatext_bits) when visible = '1' else (others => '0');
  blue_o  <= blue(7 downto 8-C_vgatext_bits) when visible = '1' else (others => '0');

end Behavioral;
