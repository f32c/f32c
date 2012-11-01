
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
	sram_addr_strobe: in std_logic;
	sram_write: in std_logic;
	sram_byte_sel: in std_logic_vector(3 downto 0);
	sram_addr: in std_logic_vector(19 downto 2);
	sram_data_in: in std_logic_vector(31 downto 0);
	sram_data_out: out std_logic_vector(31 downto 0);
	sram_ready: out std_logic
    );
end sram;

architecture Structure of sram is
    signal R_sram_phase: std_logic;
    signal R_sram_delay: std_logic_vector(3 downto 0);
    signal R_sram_data: std_logic_vector(31 downto 0);
    signal R_sram_a: std_logic_vector(18 downto 0);
    signal R_sram_d: std_logic_vector(15 downto 0);
    signal R_sram_wel, R_sram_lbl, R_sram_ubl: std_logic;
    signal R_sram_fast_read: boolean;
    signal sram_halfword: std_logic;

begin

    sram_halfword <= '0' when sram_byte_sel(3 downto 2) = "00" else
      '1' when sram_byte_sel(1 downto 0) = "00" else not R_sram_phase;

    process(clk)
    begin
	if rising_edge(clk) then
	    if sram_addr_strobe = '1' then
		if R_sram_delay = "000" & R_sram_phase then
		    R_sram_delay <= C_sram_wait_cycles;
		    R_sram_phase <= not R_sram_phase;
		else
		    if R_sram_delay = C_sram_wait_cycles and
		      (R_sram_fast_read or sram_write = '1') then
			-- begin of a preselected read or a fast store
			R_sram_delay <= R_sram_delay - 2;
		    else
			R_sram_delay <= R_sram_delay - 1;
		    end if;
		    if sram_byte_sel(3 downto 2) = "00" or
		      sram_byte_sel(1 downto 0) = "00" then
			R_sram_phase <= '0';
		    end if;
		end if;
	    else
		R_sram_delay <= C_sram_wait_cycles;
		R_sram_phase <= '1';
	    end if;
	end if;

	if falling_edge(clk) then
	    if sram_addr_strobe = '1' then
		R_sram_fast_read <= false;
		if R_sram_delay = "0000" and sram_write = '0' then
		    R_sram_a <= R_sram_a + 1;
		else
		    if R_sram_delay = C_sram_wait_cycles and
		      R_sram_a = (sram_addr & sram_halfword) then
			R_sram_fast_read <= true;
		    end if;
		    R_sram_a <= sram_addr & sram_halfword;
		end if;
		R_sram_wel <= not sram_write;
		if sram_halfword = '1' then
		    if sram_write = '1' then
			R_sram_d <= sram_data_in(31 downto 16);
		    else
			R_sram_d <= "ZZZZZZZZZZZZZZZZ";
		    end if;
		    R_sram_data(31 downto 16) <= sram_d;
		    R_sram_ubl <= not sram_byte_sel(3);
		    R_sram_lbl <= not sram_byte_sel(2);
		else
		    if sram_write = '1' then
			R_sram_d <= sram_data_in(15 downto 0);
		    else
			R_sram_d <= "ZZZZZZZZZZZZZZZZ";
		    end if;
		    R_sram_data(15 downto 0) <= sram_d;
		    R_sram_ubl <= not sram_byte_sel(1);
		    R_sram_lbl <= not sram_byte_sel(0);
		end if;
	    else
		R_sram_d <= "ZZZZZZZZZZZZZZZZ";
		R_sram_wel <= '1';
		R_sram_lbl <= '0';
		R_sram_ubl <= '0';
	    end if;
	end if;
    end process;

    sram_d <= R_sram_d;
    sram_a <= R_sram_a;
    sram_wel <= R_sram_wel;
    sram_lbl <= R_sram_lbl;
    sram_ubl <= R_sram_ubl;

    sram_ready <='1' when (R_sram_delay = x"0" and R_sram_phase = '0') else '0';
    sram_data_out <= R_sram_data;

end Structure;
