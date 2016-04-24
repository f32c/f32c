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
use work.sram_pack.all;


entity glue_bram is
    generic (
	C_clk_freq: integer;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"81ffffff"; -- 32 MB
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
	C_debug: boolean := true;

	-- SDRAM parameters
	C_sdram_address_width : integer := 24;
	C_sdram_column_bits : integer := 9;
	C_sdram_startup_cycles : integer := 10100;
	C_sdram_cycles_per_refresh : integer := 1524;

	-- SoC configuration options
	C_bram_size: integer := 8;	-- in KBytes
	C_boot_spi: boolean := false;
	C_icache_size: integer := 0;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 0;	-- 0, 2, 4 or 8 KBytes
	C_cached_addr_bits: integer := 25; -- 32MB
	C_sdram: boolean := true;
	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
	C_sio_fixed_baudrate: boolean := false;
	C_sio_break_detect: boolean := true;
	C_spi: integer := 0;
	C_spi_turbo_mode: std_logic_vector := "0000";
	C_spi_fixed_speed: std_logic_vector := "1111";
	C_simple_in: integer range 0 to 128 := 32;
	C_simple_out: integer range 0 to 128 := 32;
	C_framebuffer: boolean := false;
	C_gpio: integer range 0 to 128 := 32
    );
    port (
	clk: in std_logic;
	clk_325m: in std_logic; -- PAL video DAC clock, 325 MHz
	clk_25MHz: in std_logic; -- VGA pixel clock 25 MHz
	sdram_addr: out std_logic_vector(12 downto 0);
	sdram_data: inout std_logic_vector(15 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_ras, sdram_cas: out std_logic;
	sdram_cke, sdram_clk: out std_logic;
	sdram_we, sdram_cs: out std_logic;
	sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
	sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
	spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
	spi_miso: in std_logic_vector(C_spi - 1 downto 0);
	simple_in: in std_logic_vector(31 downto 0);
	simple_out: out std_logic_vector(31 downto 0);
	video_dac: out std_logic_vector(3 downto 0);
	gpio: inout std_logic_vector(127 downto 0)
    );
end glue_bram;

architecture Behavioral of glue_bram is

    -- signals to / from f32c cores(s)
    signal intr: std_logic_vector(5 downto 0);
    signal imem_addr, dmem_addr: std_logic_vector(31 downto 2);
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: std_logic;
    signal imem_data_ready, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal cpu_to_dmem: std_logic_vector(31 downto 0);
    signal final_to_cpu_i, final_to_cpu_d: std_logic_vector(31 downto 0);
    signal io_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);

    -- Block RAM
    signal bram_i_to_cpu, bram_d_to_cpu: std_logic_vector(31 downto 0);
    signal bram_i_ready, bram_d_ready, dmem_bram_enable: std_logic;

    -- SDRAM
    signal to_sdram: sram_port_array;
    signal sdram_ready: sram_ready_array;
    signal from_sdram: std_logic_vector(31 downto 0);
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);

    -- io base
    type T_iomap_range is array(0 to 1) of std_logic_vector(15 downto 0);
    constant iomap_range: T_iomap_range := (x"F800", x"FFFF"); -- actual range is 0xFFFFF800 .. 0xFFFFFFFF

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

    -- Composite video framebuffer
    signal R_fb_mode: std_logic_vector(1 downto 0) := "11";
    signal R_fb_base_addr: std_logic_vector(29 downto 2);
    signal R_fb_intr: std_logic;
    signal fb_addr_strobe, fb_data_ready: std_logic;
    signal fb_addr: std_logic_vector(29 downto 2);
    signal fb_tick: std_logic;

    -- GPIO
    constant iomap_gpio: T_iomap_range := (x"F800", x"F87F");
    signal gpio_range: std_logic := '0';
    constant C_gpios: integer := (C_gpio+31)/32; -- number of gpio units
    type gpios_type is array (C_gpios-1 downto 0) of std_logic_vector(31 downto 0);
    signal from_gpio, gpios: gpios_type;
    signal gpio_ce: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr: std_logic_vector(C_gpios-1 downto 0);
    signal gpio_intr_joint: std_logic := '0';

    -- Serial I/O (RS232)
    constant iomap_sio: T_iomap_range := (x"FB00", x"FB3F");
    signal sio_range: std_logic := '0';
    type from_sio_type is array (0 to C_sio - 1) of
      std_logic_vector(31 downto 0);
    signal from_sio: from_sio_type;
    signal sio_ce, sio_tx, sio_rx: std_logic_vector(C_sio - 1 downto 0);
    signal sio_break_internal: std_logic_vector(C_sio - 1 downto 0);

    -- SPI (on-board Flash, SD card, others...)
    constant iomap_spi: T_iomap_range := (x"FB40", x"FB7F");
    signal spi_range: std_logic := '0';
    type from_spi_type is array (0 to C_spi - 1) of
      std_logic_vector(31 downto 0);
    signal from_spi: from_spi_type;
    signal spi_ce: std_logic_vector(C_spi - 1 downto 0);

    -- Simple I/O: onboard LEDs, buttons and switches
    constant iomap_simple_in: T_iomap_range := (x"FF00", x"FF0F");
    constant iomap_simple_out: T_iomap_range := (x"FF10", x"FF1F");
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);
   
    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_debug: std_logic_vector(7 downto 0);
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    -- f32c core
    pipeline: entity work.cache
    generic map (
	C_arch => C_arch, C_cpuid => 0, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_cop0_compare => C_cop0_compare,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
	C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
	C_cached_addr_bits => C_cached_addr_bits,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => sio_break_internal(0), intr => intr,
	imem_addr => imem_addr, imem_data_in => final_to_cpu_i,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu_d, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => '0', snoop_addr => "------------------------------",
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
    final_to_cpu_i <= from_sdram when imem_addr(31 downto 30) = "10"
      else bram_i_to_cpu;
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1'
      else from_sdram when dmem_addr(31 downto 30) = "10"
      else bram_d_to_cpu;
    intr <= "00" & gpio_intr_joint & '0' & from_sio(0)(8) & R_fb_intr;
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11"
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    imem_data_ready <= sdram_ready(0) when imem_addr(31 downto 30) = "10"
      else bram_i_ready;
    dmem_data_ready <= sdram_ready(1) when dmem_addr(31 downto 30) = "10"
      else bram_d_ready when dmem_addr(31) = '0'
      else '1'; -- I/O

    -- SDRAM
    G_sdram:
    if C_sdram generate
    -- port 0: instruction bus
    to_sdram(0).addr_strobe <= imem_addr_strobe when
      imem_addr(31 downto 30) = "10" else '0';
    to_sdram(0).addr <= imem_addr(29 downto 2);
    to_sdram(0).data_in <= (others => '-');
    to_sdram(0).write <= '0';
    to_sdram(0).byte_sel <= (others => '1');
    -- port 1: data bus
    to_sdram(1).addr_strobe <= dmem_addr_strobe when
      dmem_addr(31 downto 30) = "10" else '0';
    to_sdram(1).addr <= dmem_addr(29 downto 2);
    to_sdram(1).data_in <= cpu_to_dmem;
    to_sdram(1).write <= dmem_write;
    to_sdram(1).byte_sel <= dmem_byte_sel;
    -- composite video framebuffer
    to_sdram(2).addr_strobe <= fb_addr_strobe;
    to_sdram(2).write <= '0';
    to_sdram(2).byte_sel <= x"f";
    to_sdram(2).addr <= fb_addr;
    to_sdram(2).data_in <= (others => '-');
    fb_data_ready <= sdram_ready(2);

    sdram: entity work.sdram_controller
    generic map (
	C_ports => 3,
	sdram_address_width => C_sdram_address_width,
	sdram_column_bits => C_sdram_column_bits,
	sdram_startup_cycles => C_sdram_startup_cycles,
	cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
	clk => clk, reset => sio_break_internal(0),
	-- internal connections
	data_out => from_sdram, bus_in => to_sdram, ready_out => sdram_ready,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- external SDRAM interface
	sdram_addr => sdram_addr, sdram_data => sdram_data,
	sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
	sdram_ras => sdram_ras, sdram_cas => sdram_cas,
	sdram_cke => sdram_cke, sdram_clk => sdram_clk,
	sdram_we => sdram_we, sdram_cs => sdram_cs
    );
    end generate;

    -- Composite video framebuffer
    G_framebuffer:
    if C_framebuffer generate
    fb: entity work.fb
    generic map (
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, clk_dac => clk_325m,
	addr_strobe => fb_addr_strobe,
	addr_out => fb_addr,
	data_ready => fb_data_ready,
	data_in => from_sdram,
	mode => R_fb_mode,
	base_addr => R_fb_base_addr,
	dac_out => video_dac,
	tick_out => fb_tick
    );
    end generate;

    -- RS232 sio
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
    G_sio_decoder: if C_sio > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      sio_range <= '1' when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range),
		   '0' when others;
    end generate;
    sio_rx(0) <= sio_rxd(0);

    -- SPI
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
    G_spi_decoder: if C_spi > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      spi_range <= '1' when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range),
		   '0' when others;
    end generate;

    --
    -- I/O
    --
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then
	    -- simple out
	    if C_simple_out > 0 and io_addr(11 downto 4) = x"71" then
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
	    -- Composite video framebuffer
	    if C_framebuffer and io_addr(11 downto 4) = x"38" then
		if C_big_endian then
		    R_fb_mode <= cpu_to_dmem(25 downto 24);
		    R_fb_base_addr <=
		      cpu_to_dmem(5 downto 0) &
		      cpu_to_dmem(15 downto 8) &
		      cpu_to_dmem(23 downto 16) &
		      cpu_to_dmem(31 downto 26);
		else
		    R_fb_mode <= cpu_to_dmem(1 downto 0);
		    R_fb_base_addr <= cpu_to_dmem(29 downto 2);
		end if;
	    end if;
	end if;
	if C_framebuffer and rising_edge(clk) then
	    if io_addr_strobe = '1' and
	      io_addr(11 downto 4) = x"38" then
		R_fb_intr <= '0';
	    end if;
	    if fb_tick = '1' then
		R_fb_intr <= '1';
	    end if;
	end if;
	if rising_edge(clk) then
	    R_simple_in(C_simple_in - 1 downto 0) <=
	      simple_in(C_simple_in - 1 downto 0);
	end if;
    end process;

    simple_out(C_simple_out - 1 downto 0) <=
      R_simple_out(C_simple_out - 1 downto 0);

    -- big address decoder when CPU reads IO
    process(io_addr, R_simple_in, R_simple_out, from_sio, from_gpio)
	variable i: integer;
    begin
	io_to_cpu <= (others => '-');
	case conv_integer(io_addr(11 downto 4)) is
	when iomap_from(iomap_gpio, iomap_range) to iomap_to(iomap_gpio, iomap_range) =>
	    for i in 0 to C_gpios - 1 loop
		if conv_integer(io_addr(6 downto 5)) = i then
		    io_to_cpu <= from_gpio(i);
		end if;
	    end loop;
	when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range) =>
	    for i in 0 to C_sio - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_sio(i);
		end if;
	    end loop;
	when iomap_from(iomap_spi, iomap_range) to iomap_to(iomap_spi, iomap_range) =>
	    for i in 0 to C_spi - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_spi(i);
		end if;
	    end loop;
	when iomap_from(iomap_simple_in, iomap_range) to iomap_to(iomap_simple_in, iomap_range) =>
	    for i in 0 to (C_simple_in + 31) / 4 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(C_simple_in - i * 32 - 1 downto i * 32) <=
		      R_simple_in(C_simple_in - i * 32 - 1 downto i * 32);
		end if;
	    end loop;
	when iomap_from(iomap_simple_out, iomap_range) to iomap_to(iomap_simple_out, iomap_range) =>
	    for i in 0 to (C_simple_out + 31) / 4 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(C_simple_out - i * 32 - 1 downto i * 32) <=
		      R_simple_out(C_simple_out - i * 32 - 1 downto i * 32);
		end if;
	    end loop;
	when others  =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    -- GPIO
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
    G_gpio_decoder_intr: if C_gpios > 0 generate
    with conv_integer(io_addr(11 downto 4)) select
      gpio_range <= '1' when iomap_from(iomap_gpio, iomap_range) to iomap_to(iomap_gpio, iomap_range),
		    '0' when others;
    gpio_intr_joint <= gpio_intr(0);
    -- TODO: currently only 32 gpio supported in fpgarduino core
    -- when support for 128 gpio is there we should use this:
    -- gpio_intr_joint <= '0' when conv_integer(gpio_intr) = 0 else '1';
    end generate;

    -- Block RAM
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

    -- Debugging SIO instance
    G_debug_sio:
    if C_debug generate
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
	bus_out(7 downto 0) => sio_to_debug_data,
	bus_out(8) => deb_sio_rx_done, bus_out(9) => open,
	bus_out(10) => deb_sio_tx_busy, bus_out(31 downto 11) => open,
	break => open
    );
    end generate;

    sio_txd(0) <= sio_tx(0) when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;
