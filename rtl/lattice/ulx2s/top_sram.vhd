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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;
use work.sram_pack.all;


entity glue is
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
	C_boot_spi: boolean := true;
	C_icache_size: integer := 8;	-- 0, 2, 4 or 8 KBytes
	C_dcache_size: integer := 2;	-- 0, 2, 4 or 8 KBytes
	C_cached_addr_bits: integer := 20; -- 1 MBytes
	C_sram: boolean := true;
	C_sram_wait_cycles: integer := 4; -- ISSI, OK do 87.5 MHz
	C_pipelined_read: boolean := true; -- works only at 81.25 MHz !!!
	C_psram_refresh: boolean := true;
	C_sio: boolean := true;
	C_leds_btns: boolean := true;
	C_gpio: boolean := true;
	C_flash: boolean := true;
	C_sdcard: boolean := true;
	C_framebuffer: boolean := true;
	C_pcm: boolean := true;
	C_timer: boolean := false;
	C_tx433: boolean := false; -- set (C_framebuffer := false, C_dds := false) for 433MHz transmitter
	C_dds: boolean := false
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_so: in std_logic;
	flash_cen, flash_sck, flash_si: out std_logic;
	sdcard_so: in std_logic;
	sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
	p_ring: out std_logic;
	p_tip: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	j1_2, j1_3, j1_4, j1_8, j1_9, j1_13, j1_14, j1_15: inout std_logic;
	j1_16, j1_17, j1_18, j1_19, j1_20, j1_21, j1_22, j1_23: inout std_logic;
	j2_2, j2_3, j2_4, j2_5, j2_6, j2_7, j2_8, j2_9: inout std_logic;
	j2_10, j2_11, j2_12, j2_13, j2_16: inout std_logic;
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
	-- sram_oel: out std_logic -- XXX the old ULXP2 board needs this!
    );
end glue;

architecture Behavioral of glue is
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

    -- synthesized clocks
    signal clk, clk_325m, ena_325m: std_logic;
    signal clk_433m: std_logic;

    -- signals to / from f32c cores(s)
    signal res: f32c_std_logic;
    signal intr: f32c_intr;
    signal imem_addr, dmem_addr: f32c_addr_bus;
    signal final_to_cpu_i, final_to_cpu_d, cpu_to_dmem: f32c_data_bus;
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: f32c_std_logic;
    signal imem_data_ready, dmem_data_ready: f32c_std_logic;
    signal dmem_byte_sel: f32c_byte_sel;

    -- ROM
    signal rom_i_to_cpu: std_logic_vector(31 downto 0);
    signal rom_i_ready: std_logic;

    -- SRAM
    signal to_sram: sram_port_array;
    signal sram_ready: sram_ready_array;
    signal from_sram: std_logic_vector(31 downto 0);
    signal snoop_cycle: std_logic;
    signal snoop_addr: std_logic_vector(31 downto 2);
    signal R_refresh_strobe: std_logic;
    signal R_refresh_addr: std_logic_vector(27 downto 0);
    signal R_refresh_cnt: integer;
    signal refresh_data_ready: std_logic;

    -- I/O
    signal io_write: std_logic;
    signal io_byte_sel: std_logic_vector(3 downto 0);
    signal io_addr: std_logic_vector(11 downto 2);
    signal cpu_to_io, io_to_cpu: std_logic_vector(31 downto 0);
    signal from_flash, from_sdcard, from_sio: std_logic_vector(31 downto 0);
    signal sio_txd, sio_ce, sio_break: std_logic;
    signal flash_ce, sdcard_ce: std_logic;
    signal io_addr_strobe: std_logic_vector((C_io_ports - 1) downto 0);
    signal next_io_port: integer range 0 to (C_io_ports - 1);
    signal R_cur_io_port: integer range 0 to (C_io_ports - 1);
    signal R_led: std_logic_vector(7 downto 0);
    signal R_sw: std_logic_vector(3 downto 0);
    signal R_btns: std_logic_vector(4 downto 0);
    signal R_fb_mode: std_logic_vector(1 downto 0) := "11";
    signal R_fb_base_addr: std_logic_vector(29 downto 2);

    -- CPU reset control
    signal R_cpu_reset: std_logic_vector(15 downto 0) := x"fffe";

    -- Video framebuffer
    signal R_fb_intr: std_logic;
    signal video_dac: std_logic_vector(3 downto 0);
    signal fb_addr_strobe, fb_data_ready: std_logic;
    signal fb_addr: std_logic_vector(29 downto 2);
    signal fb_tick: std_logic;

    -- PCM audio
    signal pcm_addr_strobe, pcm_data_ready: std_logic;
    signal pcm_addr: std_logic_vector(29 downto 2);
    signal from_pcm: std_logic_vector(31 downto 0);
    signal pcm_ce, pcm_l, pcm_r: std_logic;

    -- DDS frequency synthesizer
    signal R_dds, R_dds_fast, R_dds_acc: std_logic_vector(31 downto 0);
    signal R_dds_enable: std_logic;

    -- GPIO
    signal from_gpio: std_logic_vector(31 downto 0);
    signal gpio_ce: std_logic;
    signal gpio_intr: std_logic;
    signal gpio_28: std_logic;

    -- Timer
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;

    -- debugging only
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_debug: std_logic_vector(7 downto 0);
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    --
    -- Clock synthesizer
    --
    clk_81_325: if C_tx433 = false generate
    clkgen_video: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_25m => clk_25m, ena_325m => ena_325m,
	clk => clk, clk_325m => clk_325m, res => '0'
    );
    ena_325m <= R_dds_enable when R_fb_mode = "11" else '1';
    end generate;

    clk_81_433: if C_tx433 = true generate
    clkgen_tx433: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk_25m => clk_25m, ena_325m => '0',
	clk => clk, clk_325m => open, res => '0'
    );
    ena_325m <= '0';
    clk433gen: entity work.pll_81M25_433M33
    port map (
	CLK => clk, CLKOP => clk_433m
    );
    end generate;

    --
    -- f32c core(s)
    --
    G_CPU: for i in 0 to (C_cpus - 1) generate
    begin
    intr(i) <= "00" & gpio_intr & timer_intr & from_sio(8) & R_fb_intr
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
	C_cached_addr_bits => C_cached_addr_bits,
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
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
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
    end generate;

    --
    -- RS232 sio
    --
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq,
	C_break_detect => true
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => rs232_rx,
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_sio, break => sio_break
    );
    sio_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"30" else '0';
    end generate;

    --
    -- On-board SPI flash
    --
    G_flash:
    if C_flash generate
    flash: entity work.spi
    port map (
	clk => clk, ce => flash_ce,
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_flash,
	spi_sck => flash_sck, spi_cen => flash_cen,
	spi_mosi => flash_si, spi_miso => flash_so
    );
    flash_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"34" else '0';
    end generate;

    --
    -- MicroSD card
    --
    G_sdcard:
    if C_sdcard generate
    sdcard: entity work.spi
    port map (
	clk => clk, ce => sdcard_ce,
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_sdcard,
	spi_sck => sdcard_sck, spi_cen => sdcard_cen,
	spi_mosi => sdcard_si, spi_miso => sdcard_so
    );
    sdcard_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"35" else '0';
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
    io_addr <=  '0' & dmem_addr(R_cur_io_port)(10 downto 2);
    io_byte_sel <= dmem_byte_sel(R_cur_io_port);
    cpu_to_io <= cpu_to_dmem(R_cur_io_port);
    process(clk)
    begin
	if rising_edge(clk) then
	    R_cpu_reset(0) <= sio_break;
	    R_cur_io_port <= next_io_port;
	end if;
	if rising_edge(clk) and io_addr_strobe(R_cur_io_port) = '1'
	  and io_write = '1' then
	    -- LEDs
	    if C_leds_btns and io_addr(11 downto 4) = x"71" and
	      io_byte_sel(0) = '1' then
		R_led <= cpu_to_io(7 downto 0);
	    end if;
	    -- DDS
	    if C_dds and io_addr(11 downto 4) = x"7D" then
		R_dds <= cpu_to_io;
	    end if;
	    -- CPU reset control
	    if C_cpus /= 1 and io_addr(11 downto 4) = x"7F" then
		R_cpu_reset <= cpu_to_io(15 downto 0);
	    end if;
	    -- Framebuffer
	    if C_framebuffer and io_addr(11 downto 4) = x"38" then
		if C_big_endian then
		    R_fb_mode <= cpu_to_io(25 downto 24);
		    R_fb_base_addr <=
		      cpu_to_io(11 downto 8) &
		      cpu_to_io(23 downto 16) &
		      cpu_to_io(31 downto 26);
		else
		    R_fb_mode <= cpu_to_io(1 downto 0);
		    R_fb_base_addr <= cpu_to_io(29 downto 2);
		end if;
	    end if;
	end if;
	if C_framebuffer and rising_edge(clk) then
	    if io_addr_strobe(R_cur_io_port) = '1' and
	      io_addr(11 downto 4) = x"38" then
		R_fb_intr <= '0';
	    end if;
	    if fb_tick = '1' then
		R_fb_intr <= '1';
	    end if;
	end if;
	if C_leds_btns and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= btn_center & btn_up & btn_down & btn_left & btn_right;
	end if;
    end process;
    G_led_standard:
    if C_timer = false generate
    led <= R_led when C_leds_btns else (others => '-');
    end generate;
    G_led_timer:
    if C_timer = true generate
    ocp_mux(0) <= ocp(0) when ocp_enable(0)='1' else R_led(1);
    ocp_mux(1) <= ocp(1) when ocp_enable(1)='1' else R_led(2);
    led <= R_led(7 downto 3) & ocp_mux & R_led(0) when C_leds_btns
      else (others => '-');
    end generate;

    -- XXX replace with a balanced multiplexer
    process(io_addr, R_sw, R_btns, from_sio, from_flash, from_sdcard,
      from_gpio, from_timer)
    begin
	case io_addr(11 downto 4) is
	when x"00" | x"01" =>
	    if C_gpio then
		io_to_cpu <= from_gpio;
	    else
		io_to_cpu <= (others => '-');
	    end if;	
	when x"10" | x"11" | x"12" | x"13"  =>
	    if C_timer then
		io_to_cpu <= from_timer;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"30"  =>
	    if C_sio then
		io_to_cpu <= from_sio;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"34"  =>
	    if C_flash then
		io_to_cpu <= from_flash;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"35"  =>
	    if C_sdcard then
		io_to_cpu <= from_sdcard;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"3A"  =>
	    if C_pcm then
		io_to_cpu <= from_pcm;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"70"  =>
	    if C_leds_btns then
		io_to_cpu <="------------" & R_sw & "-----------" & R_btns;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"71"  =>
	    if C_leds_btns then
		io_to_cpu <="------------------------" & R_led;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when others =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    --
    -- ROM (only CPU #0)
    --
    rom: entity work.rom
    generic map (
	C_arch => C_arch,
	C_big_endian => C_big_endian,
	C_boot_spi => C_boot_spi
    )
    port map (
	clk => clk, strobe => imem_addr_strobe(0), addr => imem_addr(0),
	data_out => rom_i_to_cpu, data_ready => rom_i_ready
    );


    --
    -- SRAM
    --
    process(imem_addr, dmem_addr, dmem_byte_sel, cpu_to_dmem, dmem_write,
      dmem_addr_strobe, imem_addr_strobe, fb_addr_strobe, fb_addr,
      sram_ready, io_to_cpu, from_sram)
	variable data_port, instr_port, fb_port, pcm_port: integer;
	variable refresh_port: integer;
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
		else
		    -- XXX assert address eror signal?
		    dmem_data_ready(cpu) <= dmem_addr_strobe(cpu);
		    final_to_cpu_d(cpu) <= (others => '-');
		end if;
		-- CPU, instruction bus
		if sram_instr_strobe = '1' then
		    imem_data_ready(cpu) <= sram_ready(instr_port);
		    final_to_cpu_i(cpu) <= from_sram;
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
		    imem_data_ready(cpu) <= '1';
		    final_to_cpu_i(cpu) <= (others => '-');
		end if;
	    end if;
	    -- CPU, data bus
	    to_sram(data_port).addr_strobe <= sram_data_strobe;
	    to_sram(data_port).write <= dmem_write(cpu);
	    to_sram(data_port).byte_sel <= dmem_byte_sel(cpu);
	    to_sram(data_port).addr <= dmem_addr(cpu)(29 downto 2);
	    to_sram(data_port).data_in <= cpu_to_dmem(cpu);
	    -- CPU, instruction bus
	    to_sram(instr_port).addr_strobe <= sram_instr_strobe;
	    to_sram(instr_port).addr <= imem_addr(cpu)(29 downto 2);
	    to_sram(instr_port).data_in <= (others => '-');
	    to_sram(instr_port).write <= '0';
	    to_sram(instr_port).byte_sel <= x"f";
	end loop;
	-- video framebuffer
	if C_framebuffer then
	    fb_port := 2 * C_cpus;
	    to_sram(fb_port).addr_strobe <= fb_addr_strobe;
	    to_sram(fb_port).write <= '0';
	    to_sram(fb_port).byte_sel <= x"f";
	    to_sram(fb_port).addr <= fb_addr;
	    to_sram(fb_port).data_in <= (others => '-');
	    fb_data_ready <= sram_ready(fb_port);
	end if;
	if C_pcm then
	    pcm_port := 2 * C_cpus + 1;
	    to_sram(pcm_port).addr_strobe <= pcm_addr_strobe;
	    to_sram(pcm_port).write <= '0';
	    to_sram(pcm_port).byte_sel <= x"f";
	    to_sram(pcm_port).addr <= pcm_addr;
	    to_sram(pcm_port).data_in <= (others => '-');
	    pcm_data_ready <= sram_ready(pcm_port);
	end if;
	if C_psram_refresh then
	    refresh_port := 2 * C_cpus + 2;
	    to_sram(refresh_port).addr_strobe <= R_refresh_strobe;
	    to_sram(refresh_port).write <= '0';
	    to_sram(refresh_port).byte_sel <= x"f";
	    to_sram(refresh_port).addr <= R_refresh_addr;
	    to_sram(refresh_port).data_in <= (others => '-');
	    refresh_data_ready <= sram_ready(refresh_port);
	end if;
    end process;

    G_sram:
    if C_sram generate
    sram: entity work.sram
    generic map (
	C_ports => 2 * C_cpus + 3, -- extras: framebuffer, PCM, PSRAM refresh
	C_prio_port => 2 * C_cpus, -- framebuffer
	C_wait_cycles => C_sram_wait_cycles,
	C_pipelined_read => C_pipelined_read
    )
    port map (
	clk => clk, sram_a => sram_a, sram_d => sram_d,
	sram_wel => sram_wel, sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	data_out => from_sram,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	-- Multi-port connections:
	bus_in => to_sram, ready_out => sram_ready
    );
    end generate;

    -- Buggy ISSI IS66WV51216DBLL PSRAM silicon from 2015 needs this!
    G_psram_refresh:
    if C_psram_refresh generate
    process(clk)
    begin
	if rising_edge(clk) then
	    if refresh_data_ready = '1' then
		-- DRAM page size is apparently 512 bytes, our bus width is 4B
		R_refresh_addr <= R_refresh_addr + 512 / 4;
		-- Refresh all 2048 pages every 32 ms, per IS42S16100E specs
		R_refresh_cnt <= C_clk_freq * 1000000 / 32 / 2048;
	    end if;
	    if R_refresh_cnt /= 0 then
		R_refresh_cnt <= R_refresh_cnt - 1;
		R_refresh_strobe <= '0';
	    else
		R_refresh_strobe <= not refresh_data_ready;
	    end if;
	end if;
    end process;
    end generate;

    --
    -- Video framebuffer
    --
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
	data_in => from_sram,
	mode => R_fb_mode,
	base_addr => R_fb_base_addr,
	dac_out => video_dac,
	tick_out => fb_tick
    );
    end generate;

    --
    -- PCM audio
    --
    G_pcm:
    if C_pcm generate
    pcm: entity work.pcm
    port map (
	clk => clk, io_ce => pcm_ce, io_addr => io_addr(3 downto 2),
	io_bus_write => io_write, io_byte_sel => io_byte_sel,
	io_bus_in => cpu_to_io, io_bus_out => from_pcm,
	addr_strobe => pcm_addr_strobe, data_ready => pcm_data_ready,
	addr_out => pcm_addr, data_in => from_sram,
	out_r => pcm_r, out_l => pcm_l
    );
    pcm_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 4) = x"3A" else '0';
    end generate;

    p_tip <= (others => R_dds_acc(31)) when C_dds and R_dds_enable = '1'
      else video_dac when C_framebuffer and R_fb_mode /= "11"
      else (others => pcm_l);
    p_ring <= R_dds_acc(31) when C_dds and R_dds_enable = '1'
      else pcm_r;

    --
    -- GPIO
    --
    G_gpio:
    if C_gpio generate
    gpio_inst: entity work.gpio
    port map (
	clk => clk, ce => gpio_ce, addr => io_addr(4 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_gpio,
	gpio_irq => gpio_intr,
	gpio_phys(0)  =>   j1_2,
	gpio_phys(1)  =>   j1_3,
	gpio_phys(2)  =>   j1_4,
	gpio_phys(3)  =>   j1_8,
	gpio_phys(4)  =>   j1_9,
	gpio_phys(5)  =>   j1_13,
	gpio_phys(6)  =>   j1_14,
	gpio_phys(7)  =>   j1_15,
	gpio_phys(8)  =>   j1_16,
	gpio_phys(9)  =>   j1_17,
	gpio_phys(10) =>   j1_18,
	gpio_phys(11) =>   j1_19,
	gpio_phys(12) =>   j1_20,
	gpio_phys(13) =>   j1_21,
	gpio_phys(14) =>   j1_22,
	gpio_phys(15) =>   j1_23,
	gpio_phys(16) =>   j2_2,
	gpio_phys(17) =>   j2_3,
	gpio_phys(18) =>   j2_4,
	gpio_phys(19) =>   j2_5,
	gpio_phys(20) =>   j2_6,
	gpio_phys(21) =>   j2_7,
	gpio_phys(22) =>   j2_8,
	gpio_phys(23) =>   j2_9,
	gpio_phys(24) =>   j2_10,
	gpio_phys(25) =>   j2_11,
	gpio_phys(26) =>   j2_12,
	gpio_phys(27) =>   j2_13,
	gpio_phys(28) =>   gpio_28
    );
    gpio_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 8) = x"0" else '0';
    end generate;
    normal_gpio_28: if C_tx433 = false generate
    j2_16 <= gpio_28;
    end generate;
    signal_433MHz_to_gpio_28: if C_tx433 = true generate
    j2_16 <= gpio_28 and clk_433m;
    end generate;

    --
    -- Timer
    --
    G_timer:
    if C_timer generate
    icp <= R_led(3) & R_led(0); -- during debug period, leds will serve as software-generated ICP
    timer: entity work.timer
    generic map (
	C_pres => 10,
	C_bits => 12
    )
    port map (
	clk => clk, ce => timer_ce, addr => io_addr(5 downto 2),
	bus_write => io_write, byte_sel => io_byte_sel,
	bus_in => cpu_to_io, bus_out => from_timer,
	timer_irq => timer_intr,
	ocp_enable => ocp_enable, -- enable physical output
	ocp => ocp, -- output compare signal
	icp_enable => icp_enable, -- enable physical input
	icp => icp -- input capture signal
    );
    timer_ce <= io_addr_strobe(R_cur_io_port) when
      io_addr(11 downto 8) = x"1" else '0';
    end generate;

    --
    -- DDS
    --
    process(clk_325m)
    begin
	if rising_edge(clk_325m) then
	    R_dds_fast <= R_dds;
	    R_dds_acc <= R_dds_acc + R_dds_fast;
	end if;
    end process;

    -- Debugging SIO instance
    G_debug_sio:
    if C_debug generate
    debug_sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => false
    )
    port map (
	clk => clk, ce => '1', txd => deb_tx, rxd => rs232_rx,
	bus_write => deb_sio_tx_strobe, byte_sel => "0001",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_out(7 downto 0) => sio_to_debug_data,
	bus_out(8) => deb_sio_rx_done, bus_out(10) => deb_sio_tx_busy,
	break => open
    );
    end generate;

    rs232_tx <= sio_txd when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;
