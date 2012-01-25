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

	-- ISA options
	C_big_endian: boolean := true;
	C_mult_enable: boolean := true;
	C_branch_likely: boolean := true;
	C_sign_extend: boolean := true;
	C_PC_mask: std_logic_vector(31 downto 0) := x"00003fff";

	-- CPU core configuration options
	C_branch_prediction: boolean := true;
	C_result_forwarding: boolean := true;
	C_load_aligner: boolean := true;
	C_register_technology: string := "lattice";

	-- These may negatively influence timing closure:
	C_movn_movz: boolean := false; -- true: +16 LUT4, -DMIPS, incomplete
	C_fast_ID: boolean := true; -- false: +7 LUT4, -Fmax

	-- debugging options
	C_debug: boolean := false; -- true: +883 LUT4, -Fmax

	-- SoC configuration options
	C_mem_size: string := "16k";
	C_sram: boolean := true;
	C_tsc: boolean := true;
	C_sio: boolean := true;
	C_gpio: boolean := true;
	C_flash: boolean := true;
	C_sdcard: boolean := true;
	C_pcmdac: boolean := true;
	C_ddsfm: boolean := true
    );
    port (
	clk_25m: in std_logic;
	rs232_tx: out std_logic;
	rs232_rx: in std_logic;
	flash_so: in std_logic;
	flash_cen, flash_sck, flash_si: out std_logic;
	sdcard_so: in std_logic;
	sdcard_cen, sdcard_sck, sdcard_si: out std_logic;
	p_ring: out std_logic;
	p_tip: out std_logic_vector(3 downto 0);
	led: out std_logic_vector(7 downto 0);
	btn_left, btn_right, btn_up, btn_down, btn_center: in std_logic;
	sw: in std_logic_vector(3 downto 0);
	dil: out std_logic_vector(29 downto 20);
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
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

    -- SRAM
    signal R_sram_a: std_logic_vector(18 downto 0);
    signal R_sram_d: std_logic_vector(15 downto 0);
    signal R_sram_wel, R_sram_lbl, R_sram_ubl: std_logic;

    -- I/O
    signal from_sio: std_logic_vector(31 downto 0);
    signal sio_txd, sio_ce: std_logic;
    signal R_flash_cen, R_flash_sck, R_flash_si: std_logic;
    signal R_sdcard_cen, R_sdcard_sck, R_sdcard_si: std_logic;
    signal R_led: std_logic_vector(7 downto 0);
    signal R_tsc_25m: std_logic_vector(34 downto 0);
    signal R_tsc: std_logic_vector(31 downto 0);
    signal R_sw: std_logic_vector(3 downto 0);
    signal R_btns: std_logic_vector(4 downto 0);
    signal R_dac_in_l, R_dac_in_r: std_logic_vector(15 downto 2);
    signal R_dac_acc_l, R_dac_acc_r: std_logic_vector(16 downto 2);

    -- debugging only
    signal trace_addr: std_logic_vector(5 downto 0);
    signal trace_data: std_logic_vector(31 downto 0);
    signal debug_txd: std_logic;
    signal debug_res: std_logic;

    -- FM TX DDS
    signal clk_dds, dds_out: std_logic;
    signal R_dds_cnt, R_dds_div, R_dds_div1: std_logic_vector(21 downto 0);

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

    -- RS232 sio
    G_sio:
    if C_sio generate
    sio: entity sio
    generic map (
	C_big_endian => C_big_endian,
	C_clk_freq => C_clk_freq
    )
    port map (
	clk => clk, ce => sio_ce, txd => sio_txd, rxd => rs232_rx,
	byte_we => dmem_byte_we, bus_in => cpu_to_dmem, bus_out => from_sio
    );
    sio_ce <= dmem_addr_strobe when dmem_addr(31 downto 28) = x"f" and
      dmem_addr(4 downto 2) = "001" else '0';
    end generate;

    -- PCM stereo 1-bit DAC
    G_pcmdac:
    if C_pcmdac generate
    process(clk)
    begin
	if rising_edge(clk) then
	    R_dac_acc_l <= (R_dac_acc_l(16) & R_dac_in_l) + R_dac_acc_l;
	    R_dac_acc_r <= (R_dac_acc_r(16) & R_dac_in_r) + R_dac_acc_r;
	end if;
    end process;
    p_tip(3) <= R_dac_acc_l(16);
    p_tip(2) <= R_dac_acc_l(16);
    p_tip(1) <= R_dac_acc_l(16);
    p_tip(0) <= '0';
    p_ring <= R_dac_acc_r(16);
    end generate;

    -- I/O port map:
    -- 0x8*******: (2B, RW) * SRAM
    -- 0xf*****00: (4B, RW) * GPIO (LED, switches/buttons)
    -- 0xf*****04: (4B, RW) * SIO
    -- 0xf*****08: (4B, RD) * TSC
    -- 0xf*****0c: (4B, WR) * PCM signal
    -- 0xf*****10: (1B, RW) * SPI Flash
    -- 0xf*****14: (1B, RW) * SPI MicroSD
    -- 0xf*****1c: (4B, WR) * FM DDS register
    -- I/O write access:
    process(clk)
    begin
	if C_sram and falling_edge(clk) then
	    if dmem_addr_strobe = '1' and dmem_addr(31 downto 28) = x"8" then
		R_sram_a <= dmem_addr(20 downto 2);
		R_sram_d <= cpu_to_dmem(15 downto 0);
		R_sram_wel <= not dmem_byte_we(0);
		R_sram_lbl <= '0';
		R_sram_ubl <= '0';
	    else
		R_sram_wel <= '1';
		R_sram_lbl <= '1';
		R_sram_ubl <= '1';
	    end if;
	end if;
	if rising_edge(clk) and dmem_addr_strobe = '1'
	  and dmem_addr(31 downto 28) = x"f" then
	    -- GPIO
	    if C_gpio and dmem_addr(4 downto 2) = "000" then
		if dmem_byte_we(0) = '1' then
		    R_led <= cpu_to_dmem(7 downto 0);
		end if;
	    end if;
	    -- PCMDAC
	    if C_pcmdac and dmem_addr(4 downto 2) = "011" then
		if dmem_byte_we(2) = '1' then
		    if C_big_endian then
			R_dac_in_l <= cpu_to_dmem(23 downto 16) &
			  cpu_to_dmem(31 downto 26);
		    else
			R_dac_in_l <= cpu_to_dmem(31 downto 18);
		    end if;
		end if;
		if dmem_byte_we(0) = '1' then
		    if C_big_endian then
			R_dac_in_r <= cpu_to_dmem(7 downto 0) &
			  cpu_to_dmem(15 downto 10);
		    else
		        R_dac_in_r <= cpu_to_dmem(15 downto 2);
		    end if;
		end if;
	    end if;
	    -- SPI Flash
	    if C_flash and dmem_addr(4 downto 2) = "100" then
		if dmem_byte_we(0) = '1' then
		    R_flash_si <= cpu_to_dmem(7);
		    R_flash_sck <= cpu_to_dmem(6);
		    R_flash_cen <= cpu_to_dmem(5);
		end if;
	    end if;
	    -- SPI MicroSD
	    if C_sdcard and dmem_addr(4 downto 2) = "101" then
		if dmem_byte_we(0) = '1' then
		    R_sdcard_si <= cpu_to_dmem(7);
		    R_sdcard_sck <= cpu_to_dmem(6);
		    R_sdcard_cen <= cpu_to_dmem(5);
		end if;
	    end if;
	    -- DDS
	    if C_ddsfm and dmem_addr(4 downto 2) = "111" then
		if dmem_byte_we(0) = '1' then
		    if C_big_endian then
			R_dds_div <= cpu_to_dmem(15 downto 10) & 
			  cpu_to_dmem(23 downto 16) & cpu_to_dmem(31 downto 24);
		    else
			R_dds_div <= cpu_to_dmem(21 downto 0);
		    end if;
		end if;
	    end if;
	end if;
    end process;
    led <= R_led when C_gpio else "--------";
    flash_si <= R_flash_si when C_flash else 'Z';
    flash_sck <= R_flash_sck when C_flash else 'Z';
    flash_cen <= R_flash_cen when C_flash else 'Z';
    sdcard_si <= R_sdcard_si when C_sdcard else 'Z';
    sdcard_sck <= R_sdcard_sck when C_sdcard else 'Z';
    sdcard_cen <= R_sdcard_cen when C_sdcard else 'Z';
    sram_d <= R_sram_d when C_sram and R_sram_wel = '0' else "ZZZZZZZZZZZZZZZZ";
    sram_a <= R_sram_a;
    sram_wel <= R_sram_wel when C_sram else '1';
    sram_lbl <= R_sram_lbl when C_sram else '1';
    sram_ubl <= R_sram_ubl when C_sram else '1';

    process(clk)
    begin
	if C_gpio and rising_edge(clk) then
	    R_sw <= sw;
	    R_btns <= btn_center & btn_up & btn_down & btn_left & btn_right;
	end if;
    end process;

    G_tsc:
    if C_tsc generate
    process(clk_25m)
    begin
	if rising_edge(clk_25m) then
	    R_tsc_25m <= R_tsc_25m + 1;
	end if;
    end process;
    -- Safely move upper bits of tsc_25m over clock domain boundary
    process(clk, R_tsc_25m)
    begin
	if rising_edge(clk) and R_tsc_25m(2 downto 1) = "10" then
	    if C_big_endian then
		R_tsc <= R_tsc_25m(10 downto 3) & R_tsc_25m(18 downto 11) &
		  R_tsc_25m(26 downto 19) & R_tsc_25m(34 downto 27);
	    else
		R_tsc <= R_tsc_25m(34 downto 3);
	    end if;
	end if;
    end process;
    end generate;

    -- XXX replace with a balanced multiplexer
    process(dmem_addr, R_sw, R_btns, R_tsc, from_sio, flash_so, sdcard_so)
    begin
	case dmem_addr(4 downto 2) is
	when "000"  =>
	    io_to_cpu <="----------------" & "----" & R_sw & "---" & R_btns;
	when "001"  => io_to_cpu <= from_sio;
	when "010"  => io_to_cpu <= R_tsc;
	when "100"  =>
	    if C_flash then
		io_to_cpu <= "------------------------" & "0000000" & flash_so;
	    else
		io_to_cpu <= "--------------------------------";
	    end if;
	when "101"  =>
	    if C_sdcard then
		io_to_cpu <= "------------------------" & "0000000" & sdcard_so;
	    else
		io_to_cpu <= "--------------------------------";
	    end if;
	when others =>
	    io_to_cpu <= "--------------------------------";
	end case;
    end process;

    final_to_cpu <= io_to_cpu when dmem_addr(31 downto 28) = x"f"
      else x"0000" & sram_d when C_sram and dmem_addr(31 downto 28) = x"8"
      else dmem_to_cpu;

    -- Block RAM
    dmem_bram_enable <= dmem_addr_strobe when dmem_addr(31) /= '1' else '0';
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
	    R_dds_div1 <= R_dds_div; -- Cross clock domain
	    R_dds_cnt <= R_dds_cnt + R_dds_div1;
	end if;
    end process;
    dds_out <= R_dds_cnt(21);
    end generate;

    -- make a dipole?
    dil(20) <= dds_out when C_ddsfm else 'Z';
    dil(21) <= dds_out when C_ddsfm else 'Z';
    dil(22) <= dds_out when C_ddsfm else 'Z';
    dil(23) <= dds_out when C_ddsfm else 'Z';
    dil(26) <= not dds_out when C_ddsfm else 'Z';
    dil(27) <= not dds_out when C_ddsfm else 'Z';
    dil(28) <= not dds_out when C_ddsfm else 'Z';
    dil(29) <= not dds_out when C_ddsfm else 'Z';

end Behavioral;
