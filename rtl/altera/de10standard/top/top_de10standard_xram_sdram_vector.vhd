-- (c)EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;

entity de10standard_xram_sdram is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;
	C_branch_prediction: boolean := true;

	-- Main clock: 50/83
	C_clk_freq: integer := 83;

	-- SoC configuration options
	C_bram_size: integer := 1;
	C_boot_write_protect: boolean := false;
        C_icache_size: integer := 4; -- 2 or 4 compiles with 8 vectors
        C_dcache_size: integer := 4; -- 2 or 4 compiles with 8 vecotrs
        C_acram: boolean := false;
        C_sdram: boolean := true;

        C_vector: boolean := true; -- vector processor unit (wip)
        C_vector_axi: boolean := false; -- vector processor bus type (false: normal f32c)
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_vaddr_bits: integer := 11;
        C_vector_vdata_bits: integer := 32;
        C_vector_bram_pass_thru: boolean := true; -- Cyclone-IV works with "true" and "false", Cyclone-V needs "true"
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
    port (
        CLOCK_50: in std_logic;
        irda_txd: out std_logic;
        irda_rxd: in std_logic;
        sw: in std_logic_vector(9 downto 0);
        key: in std_logic_vector(2 downto 1);
        ledr: out std_logic_vector(9 downto 0);
	hex0, hex1, hex2, hex3, hex4, hex5: out std_logic_vector(7 downto 0);
        gpio: inout std_logic_vector(35 downto 0);
        vga_hs, vga_vs: out std_logic;
        vga_r, vga_g, vga_b: out std_logic_vector(7 downto 0);
        --hdmi_d: out std_logic_vector(2 downto 0);
        --hdmi_clk: out std_logic;
        -- SDRAM
        dram_addr: out std_logic_vector(12 downto 0);
        dram_dq: inout std_logic_vector(15 downto 0);
        dram_ba: out std_logic_vector(1 downto 0);
        dram_dqm: out std_logic_vector(1 downto 0);
        dram_ras_n, dram_cas_n: out std_logic;
        dram_cke: out std_logic;
        dram_clk: out std_logic;
        dram_we_n: out std_logic;
        dram_cs_n: out std_logic
    );
end;

architecture Behavioral of de10standard_xram_sdram is
  signal clk: std_logic;
  signal clk_325m: std_logic;
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
    -- clock synthesizer: Altera specific
    G_generic_clk:
    if C_clk_freq = 50 generate
      clk <= CLOCK_50;
    end generate;

    G_83M33_clk: if C_clk_freq = 83 generate
    clkgen_83: entity work.clk_50M_250M_25M_83M33
    port map(
      refclk => CLOCK_50,      --  50 MHz input from board
      outclk_0 => open,        -- 250 MHz
      outclk_1 => clk_pixel,   --  25 MHz
      outclk_2 => clk          --  83.333 MHz
    );
    end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_branch_prediction => C_branch_prediction,
      C_bram_size => C_bram_size,
      C_boot_write_protect => C_boot_write_protect,
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
      sio_txd(0) => irda_txd, sio_rxd(0) => irda_rxd,
      spi_sck(0)  => open,  spi_sck(1)  => open,
      spi_ss(0)   => open,  spi_ss(1)   => open,
      spi_mosi(0) => open,  spi_mosi(1) => open,
      spi_miso(0) => open,  spi_miso(1) => open,
      gpio(35 downto 0) => gpio(35 downto 0), gpio(127 downto 36) => open,
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready,
      sdram_addr => dram_addr, sdram_data => dram_dq,
      sdram_ba => dram_ba, sdram_dqm => dram_dqm,
      sdram_ras => dram_ras_n, sdram_cas => dram_cas_n,
      sdram_cke => dram_cke, sdram_clk => dram_clk,
      sdram_we => dram_we_n, sdram_cs => dram_cs_n,
      -- ***** VGA *****
      vga_vsync => vga_vs,
      vga_hsync => vga_hs,
      vga_r => vga_r,
      vga_g => vga_g,
      vga_b => vga_b,
      -- ***** HDMI *****
      dvid_red(0)   => tmds_rgb(2), dvid_red(1)   => open,
      dvid_green(0) => tmds_rgb(1), dvid_green(1) => open,
      dvid_blue(0)  => tmds_rgb(0), dvid_blue(1)  => open,
      dvid_clock(0) => tmds_clk,    dvid_clock(1) => open,
      simple_out(9 downto 0) => ledr,
      simple_out(17 downto 10) => hex0(7 downto 0),
      simple_out(25 downto 18) => hex1(7 downto 0),
      simple_out(31 downto 26) => hex2(5 downto 0),
      simple_in(9 downto 0) => sw, simple_in(31 downto 10) => open
    );
    hex2(7 downto 6) <= (others => '1'); -- '1' is LED off
    hex3(7 downto 0) <= (others => '1'); -- '1' is LED off
    hex4(7 downto 0) <= (others => '1'); -- '1' is LED off
    hex5(7 downto 0) <= (others => '1'); -- '1' is LED off

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

end Behavioral;
