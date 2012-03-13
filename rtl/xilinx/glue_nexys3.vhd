--
-- Copyright 2008, 2010 University of Zagreb, Croatia.
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

-- $Id: glue.vhd 914 2012-02-16 12:56:32Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity glue is
    generic(
	-- Main clock: N * 10 MHz
	C_clk_freq: integer := 170;

	-- ISA options
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_PC_mask: std_logic_vector(31 downto 0) := x"00003fff";
    
	-- COP0 options
	C_cop0_count: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
--	C_register_technology: string := "xilinx_ram32x1s";
	C_register_technology: string := "xilinx_ram16x1d";

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete
	C_fast_ID: boolean := true;

	-- debugging options
	C_debug: boolean := false;

	-- SoC configuration options
	C_mem_size: string := "16k";
	C_sio: boolean := true;
	C_gpio: boolean := true
    );
    port (
	clk_100m: in std_logic;
	rs232_dce_txd: out std_logic;
	rs232_dce_rxd: in std_logic;
--	lcd_db: out std_logic_vector(7 downto 0);
--	lcd_e, lcd_rs, lcd_rw: out std_logic;
--	j1, j2: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
--	rot_a, rot_b, rot_center: in std_logic;
	btn_center: in std_logic;
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
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_txd, sio_rxd, sio_ce: std_logic;
    signal R_led: std_logic_vector(7 downto 0);
    signal R_sw: std_logic_vector(3 downto 0);
    signal R_btns: std_logic_vector(6 downto 0);

    -- debugging only
    signal trace_addr: std_logic_vector(5 downto 0);
    signal trace_data: std_logic_vector(31 downto 0);
    signal debug_txd: std_logic;
    signal debug_res: std_logic;
    signal clk_key: std_logic;

begin

    -- f32c core
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
	clk => clk, reset => '0', intr => '0',
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	trace_addr => trace_addr, trace_data => trace_data
    );

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity work.sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => sio_rxd,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"f" and
      dmem_addr(4 downto 2) = "001" else '0';
    rs232_dce_txd <= debug_txd when C_debug and sw(3) = '1' else sio_txd;
    sio_rxd <= rs232_dce_rxd;
    end generate;

    -- I/O port map:
    -- 0x8*******: (2B, RW)   SRAM
    -- 0xf*****00: (4B, RW) * GPIO (LED, switches/buttons)
    -- 0xf*****04: (4B, RW) * SIO
    -- 0xf*****08: (4B, RD) * TSC
    -- 0xf*****0c: (4B, WR)   PCM signal
    -- 0xf*****10: (1B, RW)   SPI Flash
    -- 0xf*****14: (1B, RW)   SPI MicroSD
    -- 0xf*****1c: (4B, WR)   FM DDS register
    -- I/O write access:
    process(clk)
    begin
	if rising_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_write = '1'
	      and dmem_addr(31 downto 28) = x"f" then
		-- GPIO
		if C_gpio and dmem_addr(4 downto 2) = "000" then
		    if dmem_byte_sel(0) = '1' then
			R_led <= cpu_to_dmem(7 downto 0);
		    end if;
		    if dmem_byte_sel(1) = '1' then
--			j1 <= cpu_to_dmem(11 downto 8);
--			j2 <= cpu_to_dmem(15 downto 12);
		    end if;
		    if dmem_byte_sel(2) = '1' then
--			lcd_db <= cpu_to_dmem(23 downto 16);
		    end if;
		    if dmem_byte_sel(3) = '1' then
--			lcd_e <= cpu_to_dmem(26);
--			lcd_rs <= cpu_to_dmem(25);
--			lcd_rw <= cpu_to_dmem(24);
		    end if;
		end if;
	    end if;
	end if;
    end process;
    led <= R_led when C_gpio else "--------";

    process(clk)
    begin
	if C_gpio and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <=
--	      rot_a & rot_b & rot_center &
	      "00" & btn_center &
	      btn_north & btn_south & btn_west & btn_east;
	end if;
    end process;

    -- XXX replace with a balanced multiplexer
    process(dmem_addr, R_sw, R_btns, from_sio)
    begin
	case dmem_addr(4 downto 2) is
	when "000"  =>
	    io_to_cpu <="----------------" & "----" & R_sw & "-" & R_btns;
	when "001"  => io_to_cpu <= from_sio;
	when others =>
	    io_to_cpu <= "--------------------------------";
	end case;
    end process;

    final_to_cpu <= io_to_cpu when dmem_addr(31 downto 28) = x"f"
      else dmem_to_cpu;

    -- a DLL clock synthesizer
    clkgen: entity work.clkgen
    generic map(
	C_debug => C_debug,
	C_clk_freq => C_clk_freq
    )
    port map(
	clk_100m => clk_100m, clk => clk, key => clk_key, sel => sw(0)
    );
	
    -- Block RAM
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31) /= '1' else '0';
    imem_data_ready <= '1';
    dmem_data_ready <= '1';
    bram: entity work.bram
    generic map (
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );

    -- debugging design instance - serial port + control knob / buttons
    G_debug:
    if C_debug generate
    --clk_key <= btn_south;
    clk_key <= '1'; -- clk selector
    debug_serial: entity work.serial_debug
    port map(
	clk_50m => clk,
	rs232_txd => debug_txd,
	trace_addr => trace_addr,
	trace_data => trace_data
    );
    end generate; -- serial_debug
	
    G_nodebug:
    if not C_debug generate
    clk_key <= '1'; -- clk selector
    end generate; -- nodebug
	
end Behavioral;

