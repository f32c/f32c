--
-- Copyright 2015 Marko Zec, University of Zagreb
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

-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


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

	-- FPGA platform-specific options
	C_register_technology: string := "generic";

	-- Negatively influences timing closure, hence disabled
	C_movn_movz: boolean := false;

	-- CPU debugging
	C_debug: boolean := false;

	-- SoC configuration options
	C_mem_size: integer := 16;	-- in KBytes
	C_sio: boolean := true;
	C_gpio: boolean := true;
	C_timer: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	clk: in std_logic;
	rs232_rx: in std_logic;
	rs232_tx, rs232_break: out std_logic;
	btns: in std_logic_vector(15 downto 0);
	sw: in std_logic_vector(15 downto 0);
	gpio: inout std_logic_vector(31 downto 0);
	leds: out std_logic_vector(15 downto 0);
	lcd_7seg: out std_logic_vector(15 downto 0)
    );
end glue_bram;

architecture Behavioral of glue_bram is
    signal imem_addr: std_logic_vector(31 downto 2);
    signal imem_data_read: std_logic_vector(31 downto 0);
    signal imem_addr_strobe, imem_data_ready: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_bram_write, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
    signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr_strobe: std_logic;
    signal io_addr: std_logic_vector(11 downto 2);
    signal intr: std_logic_vector(5 downto 0); -- interrupt

    -- Timer
    signal from_timer: std_logic_vector(31 downto 0);
    signal timer_ce: std_logic;
    signal ocp, ocp_enable, ocp_mux: std_logic_vector(1 downto 0);
    signal icp, icp_enable: std_logic_vector(1 downto 0);
    signal timer_intr: std_logic;
    
    -- GPIO
    signal from_gpio: std_logic_vector(31 downto 0);
    signal gpio_ce: std_logic;
    signal gpio_intr: std_logic;
        
    -- Serial I/O (RS232)
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_ce, sio_break, sio_tx: std_logic;

    -- onboard LEDs, buttons and switches
    signal R_leds: std_logic_vector(15 downto 0);
    signal R_lcd_7seg: std_logic_vector(15 downto 0);
    signal R_btns: std_logic_vector(15 downto 0);
    signal R_sw: std_logic_vector(15 downto 0);
   
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
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => sio_break, intr => intr,
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
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
    final_to_cpu <= io_to_cpu when io_addr_strobe = '1' else dmem_to_cpu;
    intr <= "00" & gpio_intr & timer_intr & from_sio(8) & '0';
    io_addr_strobe <= '1' when dmem_addr(31 downto 30) = "11" else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    imem_data_ready <= '1';
    dmem_data_ready <= '1';

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_tx, rxd => rs232_rx,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio, break => sio_break
    );
    sio_ce <= io_addr_strobe when io_addr(11 downto 4) = x"30" else '0';
    rs232_break <= sio_break;
    end generate;

    --
    -- I/O
    --
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1' and dmem_write = '1' then
	    -- LEDs
	    if C_leds_btns and io_addr(11 downto 4) = x"70" then
		if dmem_byte_sel(0) = '1' then
		    R_leds(7 downto 0) <= cpu_to_dmem(7 downto 0);
		end if;
		if dmem_byte_sel(1) = '1' then
		    R_leds(15 downto 8) <= cpu_to_dmem(15 downto 8);
		end if;
		if dmem_byte_sel(2) = '1' then
		    R_lcd_7seg(7 downto 0) <= cpu_to_dmem(23 downto 16);
		end if;
		if dmem_byte_sel(3) = '1' then
		    R_lcd_7seg(15 downto 8) <= cpu_to_dmem(31 downto 24);
		end if;
	    end if;
	end if;
	if C_leds_btns and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= btns;
	end if;
    end process;

    G_led_standard:
    if C_timer = false generate
    leds <= R_leds when C_leds_btns else (others => '-');
    end generate;
    G_led_timer:
    if C_timer = true generate
    ocp_mux(0) <= ocp(0) when ocp_enable(0)='1' else R_leds(1);
    ocp_mux(1) <= ocp(1) when ocp_enable(1)='1' else R_leds(2);
    leds <= R_leds(15 downto 3) & ocp_mux & R_leds(0) when C_leds_btns
      else (others => '-');
    end generate;

    process(io_addr, R_sw, R_btns, from_sio, from_timer, from_gpio)
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
	when x"70"  =>
	    if C_leds_btns then
		io_to_cpu <= R_sw & R_btns;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when others =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    -- GPIO
    G_gpio:
    if C_gpio generate
    gpio_inst: entity work.gpio
    generic map (
	C_bits => 32
    )
    port map (
	clk => clk, ce => gpio_ce, addr => dmem_addr(4 downto 2),
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_gpio,
	gpio_irq => gpio_intr,
	gpio_phys => gpio -- physical input/output
    );
    gpio_ce <= io_addr_strobe when io_addr(11 downto 8) = x"0" else '0';
    end generate;


    -- Timer
    G_timer:
    if C_timer generate
    icp <= R_leds(3) & R_leds(0); -- during debug period, leds will serve as software-generated ICP
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
    dmem_bram_write <=
      dmem_addr_strobe and dmem_write when dmem_addr(31) /= '1' else '0';
    G_bram_mi32:
    if C_arch = ARCH_MI32 generate
    bram_mi32: entity work.bram_mi32
    generic map (
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_write => dmem_bram_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );
    end generate;
    G_bram_rv32:
    if C_arch = ARCH_RV32 generate
    bram_rv32: entity work.bram_rv32
    generic map (
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_write => dmem_bram_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
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
	clk => clk, ce => '1', txd => deb_tx, rxd => rs232_rx,
	bus_write => deb_sio_tx_strobe, byte_sel => "0001",
	bus_in(7 downto 0) => debug_to_sio_data,
	bus_in(31 downto 8) => x"000000",
	bus_out(7 downto 0) => sio_to_debug_data,
	bus_out(8) => deb_sio_rx_done, bus_out(9) => open,
	bus_out(10) => deb_sio_tx_busy, bus_out(31 downto 11) => open,
	break => open
    );
    end generate;

    rs232_tx <= sio_tx when not C_debug or debug_active = '0' else deb_tx;

end Behavioral;
