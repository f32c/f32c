
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.f32c_pack.all;


entity sram is
    generic (
	C_ports: integer := 4;
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
	-- Multi-port bus connections
	bus_in: in sram_port_array;
	ready_out: out sram_ready_array
    );
end sram;

architecture Structure of sram is
    -- Physical interface registers
    signal R_phase: std_logic;
    signal R_delay: std_logic_vector(3 downto 0);
    signal R_data: std_logic_vector(31 downto 0);
    signal R_a: std_logic_vector(18 downto 0);
    signal R_d: std_logic_vector(15 downto 0);
    signal R_wel, R_lbl, R_ubl: std_logic;
    signal R_fast_read: boolean;

    -- Arbiter registers
    signal R_active_port: integer;
    signal R_arbiter_locked: boolean;

    -- Arbiter internal signals
    signal cur_port: integer;
    signal next_port: integer;

    -- Misc. signals
    signal halfword: std_logic;
    signal addr_strobe: std_logic;
    signal write: std_logic;
    signal byte_sel: std_logic_vector(3 downto 0);
    signal addr: std_logic_vector(19 downto 2);
    signal data_in: std_logic_vector(31 downto 0);
    signal ready: std_logic;

begin

    -- Mux for input ports
    cur_port <= R_active_port when R_arbiter_locked else next_port;
    addr_strobe <= bus_in(cur_port).addr_strobe;
    write <= bus_in(cur_port).write;
    byte_sel <= bus_in(cur_port).byte_sel;
    addr <= bus_in(cur_port).addr;
    data_in <= bus_in(cur_port).data_in;

    -- Demux for outbound ready signals
    process(ready, R_active_port)
	variable i: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    if i = R_active_port then
		ready_out(i) <= ready;
	    else
		ready_out(i) <= '0';
	    end if;
	end loop;
    end process;

    -- Arbiter: round-robin port selection combinatorial logic
    process(bus_in, R_active_port)
	variable i, j, t: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    for j in 1 to C_ports loop
		if R_active_port = i then
		    t := (i + j) mod C_ports;
		    if bus_in(t).addr_strobe = '1' then
			exit;
		    end if;
		end if;
	    end loop;
	end loop;
	next_port <= t;
    end process;

    halfword <= '0' when byte_sel(3 downto 2) = "00" else
      '1' when byte_sel(1 downto 0) = "00" else not R_phase;

    process(clk)
    begin
	if rising_edge(clk) then
	    if addr_strobe = '1' then
		if not R_arbiter_locked then
		    R_active_port <= next_port;
		end if;
		R_arbiter_locked <= true;
		if R_delay = "000" & R_phase then
		    if R_phase = '0' then
			R_arbiter_locked <= false;
		    end if;
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
		R_arbiter_locked <= false;
		R_delay <= C_sram_wait_cycles;
		R_phase <= '1';
	    end if;
	end if;

	if rising_edge(clk) then
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
