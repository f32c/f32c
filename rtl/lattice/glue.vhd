--
-- Copyright 2011 University of Zagreb, Croatia.
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

entity glue is
	generic(
		-- CPU core configuration options
		C_register_technology: string := "lattice";
		C_mult_enable: boolean := false;
		C_branch_prediction: boolean := true; -- true: +85 LUT4
		C_result_forwarding: boolean := true; -- true: +103 LUT4
		C_fast_ID: boolean := true; -- false: +37 LUT4
		C_predecode_in_IF: boolean := false; -- true: +55 LUT4
		-- SoC configuration options
		C_tsc: boolean := true; -- true: +74 LUT4
		-- debugging options
		C_debug: boolean := true -- true: +907 LUT4
		--
		-- XP2-5E-5 default synthesis
		--
		-- C_res_fwd 1, C_fast_id 1, C_predecode 0, C_tsc 1
		-- Tot LUT4 1645 (Log 1271, RAM 192, ripple 182)
		--
	);
	port (
		clk_25m: in std_logic;
		rs232_tx: out std_logic;
		rs232_rx: in std_logic;
		led: out std_logic_vector(7 downto 0);
		btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
		sw: in std_logic_vector(3 downto 0)
	);
end glue;

architecture Behavioral of glue is
	signal clk: std_logic;
	signal imem_addr: std_logic_vector(31 downto 2);
	signal imem_data_read: std_logic_vector(31 downto 0);
	signal imem_addr_strobe, imem_data_ready: std_logic;
	signal dmem_addr: std_logic_vector(31 downto 2);
	signal dmem_addr_strobe, dmem_bram_enable, dmem_data_ready: std_logic;
	signal dmem_byte_we: std_logic_vector(3 downto 0);
	signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
	signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);

	-- I/O
	signal from_sio: std_logic_vector(31 downto 0);
	signal sio_txd, sio_ce: std_logic;
	signal led_reg: std_logic_vector(7 downto 0);
	signal tsc: std_logic_vector(31 downto 0);
	signal input: std_logic_vector(31 downto 0);

	-- debugging only
	signal trace_addr: std_logic_vector(5 downto 0);
	signal trace_data: std_logic_vector(31 downto 0);
	signal debug_txd: std_logic;
begin

	-- clock synthesizer
	clkgen: entity clkgen
	generic map (
		C_debug => C_debug
	)
	port map (
		clk_25m => clk_25m, clk => clk,
		sel => sw(3), key => btn_down,
		res => btn_up
	);

	-- the RISC core
	pipeline: entity pipeline
	generic map(
		C_mult_enable => C_mult_enable,
		C_branch_prediction => C_branch_prediction,
		C_result_forwarding => C_result_forwarding,
		C_fast_ID => C_fast_ID,
		C_predecode_in_IF => C_predecode_in_IF,
		C_register_technology => C_register_technology,
		-- debugging only
		C_debug => C_debug
	)
	port map(
		clk => clk, reset => btn_up,
		imem_addr => imem_addr, imem_data_in => imem_data_read,
		imem_addr_strobe => imem_addr_strobe, imem_data_ready => '1',
		dmem_addr => dmem_addr, dmem_byte_we => dmem_byte_we,
		dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
		dmem_addr_strobe => dmem_addr_strobe, dmem_data_ready => dmem_data_ready,
		trace_addr => trace_addr, trace_data => trace_data
	);

	-- instruction / data BRAMs
	dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31 downto 28) /= "1110"
		else '0';

	-- RS232 sio
	sio: entity sio
	generic map (
		C_debug => C_debug
	)
	port map (
		clk => clk, ce => sio_ce,
		txd => sio_txd, rxd => rs232_rx,
		byte_we => dmem_byte_we,
		bus_in => cpu_to_dmem,
		bus_out => from_sio
	);
	sio_ce <= '0' when dmem_addr(31 downto 28) /= "1110" or dmem_addr(3 downto 2) /= "01"
		else dmem_addr_strobe;

	-- I/O port map:
	-- 0xe******0:  (1B, WR) LED
	-- 0xe******4:  (4B, WR) SIO
	-- 0xe******8:  (4B, RD) TSC
	-- I/O write access:
	process(clk)
	begin
		if rising_edge(clk) then
			if (C_tsc) then
				tsc <= tsc + 1;
			end if;
			if dmem_addr(31 downto 28) = "1110" and dmem_addr(3 downto 2) = "00"
			    and dmem_addr_strobe = '1' and dmem_byte_we /= "0000" then
				led_reg <= cpu_to_dmem(7 downto 0);
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			input <= x"0000" & "0000" & sw &
			    "000" & btn_center & btn_up & btn_down & btn_left & btn_right;
		end if;
	end process;

	-- XXX replace with a balanced multiplexer
	io_to_cpu <= input when dmem_addr(3 downto 2) = "00"
		else from_sio when dmem_addr(3 downto 2) = "01"
		else tsc;

	final_to_cpu <= io_to_cpu when dmem_addr(31 downto 28) = "1110"
		else dmem_to_cpu;

	--led <= led_reg;
	led <= from_sio(15 downto 8);

	-- Block RAM
	bram: entity bram
	port map(
		clk => clk, imem_addr_strobe => imem_addr_strobe,
		imem_addr => imem_addr, imem_data_out => imem_data_read,
		dmem_addr => dmem_addr, dmem_byte_we => dmem_byte_we,
		dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem,
		dmem_addr_strobe => dmem_bram_enable, dmem_data_ready => dmem_data_ready
	);


	-- debugging design instance
	debug_serial:
	if C_debug generate
	begin
	debug_serial: entity serial_debug
	port map(
		clk => clk_25m,
		rs232_txd => debug_txd,
		trace_addr => trace_addr,
		trace_data => trace_data
	);
	end generate; -- serial_debug
	
	rs232_tx <= debug_txd when C_debug and sw(3) = '1' else sio_txd;
	
end Behavioral;

