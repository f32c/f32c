--
-- Copyright 2013 - 2014 Marko Zec, University of Zagreb.        
--
-- Neither this file nor any parts of it may be used unless an explicit 
-- permission is obtained from the author.  The file may not be copied,
-- disseminated or further distributed in its entirety or in part under
-- any circumstances.
--

-- $Id: $

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;


entity cache is
    generic (
	-- ISA options
	C_big_endian: boolean;
	C_mult_enable: boolean;
	C_branch_likely: boolean;
	C_sign_extend: boolean;
	C_ll_sc: boolean;
	C_movn_movz: boolean;
	C_PC_mask: std_logic_vector(31 downto 0);

	-- COP0 options
	C_clk_freq: integer;
	C_cpuid: integer;
	C_cop0_count: boolean;
	C_cop0_config: boolean;

	-- optimization options
	C_result_forwarding: boolean;
	C_branch_prediction: boolean;
	C_load_aligner: boolean;
	C_register_technology: string;

	-- cache options
	C_icache_size: integer := 8;

	-- debugging options
	C_debug: boolean
    );
    port (
	clk, reset: in std_logic;
	imem_addr_strobe: out std_logic;
	imem_addr: out std_logic_vector(31 downto 2);
	imem_data_in: in std_logic_vector(31 downto 0);
	imem_data_ready: in std_logic;
	dmem_addr_strobe: out std_logic;
	dmem_write: out std_logic;
	dmem_byte_sel: out std_logic_vector(3 downto 0);
	dmem_addr: out std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0);
	dmem_data_ready: in std_logic;
	snoop_cycle: in std_logic;
	snoop_addr: in std_logic_vector(31 downto 2);
	intr: in std_logic;
	-- debugging only
	trace_addr: in std_logic_vector(5 downto 0);
	trace_data: out std_logic_vector(31 downto 0)
    );
end cache;

architecture x of cache is
    signal i_addr, d_addr: std_logic_vector(31 downto 2);
    signal i_data: std_logic_vector(31 downto 0);
    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out: std_logic_vector(12 downto 0);
    signal iaddr_cacheable, icache_line_valid: boolean;
    signal i_strobe, icache_write, instr_ready: std_logic;
    signal flush_i_line, flush_d_line: std_logic;

    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);

    signal to_i_bram, from_i_bram: std_logic_vector(44 downto 0);

begin

    pipeline: entity work.pipeline
    generic map (
	C_cache => true, C_reg_IF_PC => true,
	C_cpuid => C_cpuid, C_clk_freq => C_clk_freq, C_ll_sc => C_ll_sc,
	C_big_endian => C_big_endian, C_branch_likely => C_branch_likely,
	C_sign_extend => C_sign_extend, C_movn_movz => C_movn_movz,
	C_mult_enable => C_mult_enable, C_PC_mask => C_PC_mask,
	C_cop0_count => C_cop0_count, C_cop0_config => C_cop0_config,
	C_branch_prediction => C_branch_prediction,
	C_result_forwarding => C_result_forwarding,
	C_load_aligner => C_load_aligner,
	C_register_technology => C_register_technology,
	-- debugging only
	C_debug => C_debug
    )
    port map (
	clk => clk, reset => reset, intr => intr,
	imem_addr => i_addr, imem_data_in => i_data,
	imem_addr_strobe => open,
	imem_data_ready => instr_ready,
	dmem_addr_strobe => dmem_addr_strobe,
	dmem_addr => d_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => dmem_data_in, dmem_data_out => dmem_data_out,
	dmem_data_ready => dmem_data_ready,
	snoop_cycle => snoop_cycle, snoop_addr => snoop_addr,
	flush_i_line => flush_i_line, flush_d_line => flush_d_line,
	trace_addr => trace_addr, trace_data => trace_data
    );

    icache_data_out <= from_i_bram(31 downto 0);
    icache_tag_out <= from_i_bram(44 downto 32);
    to_i_bram(31 downto 0) <= imem_data_in;
    to_i_bram(44 downto 32) <= icache_tag_in;

    G_icache_2k:
    if C_icache_size = 2 generate
    tag_dp_bram: entity work.bram_dp_x9
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '1',
	we_a => icache_write, we_b => flush_i_line,
	addr_a => "00" & i_addr(10 downto 2),
	addr_b => "00" & d_addr(10 downto 2),
	data_in_a => to_i_bram(44 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(44 downto 36),
	data_out_b => open
    );
    i_dp_bram: entity work.bram_dp_x18
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '1',
	we_a => icache_write, we_b => icache_write,
	addr_a => '0' & i_addr(10 downto 2),
	addr_b => '1' & i_addr(10 downto 2),
	data_in_a => to_i_bram(0 * 18 + 17 downto 0 * 18),
	data_in_b => to_i_bram(1 * 18 + 17 downto 1 * 18),
	data_out_a => from_i_bram(0 * 18 + 17 downto 0 * 18),
	data_out_b => from_i_bram(1 * 18 + 17 downto 1 * 18)
    );
    end generate; -- icache_2k

    G_icache_4k:
    if C_icache_size = 4 generate
    tag_dp_bram: entity work.bram_dp_x9
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '1',
	we_a => icache_write, we_b => flush_i_line,
	addr_a => '0' & i_addr(11 downto 2),
	addr_b => '0' & d_addr(11 downto 2),
	data_in_a => to_i_bram(44 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(44 downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 1 generate
    begin
    i_dp_bram: entity work.bram_dp_x18
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '0',
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(11 downto 2), addr_b => (others => '0'),
	data_in_a => to_i_bram(b * 18 + 17 downto b * 18),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(b * 18 + 17 downto b * 18),
	data_out_b => open
    );
    end generate i_block_iter;
    end generate; -- icache_4k

    G_icache_8k:
    if C_icache_size = 8 generate
    tag_dp_bram: entity work.bram_dp_x9
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '1',
	we_a => icache_write, we_b => flush_i_line,
	addr_a => i_addr(12 downto 2),
	addr_b => d_addr(12 downto 2),
	data_in_a => to_i_bram(44 downto 36),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(44 downto 36),
	data_out_b => open
    );
    i_block_iter: for b in 0 to 3 generate
    begin
    i_dp_bram: entity work.bram_dp_x9
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '0',
	we_a => icache_write, we_b => '0',
	addr_a => i_addr(12 downto 2), addr_b => (others => '0'),
	data_in_a => to_i_bram(b * 9 + 8 downto b * 9),
	data_in_b => (others => '0'),
	data_out_a => from_i_bram(b * 9 + 8 downto b * 9),
	data_out_b => open
    );
    end generate i_block_iter;
    end generate; -- icache_8k

    dmem_addr <= d_addr;

    imem_addr <= R_i_addr;
    imem_addr_strobe <= '1' when not iaddr_cacheable else R_i_strobe;
    i_data <= icache_data_out when iaddr_cacheable else imem_data_in;
    instr_ready <= imem_data_ready when not iaddr_cacheable else
      '1' when icache_line_valid else '0';

    iaddr_cacheable <=
      (C_icache_size = 2 or C_icache_size = 4 or C_icache_size = 8) and
      true; -- XXX kseg0: R_i_addr(31 downto 29) = "100";
    icache_write <= imem_data_ready when R_i_strobe = '1' else '0';
    icache_tag_in <=
      '1' & R_i_addr(31) & "00" & R_i_addr(19 downto 11)
      when C_icache_size = 2 else
      '1' & R_i_addr(31) & "000" & R_i_addr(19 downto 12)
      when C_icache_size = 4 else
      '1' & R_i_addr(31) & "0000" & R_i_addr(19 downto 13);
    icache_line_valid <=
      iaddr_cacheable and icache_tag_out(12) = '1' and
      icache_tag_in(11) = icache_tag_out(11) and
      ((C_icache_size = 2 and
      icache_tag_in(8 downto 0) = icache_tag_out(8 downto 0)) or
      (C_icache_size = 4 and
      icache_tag_in(7 downto 0) = icache_tag_out(7 downto 0)) or
      (C_icache_size = 8 and
      icache_tag_in(6 downto 0) = icache_tag_out(6 downto 0)));

    process(clk)
    begin
    if rising_edge(clk) then
	R_i_addr <= i_addr;
	if iaddr_cacheable and
	  not icache_line_valid and imem_data_ready = '0' then
	    R_i_strobe <= '1';
	else
	    R_i_strobe <= '0';
	end if;
    end if;
    end process;
end x;
