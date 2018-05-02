--
-- Copyright (c) 2015 Emanuel Stiebler
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- vendor-specific for xilinx
library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;
use work.axi_pack.all;

entity ffm_xram_sdram is
  generic
  (
	-- ISA
	C_arch: integer := ARCH_MI32;
	C_debug: boolean := false;

	C_vendor_specific_startup: boolean := false; -- false: disabled (xilinx startup doesn't work reliable on this board)

	-- SoC configuration options
	C_bram_size: integer := 16; -- K default 16
	C_boot_write_protect: boolean := true; -- set to 'false' for 1K bram size

	-- SDRAM
	C_sdram: boolean := false; -- 16-bit sdram
	C_sdram32: boolean := true; -- 32-bit sdram
	C_sdram_clock_range: integer := 3; -- 3: must be for FFM board, 2: default for other boards

        -- axi ram
	C_axiram: boolean := false; -- default true
	C_axi_mig_data_bits: integer := 128; -- bits 32 or 128 (data bus width in link between MIG and AXI interconnect), default 32

        C_mult_enable: boolean := true;
        C_mul_acc: boolean := false;    -- MI32 only, default false
        C_mul_reg: boolean := false;    -- MI32 only, default false

        -- integer multiplication doesn't work for CPU clock 100MHz, works at 83MHz
        -- cache 4K doesn't work vectors at 100MHz CPU clock
        -- cacke 2K or 8K vectors work at 100MHz CPU clock
        C_icache_size: integer := 8; -- K 0, 2, 4, 8, 16, 32 KBytes, default 8
        C_dcache_size: integer := 8; -- K 0, 2, 4, 8, 16, 32 KBytes, default 8
        C_cached_addr_bits: integer := 29; -- lower address bits than C_cached_addr_bits are cached: 2^29 -> 512MB to be cached

        -- DDR3 parameters (don't touch)
        C3_NUM_DQ_PINS        : integer := 16;
        C3_MEM_ADDR_WIDTH     : integer := 14;
        C3_MEM_BANKADDR_WIDTH : integer := 3;

        C_vector: boolean := true; -- vector processor unit
        C_vector_axi: boolean := false; -- true: use AXI I/O, false use f32c RAM port I/O
        C_vector_burst_max_bits: integer := 6; -- bits describe max burst, default 6: burst length 2^6=64
        C_vector_registers: integer := 8; -- number of internal vector registers min 2, each takes 8K
        C_vector_bram_pass_thru: boolean := false; -- number of internal vector registers min 2, each takes 8K
        C_vector_vaddr_bits: integer := 11; -- bits default 11: 2^11=2048 elements
        C_vector_vdata_bits: integer := 32; -- bits default 32: 32-bit float, don't touch
        C_vector_float_addsub: boolean := true; -- false will not have float addsub (+,-)
        C_vector_float_multiply: boolean := true; -- false will not have float multiply (*)
        C_vector_float_divide: boolean := true; -- false will not have float divide (/) will save much LUTs and DSPs

        C_dvid_ddr: boolean := true; -- false: clk_pixel_shift = 250MHz, true: clk_pixel_shift = 125MHz (DDR output driver)
        C_video_mode: integer := 1; -- 0:640x360, 1:640x480, 2:800x480, 3:800x600, 4:1024x576, 5:1024x768, 6:1280x768, 7:1280x1024, default 1

        C_vgahdmi: boolean := true;
          C_vgahdmi_axi: boolean := false; -- connect vgahdmi to video_axi_in/out instead to f32c bus arbiter
          C_vgahdmi_cache_size: integer := 0; -- KB video cache (only on f32c bus) (0: disable, 2,4,8,16,32:enable, default 8)
          C_vgahdmi_fifo_timeout: integer := 0; -- default 0
          C_vgahdmi_fifo_burst_max_bits: integer := 0; -- 6 bits -> 64x32-bit words
          C_vgahdmi_fifo_data_width: integer := 8; -- bits per pixel (default 32)

    C_vgatext: boolean := false; -- Xark's feature-rich bitmap+textmode VGA
      C_vgatext_label: string := "FFM-A7100: MIPS compatible soft-core 100MHz SDRAM"; -- default banner as initial content of screen BRAM, NOP for RAM
      C_vgatext_bits: integer := 4; -- 64 possible colors
      C_vgatext_bram_mem: integer := 0; -- KB (0: bram disabled -> use RAM)
      C_vgatext_bram_base: std_logic_vector(31 downto 28) := x"4"; -- textmode bram at 0x40000000
      C_vgatext_external_mem: integer := 32768; -- 32MB external SRAM/SDRAM
      C_vgatext_reset: boolean := true; -- reset registers to default with async reset
      C_vgatext_palette: boolean := true; -- no color palette
      C_vgatext_text: boolean := true; -- enable optional text generation
        C_vgatext_font_bram8: boolean := true; -- font in separate bram8 file (for Lattice XP2 BRAM or non power-of-two BRAM sizes)
        C_vgatext_char_height: integer := 16; -- character cell height 16: 80x30, 8: 80x60
        C_vgatext_font_height: integer := 16; -- font height 16: 80x30, 8: 80x60
        C_vgatext_font_depth: integer := 8; -- font char depth, 7=128 characters or 8=256 characters
        C_vgatext_font_linedouble: boolean := false; -- double font height by doubling each line (e.g., so 8x8 font fills 8x16 cell)
        C_vgatext_font_widthdouble: boolean := false; -- double font width by doubling each pixel (e.g., so 8 wide font is 16 wide cell)
        C_vgatext_monochrome: boolean := false; -- true for 2-color text for whole screen, else additional color attribute byte per character
        C_vgatext_finescroll: boolean := true; -- true for pixel level character scrolling and line length modulo
        C_vgatext_cursor: boolean := true; -- true for optional text cursor
        C_vgatext_cursor_blink: boolean := true; -- true for optional blinking text cursor
        C_vgatext_bus_read: boolean := false; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_reg_read: boolean := true; -- true to allow reading vgatext BRAM from CPU bus (may affect fmax). false is write only
        C_vgatext_text_fifo: boolean := true; -- enable text memory FIFO
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
          C_vgatext_bitmap_fifo_addr_width: integer := 11;

    C_sio: integer := 1;   -- 1 UART channel
    C_spi: integer := 2;   -- 2 SPI channels (ch0 not connected, ch1 SD card)
    C_timer: boolean := true; -- false: no timer
    C_ps2: boolean := false; -- no PS/2 keyboard
    C_gpio: integer := 32; -- 0: disabled, 32:32 GPIO bits
    C_simple_io: boolean := true -- includes 31 simple inputs and 32 simple outputs
  );
  port (
	clk_100mhz_p, clk_100mhz_n: in std_logic;
	uart3_txd: out std_logic;
	uart3_rxd: in std_logic;
	sd_m_cdet: in std_logic;
	sd_m_clk, sd_m_cmd: out std_logic;
	sd_m_d: inout std_logic_vector(3 downto 0);
	--FPGA_CCLK_CONF_DCLK: out std_logic;
	--FPGA_CSO, FPGA_MOSI: out std_logic;
	--FPGA_MISO_INTERNAL: in std_logic;
        --ddr3 ------------------------------------------------------------------
        --ddr3_dq                  : inout  std_logic_vector(C3_NUM_dq_PINS-1 downto 0);       -- mcb3_dram_dq
        --ddr3_a                   : out    std_logic_vector(C3_MEM_ADDR_WIDTH-1 downto 0);    -- mcb3_dram_a
        --ddr3_ba                  : out    std_logic_vector(C3_MEM_BANKADDR_WIDTH-1 downto 0);-- mcb3_dram_ba
        --ddr3_ras_n               : out    std_logic;                                         -- mcb3_dram_ras_n
        --ddr3_cas_n               : out    std_logic;                                         -- mcb3_dram_cas_n
        --ddr3_we_n                : out    std_logic;                                         -- mcb3_dram_we_n
        --ddr3_odt                 : out    std_logic;                                         -- mcb3_dram_odt
        --ddr3_cke                 : out    std_logic;                                         -- mcb3_dram_cke
        --ddr3_ldm                 : out    std_logic;                                         -- mcb3_dram_dm
        --ddr3_udm                 : out    std_logic;                                         -- mcb3_dram_udm
        --ddr3_dqs_p               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs
        --ddr3_dqs_n               : inout  std_logic_vector(1 downto 0);                      -- mcb3_dram_udqs_n
        --ddr3_ck_p                : out    std_logic;                                         -- mcb3_dram_ck
        --ddr3_ck_n                : out    std_logic;                                         -- mcb3_dram_ck_n
        --ddr3_reset_n             : out    std_logic;

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
	-- ADV7513 video chip
        dv_clk: out std_logic;
        dv_sda: inout std_logic;
        dv_scl: inout std_logic;
        --dv_int: out std_logic;
        dv_de: out std_logic;
        dv_hsync: out std_logic;
        dv_vsync: out std_logic;
        --dv_spdif: out std_logic;
        --dv_mclk: out std_logic;
        --dv_i2s: out std_logic_vector(3 downto 0);
        --dv_sclk: out std_logic;
        --dv_lrclk: out std_logic;
        dv_d: out std_logic_vector(23 downto 0);
	-- Low-Cost DVI video out
	vid_d_p, vid_d_n: out std_logic_vector(3 downto 0)
  );
end;

architecture Behavioral of ffm_xram_sdram is
    signal clk_100MHz_in: std_logic; -- converted from differential to single ended
    signal clk_fb: std_logic; -- feedback internally used in clock generator

    signal clk, sio_break: std_logic;
    signal clk_25MHz, clk_30MHz, clk_40MHz, clk_45MHz, clk_50MHz, clk_65MHz, clk_75MHz, clk_80MHz, clk_81MHz, clk_83MHz,
           clk_100MHz, clk_108MHz, clk_112M5Hz, clk_125MHz, clk_150MHz,
           clk_200MHz, clk_216MHz, clk_225MHz, clk_250MHz,
           clk_325MHz, clk_375MHz, clk_541MHz: std_logic := '0';
    signal clk_axi: std_logic;
    signal clk_pixel: std_logic;
    signal clk_pixel_shift: std_logic;
    signal clk_locked: std_logic := '0';
    signal cfgmclk: std_logic;
    type T_mode_clk_freq is array(0 to 7) of integer;
    -- CPU clocks for each video mode. must match PLL clock generator
    -- Use up to 83 MHz. 100 MHz is overclock which manifests
    -- as sometimes wrong integer multiplication in Galaga,
    -- descending group of ships becomes slightly disordered in x direction
    constant C_mode_clk_freq: T_mode_clk_freq :=
    (
      83, -- mode 0  640x360  83 100 MHz
      83, -- mode 1  640x480  83 100 MHz
      80, -- mode 2  800x480  80 100 MHz
      83, -- mode 3  800x600  83 100 MHz
      83, -- mode 4 1024x576  83 100 MHz
      81, -- mode 5 1024x768  81 108 MHz
      80, -- mode 6 1280x768  80 100 MHz
      83  -- mode 7 1280x1024 83 108 MHz
    );
    constant C_clk_freq: integer := C_mode_clk_freq(C_video_mode);

    signal calib_done: std_logic := '0';

    signal ram_en             : std_logic;
    signal ram_byte_we        : std_logic_vector(3 downto 0);
    signal ram_address        : std_logic_vector(29 downto 2);
    signal ram_data_write     : std_logic_vector(31 downto 0);
    signal ram_data_read      : std_logic_vector(31 downto 0);
    signal ram_read_busy      : std_logic := '0';
    signal ram_ready          : std_logic := '1';
    signal ram_cache_debug    : std_logic_vector(7 downto 0);
    signal ram_cache_hitcnt   : std_logic_vector(31 downto 0);
    signal ram_cache_readcnt  : std_logic_vector(31 downto 0);

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

    -- CPU memory axi port
    signal main_axi_areset_n: std_logic := '1';
    signal main_axi_miso: T_axi_miso;
    signal main_axi_mosi: T_axi_mosi;

    -- video axi port
    signal video_axi_areset_n: std_logic := '1';
    signal video_axi_aclk: std_logic;
    signal video_axi_miso: T_axi_miso;
    signal video_axi_mosi: T_axi_mosi;

    -- vector axi port
    signal vector_axi_areset_n: std_logic := '1';
    signal vector_axi_miso: T_axi_miso;
    signal vector_axi_mosi: T_axi_mosi;

    -- to switch glue/plasma vga
    signal glue_vga_vsync, glue_vga_hsync: std_logic;
    signal glue_vga_red, glue_vga_green, glue_vga_blue: std_logic_vector(7 downto 0);

    signal gpio: std_logic_vector(127 downto 0);
    signal simple_in: std_logic_vector(31 downto 0);
    signal simple_out: std_logic_vector(31 downto 0);
    signal S_ddr_d: std_logic_vector(3 downto 0);
    signal S_dvid_crgb: std_logic_vector(7 downto 0); -- clock, red, green, blue
begin
    -- convert differential input clock to single-ended
    clkin_ibufgds: ibufgds
    port map (I => clk_100MHz_P, IB => clk_100MHz_N, O => clk_100MHz_in);

    cpu83_100M_sdr_ddr_640x480: if (C_clk_freq = 83 or C_clk_freq = 100) and C_video_mode<=1 generate
    clk_cpu83_100M_sdr_ddr_640x480: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 10.0,   --  1000 MHz *10 common multiply
      divclk_divide    => 1,      --  1000 MHz /1 common divide
      clkout0_divide_f => 10.0,   --   100 MHz /10 divide
      clkout1_divide   => 5,      --   200 MHz /5 divide
      clkout2_divide   => 4,      --   250 MHz /4 divide
      clkout3_divide   => 8,      --   125 MHz /8 divide
      clkout4_divide   => 40,     --    25 MHz /40 divide
      clkout5_divide   => 12,     --    83.333 MHz /12 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_100MHz,
      clkout1  => clk_200MHz,
      clkout2  => clk_250MHz,
      clkout3  => clk_125MHz,
      clkout4  => clk_25MHz,
      clkout5  => clk_83MHz,
      locked   => clk_locked
    );
    cpu83M_sdr_640x480: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_sdr_640x480: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_25MHz;
    shift_sdr_640x480: if not C_dvid_ddr generate
      clk_pixel_shift <= clk_250MHz;
    end generate;
    shift_ddr_640x480: if C_dvid_ddr generate
      clk_pixel_shift <= clk_125MHz;
    end generate;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu80_100M_ddr_800x480: if (C_clk_freq = 80 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=2 generate
    clk_cpu80_100M_ddr_800x480: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 12.0,   --  1200 MHz *12 common multiply
      divclk_divide    => 1,      --  1200 MHz /1 common divide
      clkout0_divide_f => 8.0,    --   150 MHz /8 divide
      clkout1_divide   => 40,     --    30 MHz /40 divide
      clkout2_divide   => 12,     --   100 MHz /12 divide
      clkout3_divide   => 6,      --   200 MHz /6 divide
      clkout4_divide   => 15,     --    80 MHz /15 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_150MHz,
      clkout1  => clk_30MHz,
      clkout2  => clk_100MHz,
      clkout3  => clk_200MHz,
      clkout4  => clk_80MHz,
      locked   => clk_locked
    );
    cpu80M_ddr_800x480: if C_clk_freq = 80 generate
      clk <= clk_80MHz;
    end generate;
    cpu100M_ddr_800x480: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_30MHz;
    clk_pixel_shift <= clk_150MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu83_100M_ddr_800x600: if (C_clk_freq = 83 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=3 generate
    clk_cpu83_100M_ddr_800x600: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 10.0,   --  1000 MHz *10 common multiply
      divclk_divide    => 1,      --  1000 MHz /1 common divide
      clkout0_divide_f => 5.0,    --   200 MHz /5 divide
      clkout1_divide   => 25,     --    40 MHz /25 divide
      clkout2_divide   => 10,     --   100 MHz /10 divide
      clkout3_divide   => 12,     --    83.333 MHz /12 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_200MHz,
      clkout1  => clk_40MHz,
      clkout2  => clk_100MHz,
      clkout3  => clk_83MHz,
      locked   => clk_locked
    );
    cpu83M_ddr_800x600: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_ddr_800x600: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_40MHz;
    clk_pixel_shift <= clk_200MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu83_100M_ddr_1024x576: if (C_clk_freq = 83 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=4 generate
    clk_cpu83_100M_ddr_1024x576: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 10.0,   --  1000 MHz *10 common multiply
      divclk_divide    => 1,      --  1000 MHz /1 common divide
      clkout0_divide_f => 4.0,    --   250 MHz /4 divide
      clkout1_divide   => 20,     --    50 MHz /20 divide
      clkout2_divide   => 10,     --   100 MHz /10 divide
      clkout3_divide   => 5,      --   200 MHz /5 divide
      clkout4_divide   => 12,     --    83.333 MHz /12 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_250MHz,
      clkout1  => clk_50MHz,
      clkout2  => clk_100MHz,
      clkout3  => clk_200MHz,
      clkout4  => clk_83MHz,
      locked   => clk_locked
    );
    cpu83M_ddr_1024x576: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu100M_ddr_1024x576: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_50MHz;
    clk_pixel_shift <= clk_250MHz;
    video_axi_aclk <= clk_200MHz;
    clk_axi <= clk_200MHz;
    end generate;

    cpu81_108M_ddr_1024x768: if (C_clk_freq = 81 or C_clk_freq = 108) and C_dvid_ddr and C_video_mode=5 generate
    clk_cpu81_108M_ddr_1024x768: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 13.0,   --  1300 MHz *13 common multiply
      divclk_divide    => 1,      --  1300 MHz /1 common divide
      clkout0_divide_f => 4.0,    --   325 MHz /4 divide
      clkout1_divide   => 20,     --    65 MHz /20 divide
      clkout2_divide   => 6,      --   216 MHz /6 divide
      clkout3_divide   => 12,     --   108 MHz /12 divide
      clkout4_divide   => 16,     --    81.250 MHz /16 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_325MHz,
      clkout1  => clk_65MHz,
      clkout2  => clk_216MHz,
      clkout3  => clk_108MHz,
      clkout4  => clk_81MHz,
      locked   => clk_locked
    );
    cpu81M_ddr_1024x768: if C_clk_freq = 81 generate
      clk <= clk_81MHz;
    end generate;
    cpu108M_ddr_1024x768: if C_clk_freq = 108 generate
      clk <= clk_108MHz;
    end generate;
    clk_pixel <= clk_65MHz;
    clk_pixel_shift <= clk_325MHz;
    video_axi_aclk <= clk_216MHz;
    clk_axi <= clk_216MHz;
    end generate;

    cpu80_100M_ddr_1280x768: if (C_clk_freq = 80 or C_clk_freq = 100) and C_dvid_ddr and C_video_mode=6 generate
    clk_cpu80_100M_ddr_1280x768: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 11.25,  --  1125 MHz *11.25 common multiply
      divclk_divide    => 1,      --  1300 MHz /1 common divide
      clkout0_divide_f => 11.25,  --   100 MHz /11.25 divide
      clkout1_divide   => 5,      --   225 MHz /5 divide
      clkout2_divide   => 3,      --   375 MHz /3 divide
      clkout3_divide   => 15,     --    75 MHz /15 divide
      clkout4_divide   => 14,     --    80.357 MHz /14 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_100MHz,
      clkout1  => clk_225MHz,
      clkout2  => clk_375MHz,
      clkout3  => clk_75MHz,
      clkout4  => clk_80MHz,
      locked   => clk_locked
    );
    cpu80M_ddr_1280x768: if C_clk_freq = 80 generate
      clk <= clk_80MHz;
    end generate;
    cpu100M_ddr_1280x768: if C_clk_freq = 100 generate
      clk <= clk_100MHz;
    end generate;
    clk_pixel <= clk_75MHz;
    clk_pixel_shift <= clk_375MHz;
    video_axi_aclk <= clk_225MHz;
    clk_axi <= clk_225MHz;
    end generate;

    cpu83_108M_ddr_1280x1024: if (C_clk_freq = 83 or C_clk_freq = 108) and C_dvid_ddr and C_video_mode=7 generate
    clk_cpu83_108M_ddr_1280x1024: mmcme2_base
    generic map
    (
      clkin1_period    => 10.0,   --   100 MHz (10 ns)
      clkfbout_mult_f  => 32.5,   --  3250 MHz *32.5 common multiply
      divclk_divide    => 3,      --  1083.333 MHz /3 common divide
      clkout0_divide_f => 2.0,    --   541.666 MHz /2 divide
      clkout1_divide   => 5,      --   216.666 MHz /5 divide
      clkout2_divide   => 10,     --   108.333 MHz /10 divide
      clkout3_divide   => 13,     --    83.333 MHz /13 divide
      bandwidth        => "OPTIMIZED"
    )
    port map
    (
      pwrdwn   => '0',
      rst      => '0',
      clkin1   => clk_100MHz_in,
      clkfbin  => clk_fb,
      clkfbout => clk_fb,
      clkout0  => clk_541MHz,
      clkout1  => clk_216MHz,
      clkout2  => clk_108MHz,
      clkout3  => clk_83MHz,
      locked   => clk_locked
    );
    cpu83M_ddr_1280x1024: if C_clk_freq = 83 generate
      clk <= clk_83MHz;
    end generate;
    cpu108M_ddr_1280x1024: if C_clk_freq = 108 generate
      clk <= clk_108MHz;
    end generate;
    clk_pixel <= clk_108MHz;
    clk_pixel_shift <= clk_541MHz;
    video_axi_aclk <= clk_216MHz;
    clk_axi <= clk_216MHz;
    end generate;

    G_vendor_specific_startup: if C_vendor_specific_startup generate
    -- reset hard-block: Xilinx Artix-7 specific
    reset: startupe2
    generic map (
      prog_usr => "FALSE"
    )
    port map (
      cfgmclk => cfgmclk,
      clk => cfgmclk,
      gsr => sio_break,
      gts => '0',
      keyclearb => '0',
      pack => '1',
      usrcclko => clk,
      usrcclkts => '0',
      usrdoneo => '1',
      usrdonets => '0'
    );
    end generate;

    -- generic XRAM glue
    glue_xram: entity work.glue_xram
    generic map (
      C_clk_freq => C_clk_freq,
      C_arch => C_arch,
      C_bram_size => C_bram_size,
      C_boot_write_protect => C_boot_write_protect,
      C_sdram => C_sdram,
      C_sdram32 => C_sdram32,
      C_sdram_clock_range => C_sdram_clock_range,
      C_axiram => C_axiram,
      C_icache_size => C_icache_size,
      C_dcache_size => C_dcache_size,
      C_cached_addr_bits => C_cached_addr_bits,
      C_mult_enable => C_mult_enable, C_mul_acc => C_mul_acc, C_mul_reg => C_mul_reg,
      C_gpio => C_gpio,
      C_timer => C_timer,
      C_sio => C_sio,
      C_spi => C_spi,
      C_vector => C_vector,
      C_vector_axi => C_vector_axi,
      C_vector_burst_max_bits => C_vector_burst_max_bits,
      C_vector_registers => C_vector_registers,
      C_vector_bram_pass_thru => C_vector_bram_pass_thru,
      C_vector_vaddr_bits => C_vector_vaddr_bits,
      C_vector_vdata_bits => C_vector_vdata_bits,
      C_vector_float_addsub => C_vector_float_addsub,
      C_vector_float_multiply => C_vector_float_multiply,
      C_vector_float_divide => C_vector_float_divide,
      C_dvid_ddr => C_dvid_ddr,
      -- Video settings
      C_vgahdmi => C_vgahdmi,
      C_vgahdmi_mode => C_video_mode,
      C_vgahdmi_axi => C_vgahdmi_axi,
      C_vgahdmi_cache_size => C_vgahdmi_cache_size,
      C_vgahdmi_fifo_timeout => C_vgahdmi_fifo_timeout,
      C_vgahdmi_fifo_burst_max_bits => C_vgahdmi_fifo_burst_max_bits,
      C_vgahdmi_fifo_data_width => C_vgahdmi_fifo_data_width,

      -- vga advanced graphics text+compositing bitmap
      C_vgatext => C_vgatext,
      C_vgatext_label => C_vgatext_label,
      C_vgatext_mode => C_video_mode,
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
      C_vgatext_bitmap_fifo_addr_width => C_vgatext_bitmap_fifo_addr_width,

      C_debug => C_debug
    )
    port map (
        clk => clk,
	clk_pixel => clk_pixel,
	clk_pixel_shift => clk_pixel_shift,
	cpu_axi_in => main_axi_miso,
	cpu_axi_out => main_axi_mosi,
        video_axi_aresetn => video_axi_areset_n,
        video_axi_aclk => video_axi_aclk,
        video_axi_in => video_axi_miso,
        video_axi_out => video_axi_mosi,
        vector_axi_in => vector_axi_miso,
        vector_axi_out => vector_axi_mosi,
        sdram_addr => dr_a, sdram_data => dr_d,
        sdram_ba => dr_ba, sdram_dqm => dr_dqm,
        sdram_ras => dr_ras_n, sdram_cas => dr_cas_n,
        sdram_cke => dr_cke, sdram_clk => dr_clk,
        sdram_we => dr_we_n, sdram_cs => dr_cs_n,
	sio_txd(0) => uart3_txd,
	sio_rxd(0) => uart3_rxd,
	sio_break(0) => sio_break,
        spi_sck(0)  => open,  spi_sck(1)  => SD_M_CLK,
        spi_ss(0)   => open,  spi_ss(1)   => SD_M_D(3),
        spi_mosi(0) => open,  spi_mosi(1) => SD_M_CMD,
        spi_miso(0) => '-',   spi_miso(1) => SD_M_D(0),
	gpio(89 downto 0) => open,
	gpio(127 downto 90) => open,
	-- VGA
        vga_hsync => S_vga_hsync,
        vga_vsync => S_vga_vsync,
        vga_blank => S_vga_blank,
        vga_r => dv_d(23 downto 16),
        vga_g => dv_d(15 downto 8),
        vga_b => dv_d(7 downto 0),
	-- DVI
        dvid_clock => S_dvid_crgb(7 downto 6),
        dvid_red   => S_dvid_crgb(5 downto 4),
        dvid_green => S_dvid_crgb(3 downto 2),
        dvid_blue  => S_dvid_crgb(1 downto 0),
	-- simple I/O
	simple_out(31 downto 0) => open,
	-- simple_out(0) => led,
        simple_in(31 downto 1) => (others => '-'),
	simple_in(0) => sd_m_cdet
    );

    dv_clk <= clk_pixel;
    dv_hsync <= S_vga_hsync;
    dv_vsync <= S_vga_vsync;
    dv_de <= not S_vga_blank;

    i2c_send: entity work.i2c_sender
      port map
      (
        clk => clk_pixel,
        resend => '0',
        sioc => dv_scl,
        siod => dv_sda
      );

    G_dvi_sdr: if not C_dvid_ddr generate
    gpdi_sdr_se: for i in 0 to 3 generate
      vid_d_p(i) <= S_dvid_crgb(2*i);
      vid_d_n(i) <= not S_dvid_crgb(2*i);
    end generate;
    end generate;

    G_dvi_ddr: if C_dvid_ddr generate
    -- vendor specific DDR and differential modules
    gpdi_ddr_diff: for i in 0 to 3 generate
      gpdi_ddr:   oddr generic map (DDR_CLK_EDGE => "SAME_EDGE", INIT => '0', SRTYPE => "SYNC") port map (D1=>S_dvid_crgb(2*i), D2=>S_dvid_crgb(2*i+1), Q=>S_ddr_d(i), C=>clk_pixel_shift, CE=>'1', R=>'0', S=>'0');
      gpdi_diff:  obufds port map(i => S_ddr_d(i), o => vid_d_p(i), ob => vid_d_n(i));
    end generate;
    end generate;

    G_axiram_real: if C_axiram generate
    --u_ddr_mem : entity work.axi_mpmc
    --generic map
    --(
    --  C_mig_data_bits => C_axi_mig_data_bits, -- 32 or 128
    --  C_mig_wstrb_bits => C_axi_mig_data_bits/8  -- 4 or 16 (byte_select, normally C_mig_data_bits/8)
    --)
    --port map(
    --    sys_rst              => not clk_locked, -- release reset when clock is stable
    --    sys_clk_i            => clk_axi, -- not less than 200MHz, but not too much faster either
        -- physical signals to RAM chip
    --    ddr3_dq              => ddr_dq,
    --    ddr3_dqs_n           => ddr_dqs_n,
    --    ddr3_dqs_p           => ddr_dqs_p,
    --    ddr3_addr            => ddr_a,
    --    ddr3_ba              => ddr_ba,
    --    ddr3_ras_n           => ddr_ras_n,
    --    ddr3_cas_n           => ddr_cas_n,
    --    ddr3_we_n            => ddr_we_n,
    --    ddr3_reset_n         => ddr_reset_n,
    --    ddr3_ck_p(0)         => ddr_ck_p,
    --    ddr3_ck_n(0)         => ddr_ck_n,
    --    ddr3_cke(0)          => ddr_cke,
    --    ddr3_dm(1)           => ddr_udm,
    --    ddr3_dm(0)           => ddr_ldm,
    --    ddr3_odt(0)          => ddr_odt,

        -- multiport axi interface (AXI slaves)
    --    s00_axi_areset_out_n => main_axi_areset_n,
    --    s00_axi_aclk         => clk,
    --    s00_axi_in           => main_axi_mosi,
    --    s00_axi_out          => main_axi_miso,

    --    s01_axi_areset_out_n => vector_axi_areset_n,
    --    s01_axi_aclk         => clk,
    --    s01_axi_in           => vector_axi_mosi,
    --    s01_axi_out          => vector_axi_miso,

    --    s02_axi_areset_out_n => video_axi_areset_n,
    --    s02_axi_aclk         => video_axi_aclk,
    --    s02_axi_in           => video_axi_mosi,
    --    s02_axi_out          => video_axi_miso,

    --    init_calib_complete  => calib_done -- becomes high cca 0.3 seconds after startup
    --);
    end generate; -- G_acram_real

end Behavioral;

