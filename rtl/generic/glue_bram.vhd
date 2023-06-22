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


entity glue_bram is
    generic (
	C_clk_freq: integer;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_mul_reg: boolean := false;
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
	C_timer: boolean := true
    );
    port (
	clk: in std_logic;
	sio_rxd: in std_logic_vector(C_sio - 1 downto 0);
	sio_txd, sio_break: out std_logic_vector(C_sio - 1 downto 0);
	spi_sck, spi_ss, spi_mosi: out std_logic_vector(C_spi - 1 downto 0);
	spi_miso: in std_logic_vector(C_spi - 1 downto 0);
	simple_in: in std_logic_vector(31 downto 0);
	simple_out: out std_logic_vector(31 downto 0);
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
    signal R_simple_in, R_simple_out: std_logic_vector(31 downto 0);
   
    -- Debug
    signal sio_to_debug_data: std_logic_vector(7 downto 0);
    signal debug_to_sio_data: std_logic_vector(7 downto 0);
    signal deb_sio_rx_done, deb_sio_tx_busy, deb_sio_tx_strobe: std_logic;
    signal deb_tx: std_logic;
    signal debug_out_strobe: std_logic;
    signal debug_active: std_logic;

begin

    -- f32c core
    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_mul_reg => C_mul_reg,
	C_PC_mask => C_PC_mask,
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
	debug_active => debug_active
    );
    final_to_cpu_d <= io_to_cpu when io_addr_strobe = '1' else bram_d_to_cpu;
    intr <= "00" & gpio_intr_joint & timer_intr & from_sio(0)(8) & '0';
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11"
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    imem_data_ready <= bram_i_ready;
    dmem_data_ready <= bram_d_ready when dmem_addr(31) = '0' else '1';

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

    process(io_addr, R_simple_in, R_simple_out, from_sio, from_timer, from_gpio)
    begin
	io_to_cpu <= (others => '-');
	case conv_integer(io_addr(11 downto 4)) is
	when 16#00# to 16#07# =>
	    for i in 0 to C_gpios - 1 loop
		if conv_integer(io_addr(6 downto 5)) = i then
		    io_to_cpu <= from_gpio(i);
		end if;
	    end loop;
	when 16#10# to 16#13# =>
	    if C_timer then
		io_to_cpu <= from_timer;
	    end if;
	when 16#30# to 16#33# =>
	    for i in 0 to C_sio - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_sio(i);
		end if;
	    end loop;
	when 16#34# to 16#37# =>
	    for i in 0 to C_spi - 1 loop
		if conv_integer(io_addr(5 downto 4)) = i then
		    io_to_cpu <= from_spi(i);
		end if;
	    end loop;
	when 16#70#  =>
	    for i in 0 to (C_simple_in + 31) / 32 - 1 loop
		if conv_integer(io_addr(3 downto 2)) = i then
		    io_to_cpu(i * 32 + 31 downto i * 32) <=
		      R_simple_in(i * 32 + 31 downto i * 32);
		end if;
	    end loop;
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
    gpio_interrupt_collect: if C_gpios >= 1 generate
      gpio_intr_joint <= gpio_intr(0);
      -- TODO: currently only 32 gpio supported in fpgarduino core
      -- when support for 128 gpio is there we should use this:
      -- gpio_intr_joint <= '0' when conv_integer(gpio_intr) = 0 else '1';
    end generate;

    -- Timer
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
    timer_ce <= io_addr_strobe when io_addr(11 downto 8) = x"1" else '0';
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

end Behavioral;
