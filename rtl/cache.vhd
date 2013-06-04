-- $Id$

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;


entity cache is
    generic (
	-- ISA options
	C_big_endian: boolean;
	C_mult_enable: boolean;
	C_branch_likely: boolean;
	C_sign_extend: boolean;
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
	intr: in std_logic;
	-- debugging only
	trace_addr: in std_logic_vector(5 downto 0);
	trace_data: out std_logic_vector(31 downto 0)
    );
end cache;

architecture x of cache is
    signal i_addr: std_logic_vector(31 downto 2);
    signal i_data: std_logic_vector(31 downto 0);
    signal icache_data_in, icache_data_out: std_logic_vector(31 downto 0);
    signal icache_tag_in, icache_tag_out: std_logic_vector(11 downto 0);
    signal iaddr_cacheable, icache_line_valid: boolean;
    signal i_strobe, icache_write, instr_ready: std_logic;
    signal R_i_strobe: std_logic;
    signal R_i_addr: std_logic_vector(31 downto 2);
begin

    pipeline: entity work.pipeline
    generic map (
	C_icache => true,
	C_cpuid => C_cpuid, C_clk_freq => C_clk_freq,
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
	dmem_addr => dmem_addr,
	dmem_write => dmem_write, dmem_byte_sel => dmem_byte_sel,
	dmem_data_in => dmem_data_in, dmem_data_out => dmem_data_out,
	dmem_data_ready => dmem_data_ready,
	trace_addr => trace_addr, trace_data => trace_data
    );

    icache_lut: entity work.cache_lut
    port map (
	clk => clk,
	addr => i_addr(11 downto 2),
	rd_data => icache_data_out, rd_tag => icache_tag_out,
	wr_data => imem_data_in, wr_tag => icache_tag_in,
	wr_enable => icache_write
    );

    imem_addr <= R_i_addr;
    imem_addr_strobe <= '1' when not iaddr_cacheable else R_i_strobe;
    i_data <= icache_data_out when icache_line_valid else imem_data_in;
    instr_ready <= imem_data_ready when not iaddr_cacheable else
      '1' when icache_line_valid else '0';

    --iaddr_cacheable <= R_i_addr(31 downto 30) = "10" and R_i_addr(27) = '0';
    iaddr_cacheable <= true;
    icache_tag_in <= R_i_addr(31) & "00" & '1' & R_i_addr(19 downto 12);
    icache_line_valid <= iaddr_cacheable and icache_tag_in = icache_tag_out;
    icache_write <= imem_data_ready when R_i_strobe = '1' else '0';

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
