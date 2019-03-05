
--
-- Menlopark Innovation LLC
--
-- 03/03/2019
--
-- Created from f32c\rtl\generic\glue_bram.vhd to incorporate
-- SDR.
--
-- Note: Lots of comments in this file that shows how I/O decoding
-- and interfacing of SoC modules works.
--
-- TODO: Rename fmrds -> sdr for the SoC, but keep fmrds options.
--

--
-- Copyright (c) 2015 Marko Zec, University of Zagreb
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

use work.f32c_pack.all;


entity sdr_glue_bram is
    generic (
	C_clk_freq: integer;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"0001ffff"; -- 128 K
	C_exceptions: boolean := true;

	-- COP0 options
	C_cop0_count: boolean := true;
	C_cop0_compare: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;

	-- Negatively influences timing closure, hence disabled
	C_movn_movz: boolean := false;

	-- CPU debugging
	C_debug: boolean := false;

	-- SoC configuration options
	C_bram_size: integer := 16;	-- in KBytes
	C_boot_spi: boolean := false;
	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
	C_sio_fixed_baudrate: boolean := false;
	C_sio_break_detect: boolean := true;
	C_spi: integer := 0;
	C_spi_turbo_mode: std_logic_vector := "0000";
	C_spi_fixed_speed: std_logic_vector := "1111";
	C_simple_in: integer range 0 to 128 := 32;
	C_simple_out: integer range 0 to 128 := 32;
	C_gpio: integer range 0 to 128 := 32;
	C_timer: boolean := true;

        -- Optional SoC modules
      
        --
        -- FM RDS options for SoC SDR
        --
	C_fmrds: boolean := false; -- Enables compilation of SoC SDR module.
	C_fm_stereo: boolean := false;
        C_fm_filter: boolean := false;
        C_fm_downsample: boolean := false;
	C_rds_msg_len: integer := 260; -- bytes of circular sent message, typical 52 for PS or 260 PS+RT
        C_fmdds_hz: integer := 250000000; -- Hz clk_fmdds (>2*108 MHz, 250Mhz default)
        C_rds_clock_multiply: integer := 57; -- multiply 57 and divide 3125 from cpu clk 100 MHz
        C_rds_clock_divide: integer := 3125 -- to get 1.824 MHz for RDS logic
    );
    port (
	clk: in std_logic;
	sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
	sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
	spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
	spi_miso: in std_logic_vector(C_spi - 1 downto 0);
	simple_in: in std_logic_vector(31 downto 0);
	simple_out: out std_logic_vector(31 downto 0);
	gpio: inout std_logic_vector(127 downto 0);

        -- FM RDS for SoC SDR
	clk_fmdds: in std_logic := '0'; -- DDS clock (250Mhz typical)
	fm_antenna: out std_logic
    );
end sdr_glue_bram;

architecture Behavioral of sdr_glue_bram is

    -- signals to / from f32c cores(s)
    signal intr: std_logic_vector(5 downto 0);
    signal imem_addr, dmem_addr: std_logic_vector(31 downto 2);
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: std_logic;
    signal imem_data_ready, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal cpu_to_dmem: std_logic_vector(31 downto 0);
    signal io_to_cpu, final_to_cpu_d: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);

    -- Block RAM
    signal bram_i_to_cpu, bram_d_to_cpu: std_logic_vector(31 downto 0);
    signal bram_i_ready, bram_d_ready, dmem_bram_enable: std_logic;

    -- Timer
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;
    
    -- GPIO
    constant C_gpios: integer := (C_gpio+31)/32; -- number of gpio units
    type gpios_type is array (C_gpios-1 downto 0) of std_logic_vector(31 downto 0);
    signal from_gpio, gpios: gpios_type;
    signal gpio_ce: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr_joint: std_logic := '0';

    -- Serial I/O (RS232)
    type from_sio_type is array (0 to C_sio - 1) of
      std_logic_vector(31 downto 0);
    signal from_sio: from_sio_type;
    signal sio_ce, sio_tx, sio_rx: std_logic_vector(C_sio - 1 downto 0);
    signal sio_break_internal: std_logic_vector(C_sio - 1 downto 0);

    -- SPI (on-board Flash, SD card, others...)
    type from_spi_type is array (0 to C_spi - 1) of
      std_logic_vector(31 downto 0);
    signal from_spi: from_spi_type;
    signal spi_ce: std_logic_vector(C_spi - 1 downto 0);

    -- Simple I/O: onboard LEDs, buttons and switches
    -- Menlo: This is a registered signal.
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);
   
    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_debug: std_logic_vector(7 downto 0);
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

    -- Menlo:
    --
    -- IO Map support
    --
    -- The upper half page of the 32 bit address space is "IO Space".
    --
    -- This is 2048 bytes from 0xFFFFF800 - 0xFFFFFFFF.
    --
    -- Since byte steering logic may not exist, from looking at code they
    -- decode a number of 32 bit registers, but only access the lower
    -- byte. Sparse addressing typical of processors with fixed buses
    -- such as Alpha, and even 68000 with byte/word addressing.
    --
    -- The T_iomap_range is an array that stores two 16 bit values.
    -- Both are used in the start of the range calculation, but only
    -- the first entry is used in the end of range calculations.
    --
    --
    type T_iomap_range is array(0 to 1) of std_logic_vector(15 downto 0);

    -- actual range is 0xFFFFF800 .. 0xFFFFFFFF
    constant iomap_range: T_iomap_range := (x"F800", x"FFFF");

    function iomap_from(r: T_iomap_range; base: T_iomap_range) return integer is
       variable a, b: std_logic_vector(15 downto 0);
    begin
       a := r(0);
       b := base(0);
       return conv_integer(a(11 downto 4) - b(11 downto 4));
    end iomap_from;

    function iomap_to(r: T_iomap_range; base: T_iomap_range) return integer is
       variable a, b: std_logic_vector(15 downto 0);
    begin
       a := r(1);
       b := base(0);
       return conv_integer(a(11 downto 4) - b(11 downto 4));
    end iomap_to;

    --
    -- Menlo:
    --
    -- SoC SDR, Software Defined Radio.
    --
    -- Built from, and incorporates the functionsn of FM RDS
    -- but adds shortwave frequency coverage in addition
    -- to other modulation modes.
    --
    -- The FM RDS registers are documented in SDR.h:
    --
    -- SoC SDR
    signal from_sdr: std_logic_vector(31 downto 0);
    signal sdr_ce: std_logic;

begin

    -- f32c core
    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_cop0_compare => C_cop0_compare,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => sio_break_internal(0), intr => intr,
	imem_addr => imem_addr, imem_data_in => bram_i_to_cpu,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu_d, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => '0', snoop_addr => "------------------------------",
	flush_i_line => open, flush_d_line => open,
	-- debugging
	debug_in_data => sio_to_debug_data,
	debug_in_strobe => deb_sio_rx_done,
	debug_in_busy => open,
	debug_out_data => debug_to_sio_data,
	debug_out_strobe => deb_sio_tx_strobe,
	debug_out_busy => deb_sio_tx_busy,
	debug_debug => debug_debug,
	debug_active => debug_active
    );

    -- Menlo: Multiplex data to CPU from either the I/O or the BRAM memory bus.
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1' else bram_d_to_cpu;

    intr <= "00" & gpio_intr_joint & timer_intr & from_sio(0)(8) & '0';

--
-- Menlo:
--
-- Block RAM address space.
--
-- ---------------------------------------------------------------------------------
-- | 3 3 2 2 | 2 2 2 2 | 2 2 2 2 | 1 1 1 1 | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
-- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 | 9 8 7 6 | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
-- ---------------------------------------------------------------------------------
-- | 0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0 | 0x0000_0000
-- ---------------------------------------------------------------------------------
--   0         0         0         0         0         0         0         0
-- ---------------------------------------------------------------------------------
-- | 0 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1 | 0x7FFF_FFFF
-- ---------------------------------------------------------------------------------
--   7         F         F         F         F         F         F         F
--

--
-- External bus address space.
--
-- This is not used in this module, but in others. This represents off FPGA
-- memory such as SDRAM, or AXI bus bridges to DRAM shared with a SoC.
--
-- In most F32C projects these are still "on chip" buses, though they could
-- be bridge to PCIe on a larger design, unless its expressed through the
-- AXI bus address space.
--
-- Note: Due to this only being a 32 bit core PCIe interfaces would need
-- some sort of a mapping window for direct PCIe access.
--
-- ---------------------------------------------------------------------------------
-- | 3 3 2 2 | 2 2 2 2 | 2 2 2 2 | 1 1 1 1 | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
-- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 | 9 8 7 6 | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
-- ---------------------------------------------------------------------------------
-- | 1 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0 | 0x8000_0000
-- ---------------------------------------------------------------------------------
--   8         0         0         0         0         0         0         0
-- ---------------------------------------------------------------------------------
-- | 1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   0 1 1 1   1 1 1 1   1 1 1 1 | 0xFFFF_F7FF
-- ---------------------------------------------------------------------------------
--   F         F         F         F         F         7         F         F
--

--
-- Menlo:
--
-- I/O is memory mapped in the read/write data memory space of the CPU core.
--
-- Logic in the CPU and cache controllers ensure these are no-cache accesses.
--
-- I/O addresses have an 11 bit range starting at 0xFFFF_F800 officially.
--
-- This provides 2K of I/O decode space from 0xFFFF_F800 - 0xFFFF_FFFF.
--
-- This is defined in io.h for the F32C processor/core.
--
-- FPGAArduino\arduino\hardware\fpga\f32c\system\include\dev\io.h
-- #define	IO_BASE		0xfffff800
--
-- ---------------------------------------------------------------------------------
-- | 3 3 2 2 | 2 2 2 2 | 2 2 2 2 | 1 1 1 1 | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
-- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 | 9 8 7 6 | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
-- ---------------------------------------------------------------------------------
-- | 1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 0 0 0   0 0 0 0   0 0 0 0 |
-- ---------------------------------------------------------------------------------
--   F         F         F         F         F         8         0         0
--

--
-- Menlo:
--
-- MIPS and RISC-V I/O memory mapping details:
--
-- MIPS and RISC-V architectures require all 32 bit word access to be
-- on 32 bit word boundaries (A1 == 0, A0 == 0), otherwise an exception occurs.
-- Since instructions are always 32 bit word accesses, all instruction fetches
-- meet this requirement (or an exception is generated on an illegal jump/branch).
--
-- MIPS and RISC-V do support memory byte read and write instructions, which
-- can occur on byte addresses. Note that addresses 1 and 0 are not presented
-- outside the CPU as they are decoded within the CPU into four "byte selects"
-- provided on the vector signal dmem_byte_sel(3 downto 0). This means that
-- I/O has to take care for byte accesses to enable the proper Dx bit lane
-- according to the byte select signals.
--
-- This means that addresses coming from the CPU represent 32 bit word addresses
-- and are represented by the vector CPU memory signal dmem_addr(31 downto 2).
--
-- For I/O byte access, "byte steering" logic exists in the core to shift the
-- byte to/from the proper Dx bit lanes so it ends up in bits 7 downto 0 of the
-- CPU register. As a result, which address the lower byte of external memory
-- or I/O register depends on the endianness of the processor configuration. As
-- result of this common practice is to read a 32 bit word register and mask
-- to the lower bits to get the byte. This takes advantage of the byte steering
-- logic in the CPU. This becomes more complex as writes to byte registers
-- occur, and the hardware has to decode sparsely placing byte registers
-- on 32 bit word boundaries, or expose the endianness to the programmer.
--

--
-- Menlo:
--
-- This module decodes only the upper two bits to be 0xC000_0000 and allows
-- the official I/O address of 0xFFFF_F800 to be used due to aliasing of the
-- don't care non-decoded bits marked by X's.
--
-- This makes its I/O decode respond to the range 0xC000_000 - 0xFFFF_FFFF.
--
-- Since there are no address windows for external SDRAM and AXI bus there are
-- no conflicts with other address ranges. The convention on F32C is that addresses
-- below 0x8000_0000 are BRAM addresses, while addresses above are "off chip".
--
-- ---------------------------------------------------------------------------------
-- | 3 3 2 2 | 2 2 2 2 | 2 2 2 2 | 1 1 1 1 | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
-- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 | 9 8 7 6 | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
-- ---------------------------------------------------------------------------------
-- | 1 1 X X   X X X X   X X X X   X X X X   X X X X   1 0 0 0   0 0 0 0   0 0 X X |
-- ---------------------------------------------------------------------------------
--   C         X         X         X         X         8         0         0
--

    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11"
      else '0';

    --
    -- Menlo:
    --
    -- I/O addresses have an 11 bit range from 0xFFFF_F800 - 0xFFFF_FFFF officially.
    --
    -- To make matters easy for the decoders, bit 11 is set to 0 as it represents
    -- part of the I/O base address, and not the specific SoC device whose address
    -- is an offset from this base.
    --
    -- Note that A1 and A0 don't exist as they are byte selects.
    --
    -- ---------------------------
    -- | 1 1 | 0 0 0 0 | 0 0 0 0 |
    -- | 1 0 | 9 8 7 6 | 5 4 3 2 |
    -- ---------------------------
    --   0 X X X X X X X X X X X
    --

    --
    -- Menlo:
    --
    -- Master I/O Map
    --
    -- I/O base address is 0xFFFF_F800 which is 11 bits of decode.
    --
    -- I/O decoder base address forces A11 to 0 to make the decodes easier:
    --
    -- -------------------------------
    -- | A A A A | A A A A | A A A A |
    -- | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
    -- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
    -- -------------------------------
    -- | 0 x x x   x x x x   x x x x |
    -- -------------------------------
    --   | | | |   | | | |   | | | |
    --   + + + +   + + + +   + + + +
    --   0 0 0 0   0 0 0 0   0 0 0 0 0x000 IO_GPIO_DATA begin subdecodes 6 down to 5
    --   0 0 0 0   0 1 1 1   1 1 1 1 0x07F IO_GPIO_DATA end (supports 4 instances with A6 + A5)
    --   0 0 0 0   1 1 1 1   1 1 1 1 0x0FF Guard band for GPIO growth and loose decoding.
    --   + + + +   + + + +   + + + +
    --   0 0 0 1   0 0 0 0   0 0 0 0 0x100 IO_TIMER begin
    --   0 0 0 1   0 0 1 1   1 1 1 1 0x13F IO_TIMER end
    --   0 0 0 1   1 1 1 1   1 1 1 1 0x1FF timer_ce end (timer_ce decodes this range)
    --   + + + +   + + + +   + + + +
    --   0 0 1 1   0 0 0 0   0 0 0 0 0x300 IO_SIO_BYTE begin Note: subdecodes 5 downto 4
    --   0 0 1 1   0 0 1 1   1 1 1 1 0x33F IO_SIO_BYTE end
    --   + + + +   + + + +   + + + +
    --   0 0 1 1   0 1 0 0   0 0 0 0 0x340 IO_SPI_FLASH begin Note: subdecodes 5 downto 4
    --   0 0 1 1   0 1 1 1   1 1 1 1 0x37F IO_SPI_FLASH end
    --   + + + +   + + + +   + + + +
    --   0 1 0 0   0 0 0 0   0 0 0 0 0x400 FMRDS begin 64K decode block for FMRDS
    --   0 1 0 0   1 1 1 1   1 1 1 1 0x4FF FMRDS end CPU address 0xFFFF_FC00 - 0xFFFF_FCFF
    --   + + + +   + + + +   + + + +
    --   0 1 1 1   0 0 0 0   0 0 0 0 0x700 IO_PUSHBTN begin
    --   0 1 1 1   0 0 0 0   1 1 1 1 0x70F IO_PUSHBTN end
    --   + + + +   + + + +   + + + +
    --   0 1 1 1   0 0 0 1   0 0 0 0 0x710 IO_LED begin
    --   0 1 1 1   0 0 0 1   1 1 1 1 0x71F IO_LED end
    --   + + + +   + + + +   + + + +
    --

    io_addr <= '0' & dmem_addr(10 downto 2);

    imem_data_ready <= bram_i_ready;
    dmem_data_ready <= bram_d_ready when dmem_addr(31) = '0' else '1';

    --
    -- Menlo:
    --
    -- #define	IO_SIO_BYTE	IO_ADDR(0x300)	/* byte, RW */
    --
    -- IO_BASE + 0x300 => IO_BASE + 0x33F
    --
    -- RS232 sio
    --
    G_sio: for i in 0 to C_sio - 1 generate
	sio_instance: entity work.sio
	generic map (
	    C_clk_freq => C_clk_freq,
	    C_init_baudrate => C_sio_init_baudrate,
	    C_fixed_baudrate => C_sio_fixed_baudrate,
	    C_break_detect => C_sio_break_detect,
	    C_break_resets_baudrate => C_sio_break_detect,
	    C_big_endian => C_big_endian
	)
	port map (
	    clk => clk, ce => sio_ce(i), txd => sio_tx(i), rxd => sio_rx(i),
	    bus_write => dmem_write, byte_sel => dmem_byte_sel,
	    bus_in => cpu_to_dmem, bus_out => from_sio(i),
	    break => sio_break_internal(i)
	);
	sio_ce(i) <= io_addr_strobe when io_addr(11 downto 6) = x"3" & "00" and
	  conv_integer(io_addr(5 downto 4)) = i else '0';
	sio_break(i) <= sio_break_internal(i);
    end generate;
    sio_rx(0) <= sio_rxd(0);

    --
    -- Menlo:
    --
    -- #define	IO_SPI_FLASH	IO_ADDR(0x340)	/* half, RW */
    -- #define	IO_SPI_SDCARD	IO_ADDR(0x350)	/* half, RW */
    --
    -- SPI
    --
    G_spi: for i in 0 to C_spi - 1 generate
	spi_instance: entity work.spi
	generic map (
	    C_turbo_mode => C_spi_turbo_mode(i) = '1',
	    C_fixed_speed => C_spi_fixed_speed(i) = '1'
	)
	port map (
	    clk => clk, ce => spi_ce(i),
	    bus_write => dmem_write, byte_sel => dmem_byte_sel,
	    bus_in => cpu_to_dmem, bus_out => from_spi(i),
	    spi_sck => spi_sck(i), spi_cen => spi_ss(i),
	    spi_miso => spi_miso(i), spi_mosi => spi_mosi(i)
	);
	spi_ce(i) <= io_addr_strobe when io_addr(11 downto 6) = x"3" & "01" and
	  conv_integer(io_addr(5 downto 4)) = i else '0';
    end generate;

    --
    -- Menlo:
    --
    -- Process I/O writes to simple out
    --
    -- IO_LED
    -- IO_BASE + 0x710 => IO_BASE + 0x71F
    --
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then

	    if C_simple_out > 0 and io_addr(11 downto 4) = x"71" then

                --
                -- Menlo: Byte select decodes based on byte_sel
                --

		if dmem_byte_sel(0) = '1' then
		    R_simple_out(7 downto 0) <= cpu_to_dmem(7 downto 0);
		end if;
		if dmem_byte_sel(1) = '1' then
		    R_simple_out(15 downto 8) <= cpu_to_dmem(15 downto 8);
		end if;
		if dmem_byte_sel(2) = '1' then
		    R_simple_out(23 downto 16) <= cpu_to_dmem(23 downto 16);
		end if;
		if dmem_byte_sel(3) = '1' then
		    R_simple_out(31 downto 24) <= cpu_to_dmem(31 downto 24);
		end if;
	    end if;
	end if;
	if rising_edge(clk) then
	    R_simple_in(C_simple_in - 1 downto 0) <=
	      simple_in(C_simple_in - 1 downto 0);
	end if;
    end process;

    G_simple_out_standard:
    if C_timer = false generate
	simple_out(C_simple_out - 1 downto 0) <=
	  R_simple_out(C_simple_out - 1 downto 0);
    end generate;

    -- muxing simple_io to show PWM of timer on LEDs
    G_simple_out_timer:
    if C_timer = true generate
      ocp_mux(0) <= ocp(0) when ocp_enable(0)='1' else R_simple_out(1);
      ocp_mux(1) <= ocp(1) when ocp_enable(1)='1' else R_simple_out(2);
      simple_out <= R_simple_out(31 downto 3) & ocp_mux & R_simple_out(0) when C_simple_out > 0
        else (others => '-');
    end generate;

    --
    -- address decoder and input mux when CPU reads IO
    --
    process(io_addr, R_simple_in, R_simple_out, from_sio, from_timer, from_gpio, from_sdr)
	variable i: integer;
    begin
	io_to_cpu <= (others => '-');

	case conv_integer(io_addr(11 downto 4)) is

        -- IO_GPIO_DATA
        -- IO_BASE + 0x000 => IO_BASE + 0x07F
	when 16#00# to 16#07# =>
	    for i in 0 to C_gpios - 1 loop
		if conv_integer(io_addr(6 downto 5)) = i then
		    io_to_cpu <= from_gpio(i);
		end if;
	    end loop;

        -- IO_TIMER
        -- IO_BASE + 0x100 => IO_BASE + 0x13F
	when 16#10# to 16#13# =>
	    if C_timer then
		io_to_cpu <= from_timer;
	    end if;

        -- IO_SIO_BYTE
        -- IO_BASE + 0x300 => IO_BASE + 0x33F
	when 16#30# to 16#33# =>
	    for i in 0 to C_sio - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_sio(i);
		end if;
	    end loop;

        -- IO_SPI_FLASH
        -- IO_SPI_SDCARD
        -- IO_BASE + 0x340 => IO_BASE + 0x37F
	when 16#34# to 16#37# =>
	    for i in 0 to C_spi - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_spi(i);
		end if;
	    end loop;

        --
        -- Menlo:
        --
        -- SDR IO_BASE + 0x400 => IO_BASE + 0x4FF
        -- 0xFFFF_FC00 => 0xFFF_FCFF
        --
	when 16#40# =>
	    if C_fmrds then
		io_to_cpu <= from_sdr;
	    end if;

        -- IO_PUSHBTN
        -- IO_BASE + 0x700 => IO_BASE + 0x70F
	when 16#70#  =>
	    for i in 0 to (C_simple_in + 31) / 32 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(i * 32 + 31 downto i * 32) <=
		      R_simple_in(i * 32 + 31 downto i * 32);
		end if;
	    end loop;

        --
        -- IO_LED
        -- IO_BASE + 0x710 => IO_BASE + 0x71F
        --
        -- Simple_out can be up to 128 bits. This represents (4) 32 bit words
        -- decoded in ioaddr(3 downto 2).
        --
	-- C_simple_out: integer range 0 to 128 := 32;
        --
	when 16#71#  =>
	    for i in 0 to (C_simple_out + 31) / 32 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(i * 32 + 31 downto i * 32) <=
		      R_simple_out(i * 32 + 31 downto i * 32);
		end if;
	    end loop;

	when others  =>
	    io_to_cpu <= (others => '-');
	end case;

    end process;

    --
    -- Menlo:
    --
    -- GPIO
    --
    -- Each GPIO unit is 32 bits.
    --
    -- 0x000 - 0x07F
    --
    -- 11 downto 5 => index of instance.
    --
    G_gpio:
    for i in 0 to C_gpios-1 generate
    gpio_inst: entity work.gpio
    generic map (
	C_bits => 32
    )
    port map (
	clk => clk, ce => gpio_ce(i), addr => dmem_addr(4 downto 2),
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_gpio(i),
	gpio_irq => gpio_intr(i),
	gpio_phys => gpio(32*i+31 downto 32*i) -- physical input/output
    );
    gpio_ce(i) <= io_addr_strobe when conv_integer(io_addr(11 downto 5)) = i else '0';
    end generate;
    gpio_interrupt_collect: if C_gpios >= 1 generate
      gpio_intr_joint <= gpio_intr(0);
      -- TODO: currently only 32 gpio supported in fpgarduino core
      -- when support for 128 gpio is there we should use this:
      -- gpio_intr_joint <= '0' when conv_integer(gpio_intr) = 0 else '1';
    end generate;

    --
    -- Menlo:
    --
    -- Timer
    --
    -- 0x100 - 0x13F
    --
    -- 0x1FF guard band due to loose decoder.
    --
    G_timer:
    if C_timer generate
    icp <= R_simple_out(3) & R_simple_out(0); -- during debug period, leds will serve as software-generated ICP
    timer: entity work.timer
    generic map (
	C_pres => 10,
	C_bits => 12
    )
    port map (
	clk => clk, ce => timer_ce, addr => dmem_addr(5 downto 2),
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_timer,
	timer_irq => timer_intr,
	ocp_enable => ocp_enable, -- enable physical output
	ocp => ocp, -- output compare signal
	icp_enable => icp_enable, -- enable physical input
	icp => icp -- input capture signal
    );

    --
    -- Menlo:
    --
    -- FPGAArduino\hardware\fpga\f32c\system\include\dev\io.h
    --
    -- #define	IO_BASE		0xfffff800
    --
    -- #define	IO_ADDR(a)	(IO_BASE | (a))
    --
    -- #define	IO_TIMER	IO_ADDR(0x100)	/* 16-byte, WR */
    --
    -- This places IO_TIMER at (0xFFFF_F800 | 0x0000_0100) == 0xFFFF_F900
    --
    -- ---------------------------------------------------------------------------------
    -- | A A A A | A A A A | A A A A | A A A A | A A A A | A A A A | A A A A | A A A A |
    -- | 3 3 2 2 | 2 2 2 2 | 2 2 2 2 | 1 1 1 1 | 1 1 1 1 | 1 1 0 0 | 0 0 0 0 | 0 0 0 0 |
    -- | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 | 9 8 7 6 | 5 4 3 2 | 1 0 9 8 | 7 6 5 4 | 3 2 1 0 |
    -- ---------------------------------------------------------------------------------
    --
    -- ---------------------------------------------------------------------------------
    -- | 1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 0 0 0   X X X X   X X X X |
    -- ---------------------------------------------------------------------------------
    -- | F         F         F         F         F         8         0         0       | 0xFFFF_F800
    -- ---------------------------------------------------------------------------------
    --
    -- ---------------------------------------------------------------------------------
    -- | 0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 0   0 0 0 1   0 0 0 0   0 0 0 0 | 0x0000_0100
    -- ---------------------------------------------------------------------------------
    -- | 0         0         0         0         0         1         0         0       |
    -- ---------------------------------------------------------------------------------
    --
    -- ---------------------------------------------------------------------------------
    -- | 1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 1 1 1   1 0 0 1   X X X X   X X X X |
    -- ---------------------------------------------------------------------------------
    -- | F         F         F         F         F         9         0         0       | 0xFFFF_F900
    -- ---------------------------------------------------------------------------------
    --
    -- Note: Bit 11 is forced to '0' when io_addr is constructed, so this compare for 0x01 works.
    --

    --
    -- IO_TIMER 0x100 - 0x13F
    --
    -- Note: This actually decodes 0x100 - 0x1FF.
    --
    timer_ce <= io_addr_strobe when io_addr(11 downto 8) = x"1" else '0';
    end generate;

    --
    -- Block RAM
    --
    -- Menlo: Any address below 0x8000_0000 is Block RAM.
    --
    -- 0x0000_0000 - 0x7FFF_FFFF (2GB)
    --
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31) /= '1' else '0';
    bram: entity work.bram
    generic map (
	C_bram_size => C_bram_size,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_boot_spi => C_boot_spi
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => bram_i_to_cpu,
	imem_data_ready => bram_i_ready, dmem_data_ready => bram_d_ready,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => bram_d_to_cpu, dmem_data_in => cpu_to_dmem
    );

    --
    -- Menlo:
    --
    -- Debugging SIO instance
    --
    G_debug_sio:
    if C_debug generate
      signal bus_out : std_logic_vector(31 downto 0);
    begin
    debug_sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => false
    )
    port map (
	clk => clk, ce => '1', txd => deb_tx, rxd => sio_rxd(0),
	bus_write => deb_sio_tx_strobe, byte_sel => "0001",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_in(31 downto 8) => x"000000",
        bus_out => bus_out, break => open
    );

    sio_to_debug_data <= bus_out(7 downto 0);
    deb_sio_rx_done <= bus_out(8);
    deb_sio_tx_busy <= bus_out(10);
    end generate;

    sio_txd(0) <= sio_tx(0) when not C_debug or debug_active = '0' else deb_tx;

    --
    -- Menlo:
    --
    -- FM/RDS instantiation
    -- FM/RDS
    --
    -- IO_BASE + 0x400 => IO_BASE + 0x4FF
    -- Actual use is (4) 32 bit registers decoded from dmem_addr(3 downto 2)
    --
    -- TODO: Rename fmrds -> sdr for the SoC, but keep fmrds options.
    --
    G_fmrds:
    if C_fmrds generate
    fm_tx: entity work.sdr
    generic map (
      c_fmdds_hz => C_fmdds_hz, -- Hz FMDDS clock frequency
      C_rds_msg_len => C_rds_msg_len, -- allocate RAM for RDS message
      C_stereo => C_fm_stereo,
      -- multiply/divide to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide
      -- example settings for 25 MHz clock
      -- c_rds_clock_multiply => 228,
      -- c_rds_clock_divide => 3125
      -- settings for super slow (100Hz debug) clock
      -- c_rds_clock_multiply => 1,
      -- c_rds_clock_divide => 812500
    )
    port map (
      clk => clk,              -- RDS and PCM processing clock is CPU clock at 100Mhz
      clk_fmdds => clk_fmdds,  -- Direct Digital Synthesis
      ce => sdr_ce,
      addr => dmem_addr(7 downto 2), -- 256 byte block, A0, A1 decoded into byte_sel by CPU
      bus_write => dmem_write,
      byte_sel => dmem_byte_sel,
      bus_in => cpu_to_dmem,
      bus_out => from_sdr,
      pcm_in_left => (others => '0'),
      pcm_in_right => (others => '0'),
      -- debug => from_sdr,
      fm_antenna => fm_antenna
    );

    --
    -- This decodes 64K of space from IO_BASE + 0x400 => IO_BASE + 0x4FF
    -- Actual: 0xFFFFFC00 - 0xFFFFFCFF
    --
    -- See SDR.h
    --
    sdr_ce <= io_addr_strobe when io_addr(11 downto 8) = x"4" else '0';
    end generate;

end Behavioral;
