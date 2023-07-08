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
-- $Id$
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

use work.f32c_pack.all;
-- use work.techx_pkg.all;

entity glue is
    generic (
	-- Main clock frequency, in MHz
	C_clk_freq: integer := 100;

	-- ISA options
	C_arch: integer := ARCH_MI32;
	C_big_endian: boolean := false;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_ll_sc: boolean := false;
	C_PC_mask: std_logic_vector(31 downto 0) := x"00001fff";
	C_exceptions: boolean := false;

	-- COP0 options
	C_cop0_count: boolean := true;
	C_cop0_config: boolean := true;

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_full_shifter: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false;

	-- SoC configuration options
	C_mem_size: integer := 32;
	C_write_protect_bootloader: boolean := false;
	C_sio: boolean := true
    );
    port (
	i_100MHz_P, i_100MHz_N: in std_logic;
	UART1_TXD: out std_logic;
	UART1_RXD: in std_logic
    );
end glue;

architecture Behavioral of glue is
    signal imem_addr: std_logic_vector(31 downto 2);
    signal imem_data_read: std_logic_vector(31 downto 0);
    signal imem_addr_strobe, imem_data_ready: std_logic;
    signal dmem_addr: std_logic_vector(31 downto 2);
    signal dmem_addr_strobe, dmem_write: std_logic;
    signal dmem_bram_write, dmem_data_ready: std_logic;
    signal dmem_byte_sel: std_logic_vector(3 downto 0);
    signal dmem_to_cpu, cpu_to_dmem: std_logic_vector(31 downto 0);
    signal io_to_cpu, final_to_cpu: std_logic_vector(31 downto 0);
    signal io_addr: std_logic_vector(11 downto 2);

    -- I/O
    signal io_addr_strobe: std_logic;
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_ce: std_logic;
    signal clk: std_logic;

begin
    -- make single ended clock
    clk100in: entity work.inp_ds_port
    port map(i_in_p => i_100MHz_P,
           i_in_n => i_100MHz_N,
           o_out  => clk);
    -- f32c core
    cpu: entity work.f32c_core
    generic map (
	C_arch => C_arch, C_clk_freq => C_clk_freq,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
	-- debugging only
	C_debug => false
    )
    port map (
	clk => clk, reset => '0', intr => "000000",
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => '0', snoop_addr => "------------------------------",
	flush_i_line => open, flush_d_line => open,
	-- debugging, unused here
	debug_in_data => x"00", debug_in_strobe => '0',
	debug_in_busy => open, debug_out_data => open,
	debug_out_strobe => open, debug_out_busy => '0',
	debug_active => open
    );
    final_to_cpu <= io_to_cpu when io_addr_strobe = '1' else dmem_to_cpu;
    io_addr_strobe <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11"
      else '0';
    io_addr <= '0' & dmem_addr(10 downto 2);
    io_to_cpu <= from_sio;
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
	clk => clk, ce => sio_ce, txd => UART1_TXD, rxd =>UART1_RXD,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio, break => open
    );
    sio_ce <= io_addr_strobe when io_addr(11 downto 4) = x"30" else '0';
    end generate;

    -- Block RAM
    dmem_bram_write <=
      dmem_addr_strobe and dmem_write when dmem_addr(31) /= '1' else '0';
    G_bram_mi32_eb:
    if C_arch = ARCH_MI32 and C_big_endian generate
    bram_mi32_eb: entity work.bram_mi32_eb
    generic map (
	C_write_protect_bootloader => C_write_protect_bootloader,
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_write => dmem_bram_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );
    end generate;
    G_bram_mi32_el:
    if C_arch = ARCH_MI32 and not C_big_endian generate
    bram_mi32_el: entity work.bram_mi32_el
    generic map (
	C_write_protect_bootloader => C_write_protect_bootloader,
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

end Behavioral;
