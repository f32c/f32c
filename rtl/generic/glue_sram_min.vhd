--
-- Copyright (c) 2011-2015 Marko Zec, University of Zagreb
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

use work.f32c_pack.all;
use work.sram_pack.all;


entity glue_sram is
    generic (
	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff";

	-- COP0 options
	C_exceptions: boolean := true;
	C_cop0_count: boolean := true;
	C_cop0_compare: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;

	-- This may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

	-- Debugging / testing options (should be turned off)
	C_debug: boolean := false;

	-- SoC configuration options
	C_cpus: integer := 1;
	C_bram_size: integer := 2;	-- 2 or 16 KBytes
	C_boot_spi: boolean := false;
	C_i_rom_only: boolean := true;
	C_icache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
	C_sram: boolean := true;
	C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
	C_pipelined_read: boolean := false; -- works only at 81.25 MHz !!!
	C_sio: boolean := true;
	C_simple_in: integer range 0 to 128 := 32;
	C_simple_out: integer range 0 to 128 := 32
    );
    port (
        clk: in std_logic; -- main clock CPU and I/O
	sio_tx, sio_break: out std_logic;
	sio_rx: in std_logic;
	simple_in: in std_logic_vector(31 downto 0);
	simple_out: out std_logic_vector(31 downto 0);
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
	-- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
    );
end glue_sram;

architecture Behavioral of glue_sram is
    constant C_io_ports: integer := C_cpus;

    -- types for signals going to / from f32c core(s)
    type f32c_addr_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 2);
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
    signal final_to_cpu_i, final_to_cpu_d, cpu_to_dmem: f32c_data_bus;
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: f32c_std_logic;
    signal imem_data_ready, dmem_data_ready: f32c_std_logic;
    signal dmem_byte_sel: f32c_byte_sel;

    -- SRAM
    signal to_sram: sram_port_array;
    signal sram_ready: sram_ready_array;
    signal from_sram: std_logic_vector(31 downto 0);

    -- Block RAM
    signal bram_i_to_cpu, bram_d_to_cpu: std_logic_vector(31 downto 0);
    signal bram_i_ready, bram_d_ready, dmem_bram_enable: std_logic;

    -- I/O
    signal io_write: std_logic;
    signal io_byte_sel: std_logic_vector(3 downto 0);
    signal io_addr: std_logic_vector(11 downto 2);
    signal cpu_to_io, io_to_cpu: std_logic_vector(31 downto 0);
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_txd, sio_ce: std_logic;
    signal io_addr_strobe: std_logic_vector((C_io_ports - 1) downto 0);
    signal next_io_port: integer range 0 to (C_io_ports - 1);
    signal R_cur_io_port: integer range 0 to (C_io_ports - 1);
    signal R_fb_mode: std_logic_vector(1 downto 0) := "11";
    signal R_fb_base_addr: std_logic_vector(19 downto 2);

    -- CPU reset control
    signal R_cpu_reset: std_logic_vector(15 downto 0) := x"fffe";

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

    -- Simple I/O: onboard LEDs, buttons and switches
    constant iomap_simple_in: T_iomap_range := (x"FF00", x"FF0F");
    constant iomap_simple_out: T_iomap_range := (x"FF10", x"FF1F");
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);

    -- serial I/O (RS232)
    constant iomap_sio: T_iomap_range := (x"FB00", x"FB3F");
    signal sio_range: std_logic := '0';

    -- debugging only
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    --
    -- f32c core(s)
    --
    G_CPU: for i in 0 to (C_cpus - 1) generate
    begin
    intr(i) <= "0000" & from_sio(8) & "0"
      when i = 0 else "000000";
    res(i) <= R_cpu_reset(i);
    cpu: entity work.cache
    generic map (
	C_arch => C_arch, C_cpuid => i, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_cop0_count => C_cop0_count, C_cop0_compare => C_cop0_compare,
	C_cop0_config => C_cop0_config, C_exceptions => C_exceptions,
	C_ll_sc => C_ll_sc,
	C_icache_size => C_icache_size, C_dcache_size => C_dcache_size,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => res(i), intr => intr(i),
	imem_addr => imem_addr(i), imem_data_in => final_to_cpu_i(i),
	imem_addr_strobe => imem_addr_strobe(i),
	imem_data_ready => imem_data_ready(i),
	dmem_addr_strobe => dmem_addr_strobe(i),
	dmem_addr => dmem_addr(i),
	dmem_write => dmem_write(i), dmem_byte_sel => dmem_byte_sel(i),
	dmem_data_in => final_to_cpu_d(i), dmem_data_out => cpu_to_dmem(i),
	dmem_data_ready => dmem_data_ready(i),
	snoop_cycle => '0', snoop_addr => (others => '0'),
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
    -- RS232 sio
    --
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => sio_rx,
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_sio, break => sio_break
    );
    sio_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"30" else '0';
    end generate;

    -- Memory map:
    -- 0x0*******: (4B, RW) : Embedded block RAM (2 - 16 KBytes, fast)
    -- 0x8*******: (4B, RW) : External static RAM (1 MByte, slow)
    -- 0xf****800: (4B, RW) : GPIO data
    -- 0xf****804: (4B, WR) : GPIO control (direction 1-output 0-input)
    -- 0xf****808: (4B, WR) : GPIO rising edge interrupt flag
    -- 0xf****80C: (4B, WR) : GPIO rising edge interrupt enable
    -- 0xf****810: (4B, WR) : GPIO falling edge interrupt flag
    -- 0xf****814: (4B, WR) : GPIO falling edge interrupt enable
    -- 0xf****900: (16B,WR) : TIMER
    -- 0xf****B00: (4B, RW) : SIO
    -- 0xf****B40: (2B, RW) : SPI Flash
    -- 0xf****B50: (2B, RW) : SPI MicroSD
    -- 0xf****B80: (4B, WR) : Video framebuffer control
    -- 0xf****BA0: (4B, RW) : PCM audio DMA first addr (WR) / current addr (RD)
    -- 0xf****BA4: (4B, WR) : PCM audio DMA last addr
    -- 0xf****BA8: (3B, WR) : PCM audio DMA refill frequency (sampling rate)
    -- 0xf****D20: (2B, WR) : Lego Power Functions Infrared Controller
    -- 0xf****F00: (4B, RW) : simple I/O: switches, buttons (RD), LED, LCD (WR)
    -- 0xf****FF0: (1B, WR) : CPU reset bitmap

    --
    -- I/O arbiter
    --
    process(R_cur_io_port, dmem_addr, dmem_addr_strobe)
	variable i, j, t, cpu: integer;
    begin
	for cpu in 0 to (C_cpus - 1) loop
	    if dmem_addr(cpu)(31 downto 28) = x"F" and dmem_addr(cpu)(11) = '1' then
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
    io_addr <=  '0' & dmem_addr(R_cur_io_port)(10 downto 2);
    io_byte_sel <= dmem_byte_sel(R_cur_io_port);
    cpu_to_io <= cpu_to_dmem(R_cur_io_port);
    process(clk)
    begin
	if rising_edge(clk) then
	    R_cur_io_port <= next_io_port;
	end if;
    end process;

    --
    -- Simple I/O
    --
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe(R_cur_io_port) = '1' and io_write = '1' then
	    -- simple out
	    if C_simple_out > 0 and io_addr(11 downto 4) = iomap_from(iomap_simple_out, iomap_range) then
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
	if rising_edge(clk) then
	    R_simple_in(C_simple_in - 1 downto 0) <=
	      simple_in(C_simple_in - 1 downto 0);
	end if;
    end process;
    simple_out(C_simple_out - 1 downto 0) <=
      R_simple_out(C_simple_out - 1 downto 0);

    -- big address decoder when CPU reads IO
    process(io_addr, R_simple_in, from_sio)
    begin
	io_to_cpu <= (others => '-'); -- default, overrided later
	case conv_integer(io_addr(11 downto 4)) is
	when iomap_from(iomap_sio, iomap_range) to iomap_to(iomap_sio, iomap_range)  =>
	    if C_sio then
		io_to_cpu <= from_sio;
	    end if;
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
	when others =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    --
    -- Block RAM (only CPU #0)
    --
    dmem_bram_enable <= dmem_addr_strobe(0) when dmem_addr(0)(31) /= '1'
      else '0';
    bram: entity work.bram
    generic map (
	C_bram_size => C_bram_size,
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_boot_spi => C_boot_spi
    )
    port map (
	clk => clk, imem_addr => imem_addr(0),
	imem_data_out => bram_i_to_cpu, dmem_write => dmem_write(0),
	dmem_byte_sel => dmem_byte_sel(0), dmem_addr => dmem_addr(0),
	dmem_data_out => bram_d_to_cpu, dmem_data_in => cpu_to_dmem(0)
    );
    bram_i_ready <= imem_addr_strobe(0);
    bram_d_ready <= dmem_addr_strobe(0);

    --
    -- SRAM
    --
    process(imem_addr, dmem_addr, dmem_byte_sel, cpu_to_dmem, dmem_write,
      dmem_addr_strobe, imem_addr_strobe, sram_ready, io_to_cpu, from_sram)
	variable data_port, instr_port: integer;
	variable sram_data_strobe, sram_instr_strobe: std_logic;
    begin
	for cpu in 0 to (C_cpus - 1) loop
	    data_port := cpu;
	    instr_port := C_cpus + cpu;
	    if dmem_addr(cpu)(31 downto 28) = x"8" then
		sram_data_strobe := dmem_addr_strobe(cpu);
	    else
		sram_data_strobe := '0';
	    end if;
	    if imem_addr(cpu)(31 downto 28) = x"8" then
		sram_instr_strobe := imem_addr_strobe(cpu);
	    else
		sram_instr_strobe := '0';
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
		elsif sram_data_strobe = '1' then
		    dmem_data_ready(cpu) <= sram_ready(data_port);
		    final_to_cpu_d(cpu) <= from_sram;
		elsif C_i_rom_only then
		    -- XXX assert address eror signal?
		    dmem_data_ready(cpu) <= dmem_addr_strobe(cpu);
		    final_to_cpu_d(cpu) <= (others => '-');
		else
		    dmem_data_ready(cpu) <= bram_d_ready;
		    final_to_cpu_d(cpu) <= bram_d_to_cpu; -- BRAM
		end if;
		-- CPU, instruction bus
		if sram_instr_strobe = '1' then
		    imem_data_ready(cpu) <= sram_ready(instr_port);
		    final_to_cpu_i(cpu) <= from_sram;
		elsif imem_addr_strobe(cpu) = '0' then
		    imem_data_ready(cpu) <= '0';
		    final_to_cpu_i(cpu) <= bram_i_to_cpu;
		else
		    imem_data_ready(cpu) <= bram_i_ready;
		    final_to_cpu_i(cpu) <= bram_i_to_cpu;
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
		elsif sram_data_strobe = '1' then
		    dmem_data_ready(cpu) <= sram_ready(data_port);
		    final_to_cpu_d(cpu) <= from_sram;
		else
		    -- XXX assert address eror signal?
		    dmem_data_ready(cpu) <= '1';
		    final_to_cpu_d(cpu) <= (others => '-');
		end if;
		-- CPU, instruction bus
		if sram_instr_strobe = '1' then
		    imem_data_ready(cpu) <= sram_ready(instr_port);
		    final_to_cpu_i(cpu) <= from_sram;
		else
		    -- XXX assert address eror signal?
		    -- XXX hack for avoiding a deadlock in i-cache FSM
		    imem_data_ready(cpu) <= imem_addr_strobe(cpu);
		    final_to_cpu_i(cpu) <= (others => '-');
		end if;
	    end if;
	    -- CPU, data bus
	    to_sram(data_port).addr_strobe <= sram_data_strobe;
	    to_sram(data_port).write <= dmem_write(cpu);
	    to_sram(data_port).byte_sel <= dmem_byte_sel(cpu);
	    to_sram(data_port).addr <= "0000000000" & dmem_addr(cpu)(19 downto 2);
	    to_sram(data_port).data_in <= cpu_to_dmem(cpu);
	    -- CPU, instruction bus
	    to_sram(instr_port).addr_strobe <= sram_instr_strobe;
	    to_sram(instr_port).addr <= "0000000000" & imem_addr(cpu)(19 downto 2);
	    to_sram(instr_port).data_in <= (others => '-');
	    to_sram(instr_port).write <= '0';
	    to_sram(instr_port).byte_sel <= x"f";
	end loop;
    end process;

    G_sram:
    if C_sram generate
    sram: entity work.sram
    generic map (
	C_ports => 2 * C_cpus,
	C_wait_cycles => C_sram_wait_cycles,
	C_pipelined_read => C_pipelined_read
    )
    port map (
	clk => clk, sram_a => sram_a, sram_d => sram_d,
	sram_wel => sram_wel, sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	data_out => from_sram,
	snoop_cycle => open, snoop_addr => open,
	-- Multi-port connections:
	bus_in => to_sram, ready_out => sram_ready
    );
    end generate;

    -- Debugging SIO instance
    G_debug_sio:
    if C_debug generate
    debug_sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => false
    )
    port map (
	clk => clk, ce => '1', txd => deb_tx, rxd => sio_rx,
	bus_write => deb_sio_tx_strobe, byte_sel => "0001",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_out(7 downto 0) => sio_to_debug_data,
	bus_out(8) => deb_sio_rx_done, bus_out(10) => deb_sio_tx_busy,
	break => open
    );
    end generate;

    sio_tx <= sio_txd when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;
