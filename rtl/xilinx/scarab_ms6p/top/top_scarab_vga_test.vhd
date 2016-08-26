-- (c) EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

library unisim;
use unisim.vcomponents.all;

entity scarab_vga_test is
  generic (
	-- Main clock: 25/93/100/108/112 MHz
	C_clk_freq: integer := 93;

	C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

        C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)
        C_video_mode: integer := 6; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 6:1024x576, 7:1280x1024

        C_vgahdmi: boolean := true;
          C_vgahdmi_axi: boolean := true; -- connect vgahdmi to video_axi_in/out instead to f32c bus arbiter
          C_vgahdmi_cache_size: integer := 8; -- KB video cache (only on f32c bus) (0: disable, 2,4,8,16,32:enable)
          C_vgahdmi_fifo_timeout: integer := 0;
          C_vgahdmi_fifo_burst_max: integer := 64;
          -- output data width 8bpp
          C_vgahdmi_fifo_data_width: integer := 32; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgahdmi_fifo_addr_width: integer := 11;

    C_vgatext: boolean := false;    -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "f32c: ESA11-7a102t MIPS compatible soft-core 100MHz 256MB DDR3"; -- default banner as initial content of screen BRAM, NOP for RAM
      C_vgatext_mode: integer := 0;   -- 640x480
      C_vgatext_bits: integer := 4;   -- 64 possible colors
      C_vgatext_bram_mem: integer := 0;   -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height
        C_vgatext_font_height: integer := 16; -- font height
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false;   -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false;   -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false;    -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true;   -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true;    -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true;    -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true;  -- enable text memory FIFO
          C_vgatext_text_fifo_postpone_step: integer := 0;
          C_vgatext_text_fifo_step: integer := (82*2)/4; -- step for the FIFO refill and rewind
          C_vgatext_text_fifo_width: integer := 6; -- width of FIFO address space (default=4) length = 2^width * 4 bytes
      C_vgatext_bitmap: boolean := true; -- true for optional bitmap generation
        C_vgatext_bitmap_depth: integer := 8; -- 8-bpp 256-color bitmap
        C_vgatext_bitmap_fifo: boolean := true; -- enable bitmap FIFO
          C_vgatext_bitmap_fifo_timeout: integer := 48; -- abort compositing 48 pixels before end of line
          -- 8 bpp compositing
          -- step=horizontal width in pixels
          C_vgatext_bitmap_fifo_step: integer := 640;
          -- height=vertical height in pixels
          C_vgatext_bitmap_fifo_height: integer := 480;
          -- output data width 8bpp
          C_vgatext_bitmap_fifo_data_width: integer := 8; -- should be equal to bitmap depth
          -- bitmap width of FIFO address space length = 2^width * 4 byte
          C_vgatext_bitmap_fifo_addr_width: integer := 11
  );
  port
  (
    clk_50MHz: in std_logic;
    sdram_clk: out std_logic;
    sdram_cke: out std_logic;
    sdram_csn: out std_logic;
    sdram_rasn: out std_logic;
    sdram_casn: out std_logic;
    sdram_wen: out std_logic;
    sdram_a: out std_logic_vector (12 downto 0);
    sdram_ba: out std_logic_vector(1 downto 0);
    sdram_dqm: out std_logic_vector(1 downto 0);
    sdram_d: inout std_logic_vector (15 downto 0);
    rs232_tx: out std_logic;
    rs232_rx: in std_logic;
    flash_cs, flash_cclk, flash_mosi: out std_logic;
    flash_miso: in std_logic;
    sd_clk, sd_cd_dat3, sd_cmd: out std_logic;
    sd_dat0, sd_dat1, sd_dat2: in std_logic;
    leds: out std_logic_vector(7 downto 0);
    porta, portb, portc: inout std_logic_vector(11 downto 0);
    portd: inout std_logic_vector(3 downto 0); -- fm and cw antennas are here
    porte, portf: inout std_logic_vector(11 downto 0);
    audio1, audio2: out std_logic; -- 3.5mm audio jack
    -- warning TMDS_in is used as output
    TMDS_in_P, TMDS_in_N: out std_logic_vector(2 downto 0);
    TMDS_in_CLK_P, TMDS_in_CLK_N: out std_logic;
    FPGA_SDA, FPGA_SCL: inout std_logic; -- i2c on TMDS_in
    TMDS_out_P, TMDS_out_N: out std_logic_vector(2 downto 0);
    TMDS_out_CLK_P, TMDS_out_CLK_N: out std_logic;
    sw: in std_logic_vector(4 downto 1)
  );
end;

architecture Behavioral of scarab_vga_test is
    -- useful for conversion from KB to number of address bits
    function ceil_log2(x: integer)
      return integer is
    begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
    end ceil_log2;
    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_30MHz, clk_40MHz, clk_45MHz, clk_50MHz_out, clk_65MHz, clk_75MHz, clk_80MHz, 
           clk_100MHz, clk_108MHz, clk_112M5Hz, clk_125MHz, clk_125MHz_p, clk_125MHz_n, clk_150MHz, 
           clk_200MHz, clk_216MHz, clk_225MHz, clk_250MHz, 
           clk_325MHz, clk_375MHz_p, clk_375MHz_n,
           clk_400MHz, clk_541MHz: std_logic := '0';
    signal clk_axi: std_logic;
    signal clk_pixel: std_logic;
    signal clk_pixel_shift_p, clk_pixel_shift_n: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;

    signal vga_clk: std_logic;
    signal S_vga_red, S_vga_green, S_vga_blue: std_logic_vector(7 downto 0);
    signal S_vga_blank: std_logic;
    signal S_vga_vsync, S_vga_hsync: std_logic;
    signal S_vga_fetch_next, S_vga_line_repeat: std_logic;
    signal S_vga_active_enabled: std_logic;
    signal S_vga_addr: std_logic_vector(29 downto 2);
    signal S_vga_addr_strobe: std_logic;
    signal S_vga_suggest_cache: std_logic;
    signal S_vga_suggest_burst: std_logic_vector(15 downto 0);
    signal S_vga_data, S_vga_data_debug: std_logic_vector(31 downto 0);
    signal S_vga_read_ready: std_logic;
    signal S_vga_data_ready: std_logic;
    signal red_byte, green_byte, blue_byte: std_logic_vector(7 downto 0);
    signal vga_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_refresh: std_logic;
    signal vga_reg_dtack: std_logic; -- low active, ack from VGA reg access
    signal vga_ackback: std_logic := '0'; -- clear for ack_d, sys_clk domai
    signal video_axi_aclk: std_logic;

    -- to switch glue/plasma vga
    signal glue_vga_vsync, glue_vga_hsync: std_logic;
    signal glue_vga_red, glue_vga_green, glue_vga_blue: std_logic_vector(7 downto 0);

    signal dvid_red, dvid_green, dvid_blue, dvid_clock: std_logic_vector(1 downto 0);
    signal tmds_in_rgb, tmds_out_rgb: std_logic_vector(2 downto 0);
    signal tmds_in_clk, tmds_out_clk: std_logic;
    signal R_blinky_pixel, R_blinky_pixel_shift_p, R_blinky_pixel_shift_n: std_logic_vector(25 downto 0);
begin
  clk100M_sdr_640x480: if C_clk_freq = 100 and not C_dvid_ddr and C_video_mode=1 generate
    clkgen100_250: entity work.pll_50M_100M_25M_250M
      port map
      (
        clk_in1 => clk_50MHz, clk_out1 => clk, clk_out2 => clk_25MHz, clk_out3 => clk_250MHz
      );
    clk_pixel <= clk_25MHz;
    clk_pixel_shift_p <= clk_250MHz;
  end generate;

  clk100M_ddr_640x480: if C_clk_freq = 100 and C_dvid_ddr and C_video_mode=1 generate
    clkgen100_125: entity work.clk_50M_100M_125Mp_125Mn_25M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_100M => clk, clk_25M => clk_25MHz, 
        clk_125Mp => clk_125MHz_p, clk_125Mn => clk_125MHz_n
      );
    clk_pixel <= clk_25MHz;
    clk_pixel_shift_p <= clk_125MHz_p;
    clk_pixel_shift_n <= clk_125MHz_n;
  end generate;

  clk93M75_ddr_1280x576: if C_clk_freq = 93 and C_dvid_ddr and C_video_mode=6 generate
    clkgen93_375_75: entity work.clk_50M_93M75_375Mp_375Mn_75M
      port map
      (
        reset => '0', locked => open,
        clk_50M_in => clk_50MHz, clk_93M75 => clk, clk_75M => clk_75MHz, 
        clk_375Mp => clk_375MHz_p, clk_375Mn => clk_375MHz_n
      );
    clk_pixel <= clk_75MHz;
    clk_pixel_shift_p <= clk_375MHz_p;
    clk_pixel_shift_n <= clk_375MHz_n;
  end generate;

  sdram_clk <= '0';
  sdram_cke <= '0';
  sdram_a <= (others => '0');
  sdram_d <= (others => 'Z');
  sdram_ba <= (others => '0');
  sdram_dqm <= (others => '0');
  sdram_rasn <= '1';
  sdram_casn <= '1';
  sdram_wen <= '1';
  sdram_csn <= '1';

  rs232_tx <= '0';
  flash_cclk <= '0';
  flash_cs <= '0';
  flash_mosi <= '0';
  sd_cd_dat3 <= '0';
  sd_clk <= '0';
  sd_cmd <= '0';
  audio1 <= '0';
  audio2 <= '0';

  glue_vga_test: entity work.glue_vga_test
    generic map (
      C_clk_freq => C_clk_freq,
      C_dvid_ddr => C_dvid_ddr,
      --
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_axi => C_vgahdmi_axi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_timeout => C_vgahdmi_fifo_timeout,
      C_vgahdmi_fifo_burst_max => C_vgahdmi_fifo_burst_max,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_vgahdmi_fifo_addr_width => C_vgahdmi_fifo_addr_width,

      -- vga advanced graphics text+compositing bitmap
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_vgatext_mode,
      C_vgatext_bits => C_vgatext_bits,
      C_vgatext_bram_mem => C_vgatext_bram_mem,
      C_vgatext_bram_base => C_vgatext_bram_base,
      C_vgatext_external_mem => C_vgatext_external_mem,
      C_vgatext_reset => C_vgatext_reset,
      C_vgatext_palette => C_vgatext_palette,
      C_vgatext_text => C_vgatext_text,
      C_vgatext_font_bram8 => C_vgatext_font_bram8,
      C_vgatext_bus_read => C_vgatext_bus_read,
      C_vgatext_reg_read => C_vgatext_reg_read,
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
      C_vgatext_bitmap_fifo_timeout => C_vgatext_bitmap_fifo_timeout,
      C_vgatext_bitmap_fifo_step => C_vgatext_bitmap_fifo_step,
      C_vgatext_bitmap_fifo_height => C_vgatext_bitmap_fifo_height,
      C_vgatext_bitmap_fifo_data_width => C_vgatext_bitmap_fifo_data_width,
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width
    )
    port map (
        clk => clk,
	clk_pixel => clk_pixel,
	clk_pixel_shift => clk_pixel_shift_p,
        -- VGA/HDMI
        dvid_red   => dvid_red,
        dvid_green => dvid_green,
        dvid_blue  => dvid_blue,
        dvid_clock => dvid_clock
    );

  G_dvi_sdr: if not C_dvid_ddr generate
      tmds_out_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_out_clk <= dvid_clock(0);
      -- hdmi "in" port can be used as second output
      -- so user don't need to think which one works :)
      tmds_in_rgb <= dvid_red(0) & dvid_green(0) & dvid_blue(0);
      tmds_in_clk <= dvid_clock(0);
  end generate;

  G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific modules to
    -- convert 2-bit pairs to DDR 1-bit
    G_vga_ddrout0: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift_p,
      clk_n     => clk_pixel_shift_n,
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_out_rgb(2),
      out_green => tmds_out_rgb(1),
      out_blue  => tmds_out_rgb(0),
      out_clock => tmds_out_clk
    );
    -- hdmi "in" port can be used as second output
    -- so user don't need to think which one works :)
    G_vga_ddrout1: entity work.ddr_dvid_out_se
    port map (
      clk       => clk_pixel_shift_p,
      clk_n     => clk_pixel_shift_n,
      in_red    => dvid_red,
      in_green  => dvid_green,
      in_blue   => dvid_blue,
      in_clock  => dvid_clock,
      out_red   => tmds_in_rgb(2),
      out_green => tmds_in_rgb(1),
      out_blue  => tmds_in_rgb(0),
      out_clock => tmds_in_clk
    );
  end generate;

  -- differential output buffering for HDMI clock and video
  hdmi_output0: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_out_clk,
        tmds_out_clk_p => tmds_out_clk_p,
        tmds_out_clk_n => tmds_out_clk_n,
        tmds_in_rgb    => tmds_out_rgb,
        tmds_out_rgb_p => tmds_out_p,
        tmds_out_rgb_n => tmds_out_n
      );
  -- hdmi "in" port can be used as second output
  -- so user don't need to think which one works :)
  hdmi_output1: entity work.hdmi_out
      port map
      (
        tmds_in_clk    => tmds_in_clk,
        tmds_out_clk_p => tmds_in_clk_p,
        tmds_out_clk_n => tmds_in_clk_n,
        tmds_in_rgb    => tmds_in_rgb,
        tmds_out_rgb_p => tmds_in_p,
        tmds_out_rgb_n => tmds_in_n
      );

  process(clk_pixel)
  begin
    if rising_edge(clk_pixel) then
      R_blinky_pixel <= R_blinky_pixel+1;
    end if;
  end process;
  leds(0) <= R_blinky_pixel(R_blinky_pixel'high);

  process(clk_pixel_shift_p)
  begin
    if rising_edge(clk_pixel_shift_p) then
      R_blinky_pixel_shift_p <= R_blinky_pixel_shift_p+1;
    end if;
  end process;
  leds(1) <= R_blinky_pixel_shift_p(R_blinky_pixel_shift_p'high);

  process(clk_pixel_shift_n)
  begin
    if rising_edge(clk_pixel_shift_n) then
      R_blinky_pixel_shift_n <= R_blinky_pixel_shift_n+1;
    end if;
  end process;
  leds(2) <= R_blinky_pixel_shift_n(R_blinky_pixel_shift_n'high);

  leds(7 downto 3) <= (others => '0');

end Behavioral;
