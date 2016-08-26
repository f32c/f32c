-- (C)EMARD
-- LICENSE=BSD

-- test glue
-- display VGA/HDMI test screen

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use ieee.numeric_std.all; -- we need signed type

use work.video_mode_pack.all;

entity glue_vga_test is
generic (
  C_clk_freq: integer;

  -- video hardware output settings
  C_dvid_ddr: boolean := false; -- false: generate digital video from 250MHz SDR single edge, true: digital video from 125MHz DDR double edge
  -- C_lvds_display:
  -- false: normal monitors, DVI-D/HDMI 10-bit TMDS (25MHz pixel clock, 250MHz shift clock)
  -- true:  bare wired LCD panel, 7-bit LVDS (36MHz pixel clock, 252MHz shift clock and does only SDR, not DDR)
  C_lvds_display: boolean := false; -- false: normal DVI-D/HDMI, true: bare LCD panel
  -- TV simple 512x512 bitmap
  C_tv: boolean := false; -- enable TV output
  C_tv_fifo_width: integer := 512;
  C_tv_fifo_height: integer := 512;
  C_tv_fifo_data_width: integer range 8 to 32 := 8;
  C_tv_fifo_addr_width: integer := 11;
  -- VGA/HDMI simple 640x480 bitmap only
  C_vgahdmi: boolean := false; -- enable VGA/HDMI output to vga_ and tmds_
  C_vgahdmi_mode: integer := 0; -- video mode selection: 0:640x480, 1:800x600, 2:1024x768
  C_vgahdmi_axi: boolean := false; -- true: use AXI bus (video_axi_in/out) instead of f32c bus
  C_vgahdmi_cache_size: integer := 0; -- KB enable cache for f32c bus (C_vgahdmi_axi = false)
  C_vgahdmi_cache_use_i: boolean := false; -- true: use instruction cache (faster, maybe buggy), false: use data cache (slower, works)
  C_vgahdmi_fifo_fast_ram: boolean := true;
  C_vgahdmi_fifo_timeout: integer := 0; -- abort compositing at N pixels before end of line (0 disabled)
  C_vgahdmi_fifo_burst_max: integer := 1; -- values >= 2 enable the burst
  --C_vgahdmi_fifo_width: integer := C_video_modes(C_vgahdmi_mode).resolution_x;
  --C_vgahdmi_fifo_height: integer := C_video_modes(C_vgahdmi_mode).resolution_y;
  C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
  C_vgahdmi_fifo_addr_width: integer := 11;
  --
  C_video_base_addr_out: boolean := false; -- dummy video driver, just output base address to toplevel
  -- LED strip ws2812 POV simple 144x480 bitmap only
  C_ledstrip: boolean := false; -- enable dual channel ws2812b output
  C_ledstrip_full_circle: integer := 100; -- count of pulses per full circle of rotation
  C_ledstrip_fifo_width: integer := 72;
  C_ledstrip_fifo_height: integer := 36;
  C_ledstrip_fifo_data_width: integer range 8 to 32 := 8;
  C_ledstrip_fifo_addr_width: integer := 11;
  -- Xark's feature-rich bitmap+textmode VGA
  -- it can mix 8bpp bitmap and tiled graphics on the same screen
  -- choice of many of video modes
  -- minimal mode needs only 4K BRAM
  C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
    C_vgatext_label: string := "f32c";    -- default banner in screen memory
    C_vgatext_mode: integer := 0; -- 640x480
    C_vgatext_bits: integer := 2; -- 4 possible colors
    C_vgatext_bram_mem: integer := 4; -- 4KB text+font  memory
    C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- start address of textmode bram x"4" -> 0x40000000
    C_vgatext_external_mem: integer := 0; -- 0KB external SRAM/SDRAM
    C_vgatext_reset: boolean := true; -- reset registers to default with async reset
    C_vgatext_palette: boolean := false; -- no color palette
    C_vgatext_text: boolean := true; -- enable optional text generation
      C_vgatext_font_bram8: boolean := false; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
      C_vgatext_char_height: integer := 16; -- character cell height
      C_vgatext_font_height: integer := 8; -- font height
      C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
      C_vgatext_font_linedouble: boolean := true; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
      C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
      C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character
      C_vgatext_finescroll: boolean := false; -- true for pixel level character scrolling and line length modulo
      C_vgatext_cursor: boolean := true; -- true for optional text cursor
      C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
      C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_reg_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
      C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
      C_vgatext_text_fifo_postpone_step: integer := 0;
      C_vgatext_text_fifo_step: integer := (80*2)/4; -- step for the FIFO refill and rewind
        C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
    C_vgatext_bitmap: boolean := false; -- true for optional bitmap generation
      C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
      C_vgatext_bitmap_fifo: boolean := false; -- disable bitmap FIFO
        C_vgatext_bitmap_fifo_timeout: integer := 0; -- abort compositing at N pixels before end of line (0 disabled)
        C_vgatext_bitmap_fifo_step: integer := 640; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_height: integer := 480; -- bitmap step for the FIFO refill and rewind (0 unless repeating lines)
        C_vgatext_bitmap_fifo_addr_width: integer := 11; -- bitmap width of FIFO address space length = 2^width * 4 byte
        C_vgatext_bitmap_fifo_data_width: integer := 8  -- data width from the fifo
);
port (
  clk: in std_logic;
  clk_pixel: in std_logic := '0'; -- VGA pixel clock 25 MHz
  clk_pixel_shift: in std_logic := '0'; -- digital video (DVID/HDMI) bit shift clock, for SDR 10x clk_pixel, for DDR 5x clk_pixel, default 0 if no digital video
  clk_fmdds: in std_logic := '0'; -- FM DDS clock (>216 MHz)
  clk_cw: in std_logic := '0'; -- CW transmitter 433.92 MHz
  -- video axi is currently used only when C_vgahdmi = true and C_vgahdmi_axi = true
  video_axi_aresetn: in std_logic := '1';
  video_axi_aclk: in std_logic := '0';
  -- vector processor AXI
  --
  vga_hsync, vga_vsync: out std_logic;
  vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0) := (others => '0');
  tmds_out_rgb: out std_logic_vector(2 downto 0);
  tmds_out_clk: out std_logic := '0'; -- used for DDR output
  dvid_red, dvid_green, dvid_blue, dvid_clock: out std_logic_vector(1 downto 0);
  video_base_addr: out std_logic_vector(31 downto 2) := (others => '0'); -- video base address
  ledstrip_rotation: in std_logic := '0'; -- input from motor rotation encoder
  ledstrip_out: out std_logic_vector(1 downto 0) -- 2 channels out
);
end glue_vga_test;

architecture Behavioral of glue_vga_test is
    -- TV video
    signal R_fb_base_addr: std_logic_vector(31 downto 2) := (others => '0');
    signal R_fb_intr: std_logic;
    signal S_tv_dac: std_logic_vector(3 downto 0);
    signal S_tv_fetch_next: std_logic;
    signal S_tv_vsync: std_logic;
    signal S_tv_mode: std_logic_vector(1 downto 0) := "10";

    -- VGA/HDMI video
    signal vga_ce: std_logic; -- '1' when address is in iomap_vga range
    signal S_video_data_clk: std_logic; -- switched cpu clk or axi clk
    signal S_vga_enable: std_logic;
    signal S_vga_active_enabled: std_logic;
    signal vga_fetch_next, S_vga_fetch_enabled: std_logic; -- video module requests next data from fifo
    signal vga_line_repeat: std_logic;
    signal vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_data_r, vga_data_g, vga_data_b: std_logic_vector(7 downto 0);
    -- VGA RAM port
    signal vga_addr: std_logic_vector(29 downto 2);
    signal vga_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_data_ready: std_logic; -- RAM responds to FIFO
    signal vga_data: std_logic_vector(31 downto 0);
    -- Video FIFO data bus
    signal video_fifo_suggest_cache: std_logic := '0';
    signal video_fifo_suggest_burst: std_logic_vector(15 downto 0);
    signal video_fifo_addr: std_logic_vector(29 downto 2);
    signal video_fifo_addr_strobe: std_logic; -- FIFO requests to read from RAM
    signal video_fifo_data_ready: std_logic; -- RAM responds to FIFO
    signal video_fifo_data: std_logic_vector(31 downto 0);
    signal video_fifo_read_ready: std_logic := '1';

    signal video_bram_write: std_logic;
    signal video_bram_addr_strobe: std_logic;
    signal S_vga_r, S_vga_g, S_vga_b: std_logic_vector(7 downto 0);
    signal S_vga_vsync, S_vga_hsync: std_logic;
    signal S_vga_vblank, S_vga_blank: std_logic;
    signal vga_frame: std_logic; -- fifo outputs signal for frame interrupt


    signal ledstrip_ce: std_logic;
    signal S_ledstrip_active: std_logic;
    signal S_ledstrip_pixel_data: std_logic_vector(23 downto 0) := (others => '0');
    signal S_ledstrip_counter, S_ledstrip_counter2: std_logic_vector(23 downto 0);
    signal S_ledstrip_line, S_ledstrip_bit: std_logic_vector(15 downto 0);
    signal S_ledstrip_out: std_logic;
    signal S_ledstrip_wraparound: std_logic;
    signal R_ledstrip_wraparound_shift: std_logic_vector(2 downto 0);
    signal R_ledstrip_capture: std_logic_vector(31 downto 0);
    signal from_ledstrip: std_logic_vector(31 downto 0);

    -- VGA_textmode VGA/HDMI video (text and font in BRAM, bitmap in sdram)
    signal vga_textmode_ce: std_logic;
    signal from_vga_textmode: std_logic_vector(31 downto 0);
    signal vga_textmode_red: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_green: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_blue: std_logic_vector(C_vgatext_bits-1 downto 0);
    signal vga_textmode_hsync: std_logic;
    signal vga_textmode_vsync: std_logic;
    signal vga_textmode_blank: std_logic;

    -- VGA_textmode BRAM access
    signal vga_textmode_dmem_write: std_logic;
    signal vga_textmode_dmem_to_cpu: std_logic_vector(31 downto 0);
    signal vga_textmode_bram_addr: std_logic_vector(15 downto 2);
    signal vga_textmode_bram_data_in: std_logic_vector(31 downto 0);
    signal vga_textmode_bram_data: std_logic_vector(31 downto 0);
    signal vga_textmode_bram8_data: std_logic_vector(7 downto 0);
    signal vga_textmode_dmem8_write: std_logic;

    -- VGA_textmode SRAM/FIFO text access
    signal vga_textmode_text_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_data: std_logic_vector(31 downto 0);
    signal vga_textmode_text_strobe: std_logic;
    signal vga_textmode_text_rewind: std_logic;
    signal vga_textmode_text_ready: std_logic; -- SDRAM data ready
    signal vga_textmode_text_sdram_addr: std_logic_vector(29 downto 2);
    signal vga_textmode_text_sdram_strobe: std_logic; -- FIFO requests to read from RAM
    signal vga_textmode_text_sdram_ready: std_logic; -- RAM responds to FIFO
    signal vga_textmode_text_active: std_logic; -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_text_frame: std_logic;

    -- VGA_textmode SRAM/FIFO bitmap access
    signal vga_textmode_bitmap_addr: std_logic_vector(29 downto 2); -- FIFO start or SRAM address
    signal vga_textmode_bitmap_data: std_logic_vector(C_vgatext_bitmap_fifo_data_width-1 downto 0); -- data from FIFO or SRAM
    signal vga_textmode_bitmap_strobe: std_logic; -- FIFO fetch next word
    signal vga_textmode_bitmap_rewind: std_logic; -- rewind FIFO
    signal vga_textmode_bitmap_ready: std_logic; -- SRAM data ready
    signal vga_textmode_bitmap_active: std_logic; -- true when visible scan-line, false in vertical blanking period
    signal vga_textmode_bitmap_frame: std_logic;

    -- VGA to DVI-D conversion in DDR mode
    signal dvid_red_ddr, dvid_green_ddr, dvid_blue_ddr, dvid_clock_ddr: std_logic_vector(1 downto 0);
begin
    -- VGA/HDMI
    G_vgahdmi:
    if C_vgahdmi generate

    -- 8/16/32 bpp conversion into RGB-888 for display.
    -- unspported bpp values produce black screen
    -- LSB bit extended as padding improving max dynamic range
    G_vgabit_RGB_332_888: if C_vgahdmi_fifo_data_width = 8 generate
      vga_data_r <= vga_data_from_fifo(7 downto 5) & vga_data_from_fifo(7 downto 5) & vga_data_from_fifo(7 downto 6); -- red
      vga_data_g <= vga_data_from_fifo(4 downto 2) & vga_data_from_fifo(4 downto 2) & vga_data_from_fifo(4 downto 3); -- green
      vga_data_b <= vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0) & vga_data_from_fifo(1 downto 0); -- blue
    end generate;
    G_vgabit_RGB_565_888: if C_vgahdmi_fifo_data_width = 16 generate
      vga_data_r <= vga_data_from_fifo(15 downto 11) & vga_data_from_fifo(15 downto 13); -- red
      vga_data_g <= vga_data_from_fifo(10 downto 5) & vga_data_from_fifo(10 downto 9); -- green
      vga_data_b <= vga_data_from_fifo(4 downto 0) & vga_data_from_fifo(4 downto 2); -- blue
    end generate;
    G_vgabit_RGB_888_888: if C_vgahdmi_fifo_data_width = 32 generate
      -- only 24 from 32 bits are used, 8 bits reserved for alpha channel
      vga_data_r <= vga_data_from_fifo(23 downto 16); -- red
      vga_data_g <= vga_data_from_fifo(15 downto 8); -- green
      vga_data_b <= vga_data_from_fifo(7 downto 0); -- blue
    end generate;

    -- VGA video generator - pixel clock synchronous
    vgabitmap: entity work.vga
    generic map (
      C_resolution_x => C_video_modes(C_vgahdmi_mode).visible_width,
      C_hsync_front_porch => C_video_modes(C_vgahdmi_mode).h_front_porch,
      C_hsync_pulse => C_video_modes(C_vgahdmi_mode).h_sync_pulse,
      C_hsync_back_porch => C_video_modes(C_vgahdmi_mode).h_back_porch,
      C_resolution_y => C_video_modes(C_vgahdmi_mode).visible_height,
      C_vsync_front_porch => C_video_modes(C_vgahdmi_mode).v_front_porch,
      C_vsync_pulse => C_video_modes(C_vgahdmi_mode).v_sync_pulse,
      C_vsync_back_porch => C_video_modes(C_vgahdmi_mode).v_back_porch
    )
    port map (
      clk_pixel => clk_pixel,
      test_picture => not S_vga_enable, -- shows test picture when VGA is disabled (on startup)
      fetch_next => vga_fetch_next,
      line_repeat => vga_line_repeat,
      red_byte    => vga_data_r,
      green_byte  => vga_data_g,
      blue_byte   => vga_data_b,
      vga_r => S_vga_r,
      vga_g => S_vga_g,
      vga_b => S_vga_b,
      vga_hsync => S_vga_hsync,
      vga_vsync => S_vga_vsync,
      vga_blank => S_vga_blank, -- '1' when outside of horizontal or vertical graphics area
      vga_vblank => S_vga_vblank -- '1' when outside of vertical graphics area (used for vblank interrupt)
    );
    vga_r <= S_vga_r;
    vga_g <= S_vga_g;
    vga_b <= S_vga_b;
    vga_vsync <= S_vga_vsync xor not C_video_modes(C_vgahdmi_mode).v_sync_polarity;
    vga_hsync <= S_vga_hsync xor not C_video_modes(C_vgahdmi_mode).h_sync_polarity;

    G_vgahdmi_tmds_display: if not C_lvds_display generate
    -- DVI-D TMDS Encoder Block
    -- XXX Fixme: unify this block with vgatextmode (use same signal names)
    G_vgahdmi_dvid: entity work.vga2dvid
    generic map (
      C_ddr     => C_dvid_ddr,
      C_depth   => 8 -- 8bpp (8 bit per pixel)
    )
    port map (
      clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

      in_red   => S_vga_r,
      in_green => S_vga_g,
      in_blue  => S_vga_b,

      in_blank => S_vga_blank,
      in_hsync => S_vga_hsync,
      in_vsync => S_vga_vsync,

      -- single-ended output ready for differential buffers
      out_red   => dvid_red,
      out_green => dvid_green,
      out_blue  => dvid_blue,
      out_clock => dvid_clock
    );
    end generate;

    G_vgahdmi_lvds_display: if C_lvds_display generate
    -- LCD LVDS Encoder Block
    -- XXX Fixme: unify this block with vgatextmode (use same signal names)
    G_vgahdmi_lcd: entity work.vga2lcd
    generic map (
      C_depth => 8 -- 8bpp (8 bit per pixel)
    )
    port map (
      clk_pixel => clk_pixel, clk_shift => clk_pixel_shift,

      in_red   => S_vga_r,
      in_green => S_vga_g,
      in_blue  => S_vga_b,

      in_blank => S_vga_blank,
      in_hsync => S_vga_hsync,
      in_vsync => S_vga_vsync,

      -- single-ended output ready for differential buffers
      out_red_green  => dvid_red,
      out_green_blue => dvid_green,
      out_blue_sync  => dvid_blue,
      out_clock      => dvid_clock
    );
    end generate;

    end generate; -- G_vgahdmi

end Behavioral;

