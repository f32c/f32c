-- (c) EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;

package video_mode_pack is

-- timings for popular video modes:

-- 0: 640x480
-- 1: 800x600
-- 2: 1024x768

type T_video_mode is
record
    pixel_clock_Hz:                             integer; -- currently informational (not used)
    visible_width,  visible_height:             integer;
    h_front_porch, h_sync_pulse, h_back_porch:  integer;
    v_front_porch, v_sync_pulse, v_back_porch:  integer;
    h_sync_polarity, v_sync_polarity:           std_logic;
end record;

type T_video_modes is array (0 to 3) of T_video_mode;

constant C_video_modes: T_video_modes :=
  (
    ( -- mode 0: 640x480 @ 60Hz
      pixel_clock_Hz  =>  25000000, -- technically 25,175,000Hz, but 25Mhz is close enough
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
    ( -- mode 1: 800x600 @ 60Hz
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
    (-- mode 2: 1024x768 @ 60Hz  (clk_pixel 65.00MHz - good luck!)
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
    (-- mode 3: 1280x1024 @ 60Hz  (clk_pixel 108.00MHz - good luck xilinx 7-series)
      pixel_clock_Hz  =>  108000000,
      visible_width   =>  1280,
      visible_height  =>  1024,
      h_front_porch   =>  48,
      h_sync_pulse    =>  112,
      h_back_porch    =>  248,
      v_front_porch   =>  1,
      v_sync_pulse    =>  3,
      v_back_porch    =>  38,
      h_sync_polarity =>  '0',
      v_sync_polarity =>  '0'
    )
  );

end package;
