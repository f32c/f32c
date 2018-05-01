--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- LICENSE=BSD
--
-- Generates VGA picture from sequential bitmap data from pixel clock
-- synchronous FIFO.

-- the pixel data in *_byte registers
-- should be present ahead of time

-- signal 'fetch_next' is set high for 1 clk_pixel
-- period as soon as current pixel data is consumed
-- fifo should be fast enough to fetch new data for
-- new pixel

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all; -- to calculate log2 bit size
--use work.f32c_pack.all;

entity vga is
  generic(
    C_resolution_x: integer := 640;
    C_hsync_front_porch: integer := 16;
    C_hsync_pulse: integer := 96;
    C_hsync_back_porch: integer := 44; -- 48
    C_resolution_y: integer := 480;
    C_vsync_front_porch: integer := 10;
    C_vsync_pulse: integer := 2;
    C_vsync_back_porch: integer := 31; -- 33
    C_dbl_x: integer := 0;  -- 0-normal X, 1-double X
    C_dbl_y: integer := 0   -- 0-normal X, 1-double X
  );
  port
  (
    clk_pixel: in std_logic;  -- pixel clock, 25 MHz for 640x480
    test_picture: in std_logic := '0'; -- show test picture
    fetch_next: out std_logic; -- request FIFO to fetch next pixel data
    line_repeat: out std_logic; -- request FIFO to repeat previous scan line content (used in y-doublescan)
    --beam_x: out std_logic_vector(9 downto 0);
    --beam_y: out std_logic_vector(9 downto 0);
    red_byte, green_byte, blue_byte: in std_logic_vector(7 downto 0); -- pixel data from FIFO
    vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0); -- 8-bit VGA video signal out
    vga_hsync, vga_vsync: out std_logic; -- VGA sync
    vga_vblank, vga_blank: out std_logic -- V blank for CPU interrupts and H+V blank for digital encoder (HDMI)
  );
end vga;

architecture syn of vga is
    -- function integer ceiling log2
    -- returns how many bits are needed to represent a number of states
    -- example ceil_log2(255) = 8,  ceil_log2(256) = 8, ceil_log2(257) = 9
    function ceil_log2(x: integer) return integer is
    begin
      return integer(ceil((log2(real(x)+1.0E-6))-1.0E-6));
    end ceil_log2;

  constant C_frame_x: integer := C_resolution_x + C_hsync_front_porch + C_hsync_pulse + C_hsync_back_porch;
    -- frame_x = 640 + 16 + 96 + 48 = 800;
  constant C_frame_y: integer := C_resolution_y + C_vsync_front_porch + C_vsync_pulse + C_vsync_back_porch;
    -- frame_y = 480 + 10 + 2 + 33 = 525;
    -- refresh_rate = pixel_clock/(frame_x*frame_y) = 25MHz / (800*525) = 59.52Hz
  constant C_synclen: integer := 3; -- >=2, bit length of the clock synchronizer shift register
  signal CounterX: std_logic_vector(ceil_log2(C_frame_x-1)-1 downto 0); -- (9 downto 0) is good for up to 1023 frame timing width (resolution 640x480)
  signal CounterY: std_logic_vector(ceil_log2(C_frame_y-1)-1 downto 0); -- (9 downto 0) is good for up to 1023 frame timing width (resolution 640x480)
  signal hSync, vSync, vBlank, DrawArea, fetcharea: std_logic;
  signal clksync: std_logic_vector(C_synclen-1 downto 0); -- fifo to clock synchronizer shift register
  signal shift_red, shift_green, shift_blue: std_logic_vector(7 downto 0); -- RENAME shift_ -> latch_
  -- test picture generation
  signal W, A, T, test_red, test_green, test_blue: std_logic_vector(7 downto 0);
  signal Z: std_logic_vector(5 downto 0);
begin
  -- wire fetcharea; // when to fetch data, must be 1 byte earlier than draw area
  fetcharea <= '1' when CounterX < C_resolution_x and CounterY < C_resolution_y else '0';
  -- output request to fetch new data every pixel
  fetch_next <= fetcharea;
  -- increment and wraparound X and Y counters
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      -- DrawArea is fetcharea delayed one clock later
      DrawArea <= fetcharea;
      -- on end of each X line, reset CounterX
      -- and increment Y counter, also reset Y at bottom of screen
      if CounterX = C_frame_x - 1 then
        CounterX <= (others => '0');
        if CounterY = C_frame_y - 1 then
          CounterY <= (others => '0');
        else
          CounterY <= CounterY + 1;
        end if;
      else
        CounterX <= CounterX + 1;
      end if;
    end if;
  end process;
  
  --beam_x <= CounterX;
  --beam_y <= CounterY;

  vga_blank <= not DrawArea;
  -- Sync and VBlank generation
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      if CounterX = C_resolution_x + C_hsync_front_porch then
        hSync <= '1';
      end if;
      if CounterX = C_resolution_x + C_hsync_front_porch + C_hsync_pulse then
        hSync <= '0';
      end if;
      if CounterY = C_resolution_y then
        vBlank <= '1';
      end if;
      if CounterY = C_resolution_y + C_vsync_front_porch then
        vSync <= '1';
      end if;
      if CounterY = C_resolution_y + C_vsync_front_porch + C_vsync_pulse then
        vSync <= '0';
        vBlank <= '0';
      end if;
    end if;
  end process;
  vga_hsync <= hSync;
  vga_vsync <= vSync;
  vga_vblank <= vBlank;
  line_repeat <= '0' when C_dbl_y = 0 else hSync and not CounterY(0);

  -- test picture generator
  A <= (others => '1') when CounterX(7 downto 5) = "010" and CounterY(7 downto 5) = "010" else (others => '0');
  W <= (others => '1') when CounterX(7 downto 0) = CounterY(7 downto 0) else (others => '0');
  Z <= (others => '1') when CounterY(4 downto 3) = not CounterX(4 downto 3) else (others => '0');
  T <= (others => CounterY(6));
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      test_red   <= (((CounterX(5 downto 0) and Z) & "00") or W) and not A;
      test_green <= ((CounterX(7 downto 0) and T) or W) and not A;
      test_blue  <= CounterY(7 downto 0) or W or A;
    end if;
  end process;  
  
  -- output multiplexer: bitmap graphics or test picture
  vga_r <= (others => '0') when DrawArea = '0' else red_byte   when test_picture='0' else test_red;
  vga_g <= (others => '0') when DrawArea = '0' else green_byte when test_picture='0' else test_green;
  vga_b <= (others => '0') when DrawArea = '0' else blue_byte  when test_picture='0' else test_blue;

end syn;
