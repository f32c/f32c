--
-- Copyright 2008-2015 Marko Zec, University of Zagreb
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

entity glue is
    generic(
	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 80;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"00007fff";
    
	-- COP0 options
	C_exceptions: boolean := false;
	C_cop0_count: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;

	-- FPGA platform-specific options
	C_register_technology: string := "xilinx_ram16x1d"; --"xilinx_ram32x1s";

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete

	-- SoC configuration options
	C_bram_size: integer := 32;	-- KBytes
	C_sio: boolean := true;
	C_leds_btns: boolean := true;
	C_lcd: boolean := true
    );
    port (
	clk_50m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
	lcd_db: out std_logic_vector(7 downto 0);
	lcd_e, lcd_rs, lcd_rw: out std_logic;
	j1, j2: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
	rot_a, rot_b, rot_center: in std_logic;
	btn_south, btn_north, btn_east, btn_west: in std_logic;
	sw: in std_logic_vector(3 downto 0)
    );
end glue;

architecture Behavioral of glue is
    signal clk: std_logic;
    signal imem_addr: std_logic_vector(31 downto 2);
    signal imem_data_read: std_logic_vector(31 downto 0);
    signal imem_addr_strobe, imem_data_ready: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_bram_enable, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
    signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);

    -- I/O
    signal io_addr_strobe: std_logic;
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_ce: std_logic;
    signal R_led: std_logic_vector(7 downto 0);
    signal R_lcd: std_logic_vector(5 downto 0);
    signal R_sw: std_logic_vector(3 downto 0);
    signal R_btns: std_logic_vector(6 downto 0);

begin

    -- clock synthesizer
    clkgen: entity work.clkgen
    generic map(
	C_clk_freq => C_clk_freq,
	C_debug => false
    )
    port map(
	clk_50m => clk_50m, clk => clk, key => '0', sel => '0'
    );

    -- f32c core
    pipeline: entity work.pipeline
    generic map (
	C_arch => C_arch, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_exceptions => C_exceptions, C_ll_sc => C_ll_sc,
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => false
    )
    port map (
	clk => clk, reset => '0', intr => (others => '0'),
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => '0', snoop_addr => "------------------------------",
	flush_i_line => open, flush_d_line => open,
	trace_addr => "------", trace_data => open
    );
    final_to_cpu <= io_to_cpu when io_addr_strobe = '1' else dmem_to_cpu;

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_fixed_baudrate => true,
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, ce => sio_ce, txd => rs232_dce_txd, rxd => rs232_dce_rxd,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11" and
      dmem_addr(7 downto 4) = x"2" else '0';
    end generate;

    --
    -- I/O port map:
    -- 0xf*****10: (2B, RW) : LED, LCD (WR), switches, buttons (RD)
    -- 0xf*****20: (4B, RW) * SIO
    --
    io_addr_strobe <= '1' when dmem_addr(31 downto 30) = "11" else '0';
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1'
	  and dmem_write = '1' then
	    -- LEDs
	    if C_leds_btns and dmem_addr(7 downto 4) = x"1" and
	      dmem_byte_sel(1) = '1' then
		R_led <= cpu_to_dmem(7 downto 0);
	    end if;
	    -- LCD
	    if C_lcd and dmem_addr(7 downto 4) = x"1" and
	      dmem_byte_sel(3) = '1' then
		R_lcd <= cpu_to_dmem(13 downto 8);
	    end if;
	end if;
	if C_leds_btns and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= rot_a & rot_b & rot_center &
	      btn_north & btn_south & btn_west & btn_east;
	end if;
    end process;
    led <= R_led when C_leds_btns else "ZZZZZZZZ";
    lcd_db <= R_lcd(3 downto 0) & "ZZZZ" when C_lcd else "ZZZZZZZZ";
    lcd_rs <= R_lcd(4) when C_lcd else 'Z';
    lcd_e <= R_lcd(5) when C_lcd else 'Z';
    lcd_rw <= '0' when C_lcd else 'Z';
    process(dmem_addr, R_sw, R_btns, from_sio)
    begin
	case dmem_addr(7 downto 4) is
	when x"1"  =>
	    if C_leds_btns then
		io_to_cpu <="------------" & R_sw & "---------" & R_btns;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when x"2"  =>
	    if C_sio then
		io_to_cpu <= from_sio;
	    else
		io_to_cpu <= (others => '-');
	    end if;
	when others =>
	    io_to_cpu <= (others => '-');
	end case;
    end process;

    -- Block RAM
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31) /= '1' else '0';
    imem_data_ready <= '1';
    dmem_data_ready <= '1';
    bram: entity work.bram
    generic map (
	C_mem_size => C_bram_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );

    -- Appease XST for unused ports
    j1 <= "ZZZZ";
    j2 <= "ZZZZ";

end Behavioral;
