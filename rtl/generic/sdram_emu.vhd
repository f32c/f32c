library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sdram_emu is
    generic (
	C_size_k: natural := 32;
	C_column_bits: natural := 9
    );
    port (
	clk: in std_logic;
	cke: in std_logic;
	csn: in std_logic;
	rasn: in std_logic;
	casn: in std_logic;
	wen: in std_logic;
	a: in std_logic_vector(12 downto 0);
	ba: in std_logic_vector(1 downto 0);
	dqm: in std_logic_vector(1 downto 0);
	d: inout std_logic_vector(15 downto 0)
    );
end sdram_emu;

architecture x of sdram_emu is
    type T_bram is array(0 to C_size_k * 512 - 1)
      of std_logic_vector(7 downto 0);

    signal M_bram_lo, M_bram_hi: T_bram;

    constant C_cmd_active: std_logic_vector := "0011";
    constant C_cmd_read: std_logic_vector :=   "0101";
    constant C_cmd_write: std_logic_vector :=  "0100";
    constant C_cmd_ldmod: std_logic_vector :=  "0000";

    signal R_row: std_logic_vector(9 downto 0);
    signal R_bank: std_logic_vector(1 downto 0);
    signal R_c1: std_logic;
    signal R_from_bram, R_from_bram1: std_logic_vector(15 downto 0);
    signal R_read_cycle, R_read_cycle1: boolean;
    signal R_write_cycle: boolean;

    signal cmd: std_logic_vector(3 downto 0);
    signal ea: natural;

begin
    cmd <= csn & rasn & casn & wen;
    ea <= conv_integer(R_row & R_bank & a(C_column_bits - 1 downto 0) & R_c1);

    process(clk)
    begin
    if rising_edge(clk) then
	R_read_cycle <= false;
	R_read_cycle1 <= R_read_cycle;
	d <= (others => 'Z');
	R_from_bram <= M_bram_hi(ea) & M_bram_lo(ea);
	R_from_bram1 <= R_from_bram;
	R_c1 <= '0';

	if R_read_cycle or R_read_cycle1 then
	    d <= R_from_bram;
	end if;

	if R_write_cycle or cmd = C_cmd_write then
	    if dqm(0) = '0' then
		M_bram_lo(ea) <= d(7 downto 0);
	    end if;
	    if dqm(1) = '0' then
		M_bram_hi(ea) <= d(15 downto 8);
	    end if;
	end if;

	case cmd is
	when C_cmd_active =>
	    R_row <= a(9 downto 0);
	    R_bank <= ba;
	when C_cmd_read =>
	    R_c1 <= '1';
	    R_read_cycle <= R_c1 = '0';
	when C_cmd_write =>
	    R_write_cycle <= R_c1 = '0';
	    R_c1 <= '1';
	when others =>
	end case;
    end if;
    end process;
end x;
