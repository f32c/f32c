
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.f32c_pack.all;


entity sram is
    generic (
	C_ports: integer;
	C_sram_wait_cycles: std_logic_vector; -- XXX unused, remove!
	C_wait_cycles: integer := 13
    );
    port (
	clk: in std_logic;
	-- To internal bus / logic blocks
	data_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
	ready_out: out sram_ready_array;
	-- Inbound multi-port bus connections
	bus_in: in sram_port_array;
	-- To physical SRAM signals
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
    );
end sram;

architecture Structure of sram is
    -- Physical interface registers
    signal R_a: std_logic_vector(18 downto 0);		-- to SRAM
    signal R_d: std_logic_vector(15 downto 0);		-- to SRAM
    signal R_wel, R_lbl, R_ubl: std_logic;		-- to SRAM
    signal R_wc, R_high_half: std_logic;		-- internal
    signal R_byte_sel: std_logic_vector(3 downto 0);	-- internal

    -- Bus interface registers
    signal R_bus_out: std_logic_vector(31 downto 0);	-- to CPU bus
    signal R_ready: std_logic;				-- to CPU bus

    -- Bus interface signals (resolved from bus_in record via R_cur_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(19 downto 2);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_cur_port, R_prev_port: integer;
    signal R_phase: integer;

    -- Arbiter internal signals
    signal next_port: integer;

begin

    --
    -- R_phase strobe write R_phase' R_cur_port' R_wc' R_ready' R_a' R_d' R_wel'
    --    0	  0	*	0	new	  0	   0	R_a  R_d    1
    --    0	  1	0	1    R_cur_port	 write	   0	new   Z   !write
    --    0	  1	1	1    R_cur_port	 write	   1	new  new  !write
    --	  1	  *	*	2    R_cur_port  R_wc	   0    R_a  R_d  !R_wc
    --

    -- Mux for input ports
    addr_strobe <= bus_in(R_cur_port).addr_strobe;
    write <= bus_in(R_cur_port).write;
    byte_sel <= bus_in(R_cur_port).byte_sel;
    addr <= bus_in(R_cur_port).addr;
    data_in <= bus_in(R_cur_port).data_in;

    -- Demux for outbound ready signals
    process(R_ready, R_cur_port)
	variable i: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    if i = R_prev_port then
		ready_out(i) <= R_ready;
	    else
		ready_out(i) <= '0';
	    end if;
	end loop;
    end process;

    -- Arbiter: round-robin port selection combinatorial logic
    process(bus_in, R_cur_port)
	variable i, j, t: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    for j in 1 to C_ports loop
		if R_cur_port = i then
		    t := (i + j) mod C_ports;
		    if bus_in(t).addr_strobe = '1' then
			exit;
		    end if;
		end if;
	    end loop;
	end loop;
	next_port <= t;
    end process;

    process(clk)
    begin
	if rising_edge(clk) then
	    R_prev_port <= R_cur_port;
	    if R_phase = 0 then
		if addr_strobe = '0' then
		    R_cur_port <= next_port;
		    -- to CPU bus
		    R_ready <= '0';
		else
		    R_byte_sel <= byte_sel;
		    if byte_sel(1 downto 0) = "00" then
			R_phase <= C_wait_cycles + 1;
			R_high_half <= '1';
			R_a <= addr & '1';
			R_ubl <= byte_sel(3);
			R_lbl <= byte_sel(2);
		    else
			R_phase <= R_phase + 1;
			R_high_half <= '0';
			R_a <= addr & '0';
			R_ubl <= byte_sel(1);
			R_lbl <= byte_sel(0);
		    end if;
		end if;
	    elsif R_phase = C_wait_cycles then
		-- Sample low half word, bump addr
		if R_wc = '0' then
		    R_bus_out(15 downto 0) <= sram_d;
		end if;
		R_phase <= R_phase + 1;
		R_high_half <= '1';
		R_a(0) <= '1';
	    elsif R_phase >= C_wait_cycles * 2 then
		if R_wc = '0' then
		    if R_high_half = '1' then
			R_bus_out(31 downto 16) <= sram_d;
		    else
			R_bus_out(15 downto 0) <= sram_d;
		    end if;
		end if;
		R_wc <= '0';
		R_phase <= 0;
		R_ready <= '1';
		R_cur_port <= next_port;
		-- physical signals to SRAM
		R_wel <= '1';
		R_ubl <= '0';
		R_lbl <= '0';
		R_d <= (others => 'Z');
	    else
		R_phase <= R_phase + 1;
	    end if;
	end if;
    end process;

    sram_d <= R_d;
    sram_a <= R_a;
    sram_wel <= R_wel;
    sram_lbl <= R_lbl;
    sram_ubl <= R_ubl;

    data_out <= R_bus_out;

end Structure;
