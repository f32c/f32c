-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

entity ffm_xram_sdram_vector is
    generic
    (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;
	C_branch_prediction: boolean := true;

	-- Main clock: 81/83/112 (83 for hdmi video)
	C_clk_freq: integer := 50;

	-- SoC configuration options
	C_bram_size: integer := 2;
        C_icache_size: integer := 2;
        C_dcache_size: integer := 2;
        C_acram: boolean := false;
        C_sdram: boolean := true;

        C_vector: boolean := true; -- vector processor unit (wip)
        C_vector_axi: boolean := false; -- vector processor bus type (false: normal f32c)
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_bram_pass_thru: boolean := true; -- Cyclone-V won't compile with pass_thru=false
        C_vector_vaddr_bits: integer := 10;
        C_vector_vdata_bits: integer := 32;
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

        C_hdmi_out: boolean := false;

        C_vgahdmi: boolean := true; -- simple VGA bitmap with compositing
        C_vgahdmi_cache_size: integer := 0; -- KB (0 to disable, 2,4,8,16,32 to enable)
        -- normally this should be  actual bits per pixel
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;

	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
        C_spi: integer := 2;
	C_gpio: integer := 32;
	C_timer: boolean := true;
	C_simple_io: boolean := true
    );
    port
    (
	clock_50a: in std_logic;
	-- RS232
	uart3_txd: out std_logic; -- rs232 txd
	uart3_rxd: in std_logic; -- rs232 rxd
	-- LED
	led: out std_logic;
	-- SD card (SPI)
        sd_m_clk, sd_m_cmd: out std_logic;
        sd_m_d: inout std_logic_vector(3 downto 0); 
        sd_m_cdet: in std_logic;
        -- SDRAM
	dr_clk: out std_logic;
	dr_cke: out std_logic;
	dr_cs_n: out std_logic;
	dr_a: out std_logic_vector(12 downto 0);
	dr_ba: out std_logic_vector(1 downto 0);
	dr_ras_n, dr_cas_n: out std_logic;
	dr_dqm: out std_logic_vector(3 downto 0);
	dr_d: inout std_logic_vector(31 downto 0);
	dr_we_n: out std_logic;
	-- HDMI video out
	vid_d_p, vid_d_n: out std_logic_vector(2 downto 0);
	vid_clk_p, vid_clk_n: out std_logic
    );
end;

architecture Behavioral of ffm_xram_sdram_vector is
  signal clk: std_logic;
  signal clk_pixel, clk_pixel_shift: std_logic;
  signal tmds_rgb: std_logic_vector(2 downto 0);
  signal tmds_clk: std_logic;
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic;
begin
    -- clock: generic, direct from onboard oscillator
    G_generic_clk:
    if C_clk_freq /= 81 and C_clk_freq /= 83 generate
      clk <= clock_50a;
      clk_pixel <= clock_50a; -- wrong, should be 25 MHz
      clk_pixel_shift <= clock_50a; -- wrong, should be 250 MHz
    end generate;

    --G_83m333_clk: if C_clk_freq = 83 generate
    --clkgen: entity work.pll_50M_250M_25M_83M333
    --port map(
    --  inclk0 => clk_50MHz,      --  50 MHz input from board
    --  c0 => clk_pixel_shift,  -- 250 MHz
    --  c1 => clk_pixel,        --  25 MHz
    --  c2 => clk               --  83.333 MHz
    --);
    --end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_branch_prediction => C_branch_prediction,
      C_bram_size => C_bram_size,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_acram => C_acram,
      C_sdram => C_sdram,
      C_sdram_address_width => 24,
      C_sdram_column_bits => 9,
      C_sdram_startup_cycles => 10100,
      C_sdram_cycles_per_refresh => 1524,
      -- vector processor
      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_registers => C_vector_registers,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_bram_pass_thru => C_vector_bram_pass_thru,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,
      -- vga simple bitmap
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_timer => C_timer,
      C_sio => C_sio,
      C_sio_init_baudrate => C_sio_init_baudrate,
      C_spi => C_spi,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      clk_pixel => clk_pixel,
      clk_pixel_shift => clk_pixel_shift,
      sio_txd(0) => uart3_txd, sio_rxd(0) => uart3_rxd,
      spi_sck(0)  => open,  spi_sck(1)  => sd_m_clk,
      spi_ss(0)   => open,  spi_ss(1)   => sd_m_d(3),
      spi_mosi(0) => open,  spi_mosi(1) => sd_m_cmd,
      spi_miso(0) => open,  spi_miso(1) => sd_m_d(0),
      gpio => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready,
      sdram_addr => dr_a, sdram_data => dr_d(15 downto 0),
      sdram_ba => dr_ba, sdram_dqm => dr_dqm(1 downto 0),
      sdram_ras => dr_ras_n, sdram_cas => dr_cas_n,
      sdram_cke => dr_cke, sdram_clk => dr_clk,
      sdram_we => dr_we_n, sdram_cs => dr_cs_n,
      -- ***** HDMI *****
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
      simple_out(0) => led, simple_out(31 downto 1) => open,
      simple_in(1 downto 0) => (others => '0'), simple_in(31 downto 2) => open
    );
    
    -- unused RAM upper 16 bits
    dr_dqm(3 downto 2) <= (others => '0');
    dr_d(31 downto 16) <= (others => 'Z');

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

    -- differential output buffering for HDMI clock and video
    G_hdmi_out: if C_hdmi_out generate
    hdmi_output: entity work.hdmi_out
      port map
      (
        tmds_in_rgb    => tmds_rgb,
        tmds_out_rgb_p => vid_d_p,   -- D2+ red  D1+ green  D0+ blue
        tmds_out_rgb_n => vid_d_n,   -- D2- red  D1- green  D0- blue
        tmds_in_clk    => tmds_clk,
        tmds_out_clk_p => vid_clk_p, -- CLK+ clock
        tmds_out_clk_n => vid_clk_n  -- CLK- clock
      );
    end generate;

end Behavioral;
