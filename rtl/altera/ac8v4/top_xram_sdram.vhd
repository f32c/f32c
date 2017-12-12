-- AUTHOR=EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

entity top_ac8v4_xram_sdram is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	-- Main clock: 81/83/112 (83 for hdmi video)
	C_clk_freq: integer := 50;

	-- SoC configuration options
	C_bram_size: integer := 2;
        C_icache_size: integer := 2;
        C_dcache_size: integer := 2;
        C_acram: boolean := false;
        C_sdram: boolean := true;

        C_hdmi_out: boolean := false;

        C_vgahdmi: boolean := false; -- simple VGA bitmap with compositing
        C_vgahdmi_cache_size: integer := 0; -- KB (0 to disable, 2,4,8,16,32 to enable)
        -- normally this should be  actual bits per pixel
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;

	C_sio: integer := 1;
	C_spi: integer := 2;
	C_gpio: integer := 32
    );
    port (
	clk_50m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	bit: out std_logic_vector(7 downto 0);
	seg: out std_logic_vector(7 downto 0);
	btn: in std_logic_vector(1 to 4);
	-- sw: in std_logic_vector(3 downto 0);
	sd_mmc_clk, sd_mmc_cs, sd_mmc_di: out std_logic;
	sd_mmc_do: in std_logic;
	sdr_ad: out std_logic_vector(12 downto 0);
	sdr_da: inout std_logic_vector(15 downto 0);
	sdr_ba: out std_logic_vector(1 downto 0);
	sdr_dqm: out std_logic_vector(1 downto 0);
	sdr_ras, sdr_cas: out std_logic;
	sdr_cke, sdr_clk: out std_logic;
	sdr_we, sdr_cs: out std_logic
	-- hdmi_dp, hdmi_dn: out std_logic_vector(2 downto 0);
	-- hdmi_clkp, hdmi_clkn: out std_logic;
        -- video_dac: out std_logic_vector(3 downto 0)
    );
end;

architecture Behavioral of top_ac8v4_xram_sdram is
  signal clk: std_logic;
  signal clk_325m: std_logic;
  signal clk_pixel, clk_pixel_shift: std_logic;
  signal btns: std_logic_vector(3 downto 0);
  signal tmds_rgb: std_logic_vector(2 downto 0);
  signal tmds_clk: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
begin
    -- clock synthesizer: Altera specific
    G_generic_clk:
    if C_clk_freq = 50 generate
    clk <= clk_50m;    
    end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_bram_size => C_bram_size,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_acram => C_acram,
      C_sdram => C_sdram,
      C_sdram_address_width => 24,
      C_sdram_column_bits => 9,
      C_sdram_startup_cycles => 10100,
      C_sdram_cycles_per_refresh => 1524,
      C_spi => C_spi,
      -- vga simple bitmap
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_pixel,
      clk_pixel_shift => clk_pixel_shift,
      sio_txd(0) => rs232_tx, sio_rxd(0) => rs232_rx,
      spi_sck(0) => open, spi_ss(0) => open, spi_mosi(0) => open, spi_miso(0) => '0',
      spi_sck(1) => sd_mmc_clk, spi_ss(1) => sd_mmc_cs, spi_mosi(1) => sd_mmc_di, spi_miso(1) => sd_mmc_do,
      gpio => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready,
      sdram_addr => sdr_ad, sdram_data => sdr_da,
      sdram_ba => sdr_ba, sdram_dqm => sdr_dqm,
      sdram_ras => sdr_ras, sdram_cas => sdr_cas,
      sdram_cke => sdr_cke, sdram_clk => sdr_clk,
      sdram_we => sdr_we, sdram_cs => sdr_cs,
      -- ***** HDMI *****
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
      simple_out(7 downto 0) => seg, simple_out(31 downto 8) => open,
      simple_in(3 downto 0) => btns, simple_in(31 downto 4) => open
    );
    btns <= btn(4) & btn(3) & btn(2) & btn(1);
    bit <= (others => '1');

    G_acram: if C_acram generate
    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 12
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(13 downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_ready => ram_ready,
      acram_en => ram_en
    );
    end generate;

    -- differential output buffering for HDMI clock and video
    --G_hdmi: if C_hdmi_out generate
    --hdmi_output: entity work.hdmi_out
    --  port map
    --  (
    --    tmds_in_rgb    => tmds_rgb,
    --    tmds_out_rgb_p => hdmi_dp,   -- D2+ red  D1+ green  D0+ blue
    --    tmds_out_rgb_n => hdmi_dn,   -- D2- red  D1- green  D0- blue
    --    tmds_in_clk    => tmds_clk,
    --    tmds_out_clk_p => hdmi_clkp, -- CLK+ clock
    --    tmds_out_clk_n => hdmi_clkn  -- CLK- clock
    --  );
    --end generate;

end Behavioral;
