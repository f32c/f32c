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
	C_clk_freq: integer := 81;

	-- CPU core configuration options
	C_mult_enable: boolean := true; -- true: +27 LUT4
	C_result_forwarding: boolean := true; -- true: +181 LUT4
	C_branch_prediction: boolean := false; -- true: +77 LUT4
	C_load_aligner: boolean := false; -- true: +168 LUT4
	C_register_technology: string := "lattice";

	-- These may negatively influence timing closure:
	C_branch_likely: boolean := false; -- true: +3 LUT4, -Fmax
	C_movn_movz: boolean := false; -- true: +5 LUT4
	C_fast_ID: boolean := true; -- false: +7 LUT4, -Fmax

	-- This changes movn_movz calling convenction (swaps rs / rt)
	C_mips32_movn_movz: boolean := false; -- true: +12 LUT4, -Fmax

	-- debugging options
	C_debug: boolean := false; -- true: +883 LUT4, -Fmax

	-- SoC configuration options
	C_mem_size: string := "16k";
	C_tsc: boolean := true; -- true: +68 LUT4
	C_sio: boolean := true; -- true: +137 LUT4
	C_gpio: boolean := false; -- true: +13 LUT4
	C_spi: boolean := false; -- true: +10 LUT4
	C_pcmdac: boolean := false; -- true: +32 LUT4
	C_ddsfm: boolean := false -- true: +23 LUT4

	--
	-- XP2-8E-7 area optimized synthesis @ 81.25 MHz:
	--
	-- Global config:
	--   C_tsc 1, C_sio 1, C_gpio 0, C_spi 0, C_pcmdac 0, C_ddsfm 0
	--
	-- Config #1:
	--   C_mult_enable 1, C_res_fwd 1, C_bpred 1, C_load_aligner 1
	--   regs 736 slices 919 logic LUT4 1391 total LUT4 1823
	--   DMIPS/MHz 1.416  DMIPS/MHz/kLUT4 0.777
	--
	-- Config #2:
	--   C_mult_enable 1, C_res_fwd 1, C_bpred 1, C_load_aligner 0
	--   regs 730 slices 880 logic LUT4 1221 total LUT4 1653
	--   DMIPS/MHz 1.359  DMIPS/MHz/kLUT4 0.821
	--
	-- Config #3:
	--   C_mult_enable 1, C_res_fwd 1, C_bpred 0, C_load_aligner 0
	--   regs 671 slices 796 logic LUT4 1156 total LUT4 1576
	--   DMIPS/MHz 1.296  DMIPS/MHz/kLUT4 0.823
	--
	-- Config #4:
	--   C_mult_enable 1, C_res_fwd 0, C_bpred 0, C_load_aligner 0
	--   regs 662 slices 699 logic LUT4 962 total LUT4 1394
	--   DMIPS/MHz 0.984  DMIPS/MHz/kLUT4 0.706
	--
	-- Config #5:
	--   C_mult_enable 0, C_res_fwd 0, C_bpred 0, C_load_aligner 0
	--   regs 658 slices 692 logic LUT4 948 total LUT4 1380
	--   DMIPS/MHz 0.800  DMIPS/MHz/kLUT4 0.580
	--
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	spi_so: in std_logic;
	spi_cen, spi_sck, spi_si: out std_logic;
	p_ring: out std_logic;
	p_tip: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	edge: out std_logic_vector(8 downto 0)
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
    signal spi_cen_reg, spi_sck_reg, spi_si_reg: std_logic;
    signal led_reg: std_logic_vector(7 downto 0);
    signal tsc_25m: std_logic_vector(34 downto 0);
    signal tsc: std_logic_vector(31 downto 0);
    signal from_gpio: std_logic_vector(31 downto 0);
    signal dac_in_l, dac_in_r: std_logic_vector(15 downto 2);
    signal dac_acc_l, dac_acc_r: std_logic_vector(16 downto 2);

    -- debugging only
    signal trace_addr: std_logic_vector(5 downto 0);
    signal trace_data: std_logic_vector(31 downto 0);
    signal debug_txd: std_logic;
    signal debug_res: std_logic;

    -- FM TX DDS
    signal clk_dds, dds_out: std_logic;
    signal dds_cnt, dds_div, dds_div1: std_logic_vector(21 downto 0);

begin

    -- clock synthesizer
    clkgen: entity clkgen
    generic map (
	C_clk_freq => C_clk_freq,
	C_debug => C_debug
    )
    port map (
	clk_25m => clk_25m, clk => clk, clk_325m => clk_dds,
	sel => sw(2), key => btn_down, res => debug_res
    );
    debug_res <= btn_up and sw(0) when C_debug else '0';

    -- f32c core
    pipeline: entity pipeline
    generic map (
	C_mult_enable => C_mult_enable,
	C_movn_movz => C_movn_movz,
	C_mips32_movn_movz => C_mips32_movn_movz,
	C_branch_likely => C_branch_likely,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_fast_ID => C_fast_ID,
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => btn_up,
	imem_addr => imem_addr, imem_data_in => imem_data_read,
	imem_addr_strobe => imem_addr_strobe, imem_data_ready => '1',
	dmem_addr => dmem_addr, dmem_byte_we => dmem_byte_we,
	dmem_data_in => final_to_cpu, dmem_data_out => cpu_to_dmem,
	dmem_addr_strobe => dmem_addr_strobe,
	dmem_data_ready => dmem_data_ready,
	trace_addr => trace_addr, trace_data => trace_data
    );

    -- instruction / data BRAMs
    dmem_bram_enable <=
      dmem_addr_strobe when dmem_addr(31 downto 28) /= "1110" else '0';

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity sio
    generic map (
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => rs232_rx,
	byte_we => dmem_byte_we, bus_in => cpu_to_dmem,
	bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 28) = "1110" and
      dmem_addr(3 downto 2) = "01" else '0';
    end generate;

    -- PCM stereo 1-bit DAC
    G_pcmdac:
    if C_pcmdac generate
    process(clk)
    begin
	if rising_edge(clk) then
	    dac_acc_l <= (dac_acc_l(16) & dac_in_l) + dac_acc_l;
	    dac_acc_r <= (dac_acc_r(16) & dac_in_r) + dac_acc_r;
	end if;
    end process;
    p_tip(3) <= dac_acc_l(16);
    p_tip(2) <= dac_acc_l(16);
    p_tip(1) <= dac_acc_l(16);
    p_tip(0) <= 'Z';
    p_ring <= dac_acc_r(16);
    end generate;

    -- I/O port map:
    -- 0xe*****00: (4B, RW) GPIO (LED, switches/buttons, edge conn.)
    -- 0xe*****04: (4B, RW) SIO
    -- 0xe*****08: (4B, RD) TSC
    -- 0xe*****0c: (4B, WR) PCM signal
    -- 0xe*****10: (1B, RW) SPI Flash
    -- 0xe*****14: (1B, RW) SPI MicsoSD
    -- 0xe*****1c: (4B, WR) DDS register
    -- I/O write access:
    process(clk)
    begin
	if rising_edge(clk) and dmem_addr_strobe = '1'
	  and dmem_addr(31 downto 28) = "1110" then
	    -- GPIO
	    if C_gpio and dmem_addr(4 downto 2) = "000" then
		if dmem_byte_we(0) = '1' then
		    led_reg <= cpu_to_dmem(7 downto 0);
		end if;
	    end if;
	    -- PCMDAC
	    if C_pcmdac and dmem_addr(4 downto 2) = "011" then
		if dmem_byte_we(2) = '1' then
		    dac_in_l <= cpu_to_dmem(31 downto 18);
		end if;
		if dmem_byte_we(0) = '1' then
		    dac_in_r <= cpu_to_dmem(15 downto 2);
		end if;
	    end if;
	    -- SPI
	    if C_spi and dmem_addr(4 downto 2) = "100" then
		if dmem_byte_we(0) = '1' then
		    spi_si_reg <= cpu_to_dmem(7);
		    spi_sck_reg <= cpu_to_dmem(6);
		    spi_cen_reg <= cpu_to_dmem(5);
		end if;
	    end if;
	    -- DDS
	    if C_ddsfm and dmem_addr(4 downto 2) = "111" then
		if dmem_byte_we(0) = '1' then
		    dds_div <= cpu_to_dmem(21 downto 0);
		end if;
	    end if;
	end if;
    end process;
    led <= led_reg when C_gpio else "ZZZZZZZZ";
    spi_si <= spi_si_reg when C_spi else 'Z';
    spi_sck <= spi_sck_reg when C_spi else 'Z';
    spi_cen <= spi_cen_reg when C_spi else 'Z';

    process(clk)
    begin
	if C_gpio and rising_edge(clk) then
	    from_gpio(4 downto 0) <= btn_center &
	      btn_up & btn_down & btn_left & btn_right;
	    from_gpio(11 downto 8) <= sw;
	end if;
    end process;

    G_tsc:
    if C_tsc generate
    process(clk_25m)
    begin
	if rising_edge(clk_25m) then
	    tsc_25m <= tsc_25m + 1;
	end if;
    end process;
    -- Safely move upper bits of tsc_25m over clock domain boundary
    process(clk)
    begin
	if rising_edge(clk) and tsc_25m(2 downto 1) = "10" then
	    tsc <= tsc_25m(34 downto 3);
	end if;
    end process;
    end generate;

    -- XXX replace with a balanced multiplexer
    process(dmem_addr, from_gpio, from_sio, tsc, spi_so)
    begin
	case dmem_addr(4 downto 2) is
	when "000"  => io_to_cpu <= from_gpio;
	when "001"  => io_to_cpu <= from_sio;
	when "010"  => io_to_cpu <= tsc;
	when "100"  =>
	    if C_spi then
		io_to_cpu <= x"0000000" & "000" & spi_so;
	    else
		io_to_cpu <= x"00000000";
	    end if;
	when others => io_to_cpu <= x"00000000";
	end case;
    end process;

    final_to_cpu <= io_to_cpu when dmem_addr(31 downto 28) = "1110"
      else dmem_to_cpu;

    -- Block RAM
    bram: entity bram
    generic map (
	C_mem_size => C_mem_size
    )
    port map (
	clk => clk, imem_addr_strobe => imem_addr_strobe,
	imem_addr => imem_addr, imem_data_out => imem_data_read,
	dmem_addr => dmem_addr, dmem_byte_we => dmem_byte_we,
	dmem_data_out => dmem_to_cpu, dmem_data_in => cpu_to_dmem,
	dmem_addr_strobe => dmem_bram_enable,
	dmem_data_ready => dmem_data_ready
    );


    -- debugging design instance
    G_debug:
    if C_debug generate
    debug: entity serial_debug
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
	    dds_div1 <= dds_div; -- Cross clock domain
	    dds_cnt <= dds_cnt + dds_div1;
	end if;
    end process;
    dds_out <= dds_cnt(21);
    end generate;

    -- make a dipole?
    edge(0) <= dds_out when C_ddsfm else 'Z';
    edge(1) <= dds_out when C_ddsfm else 'Z';
    edge(2) <= dds_out when C_ddsfm else 'Z';
    edge(3) <= dds_out when C_ddsfm else 'Z';
    edge(5) <= not dds_out when C_ddsfm else 'Z';
    edge(6) <= not dds_out when C_ddsfm else 'Z';
    edge(7) <= not dds_out when C_ddsfm else 'Z';
    edge(8) <= not dds_out when C_ddsfm else 'Z';

end Behavioral;
