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
	C_PC_mask: std_logic_vector(31 downto 0) := x"0000ffff";
	C_exceptions: boolean := true;

	-- COP0 options
	C_cop0_count: boolean := true;
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

	-- SoC configuration options
	C_mem_size: integer := 16;	-- in KBytes
	C_sio: boolean := true;
	C_leds_btns: boolean := true
    );
    port (
	clk: in std_logic;
	intr: in std_logic_vector(7 downto 2);
	rs232_rx: in std_logic;
	rs232_tx, rs232_break: out std_logic;
	btns: in std_logic_vector(7 downto 0);
	sw: in std_logic_vector(7 downto 0);
	leds: out std_logic_vector(7 downto 0)
    );
end glue_bram;

architecture Behavioral of glue_bram is
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
    signal sio_ce, sio_intr: std_logic;
    signal R_leds: std_logic_vector(7 downto 0);
    signal R_sw: std_logic_vector(7 downto 0);
    signal R_btns: std_logic_vector(7 downto 0);

begin

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
	C_load_aligner => C_load_aligner, C_full_shifter => C_full_shifter,
	C_ll_sc => C_ll_sc, C_exceptions => C_exceptions,
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => false
    )
    port map (
	clk => clk, reset => '0', intr => intr,
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
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, ce => sio_ce, txd => rs232_tx, rxd => rs232_rx,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio, break => rs232_break
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 30) = "11" and
      dmem_addr(7 downto 4) = x"2" else '0';
    sio_intr <= from_sio(8);
    end generate;

    --
    -- I/O port map:
    -- 0xf*****10: (4B, RW) : LED (WR), switches, buttons (RD)
    -- 0xf*****20: (4B, RW) * SIO
    --
    io_addr_strobe <= '1' when C_leds_btns and dmem_addr(31 downto 30) = "11"
      else '0';
    process(clk)
    begin
	if rising_edge(clk) and io_addr_strobe = '1'
	  and dmem_write = '1' then
	    -- LEDs
	    if C_leds_btns and dmem_addr(7 downto 4) = x"1" and
	      dmem_byte_sel(1) = '1' then
		R_leds <= cpu_to_dmem(15 downto 8);
	    end if;
	end if;
	if C_leds_btns and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= btns;
	end if;
    end process;
    leds <= R_leds when C_leds_btns else "ZZZZZZZZ";
    process(dmem_addr, R_sw, R_btns, from_sio)
    begin
	case dmem_addr(7 downto 4) is
	when x"1"  =>
	    if C_leds_btns then
		io_to_cpu <="--------" & R_sw & "--------" & R_btns;
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
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_addr_strobe => dmem_bram_enable, dmem_write => dmem_write,
	dmem_byte_sel => dmem_byte_sel, dmem_addr => dmem_addr,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem
    );
	
end Behavioral;
