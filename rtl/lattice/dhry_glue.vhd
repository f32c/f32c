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

entity glue is
    generic (
	-- Main clock: 50, 62, 75, 81, 87, 100, 112, 125, 137, 150 MHz
	C_clk_freq: integer := 100;

	-- ISA options
	C_big_endian: boolean := false; -- true: +7 LUT4
	C_mult_enable: boolean := true; -- true: +16 LUT4
	C_branch_likely: boolean := true; -- true: +2 LUT4
	C_sign_extend: boolean := true; -- +24 LUT4
	C_PC_mask: std_logic_vector(31 downto 0) := x"00001fff"; -- 8 LUT4/bit

	-- CPU core configuration options
	C_branch_prediction: boolean := true; -- true: +37 LUT4, +1 BRAM
	C_result_forwarding: boolean := true; -- true: +244 LUT4
	C_load_aligner: boolean := true; -- true: +82 LUT4

	-- FPGA platform-specific options
	C_register_technology: string := "lattice";

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +5 LUT4, -DMIPS
	C_fast_ID: boolean := true; -- false: +7 LUT4, -Fmax

	-- SoC configuration options
	C_mem_size: string := "16k";
	C_tsc: boolean := true;
	C_sio: boolean := true

	--
	-- XP2-5E-7, 81.25 MHz, pushbutton Area optimization
	-- XXX: 125 MHz gives lower LUT footprint?
	--
	-- C_res_fw 1, C_bp 1, C_load_align 1
	-- slices: 803 LUTs: 1592 DMIPS: 138.8 DMIPS/MHz: 1.71
	-- DMIPS/MHz/kLUTs (Soc): 1.07 DMIPS/MHz/kLUTs (core): 1.18
	--
	-- C_res_fw 1, C_bp 1, C_load_align 0
	-- slices: 770 LUTs: 1510 DMIPS: 132.1 DMIPS/MHz: 1.63
	-- DMIPS/MHz/kLUTs (Soc): 1.07 DMIPS/MHz/kLUTs (core): 1.19
	--
	-- C_res_fw 1, C_bp 0, C_load_align 1
	-- slices: 785 LUTs: 1560 DMIPS: 130.6 DMIPS/MHz: 1.61
	-- DMIPS/MHz/kLUTs (Soc): 1.03 DMIPS/MHz/kLUTs (core): 1.14
	--
	-- C_res_fw 1, C_bp 0, C_load_align 0
	-- slices: 741 LUTs: 1475 DMIPS: 124.6 DMIPS/MHz: 1.53
	-- DMIPS/MHz/kLUTs (Soc): 1.04 DMIPS/MHz/kLUTs (core): 1.16
	--
	-- C_res_fw 0, C_bp 1, C_load_align 1
	-- slices: 692 LUTs: 1373 DMIPS: 103.6 DMIPS/MHz: 1.28
	-- DMIPS/MHz/kLUTs (Soc): 0.93 DMIPS/MHz/kLUTs (core): 1.04
	--
	-- C_res_fw 0, C_bp 0, C_load_align 0
	-- slices: 644 LUTs: 1273 DMIPS:  96.1 DMIPS/MHz: 1.18
	-- DMIPS/MHz/kLUTs (Soc): 0.93 DMIPS/MHz/kLUTs (core): 1.00
	--
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic
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
    signal sio_ce: std_logic;
    signal tsc_25m: std_logic_vector(34 downto 0);
    signal tsc: std_logic_vector(31 downto 0);

begin

    -- clock synthesizer
    clkgen: entity clkgen
    generic map (
	C_clk_freq => C_clk_freq,
	C_debug => false
    )
    port map (
	clk_25m => clk_25m, clk => clk, clk_325m => open,
	sel => '0', key => '0', res => '0'
    );

    -- f32c core
    pipeline: entity pipeline
    generic map (
	C_big_endian => C_big_endian,
	C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend,
	C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable,
	C_PC_mask => C_PC_mask,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_fast_ID => C_fast_ID,
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => false
    )
    port map (
	clk => clk, reset => '0',
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe,
	imem_data_ready => imem_data_ready,
	dmem_addr_strobe => dmem_addr_strobe, dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_data_ready => dmem_data_ready,
	trace_addr => "000000", trace_data => open
    );


    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity sio
    generic map (
	C_clk_freq => C_clk_freq,
	C_fixed_baudrate => true,
	C_big_endian => C_big_endian
    )
    port map (
	clk => clk, ce => sio_ce, txd => rs232_tx, rxd => rs232_rx,
	bus_write => dmem_write, byte_sel => dmem_byte_sel,
	bus_in => cpu_to_dmem, bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"f" and
      dmem_addr(4 downto 2) = "001" else '0';
    end generate;

    --
    -- I/O port map:
    -- 0x8*******: (2B, RW)   SRAM
    -- 0xf*****00: (4B, RW)   GPIO (LED, switches/buttons)
    -- 0xf*****04: (4B, RW) * SIO
    -- 0xf*****08: (4B, RD) * TSC
    -- 0xf*****0c: (4B, WR)   PCM signal
    -- 0xf*****10: (1B, RW)   SPI Flash
    -- 0xf*****14: (1B, RW)   SPI MicroSD
    -- 0xf*****1c: (4B, WR)   FM DDS register
    --
    process(dmem_addr, from_sio, tsc)
    begin
        case dmem_addr(4 downto 2) is
        when "000"  =>
            io_to_cpu <="----------------" & "--------" & "---00000";
        when "001"  => io_to_cpu <= from_sio;
        when "010"  => io_to_cpu <= tsc;
        when others =>
            io_to_cpu <= "--------------------------------";
        end case;
    end process;

    final_to_cpu <= io_to_cpu when dmem_addr(31) = '1' else dmem_to_cpu;

    G_tsc:
    if C_tsc generate
    process(clk_25m)
    begin
	if rising_edge(clk_25m) then
	    tsc_25m <= tsc_25m + 1;
	end if;
    end process;
    -- Safely move upper bits of tsc_25m over clock domain boundary
    process(clk, tsc_25m)
    begin
	if rising_edge(clk) and tsc_25m(2 downto 1) = "10" then
	    if C_big_endian then
		tsc <= tsc_25m(10 downto 3) & tsc_25m(18 downto 11) &
		  tsc_25m(26 downto 19) & tsc_25m(34 downto 27);
	    else
		tsc <= tsc_25m(34 downto 3);
	    end if;
	end if;
    end process;
    end generate;

    -- Block RAM
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31) /= '1' else '0';
    imem_data_ready <= '1';
    dmem_data_ready <= '1';
    bram: entity bram
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
