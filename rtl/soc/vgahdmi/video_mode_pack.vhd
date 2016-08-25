-- (c) EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;

package video_mode_pack is

-- timings for popular video modes:
-- even modes: 16:9
-- odd modes:   4:3

-- 0: 640x360 16:9
-- 1: 640x480 4:3
-- 2: 800x450 16:9
-- 3: 800x600 4:3
-- 4: 1024x576 16:9
-- 5: 1024x768 4:3
-- 6: 1280x768 16:9
-- 7: 1280x1024 4:3

-- see also:
-- http://tinyvga.com/vga-timing
-- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf

type T_video_mode is
record
    pixel_clock_Hz:                             integer; -- currently informational (not used)
    visible_width,  visible_height:             integer;
    h_front_porch, h_sync_pulse, h_back_porch:  integer;
    v_front_porch, v_sync_pulse, v_back_porch:  integer;
    h_sync_polarity, v_sync_polarity:           std_logic; -- '0':negative/falling-edge, '1':positive/rising-edge
end record;

type T_video_modes is array (0 to 7) of T_video_mode;

constant C_video_modes: T_video_modes :=
  (
    ( -- mode 0: 640x360 @ 70Hz
      pixel_clock_Hz  =>  25175000, -- 25 MHz works
      visible_width   =>  640,
      visible_height  =>  360,
      h_front_porch   =>  16,
      h_sync_pulse    =>  96,
      h_back_porch    =>  48,
      v_front_porch   =>  37,
      v_sync_pulse    =>  2,
      v_back_porch    =>  60,
      h_sync_polarity =>  '1',
      v_sync_polarity =>  '0'
    ),
    ( -- mode 1: 640x480 @ 60Hz
      pixel_clock_Hz  =>  25175000, -- 25 MHz works
      visible_width   =>  640,
      visible_height  =>  480,
      h_front_porch   =>  16,
      h_sync_pulse    =>  96,
      h_back_porch    =>  48,
      v_front_porch   =>  10,
      v_sync_pulse    =>  2,
      v_back_porch    =>  33,
      h_sync_polarity =>  '0',
      v_sync_polarity =>  '0'
    ),
    ( -- mode 2: 800x480 @ 60 Hz
      pixel_clock_Hz  =>  29892000, -- 30 MHz works
      visible_width   =>  800,
      visible_height  =>  480,
      h_front_porch   =>  16,
      h_sync_pulse    =>  80,
      h_back_porch    =>  96,
      v_front_porch   =>  1,
      v_sync_pulse    =>  3,
      v_back_porch    =>  13,
      h_sync_polarity =>  '1',
      v_sync_polarity =>  '1'
    ),
    ( -- mode 3: 800x600 @ 60Hz
      pixel_clock_Hz  =>  40000000,
      visible_width   =>  800,
      visible_height  =>  600,
      h_front_porch   =>  40,
      h_sync_pulse    =>  128,
      h_back_porch    =>  88,
      v_front_porch   =>  1,
      v_sync_pulse    =>  4,
      v_back_porch    =>  23,
      h_sync_polarity =>  '1',
      v_sync_polarity =>  '1'
    ),
    ( -- mode 4: 1024x576 @ 64Hz
      pixel_clock_Hz  =>  50000000,
      visible_width   =>  1024,
      visible_height  =>  576,
      h_front_porch   =>  16,
      h_sync_pulse    =>  132,
      h_back_porch    =>  128,
      v_front_porch   =>  3,
      v_sync_pulse    =>  6,
      v_back_porch    =>  12,
      h_sync_polarity =>  '0',
      v_sync_polarity =>  '0'
    ),
    ( -- mode 5: 1024x768 @ 60Hz
      pixel_clock_Hz  =>  65000000,
      visible_width   =>  1024,
      visible_height  =>  768,
      h_front_porch   =>  24,
      h_sync_pulse    =>  136,
      h_back_porch    =>  160,
      v_front_porch   =>  3,
      v_sync_pulse    =>  6,
      v_back_porch    =>  29,
      h_sync_polarity =>  '0',
      v_sync_polarity =>  '0'
    ),
    ( -- mode 6: 1280x768 @ 60Hz
      pixel_clock_Hz  =>  74500000, -- 75 MHz works
      visible_width   =>  1280,
      visible_height  =>  768,
      h_front_porch   =>  64,
      h_sync_pulse    =>  192,
      h_back_porch    =>  192,
      v_front_porch   =>  3,
      v_sync_pulse    =>  5,
      v_back_porch    =>  20,
      h_sync_polarity =>  '0',
      v_sync_polarity =>  '1'
    ),
    ( -- mode 7: 1280x1024 @ 60Hz  (clk_pixel 108.00MHz - good luck xilinx 7-series)
      pixel_clock_Hz  =>  108000000,
      visible_width   =>  1280,
      visible_height  =>  1024,
      h_front_porch   =>  48,
      h_sync_pulse    =>  112,
      h_back_porch    =>  248,
      v_front_porch   =>  1,
      v_sync_pulse    =>  3,
      v_back_porch    =>  38,
      h_sync_polarity =>  '1',
      v_sync_polarity =>  '1'
    )
  );

end package;
