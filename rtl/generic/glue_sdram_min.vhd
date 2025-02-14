--
-- Copyright (c) 2015-2023 Marko Zec
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;
use work.sdram_pack.all;


entity glue_sdram_min is
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

	-- CPU's caches
	C_icache_size: integer := 8;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 8;	-- 0, 2, 4 or 8 KBytes
	C_cached_addr_bits: integer := 25; -- 32 MB
	C_cache_bursts: boolean := true;

	-- CPU debugging
	C_debug: boolean := false;

	-- SDRAM parameters
	C_sdram_address_width: integer := 24;
	C_sdram_column_bits: integer := 9;
	C_sdram_startup_cycles: integer := 10100;
	C_sdram_cycles_per_refresh: integer := 1524;

	-- SoC configuration options
	C_cpus: integer := 1;
	C_sdram: boolean := true;
	C_sio: integer := 1;
	C_sio_init_baudrate: integer := 115200;
	C_sio_fixed_baudrate: boolean := false;
	C_sio_break_detect: boolean := true;
	C_spi: integer := 0;
	C_spi_fixed_speed: std_logic_vector := "1111";
	C_simple_in: natural := 32;
	C_simple_out: natural := 32;
	C_rtc: boolean := true
    );
    port (
	clk: in std_logic;
	reset: in std_logic := '0';
	xbus_addr: out std_logic_vector(31 downto 2);
	xbus_strobe: out std_logic;
	xbus_write: out std_logic;
	xbus_byte_sel: out std_logic_vector(3 downto 0);
	xbus_data_out: out std_logic_vector(31 downto 0);
	xbus_data_in: in std_logic_vector(31 downto 0) := (others => '-');
	xbus_ack: in std_logic := '1';
	sdram_addr: out std_logic_vector(12 downto 0);
	sdram_data: inout std_logic_vector(15 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_ras, sdram_cas: out std_logic;
	sdram_cke, sdram_clk: out std_logic;
	sdram_we, sdram_cs: out std_logic;
	sio_rxd: in std_logic_vector(C_sio - 1 downto 0) := (others => '1');
	sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
	spi_sck, spi_ss: out std_logic_vector(C_spi - 1 downto 0);
	spi_mosi, spi_miso: inout std_logic_vector(C_spi - 1 downto 0);
	simple_in: in std_logic_vector(C_simple_in - 1 downto 0) :=
	  (others => '0');
	simple_out: out std_logic_vector(C_simple_out - 1 downto 0)
    );
end glue_sdram_min;

architecture Behavioral of glue_sdram_min is
    constant C_io_ports: integer := C_cpus;

    -- types for signals going to / from f32c core(s)
    type f32c_addr_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 2);
    type f32c_burst_len is array(0 to (C_cpus - 1)) of
      std_logic_vector(2 downto 0);
    type f32c_byte_sel is array(0 to (C_cpus - 1)) of
      std_logic_vector(3 downto 0);
    type f32c_data_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 0);
    type f32c_std_logic is array(0 to (C_cpus - 1)) of std_logic;
    type f32c_intr is array(0 to (C_cpus - 1)) of std_logic_vector(5 downto 0);
    type f32c_debug_addr is array(0 to (C_cpus - 1)) of
      std_logic_vector(5 downto 0);

    -- signals to / from f32c cores(s)
    signal res: f32c_std_logic;
    signal intr: f32c_intr;
    signal imem_addr, dmem_addr: f32c_addr_bus;
    signal imem_burst_len, dmem_burst_len: f32c_burst_len;
    signal final_to_cpu_i, final_to_cpu_d, cpu_to_dmem: f32c_data_bus;
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: f32c_std_logic;
    signal imem_data_ready, dmem_data_ready: f32c_std_logic;
    signal dmem_byte_sel: f32c_byte_sel;

    -- Boot ROM
    signal rom_i_to_cpu: std_logic_vector(31 downto 0);
    signal rom_i_ready: std_logic;

    -- SDRAM
    constant C_ras: natural range 2 to 3 := 2 + C_clk_freq / 137;
    constant C_cas: natural range 2 to 3 := 2 + C_clk_freq / 137;
    constant C_pre: natural range 2 to 3 := 2 + C_clk_freq / 137;
    constant C_clock_range: natural range 0 to 2 := 1 + C_clk_freq / 101;
    signal sdram_req: sdram_req_array;
    signal sdram_resp: sdram_resp_array;
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);

    -- eXternal BUS (XBUS)
    signal xbus_addr_range: boolean;

    -- I/O
    signal io_write: std_logic;
    signal io_byte_sel: std_logic_vector(3 downto 0);
    signal io_addr: std_logic_vector(11 downto 2);
    signal cpu_to_io, io_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic_vector((C_io_ports - 1) downto 0);
    signal next_io_port: integer range 0 to (C_io_ports - 1);
    signal R_cur_io_port: integer range 0 to (C_io_ports - 1);

    function F_init_PC(cpuid: integer) return std_logic_vector is
    begin
	if cpuid = 0 then
	    return x"00000000";
	else
	    return x"80000000";
	end if;
    end F_init_PC;

    -- CPU reset control: 0x7C0
    constant C_io_cpu_reset: std_logic_vector(7 downto 0) := x"7C";
    signal R_cpu_reset: std_logic_vector(15 downto 0) := (others => '1');

    -- Simple input (buttons and switches): 0x700 .. 070F
    constant C_io_simple_in: std_logic_vector(7 downto 0) := x"70";
    signal R_simple_in: std_logic_vector(31 downto 0);

    -- Simple output (onboard LEDs): 0x710 .. 0x71F
    constant C_io_simple_out: std_logic_vector(7 downto 0) := x"71";
    signal R_simple_out: std_logic_vector(31 downto 0);

    -- Serial I/O (RS232): 0x300 .. 0x33F
    constant C_io_sio0: std_logic_vector(7 downto 0) := x"30";
    constant C_io_sio1: std_logic_vector(7 downto 0) := x"31";
    constant C_io_sio2: std_logic_vector(7 downto 0) := x"32";
    constant C_io_sio3: std_logic_vector(7 downto 0) := x"33";
    signal sio_io_range: boolean;
    type from_sio_type is array (0 to C_sio - 1) of
      std_logic_vector(31 downto 0);
    signal from_sio: from_sio_type;
    signal sio_ce, sio_intr: std_logic_vector(C_sio - 1 downto 0);
    signal sio_tx, sio_rx: std_logic_vector(C_sio - 1 downto 0);

    -- SPI (on-board Flash, SD card, others...): 0x340 .. 0x37F
    constant C_io_spi0: std_logic_vector(7 downto 0) := x"34";
    constant C_io_spi1: std_logic_vector(7 downto 0) := x"35";
    constant C_io_spi2: std_logic_vector(7 downto 0) := x"36";
    constant C_io_spi3: std_logic_vector(7 downto 0) := x"37";
    signal spi_io_range: boolean;
    type from_spi_type is array (0 to C_spi - 1) of
      std_logic_vector(31 downto 0);
    signal from_spi: from_spi_type;
    signal spi_ce: std_logic_vector(C_spi - 1 downto 0);

    -- RTC: 0x780 .. 0x78F
    constant C_io_rtc: std_logic_vector(7 downto 0) := x"78";
    signal rtc_io_range: boolean;
    signal rtc_ce: std_logic;
    signal from_rtc: std_logic_vector(31 downto 0);

    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;
    signal debug_bus_out: std_logic_vector(31 downto 0);

begin

    --
    -- f32c core(s)
    --
    G_CPU: for i in 0 to (C_cpus - 1) generate
    begin
    intr(i) <= "000" & '0' & sio_intr(0) & '0' when i = 0 else "000000";
    res(i) <= R_cpu_reset(i);
    cpu: entity work.f32c_cache
    generic map (
	C_arch => C_arch, C_cpuid => i,
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
	C_cache_bursts => C_cache_bursts,
	C_init_PC => F_init_PC(i),
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => res(i), intr => intr(i),
	imem_addr => imem_addr(i), imem_data_in => final_to_cpu_i(i),
	imem_addr_strobe => imem_addr_strobe(i),
	imem_burst_len => imem_burst_len(i),
	imem_data_ready => imem_data_ready(i),
	dmem_addr_strobe => dmem_addr_strobe(i),
	dmem_addr => dmem_addr(i),
	dmem_burst_len => dmem_burst_len(i),
	dmem_write => dmem_write(i), dmem_byte_sel => dmem_byte_sel(i),
	dmem_data_in => final_to_cpu_d(i), dmem_data_out => cpu_to_dmem(i),
	dmem_data_ready => dmem_data_ready(i),
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- debugging
	debug_in_data => sio_to_debug_data,
	debug_in_strobe => deb_sio_rx_done,
	debug_in_busy => open,
	debug_out_data => debug_to_sio_data,
	debug_out_strobe => deb_sio_tx_strobe,
	debug_out_busy => deb_sio_tx_busy,
	debug_active => debug_active
    );
    end generate;

    --
    -- Boot ROM (only CPU #0, only instruction bus)
    --
    rom: entity work.rom
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_boot_spi => true
    )
    port map (
	clk => clk, strobe => imem_addr_strobe(0), addr => imem_addr(0),
	data_out => rom_i_to_cpu, data_ready => rom_i_ready
    );

    --
    -- SDRAM
    --
    process(imem_addr, dmem_addr, dmem_byte_sel, cpu_to_dmem, dmem_write,
      dmem_addr_strobe, imem_addr_strobe, rom_i_ready,rom_i_to_cpu,
      sdram_req, sdram_resp, io_to_cpu, io_addr_strobe, io_write,
      R_cur_io_port, xbus_addr_range, xbus_data_in, xbus_ack,
      dmem_burst_len, imem_burst_len)
	variable data_port, instr_port: integer;
	variable sdram_data_strobe, sdram_instr_strobe: std_logic;
    begin
    for cpu in 0 to (C_cpus - 1) loop
	data_port := cpu;
	instr_port := C_cpus + cpu;
	sdram_data_strobe := '0';
	sdram_instr_strobe := '0';

	if dmem_addr(cpu)(31 downto 28) = x"8" then
	    sdram_data_strobe := dmem_addr_strobe(cpu);
	end if;
	if imem_addr(cpu)(31 downto 28) = x"8" then
	    sdram_instr_strobe := imem_addr_strobe(cpu);
	end if;
	if cpu = 0 then
	    -- CPU, data bus
	    if io_addr_strobe(cpu) = '1' then
		if R_cur_io_port = cpu then
		    dmem_data_ready(cpu) <= '1';
		else
		    dmem_data_ready(cpu) <= '0';
		end if;
		final_to_cpu_d(cpu) <= io_to_cpu;
	    elsif sdram_data_strobe = '1' then
		dmem_data_ready(cpu) <= sdram_resp(data_port).data_ready;
		final_to_cpu_d(cpu) <= sdram_resp(data_port).data_out;
	    elsif xbus_addr_range then
		dmem_data_ready(cpu) <= xbus_ack;
		final_to_cpu_d(cpu) <= xbus_data_in;
	    else -- ROM, instruction bus only
		dmem_data_ready(cpu) <= '1';
		final_to_cpu_d(cpu) <= (others => '-');
	    end if;
	    -- CPU, instruction bus
	    if sdram_instr_strobe = '1' then
		imem_data_ready(cpu) <= sdram_resp(instr_port).data_ready;
		final_to_cpu_i(cpu) <= sdram_resp(instr_port).data_out;
	    else
		imem_data_ready(cpu) <= rom_i_ready;
		final_to_cpu_i(cpu) <= rom_i_to_cpu;
	    end if;
	else -- CPU #1, CPU #2...
	    -- CPU, data bus
	    if io_addr_strobe(cpu) = '1' then
		if R_cur_io_port = cpu then
		    dmem_data_ready(cpu) <= '1';
		else
		    dmem_data_ready(cpu) <= '0';
		end if;
		final_to_cpu_d(cpu) <= io_to_cpu;
	    elsif sdram_data_strobe = '1' then
		dmem_data_ready(cpu) <= sdram_resp(data_port).data_ready;
		final_to_cpu_d(cpu) <= sdram_resp(data_port).data_out;
	    else
		-- XXX assert address eror signal?
		dmem_data_ready(cpu) <= '1';
		final_to_cpu_d(cpu) <= (others => '-');
	    end if;
	    -- CPU, instruction bus
	    if sdram_instr_strobe = '1' then
		imem_data_ready(cpu) <= sdram_resp(instr_port).data_ready;
		final_to_cpu_i(cpu) <= sdram_resp(instr_port).data_out;
	    else
		-- XXX assert address eror signal?
		imem_data_ready(cpu) <= '1';
		final_to_cpu_i(cpu) <= (others => '-');
	    end if;
	end if;
	-- CPU, data bus
	sdram_req(data_port).strobe <= sdram_data_strobe;
	sdram_req(data_port).burst_len(2 downto 0) <= dmem_burst_len(cpu);
	sdram_req(data_port).write <= dmem_write(cpu);
	sdram_req(data_port).byte_sel <= dmem_byte_sel(cpu);
	sdram_req(data_port).addr <= dmem_addr(cpu);
	sdram_req(data_port).data_in <= cpu_to_dmem(cpu);
	-- CPU, instruction bus
	sdram_req(instr_port).strobe <= sdram_instr_strobe;
	sdram_req(instr_port).burst_len(2 downto 0) <= imem_burst_len(cpu);
	sdram_req(instr_port).addr <= imem_addr(cpu);
	sdram_req(instr_port).data_in <= (others => '-');
	sdram_req(instr_port).write <= '0';
	sdram_req(instr_port).byte_sel <= x"f";
    end loop;
    end process;

    sdram: entity work.sdram_controller
    generic map (
	C_ports => 2 * C_cpus,
	C_ras => C_ras, C_cas => C_cas, C_pre => C_pre,
	C_clock_range => C_clock_range,
	C_address_width => C_sdram_address_width,
	C_column_bits => C_sdram_column_bits,
	C_startup_cycles => C_sdram_startup_cycles,
	C_cycles_per_refresh => C_sdram_cycles_per_refresh
    )
    port map (
	clk => clk, reset => res(0),
	-- internal connections
	req => sdram_req, resp => sdram_resp,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- external SDRAM interface
	sdram_addr => sdram_addr, sdram_data => sdram_data,
	sdram_ba => sdram_ba, sdram_dqm => sdram_dqm,
	sdram_ras => sdram_ras, sdram_cas => sdram_cas,
	sdram_cke => sdram_cke, sdram_clk => sdram_clk,
	sdram_we => sdram_we, sdram_cs => sdram_cs
    );

    --
    -- External data bus (only CPU #0)
    --
    xbus_addr_range <= dmem_addr(0)(31 downto 30) = "01";
    xbus_addr <= dmem_addr(0);
    xbus_data_out <= cpu_to_dmem(0);
    xbus_strobe <= dmem_addr_strobe(0) when xbus_addr_range else '0';
    xbus_write <= dmem_write(0) when xbus_addr_range else '0';
    xbus_byte_sel <= dmem_byte_sel(0) when xbus_addr_range else x"0";

    --
    -- I/O arbiter
    --
    process(R_cur_io_port, dmem_addr, dmem_addr_strobe, io_addr_strobe)
	variable t: integer;
    begin
    for cpu in 0 to (C_cpus - 1) loop
	if dmem_addr(cpu)(31 downto 28) = x"f" then
	    io_addr_strobe(cpu) <= dmem_addr_strobe(cpu);
	else
	    io_addr_strobe(cpu) <= '0';
	end if;
    end loop;
    t := R_cur_io_port;
    for i in 0 to (C_io_ports - 1) loop
	for j in 1 to C_io_ports loop
	    if R_cur_io_port = i then
		t := (i + j) mod C_io_ports;
		if io_addr_strobe(t) = '1' then
		    exit;
		end if;
	    end if;
	end loop;
    end loop;
    next_io_port <= t;
    end process;

    --
    -- I/O access
    --
    io_write <= dmem_write(R_cur_io_port);
    io_addr <= '0' & dmem_addr(R_cur_io_port)(10 downto 2);
    io_byte_sel <= dmem_byte_sel(R_cur_io_port);
    cpu_to_io <= cpu_to_dmem(R_cur_io_port);
    process(clk, io_addr_strobe, io_write, R_cur_io_port)
    begin
	if rising_edge(clk) then
	    -- IO arbiter
	    R_cur_io_port <= next_io_port;

	    -- Simple input synchronizer
	    if C_simple_in > 0 then
		R_simple_in(C_simple_in - 1 downto 0) <=
		  simple_in(C_simple_in - 1 downto 0);
	    end if;

	    -- CPU reset control
	    R_cpu_reset(0) <= '0';
	    if C_cpus > 1 and io_addr_strobe(R_cur_io_port) = '1'
	      and io_write = '1' and io_addr(11 downto 4) = C_io_cpu_reset then
		R_cpu_reset <= cpu_to_io(15 downto 0);
	    end if;
	    if reset = '1' then
		R_cpu_reset <= (others => '1');
	    end if;
	end if;
	if rising_edge(clk) and io_addr_strobe(R_cur_io_port) = '1'
	  and io_write = '1' then
	    -- simple out
	    if C_simple_out > 0 and
	      io_addr(11 downto 4) = C_io_simple_out then
		if io_byte_sel(0) = '1' then
		    R_simple_out(7 downto 0) <= cpu_to_io(7 downto 0);
		end if;
		if io_byte_sel(1) = '1' then
		    R_simple_out(15 downto 8) <= cpu_to_io(15 downto 8);
		end if;
		if io_byte_sel(2) = '1' then
		    R_simple_out(23 downto 16) <= cpu_to_io(23 downto 16);
		end if;
		if io_byte_sel(3) = '1' then
		    R_simple_out(31 downto 24) <= cpu_to_io(31 downto 24);
		end if;
	    end if;
	end if;
    end process;
    simple_out <= R_simple_out(C_simple_out - 1 downto 0);

    --
    -- RS232 SIO
    --
    G_sio: for i in 0 to C_sio - 1 generate
	I_sio: entity work.sio
	generic map (
	    C_clk_freq => C_clk_freq,
	    C_init_baudrate => C_sio_init_baudrate,
	    C_fixed_baudrate => C_sio_fixed_baudrate,
	    C_break_detect => C_sio_break_detect,
	    C_break_resets_baudrate => C_sio_break_detect
	)
	port map (
	    clk => clk, txd => sio_tx(i), rxd => sio_rx(i), ce => sio_ce(i),
	    bus_write => io_write, bus_addr => io_addr(3 downto 2),
	    bus_in => cpu_to_io, bus_out => from_sio(i),
	    rx_ready => sio_intr(i), break => sio_break(i)
	);
	sio_ce(i) <= io_addr_strobe(R_cur_io_port) when sio_io_range and
	  conv_integer(io_addr(5 downto 4)) = i else '0';
	sio_txd(i) <= sio_tx(i) when not C_debug or i /= 0
	  or debug_active = '0' else deb_tx;
    end generate;
    sio_io_range <= io_addr(11 downto 4) = C_io_sio0
      or io_addr(11 downto 4) = C_io_sio1
      or io_addr(11 downto 4) = C_io_sio2
      or io_addr(11 downto 4) = C_io_sio3;
    sio_rx(0) <= sio_rxd(0);

    --
    -- SPI
    --
    G_spi: for i in 0 to C_spi - 1 generate
	spi_instance: entity work.spi
	generic map (
	    C_fixed_speed => C_spi_fixed_speed(i) = '1'
	)
	port map (
	    clk => clk, ce => spi_ce(i),
	    bus_write => io_write, byte_sel => io_byte_sel,
	    bus_in => cpu_to_io, bus_out => from_spi(i),
	    spi_sck => spi_sck(i), spi_cen(0) => spi_ss(i),
	    spi_cen(3 downto 1) => open,
	    spi_miso => spi_miso(i), spi_mosi => spi_mosi(i)
	);
	spi_ce(i) <= io_addr_strobe(R_cur_io_port) when spi_io_range and
	  conv_integer(io_addr(5 downto 4)) = i else '0';
    end generate;
    spi_io_range <= io_addr(11 downto 4) = C_io_spi0
      or io_addr(11 downto 4) = C_io_spi1
      or io_addr(11 downto 4) = C_io_spi2
      or io_addr(11 downto 4) = C_io_spi3;

    --
    -- RTC
    --
    G_rtc: if C_rtc generate
    I_rtc: entity work.rtc
    generic map (
	C_clk_freq_mhz => C_clk_freq
    )
    port map (
	clk => clk, ce => rtc_ce,
	bus_addr => io_addr(3 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_rtc
    );
    rtc_ce <= io_addr_strobe(R_cur_io_port) when rtc_io_range else '0';
    rtc_io_range <= io_addr(11 downto 4) = C_io_rtc;
    end generate;

    -- Address decoder when CPU reads IO
    process(io_addr, from_sio, from_spi, from_rtc, R_simple_in, R_simple_out)
    begin
	io_to_cpu <= (others => '0');
	case io_addr(11 downto 4) is
	when C_io_sio0 | C_io_sio1 | C_io_sio2 | C_io_sio3 =>
	    for i in 0 to C_sio - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_sio(i);
		end if;
	    end loop;
	when C_io_spi0 | C_io_spi1 | C_io_spi2 | C_io_spi3 =>
	    for i in 0 to C_spi - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_spi(i);
		end if;
	    end loop;
	when C_io_simple_in =>
	    for i in 0 to (C_simple_in + 31) / 4 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(C_simple_in - i * 32 - 1 downto i * 32) <=
		      R_simple_in(C_simple_in - i * 32 - 1 downto i * 32);
		end if;
	    end loop;
	when C_io_simple_out =>
	    for i in 0 to (C_simple_out + 31) / 4 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(C_simple_out - i * 32 - 1 downto i * 32) <=
		      R_simple_out(C_simple_out - i * 32 - 1 downto i * 32);
		end if;
	    end loop;
	when C_io_rtc =>
	    io_to_cpu <= from_rtc;
	when others  =>
	    io_to_cpu <= (others => '0');
	end case;
    end process;

    --
    -- Debugging SIO instance
    --
    G_debug_sio:
    if C_debug generate
    debug_sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => '1', txd => deb_tx, rxd => sio_rxd(0),
	bus_write => deb_sio_tx_strobe, bus_addr => "00", -- XXX fixme!
	bus_in(31 downto 8) => x"000000",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_out => debug_bus_out, break => open, rx_ready => open
    );
    deb_sio_tx_busy <= debug_bus_out(10);
    deb_sio_rx_done <= debug_bus_out(8); -- XXX fixme!
    sio_to_debug_data <= debug_bus_out(7 downto 0); -- XXX fixme!
    end generate;
end Behavioral;
