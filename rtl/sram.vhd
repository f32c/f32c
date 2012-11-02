
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity sram is
    generic (
	C_sram_wait_cycles: std_logic_vector
    );
    port (
	-- To physical SRAM signals
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic;
	-- To internal logic blocks
	clk: in std_logic;
	data_out: out std_logic_vector(31 downto 0);
	-- Port A
	A_addr_strobe: in std_logic;
	A_write: in std_logic;
	A_byte_sel: in std_logic_vector(3 downto 0);
	A_addr: in std_logic_vector(19 downto 2);
	A_data_in: in std_logic_vector(31 downto 0);
	A_ready: out std_logic
    );
end sram;

architecture Structure of sram is
    signal R_phase: std_logic;
    signal R_delay: std_logic_vector(3 downto 0);
    signal R_data: std_logic_vector(31 downto 0);
    signal R_a: std_logic_vector(18 downto 0);
    signal R_d: std_logic_vector(15 downto 0);
    signal R_wel, R_lbl, R_ubl: std_logic;
    signal R_fast_read: boolean;
    signal halfword: std_logic;

    signal addr_strobe: std_logic;
    signal write: std_logic;
    signal byte_sel: std_logic_vector(3 downto 0);
    signal addr: std_logic_vector(19 downto 2);
    signal data_in: std_logic_vector(31 downto 0);
    signal ready: std_logic;
begin

    -- Port mux
    addr_strobe <= A_addr_strobe;
    write <= A_write;
    byte_sel <= A_byte_sel;
    addr <= A_addr;
    data_in <= A_data_in;
    A_ready <= ready;

    halfword <= '0' when byte_sel(3 downto 2) = "00" else
      '1' when byte_sel(1 downto 0) = "00" else not R_phase;

    process(clk)
    begin
	if rising_edge(clk) then
	    if addr_strobe = '1' then
		if R_delay = "000" & R_phase then
		    R_delay <= C_sram_wait_cycles;
		    R_phase <= not R_phase;
		else
		    if R_delay = C_sram_wait_cycles and
		      (R_fast_read or write = '1') then
			-- begin of a preselected read or a fast store
			R_delay <= R_delay - 2;
		    else
			R_delay <= R_delay - 1;
		    end if;
		    if byte_sel(3 downto 2) = "00" or
		      byte_sel(1 downto 0) = "00" then
			R_phase <= '0';
		    end if;
		end if;
	    else
		R_delay <= C_sram_wait_cycles;
		R_phase <= '1';
	    end if;
	end if;

	if falling_edge(clk) then
	    if addr_strobe = '1' then
		R_fast_read <= false;
		if R_delay = "0000" and write = '0' then
		    R_a <= R_a + 1;
		else
		    if R_delay = C_sram_wait_cycles and
		      R_a = (addr & halfword) then
			R_fast_read <= true;
		    end if;
		    R_a <= addr & halfword;
		end if;
		R_wel <= not write;
		if halfword = '1' then
		    if write = '1' then
			R_d <= data_in(31 downto 16);
		    else
			R_d <= "ZZZZZZZZZZZZZZZZ";
		    end if;
		    R_data(31 downto 16) <= sram_d;
		    R_ubl <= not byte_sel(3);
		    R_lbl <= not byte_sel(2);
		else
		    if write = '1' then
			R_d <= data_in(15 downto 0);
		    else
			R_d <= "ZZZZZZZZZZZZZZZZ";
		    end if;
		    R_data(15 downto 0) <= sram_d;
		    R_ubl <= not byte_sel(1);
		    R_lbl <= not byte_sel(0);
		end if;
	    else
		R_d <= "ZZZZZZZZZZZZZZZZ";
		R_wel <= '1';
		R_lbl <= '0';
		R_ubl <= '0';
	    end if;
	end if;
    end process;

    sram_d <= R_d;
    sram_a <= R_a;
    sram_wel <= R_wel;
    sram_lbl <= R_lbl;
    sram_ubl <= R_ubl;

    ready <='1' when (R_delay = x"0" and R_phase = '0') else '0';
    data_out <= R_data;

end Structure;
