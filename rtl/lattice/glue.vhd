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
		C_clk_mhz: integer := 25; -- must be a multiple of 5
		C_mult_enable: boolean := false;
		C_branch_prediction: boolean := false;
		C_result_forwarding: boolean := true;
		C_register_technology: string := "lattice";
		-- debugging
		C_serial_trace: boolean := true
	);
	port (
		clk_25m: in std_logic;
		rs232_tx: out std_logic;
		rs232_rx: in std_logic;
		led: out std_logic_vector(7 downto 0);
		btn_left, btn_right, btn_up, btn_down: in std_logic;
		sw: in std_logic_vector(3 downto 0)
	);
end glue;

architecture Behavioral of glue is
	signal clk, slowclk: std_logic;
	signal imem_addr: std_logic_vector(31 downto 2);
	signal imem_data_read: std_logic_vector(31 downto 0);
	signal imem_addr_strobe, imem_data_ready: std_logic;
	signal dmem_addr: std_logic_vector(31 downto 2);
	signal dmem_addr_strobe, dmem_bram_enable, dmem_data_ready: std_logic;
	signal dmem_byte_we: std_logic_vector(3 downto 0);
	signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
	signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);

   -- I/O
	signal led_reg: std_logic_vector(7 downto 0);
	signal lcd_data: std_logic_vector(7 downto 0);
	signal lcd_ctrl: std_logic_vector(1 downto 0);
	signal tsc: std_logic_vector(31 downto 0);
	signal input: std_logic_vector(31 downto 0);

	-- debugging only
	signal clk_key: std_logic;
	signal trace_addr: std_logic_vector(5 downto 0);
	signal trace_data: std_logic_vector(31 downto 0);
begin

	-- debugging design instance - serial port + control knob / buttons
	debug_serial:
	if C_serial_trace generate
	begin
		clk_key <= btn_down;
	
		debug_serial: entity serial_debug
		port map(
			clk => clk_25m,
			rs232_txd => rs232_tx,
			trace_addr => trace_addr,
			trace_data => trace_data
		);
	end generate; -- serial_debug
	
	nodebug:
	if not C_serial_trace generate
	begin
		clk_key <= '1'; -- clk selector
		rs232_tx <= '1'; -- appease tools
	end generate; -- nodebug
	
	led <= "00" & trace_addr;
end Behavioral;

