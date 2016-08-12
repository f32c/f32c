-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity glue is
  generic (
    -- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
    C_clk_freq: integer := 50;

    C_dvid_ddr: boolean := true; -- generate HDMI with DDR
    C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x450, 3:800x600, 5:1024x768

    C_vgahdmi: boolean := true;

    -- VGA textmode and graphics, full featured
    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "FleaFPGA-Uno f32c: 50MHz MIPS-compatible soft-core, 512KB SRAM";
    C_vgatext_mode: integer := 0;   -- 640x480
    C_vgatext_bits: integer := 4;   -- 4096 possible colors
    C_vgatext_bram_mem: integer := 8;   -- 8KB text+font  memory
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true;   -- reset registers to default with async reset
    C_vgatext_palette: boolean := true;  -- no color palette
    C_vgatext_text: boolean := true;    -- enable optional text generation
    C_vgatext_font_bram8: boolean := true;    -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
    C_vgatext_char_height: integer := 16;   -- character cell height
    C_vgatext_font_height: integer := 16;    -- font height
    C_vgatext_font_depth: integer := 8;     -- font char depth, 7=128 characters or 8=256 characters
    C_vgatext_font_linedouble: boolean := true;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
    C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
    C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
    C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
    C_vgatext_cursor: boolean := true;    -- true for optional text cursor
    C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
    C_vgatext_bus_read: boolean := true; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_reg_read: boolean := false; -- true: allow reading vgatext BRAM from CPU bus (may affect fmax). false: write only
    C_vgatext_text_fifo: boolean := true;  -- disable text memory FIFO
      C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
      C_vgatext_text_fifo_width: integer := 6;  -- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := true;     -- true for optional bitmap generation
    C_vgatext_bitmap_depth: integer := 8;   -- 8-bpp 16-color bitmap
    C_vgatext_bitmap_fifo: boolean := true;  -- disable bitmap FIFO
    -- step=horizontal width in pixels
    C_vgatext_bitmap_fifo_step: integer := 640;
    -- height=vertical height in pixels
    C_vgatext_bitmap_fifo_height: integer := 480;
    -- output data width 8bpp
    C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
    -- bitmap width of FIFO address space length = 2^width * 4 byte
    C_vgatext_bitmap_fifo_addr_width: integer := 11
  );
  port (
  sys_clock   : in    std_logic;  -- main clock input from 25MHz clock source
  --sys_reset   : in    std_logic;  --

  Shield_reset : inout    std_logic;  -- Buffered reset signal out to GPIO header
  --clk_25m: in std_logic;

  LVDS_Red    : out   std_logic;
  LVDS_Green  : out   std_logic;
  LVDS_Blue   : out   std_logic;
  LVDS_ck     : out   std_logic;

  User_LED1   : inout std_logic;
  User_LED2   : out   std_logic;
  User_n_PB1  : in    std_logic
  );
end glue;

architecture Behavioral of glue is
  signal clk, rs232_break, rs232_break2: std_logic;
  signal clk_dvi, clk_dvin, clk_pixel: std_logic;
  signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
  signal R_blinky_pixel, R_blinky_pixel_shift: std_logic_vector(25 downto 0);
begin

  video_mode_1_640x360: if C_video_mode = 0 generate
  clk_640x480: entity work.clkgen640x480
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 125 MHz
    CLKOS       =>  clk_dvin,  -- 125 MHz inverted
    CLKOS2      =>  clk_pixel, --  25 MHz
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

  video_mode_1_640x480: if C_video_mode = 1 generate
  clk_640x480: entity work.clkgen640x480
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 125 MHz
    CLKOS       =>  clk_dvin,  -- 125 MHz inverted
    CLKOS2      =>  clk_pixel, --  25 MHz
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

  video_mode_2_800x480: if C_video_mode = 2 generate
  clk_800x480: entity work.clkgen800x480
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 150 MHz
    CLKOS       =>  clk_dvin,  -- 150 MHz inverted
    CLKOS2      =>  clk_pixel, --  30 MHz
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

  video_mode_3_800x600: if C_video_mode = 3 generate
  clk_800x600: entity work.clkgen800x600
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 200 MHz
    CLKOS       =>  clk_dvin,  -- 200 MHz inverted
    CLKOS2      =>  clk_pixel, --  40 MHz
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

  video_mode_4_1024x576: if C_video_mode = 4 generate
  clk_1024x576: entity work.clkgen800x480 -- not correct clock, this won't work
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 160 MHz requred, actual 150
    CLKOS       =>  clk_dvin,  -- 160 MHz inverted required, actual 150
    CLKOS2      =>  clk_pixel, --  32 MHz required, actual 30
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

  video_mode_5_1024x768: if C_video_mode = 5 generate
  clk_1024x768: entity work.clkgen1024x768
  port map(
    CLKI        =>  sys_clock, --  50 MHz
    CLKOP       =>  clk_dvi,   -- 325 MHz
    CLKOS       =>  clk_dvin,  -- 325 MHz inverted
    CLKOS2      =>  clk_pixel, --  65 MHz
    CLKOS3      =>  clk        --  50 MHz
  );
  end generate;

    -- generic BRAM glue
  glue_vga_test: entity work.glue_vga_test
  generic map (
    C_clk_freq => C_clk_freq,

    C_dvid_ddr => C_dvid_ddr,

    -- vga simple compositing bitmap only graphics
    C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,

    -- vga textmode + bitmap full feature graphics
    C_vgatext => C_vgatext,
        C_vgatext_label => C_vgatext_label,
        C_vgatext_mode => C_video_mode,
        C_vgatext_bits => C_vgatext_bits,
        C_vgatext_bram_mem => C_vgatext_bram_mem,
        C_vgatext_external_mem => C_vgatext_external_mem,
        C_vgatext_reset => C_vgatext_reset,
        C_vgatext_palette => C_vgatext_palette,
        C_vgatext_bus_read => C_vgatext_bus_read,
        C_vgatext_reg_read => C_vgatext_reg_read,
        C_vgatext_text => C_vgatext_text,
        C_vgatext_font_bram8 => C_vgatext_font_bram8,
        C_vgatext_text_fifo => C_vgatext_text_fifo,
        C_vgatext_text_fifo_step => C_vgatext_text_fifo_step,
        C_vgatext_text_fifo_width => C_vgatext_text_fifo_width,
        C_vgatext_char_height => C_vgatext_char_height,
        C_vgatext_font_height => C_vgatext_font_height,
        C_vgatext_font_depth => C_vgatext_font_depth,
        C_vgatext_font_linedouble => C_vgatext_font_linedouble,
        C_vgatext_font_widthdouble => C_vgatext_font_widthdouble,
        C_vgatext_monochrome => C_vgatext_monochrome,
        C_vgatext_finescroll => C_vgatext_finescroll,
        C_vgatext_cursor => C_vgatext_cursor,
        C_vgatext_cursor_blink => C_vgatext_cursor_blink,
        C_vgatext_bitmap => C_vgatext_bitmap,
        C_vgatext_bitmap_depth => C_vgatext_bitmap_depth,
        C_vgatext_bitmap_fifo => C_vgatext_bitmap_fifo,
        C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
        C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,
        C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width
  )
  port map (
    clk => clk,
    clk_pixel => clk_pixel,
    clk_pixel_shift => clk_dvi,

    dvid_red   => dvid_red,
    dvid_green => dvid_green,
    dvid_blue  => dvid_blue,
    dvid_clock => dvid_clock
  );

  -- vendor specific modules to
  -- convert single ended DDR to phyisical output signals
  G_vgatext_ddrout: entity work.ddr_dvid_out_se
  port map (
    clk       => clk_dvi,
    clk_n     => clk_dvin,
    in_red    => dvid_red,
    in_green  => dvid_green,
    in_blue   => dvid_blue,
    in_clock  => dvid_clock,
    out_red   => LVDS_Red,
    out_green => LVDS_Green,
    out_blue  => LVDS_Blue,
    out_clock => LVDS_ck
  );
  
  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      R_blinky_pixel <= R_blinky_pixel+1;
    end if;
  end process;
  User_LED1 <= R_blinky_pixel(R_blinky_pixel'high);

  process(clk_dvi)
  begin
    if rising_edge(clk_dvi) then
      R_blinky_pixel_shift <= R_blinky_pixel_shift+1;
    end if;
  end process;
  User_LED2 <= R_blinky_pixel_shift(R_blinky_pixel_shift'high);

end Behavioral;
