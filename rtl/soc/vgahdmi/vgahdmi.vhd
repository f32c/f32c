--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- LICENSE=BSD
--
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.f32c_pack.all;

-- vhdl wrapper for verilog module

entity vgahdmi is
  generic(
    dbl_x          : integer := 0;  -- 0-normal X, 1-double X
    dbl_y          : integer := 0;  -- 0-normal X, 1-double X
    visible_y      : integer := 480;-- visible y (vertical size)
    test_picture   : integer := 0   -- 0-don't, 1-show some test picture
  );
  port
  (
    clk_pixel  : in std_logic;  -- pixel clock, 25 MHz
    clk_tmds   : in std_logic := '0'; -- hdmi clock 250 MHz (or 0 if HDMI output is not used)
    dispAddr   : out std_logic_vector(15 downto 0); -- requested mem address
    dispData   : in  std_logic_vector(7 downto 0);  -- returned data
    vga_r, vga_g, vga_b:  out std_logic_vector(2 downto 0); -- VGA video signal
    vga_hsync, vga_vsync: out std_logic; -- VGA sync
    TMDS_out_RGB : out std_logic_vector(2 downto 0) -- HDMI output
  );
end vgahdmi;

architecture syn of vgahdmi is
  component vgahdmi_v
    generic (
      dbl_x          : integer := 0;  -- 0-normal X, 1-double X
      dbl_y          : integer := 0;  -- 0-normal X, 1-double X
      visible_y      : integer := 480;-- visible y (vertical size)
      test_picture   : integer := 0   -- 0-don't, 1-show some test picture
    );
    port (
      clk_pixel  : in std_logic;  -- pixel clock, 25 MHz
      clk_tmds   : in std_logic := '0'; -- hdmi clock 250 MHz (or 0 if HDMI output is not used)
      dispAddr   : out std_logic_vector(15 downto 0); -- requested mem address
      dispData   : in  std_logic_vector(7 downto 0);  -- returned data
      vga_r, vga_g, vga_b:  out std_logic_vector(2 downto 0); -- VGA video signal
      vga_hsync, vga_vsync: out std_logic; -- VGA sync
      TMDS_out_RGB : out std_logic_vector(2 downto 0) -- HDMI output
    );
  end component;

begin
  vgahdmi_inst: vgahdmi_v
  generic map(
    dbl_x => dbl_x,
    dbl_y => dbl_y,
    visible_y => visible_y,
    test_picture => test_picture
  )
  port map(
      clk_pixel => clk_pixel,
      clk_tmds  => clk_tmds,
      dispAddr  => dispAddr,
      dispData  => dispData,
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      vga_hsync => vga_hsync,
      vga_vsync => vga_vsync,
      TMDS_out_RGB => TMDS_out_RGB
  );

end syn;
