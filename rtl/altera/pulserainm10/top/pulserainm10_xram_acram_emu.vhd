-- AUTHOR=EMARD
-- LICENSE=BSD

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

use work.f32c_pack.all;

entity pulserainm10_xram is
    generic (
	-- ISA: either ARCH_MI32 or ARCH_RV32
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;
        C_mult_enable: boolean := true;

        --C_mul_acc: boolean := false;    -- MI32 only
        --C_mul_reg: boolean := false;    -- MI32 only
        --C_branch_likely: boolean := false;
        --C_sign_extend: boolean := false;
        --C_ll_sc: boolean := false;
        --C_PC_mask: std_logic_vector(31 downto 0) := x"00ffffff"; -- 1MB
        --C_exceptions: boolean := false;

        -- COP0 options
        --C_cop0_count: boolean := false;
        --C_cop0_compare: boolean := false;
        --C_cop0_config: boolean := false;

        -- CPU core configuration options
        --C_branch_prediction: boolean := false;
        --C_full_shifter: boolean := false;
        --C_result_forwarding: boolean := false;
        --C_load_aligner: boolean := false;

        -- Negatively influences timing closure, hence disabled
        --C_movn_movz: boolean := false;

	-- Main clock: 25/83/100 MHz
	C_clk_freq: integer := 100;

	-- SoC configuration options
	C_bram_size: integer := 0; -- BRAM disabled
	C_bram_const_init: boolean := false; -- MAX10 cannot preload bootloader using VHDL constant intializer
	C_boot_write_protect: boolean := false; -- leave boot block writeable
	C_xdma: boolean := true; -- bootloader initializes XRAM with external DMA
        C_icache_size: integer := 0;
        C_dcache_size: integer := 0;
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached
        C_acram: boolean := true;
        C_acram_wait_cycles: integer := 4; -- only 6 completey works, 4 partially (other boards work with 3 or more)
        C_acram_emu_kb: integer := 32; -- KB axi_cache emulation (power of 2, MAX 32)
        C_xram_base: std_logic_vector(31 downto 28) := x"0"; -- XRAM (acram emu) at address 0 (instead of disabled BRAM)

        C_hdmi_out: boolean := false;
        C_dvid_ddr: boolean := false;

        C_vgahdmi: boolean := false; -- simple VGA bitmap with compositing
        C_vgahdmi_cache_size: integer := 0; -- KB (0 to disable, 2,4,8,16,32 to enable)
        -- normally this should be  actual bits per pixel
        C_vgahdmi_fifo_data_width: integer range 8 to 32 := 8;
        -- width of FIFO address space -> size of fifo
        -- for 8bpp compositing use 11 -> 2048 bytes

	C_sio: integer := 1;
	C_gpio: integer := 16;
	C_timer: boolean := true; -- needs simple out of 32 elements ?
	C_simple_in: integer := 1;
	C_simple_out: integer := 32
    );
    port (
	osc_in: in std_logic;
	uart_txd: out std_logic;
	uart_rxd: in std_logic;
	uart_aux_txd: out std_logic;
	uart_aux_rxd: in std_logic;
	debug_led: out std_logic;
	push_button: in std_logic;
	p0, p1: inout std_logic_vector(7 downto 0)
    );
end;

architecture Behavioral of pulserainm10_xram is
  -- useful for conversion from KB to number of address bits
  function ceil_log2(x: integer)
      return integer is
  begin
      return integer(ceil((log2(real(x)-1.0E-6))-1.0E-6)); -- 256 -> 8, 257 -> 9
  end ceil_log2;

  signal clk: std_logic;
  signal clk_pixel, clk_pixel_shift: std_logic;
  signal clk_25M02: std_logic;
  signal S_reset: std_logic := '0';
  signal xdma_addr: std_logic_vector(29 downto 2) := ('0', others => '0'); -- preload address 0x00000000 XRAM
  signal xdma_strobe: std_logic := '0';
  signal xdma_data_ready: std_logic;
  signal xdma_write: std_logic := '0';
  signal xdma_byte_sel: std_logic_vector(3 downto 0) := (others => '1');
  signal xdma_data_in: std_logic_vector(31 downto 0) := (others => '-');
  signal ram_en             : std_logic;
  signal ram_byte_we        : std_logic_vector(3 downto 0) := (others => '0');
  signal ram_address        : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_write     : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_data_read      : std_logic_vector(31 downto 0) := (others => '0');
  signal ram_ready          : std_logic := '1';
  signal S_hdmi_pd0, S_hdmi_pd1, S_hdmi_pd2: std_logic_vector(9 downto 0);
  signal tx_in: std_logic_vector(29 downto 0);
  signal tmds_d: std_logic_vector(3 downto 0);
  signal R_blinky: std_logic_vector(25 downto 0);
  signal S_uart_break: std_logic;
begin
    G_25m_clk: if C_clk_freq = 25 generate
    clkgen_25: entity work.clk_12M_25M05_125M25P_125M25N_100M2_83M5
    port map(
      inclk0 => osc_in,        --  12 MHz input from board
      c0 => clk_25M02,         --  25.05 MHz
      c1 => open,              -- 125.25 MHz positive
      c2 => open,              -- 125.25 MHz negative
      c3 => open,              -- 100.20 MHz
      c4 => open               --  83.50 MHz
    );
    clk <= clk_25M02;
    end generate;

    G_83m_clk: if C_clk_freq = 83 generate
    clkgen_83: entity work.clk_12M_25M05_125M25P_125M25N_100M2_83M5
    port map(
      inclk0 => osc_in,        --  12 MHz input from board
      c0 => clk_25M02,         --  25.05 MHz
      c1 => open,              -- 125.25 MHz positive
      c2 => open,              -- 125.25 MHz negative
      c3 => open,              -- 100.20 MHz
      c4 => clk                --  83.50 MHz
    );
    end generate;

    G_100m_clk: if C_clk_freq = 100 generate
    clkgen_100: entity work.clk_12M_25M05_125M25P_125M25N_100M2_83M5
    port map(
      inclk0 => osc_in,        --  12 MHz input from board
      c0 => clk_25M02,         --  25.05 MHz
      c1 => open,              -- 125.25 MHz positive
      c2 => open,              -- 125.25 MHz negative
      c3 => clk,               -- 100.20 MHz
      c4 => open               --  83.50 MHz
    );
    end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_arch => C_arch,
      C_clk_freq => C_clk_freq,
      C_xdma => C_xdma,
      C_bram_size => C_bram_size,
      C_bram_const_init => C_bram_const_init,
      C_boot_write_protect => C_boot_write_protect,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_acram => C_acram,
      C_acram_wait_cycles => C_acram_wait_cycles,
      C_xram_base => C_xram_base,
      C_sio => C_sio,
      C_timer => C_timer,
      C_gpio => C_gpio,
      C_simple_in => C_simple_in,
      C_simple_out => C_simple_out,
      -- vga simple bitmap
      C_dvid_ddr => C_dvid_ddr,
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,
      C_debug => C_debug
    )
    port map (
      clk => clk,
      --clk_pixel => clk_pixel,
      --clk_pixel_shift => clk_pixel_shift,
      reset => S_reset,
      xdma_addr => xdma_addr, xdma_strobe => xdma_strobe,
      xdma_write => '1', xdma_byte_sel => "1111",
      xdma_data_in => xdma_data_in, xdma_data_ready => xdma_data_ready,
      sio_txd(0) => uart_txd, sio_rxd(0) => uart_rxd, sio_break(0) => S_uart_break,
      spi_sck => open, spi_ss => open, spi_mosi => open, spi_miso => "",
      acram_en => ram_en,
      acram_addr(29 downto 2) => ram_address(29 downto 2),
      acram_byte_we(3 downto 0) => ram_byte_we(3 downto 0),
      acram_data_rd(31 downto 0) => ram_data_read(31 downto 0),
      acram_data_wr(31 downto 0) => ram_data_write(31 downto 0),
      acram_ready => ram_ready,
      -- ***** VGA *****
      --vga_vsync => vga_vs,
      --vga_hsync => vga_hs,
      --vga_r(7 downto 4) => vga_r(3 downto 0),
      --vga_r(3 downto 0) => open,
      --vga_g(7 downto 4) => vga_g(3 downto 0),
      --vga_g(3 downto 0) => open,
      --vga_b(7 downto 4) => vga_b(3 downto 0),
      --vga_b(3 downto 0) => open,
      -- ***** HDMI *****
      --dvi_r => S_hdmi_pd2, dvi_g => S_hdmi_pd1, dvi_b => S_hdmi_pd0,
      -- gpio(7 downto 0) => p0, gpio(12 downto 8) => p1(4 downto 0), gpio(127 downto 13) => open,
      gpio(7 downto 0) => p0, gpio(15 downto 8) => p1(7 downto 0), gpio(127 downto 16) => open,
      simple_out(0) => debug_led,
      simple_out(31 downto 1) => open,
      simple_in(0) => push_button,
      simple_in(31 downto 1) => (others => '0')
    );

    G_acram: if C_acram generate
    acram_emulation: entity work.acram_emu
    generic map
    (
      C_addr_width => 8 + ceil_log2(C_acram_emu_kb)
    )
    port map
    (
      clk => clk,
      acram_a => ram_address(9 + ceil_log2(C_acram_emu_kb) downto 2),
      acram_d_wr => ram_data_write,
      acram_d_rd => ram_data_read,
      acram_byte_we => ram_byte_we,
      acram_en => ram_en
    );
    end generate;

    G_blinky: if true generate
      process(clk)
      begin
        if rising_edge(clk) then
          R_blinky <= R_blinky+1;
        end if;
      end process;
      -- p1(7) <= not R_blinky(R_blinky'high); -- RED LED connected to VCC
    end generate;

    -- generic "differential" output buffering for HDMI clock and video
    --hdmi_output1: entity work.hdmi_out
    --  port map
    --  (
    --    tmds_in_rgb    => tmds_rgb,
    --    tmds_out_rgb_p => hdmi_dp,   -- D2+ red  D1+ green  D0+ blue
    --    tmds_out_rgb_n => hdmi_dn,   -- D2- red  D1- green  D0+ blue
    --    tmds_in_clk    => tmds_clk,
    --    tmds_out_clk_p => hdmi_clkp, -- CLK+ clock
    --    tmds_out_clk_n => hdmi_clkn  -- CLK- clock
    --  );

    -- true differential, vendor-specific
    -- tx_in <= S_HDMI_PD2 & S_HDMI_PD1 & S_HDMI_PD0; -- this would be normal bit order, but
    -- generic serializer follows vendor specific serializer style
    --tx_in <=  S_HDMI_PD2(0) & S_HDMI_PD2(1) & S_HDMI_PD2(2) & S_HDMI_PD2(3) & S_HDMI_PD2(4) & S_HDMI_PD2(5) & S_HDMI_PD2(6) & S_HDMI_PD2(7) & S_HDMI_PD2(8) & S_HDMI_PD2(9) &
    --          S_HDMI_PD1(0) & S_HDMI_PD1(1) & S_HDMI_PD1(2) & S_HDMI_PD1(3) & S_HDMI_PD1(4) & S_HDMI_PD1(5) & S_HDMI_PD1(6) & S_HDMI_PD1(7) & S_HDMI_PD1(8) & S_HDMI_PD1(9) &
    --          S_HDMI_PD0(0) & S_HDMI_PD0(1) & S_HDMI_PD0(2) & S_HDMI_PD0(3) & S_HDMI_PD0(4) & S_HDMI_PD0(5) & S_HDMI_PD0(6) & S_HDMI_PD0(7) & S_HDMI_PD0(8) & S_HDMI_PD0(9);

    --vendorspec_serializer_inst: entity work.serializer
    --PORT MAP
    --(
    --    tx_in => tx_in,
    --    tx_inclock => CLK_PIXEL_SHIFT, -- NOTE: vendor-specific serializer needs CLK_PIXEL x5
    --    tx_syncclock => CLK_PIXEL,
    --    tx_out => tmds_d(2 downto 0)
    --);
    --hdmi_clk <= CLK_PIXEL;
    --hdmi_d   <= tmds_d(2 downto 0);

    -- this module must be present in order for bitstream to load
    -- from onchip flash
    vendorspec_dual_config: entity work.dual_config
    port map
    (
      avmm_rcv_address => "000",         -- avalon.address
      avmm_rcv_read => '0',              --       .read
      avmm_rcv_writedata => x"00000000", --       .writedata
      avmm_rcv_write => '0',             --       .write
      avmm_rcv_readdata => open,         --       .readdata
      clk => clk_25M02,                  --    clk.clk 25.02MHz
      nreset => '1'                      -- nreset.reset_n
    );

    -- preload the f32c bootloader and reset CPU
    -- preloads initially at startup and during each reset of the CPU
    boot_preload: entity work.max10_boot_preloader
    port map
    (
      clk => clk,
      reset_in => S_uart_break, -- input reset rising edge (from serial break) starts DMA preload
      reset_out => S_reset, -- 1 during DMA preload (holds CPU in reset state)
      addr => xdma_addr(9 downto 2), -- must fit bootloader size 1K 10-bit byte address
      data => xdma_data_in, -- comes from register - last read data will stay on the bus
      strobe => xdma_strobe, -- use strobe as strobe and as write signal
      ready => xdma_data_ready -- response from RAM arbiter (write completed)
    );
    -- p1(5) <= not S_reset; -- GREEN LED (connected to VCC)
    -- p1(7) <= not xdma_strobe; -- RED LED
    -- p1(5) <= not '1';
    -- uart_txd <= uart_rxd; -- loopback test for RS232

end Behavioral;
