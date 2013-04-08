--
-- Copyright 2011 University of Zagreb.
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
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--

-- $Id: glue.vhd 116 2011-03-28 12:43:12Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


entity glue is
    generic (
	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 81;

	-- ISA options
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_PC_mask: std_logic_vector(31 downto 0) := x"800fffff";

	-- COP0 options
	C_cop0_count: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
	C_register_technology: string := "lattice";

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete
	C_fast_ID: boolean := true; -- false: +7 LUT4, -Fmax

	-- debugging options
	C_debug: boolean := false; -- true: +883 LUT4, -Fmax

	-- SoC configuration options
	C_cpus: integer := 1;
	C_bram_size: string := "16k";
	C_sram: boolean := true;
	C_sram_wait_cycles: std_logic_vector := x"5"; -- ISSI, OK do 87.5 MHz
	C_sio: boolean := true;
	C_gpio: boolean := true;
	C_flash: boolean := true;
	C_sdcard: boolean := true;
	C_pcmdac: boolean := true;
	C_ddsfm: boolean := true
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
	j1: out std_logic_vector(23 downto 20);
	j2: out std_logic_vector(5 downto 2);
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
    );
end glue;

architecture Behavioral of glue is
    -- types for signals going to / from f32c core(s)
    type f32c_addr_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 2);
    type f32c_byte_sel is array(0 to (C_cpus - 1)) of
      std_logic_vector(3 downto 0);
    type f32c_data_bus is array(0 to (C_cpus - 1)) of
      std_logic_vector(31 downto 0);
    type f32c_std_logic is array(0 to (C_cpus - 1)) of std_logic;
    type f32c_debug_addr is array(0 to (C_cpus - 1)) of
      std_logic_vector(5 downto 0);

    -- types for interfacing to multi-port SRAM controller
    type sram_port_multi is array(0 to (3 * C_cpus - 1)) of sram_port_type;
    type sram_ready_multi is array(0 to (3 * C_cpus - 1)) of std_logic;


    signal clk: std_logic;

    -- signals to / from f32c cores(s)
    signal res, intr: f32c_std_logic;
    signal imem_addr, dmem_addr: f32c_addr_bus;
    signal final_to_cpu_i, final_to_cpu_d, cpu_to_dmem: f32c_data_bus;
    signal imem_addr_strobe, dmem_addr_strobe, dmem_write: f32c_std_logic;
    signal imem_data_ready, dmem_data_ready: f32c_std_logic;
    signal dmem_byte_sel: f32c_byte_sel;

    -- SRAM
    signal to_sram: sram_port_multi;
    signal sram_ready: sram_ready_multi;
    signal sram_data_strobe, sram_data_ready: std_logic;
    signal sram_instr_strobe, sram_instr_ready: std_logic;
    signal from_sram: std_logic_vector(31 downto 0);

    -- Block RAM
    signal imem_to_cpu, dmem_to_cpu: std_logic_vector(31 downto 0);
    signal dmem_bram_enable: std_logic;

    -- I/O
    signal io_to_cpu: std_logic_vector(31 downto 0);
    signal from_sio, from_flash, from_sdcard: std_logic_vector(31 downto 0);
    signal sio_txd, sio_ce, flash_ce, sdcard_ce: std_logic;
    signal R_led: std_logic_vector(7 downto 0);
    signal R_sw: std_logic_vector(3 downto 0);
    signal R_btns: std_logic_vector(4 downto 0);
    signal R_dac_in_l, R_dac_in_r: std_logic_vector(15 downto 2);
    signal R_dac_acc_l, R_dac_acc_r: std_logic_vector(16 downto 2);

    -- debugging only
    signal trace_addr: f32c_debug_addr;
    signal trace_data: f32c_data_bus;
    signal debug_txd: std_logic;

    -- FM TX DDS
    signal clk_dds, dds_out: std_logic;
    signal R_dds_cnt, R_dds_div, R_dds_div1: std_logic_vector(21 downto 0);

    -- Video framebuffer
    signal video_dac: std_logic_vector(3 downto 0);
    signal fb_addr_strobe, fb_data_ready: std_logic;
    signal fb_addr: std_logic_vector(19 downto 2);

begin

    -- clock synthesizer
    clkgen: entity work.clkgen
    generic map (
	C_clk_freq => C_clk_freq,
	C_debug => C_debug
    )
    port map (
	clk_25m => clk_25m, clk => clk, clk_325m => clk_dds,
	sel => sw(2), key => btn_down, res => '0'
    );

    -- f32c core(s)
    G_CPU: for i in 0 to (C_cpus - 1) generate
    begin
    intr(i) <= '0';
    res(i) <= sw(i);
    pipeline: entity work.pipeline
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_fast_ID => C_fast_ID,
	C_register_technology => C_register_technology,
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
	trace_addr => trace_addr(i), trace_data => trace_data(i)
    );
    end generate;

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => rs232_rx,
	bus_write => dmem_write(0), byte_sel => dmem_byte_sel(0),
	bus_in => cpu_to_dmem(0), bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe(0) when dmem_addr(0)(31 downto 28) = x"f" and
      dmem_addr(0)(4 downto 2) = "001" else '0';
    end generate;

    -- On-board SPI flash
    G_flash:
    if C_flash generate
    flash: entity work.spi
    port map (
	clk => clk, ce => flash_ce,
	bus_write => dmem_write(0), byte_sel => dmem_byte_sel(0),
	bus_in => cpu_to_dmem(0), bus_out => from_flash,
	spi_sck => flash_sck, spi_cen => flash_cen,
	spi_si => flash_si, spi_so => flash_so
    );
    flash_ce <= dmem_addr_strobe(0) when dmem_addr(0)(31 downto 28) = x"f" and
      dmem_addr(0)(4 downto 2) = "100" else '0';
    end generate;

    -- MicroSD card
    G_sdcard:
    if C_sdcard generate
    sdcard: entity work.spi
    port map (
	clk => clk, ce => sdcard_ce,
	bus_write => dmem_write(0), byte_sel => dmem_byte_sel(0),
	bus_in => cpu_to_dmem(0), bus_out => from_sdcard,
	spi_sck => sdcard_sck, spi_cen => sdcard_cen,
	spi_si => sdcard_si, spi_so => sdcard_so
    );
    sdcard_ce <= dmem_addr_strobe(0) when dmem_addr(0)(31 downto 28) = x"f" and
      dmem_addr(0)(4 downto 2) = "101" else '0';
    end generate;

    -- PCM stereo 1-bit DAC
    G_pcmdac:
    if C_pcmdac generate
    process(clk)
    begin
	if rising_edge(clk) then
	    R_dac_acc_l <= (R_dac_acc_l(16) & R_dac_in_l) + R_dac_acc_l;
	    R_dac_acc_r <= (R_dac_acc_r(16) & R_dac_in_r) + R_dac_acc_r;
	end if;
    end process;
    p_tip(3) <= R_dac_acc_l(16) when sw(3) = '0' else video_dac(3);
    p_tip(2) <= R_dac_acc_l(16) when sw(3) = '0' else video_dac(2);
    p_tip(1) <= R_dac_acc_l(16) when sw(3) = '0' else video_dac(1);
    p_tip(0) <= '0' when sw(3) = '0' else video_dac(0);
    p_ring <= R_dac_acc_r(16);
    end generate;

    -- I/O port map:
    -- 0x8*******: (4B, RW) * SRAM
    -- 0xf*****00: (4B, RW) * GPIO (LED, switches/buttons)
    -- 0xf*****04: (4B, RW) * SIO
    -- 0xf*****0c: (4B, WR) * PCM signal
    -- 0xf*****10: (1B, RW) * SPI Flash
    -- 0xf*****14: (1B, RW) * SPI MicroSD
    -- 0xf*****1c: (4B, WR) * FM DDS register

    -- I/O write access:
    process(clk)
    begin
	if rising_edge(clk) and dmem_addr_strobe(0) = '1'
	  and dmem_write(0) = '1' and dmem_addr(0)(31 downto 28) = x"f" then
	    -- GPIO
	    if C_gpio and dmem_addr(0)(4 downto 2) = "000" then
		R_led <= cpu_to_dmem(0)(7 downto 0);
	    end if;
	    -- PCMDAC
	    if C_pcmdac and dmem_addr(0)(4 downto 2) = "011" then
		if dmem_byte_sel(0)(2) = '1' then
		    if C_big_endian then
			R_dac_in_l <= cpu_to_dmem(0)(23 downto 16) &
			  cpu_to_dmem(0)(31 downto 26);
		    else
			R_dac_in_l <= cpu_to_dmem(0)(31 downto 18);
		    end if;
		end if;
		if dmem_byte_sel(0)(0) = '1' then
		    if C_big_endian then
			R_dac_in_r <= cpu_to_dmem(0)(7 downto 0) &
			  cpu_to_dmem(0)(15 downto 10);
		    else
			R_dac_in_r <= cpu_to_dmem(0)(15 downto 2);
		    end if;
		end if;
	    end if;
	    -- DDS
	    if C_ddsfm and dmem_addr(0)(4 downto 2) = "111" then
		if C_big_endian then
		    R_dds_div <= cpu_to_dmem(0)(15 downto 10) & 
		      cpu_to_dmem(0)(23 downto 16) &
		      cpu_to_dmem(0)(31 downto 24);
		else
		    R_dds_div <= cpu_to_dmem(0)(21 downto 0);
		end if;
	    end if;
	end if;
    end process;
    led <= R_led when C_gpio else "--------";

    process(clk)
    begin
	if C_gpio and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= btn_center & btn_up & btn_down & btn_left & btn_right;
	end if;
    end process;

    -- XXX replace with a balanced multiplexer
    process(dmem_addr, R_sw, R_btns, from_sio, from_flash, from_sdcard)
    begin
	case dmem_addr(0)(4 downto 2) is
	when "000"  =>
	    io_to_cpu <="----------------" & "----" & R_sw & "---" & R_btns;
	when "001"  =>
	    if C_sio then
		io_to_cpu <= from_sio;
	    else
		io_to_cpu <= "--------------------------------";
	    end if;
	when "100"  =>
	    if C_flash then
		io_to_cpu <= from_flash;
	    else
		io_to_cpu <= "--------------------------------";
	    end if;
	when "101"  =>
	    if C_sdcard then
		io_to_cpu <= from_sdcard;
	    else
		io_to_cpu <= "--------------------------------";
	    end if;
	when others =>
	    io_to_cpu <= "--------------------------------";
	end case;
    end process;

    -- Block RAM
    dmem_bram_enable <= dmem_addr_strobe(0) when dmem_addr(0)(31) /= '1'
      else '0';
    bram: entity work.bram
    generic map (
	C_mem_size => C_bram_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe(0),
	imem_addr => imem_addr(0), imem_data_out => imem_to_cpu,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write(0),
	dmem_byte_sel => dmem_byte_sel(0), dmem_addr => dmem_addr(0),
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem(0)
    );

    -- SRAM
    sram_data_strobe <= dmem_addr_strobe(0) when
      dmem_addr(0)(31 downto 28) = x"8" and C_sram else '0';
    dmem_data_ready(0) <= sram_data_ready when sram_data_strobe = '1' else '1';
    sram_instr_strobe <= imem_addr_strobe(0) when
      imem_addr(0)(31 downto 28) = x"8" and C_sram else '0';
    imem_data_ready(0) <= sram_instr_ready when sram_instr_strobe = '1'
      else '1';

    process(imem_addr, dmem_addr, dmem_byte_sel, cpu_to_dmem, dmem_write,
      sram_data_strobe, sram_instr_strobe, fb_addr_strobe, fb_addr,
      sram_ready, io_to_cpu, from_sram)
	variable cpu, p: integer;
	variable fb_ready: std_logic;
    begin
	fb_ready := '0';
	for cpu in 0 to (C_cpus - 1) loop
	    p := cpu * 3;
	    if cpu = 0 then
		-- CPU, data bus
		to_sram(p).addr_strobe <= sram_data_strobe;
		sram_data_ready <= sram_ready(p);
		if dmem_addr(0)(31 downto 28) = x"f" then
		    final_to_cpu_d(0) <= io_to_cpu;
		elsif sram_data_strobe = '1' then
		    final_to_cpu_d(0) <= from_sram;
		else
		    final_to_cpu_d(0) <= dmem_to_cpu;
		end if;
		-- CPU, instruction bus
		to_sram(p + 1).addr_strobe <= sram_instr_strobe;
		sram_instr_ready <= sram_ready(p + 1);
		if sram_instr_strobe = '1' then
		    final_to_cpu_i(0) <= from_sram;
		else
		    final_to_cpu_i(0) <= imem_to_cpu;
		end if;
	    else -- CPU #1, CPU #2...
		-- CPU, data bus
		to_sram(p).addr_strobe <= dmem_addr_strobe(cpu);
		dmem_data_ready(cpu) <= sram_ready(p);
		final_to_cpu_d(1) <= from_sram;
		-- CPU, instruction bus
		to_sram(p + 1).addr_strobe <= imem_addr_strobe(cpu);
		imem_data_ready(cpu) <= sram_ready(p + 1);
		final_to_cpu_i(1) <= from_sram;
	    end if;
	    -- CPU, data bus
	    to_sram(p).write <= dmem_write(cpu);
	    to_sram(p).byte_sel <= dmem_byte_sel(cpu);
	    to_sram(p).addr <= dmem_addr(cpu)(19 downto 2);
	    to_sram(p).data_in <= cpu_to_dmem(cpu);
	    -- CPU, instruction bus
	    to_sram(p + 1).addr <= imem_addr(cpu)(19 downto 2);
	    to_sram(p + 1).data_in <= (others => '-');
	    to_sram(p + 1).write <= '0';
	    to_sram(p + 1).byte_sel <= x"f";
	    -- video framebuffer
	    to_sram(p + 2).addr_strobe <= fb_addr_strobe;
	    to_sram(p + 2).write <= '0';
	    to_sram(p + 2).byte_sel <= x"f";
	    to_sram(p + 2).addr <= fb_addr;
	    to_sram(p + 2).data_in <= (others => '-');
	    if sram_ready(p + 2) = '1' then
		fb_ready := '1';
	    end if;
	end loop;
	fb_data_ready <= fb_ready;
    end process;

    sram: entity work.sram
    generic map (
	C_ports => C_cpus * 3,
	C_sram_wait_cycles => C_sram_wait_cycles
    )
    port map (
	clk => clk, sram_a => sram_a, sram_d => sram_d,
	sram_wel => sram_wel, sram_lbl => sram_lbl, sram_ubl => sram_ubl,
	data_out => from_sram,
	-- Multi-port connections:
	bus_in => to_sram, ready_out => sram_ready
    );

    -- debugging design instance
    G_debug:
    if C_debug generate
    debug: entity work.serial_debug
    port map (
	clk => clk_25m, rs232_txd => debug_txd,
	trace_addr => trace_addr, trace_data => trace_data
    );
    end generate;

    rs232_tx <= debug_txd when C_debug and sw(3) = '1' else sio_txd;

    -- DDS FM transmitter
    G_ddsfm:
    if C_ddsfm generate
    process(clk_dds)
    begin
	if (rising_edge(clk_dds)) then
	    R_dds_div1 <= R_dds_div; -- Cross clock domain
	    R_dds_cnt <= R_dds_cnt + R_dds_div1;
	end if;
    end process;
    dds_out <= R_dds_cnt(21);
    end generate;

    -- make a dipole?
    j1(20) <= dds_out when C_ddsfm else 'Z';
    j1(21) <= dds_out when C_ddsfm else 'Z';
    j1(22) <= dds_out when C_ddsfm else 'Z';
    j1(23) <= dds_out when C_ddsfm else 'Z';
    j2(2) <= not dds_out when C_ddsfm else 'Z';
    j2(3) <= not dds_out when C_ddsfm else 'Z';
    j2(4) <= not dds_out when C_ddsfm else 'Z';
    j2(5) <= not dds_out when C_ddsfm else 'Z';

    -- Breakout game, producing PAL composite video
    fb: entity work.fb
    port map (
	clk => clk, clk_dac => clk_dds,
	addr_strobe => fb_addr_strobe,
	addr_out => fb_addr,
	data_ready => fb_data_ready,
	data_in => from_sram,
	dac_out => video_dac
    );

end Behavioral;
