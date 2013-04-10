
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.f32c_pack.all;


entity sram is
    generic (
	C_ports: integer;
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
    signal R_a: std_logic_vector(18 downto 0);		-- to SRAM
    signal R_d: std_logic_vector(15 downto 0);		-- to SRAM
    signal R_wel, R_lbl, R_ubl: std_logic;		-- to SRAM

    -- Bus interface internal signals
    signal R_data_out: std_logic_vector(31 downto 0);	-- to CPU bus
    signal R_ready: std_logic;				-- to CPU bus

    -- Arbiter registers
    signal R_cur_port, R_prev_port: integer;
    signal R_phase: integer;

    -- Arbiter internal signals
    signal next_port: integer;

    -- Misc. signals
    signal addr_strobe: std_logic;
    signal write: std_logic;
    signal byte_sel: std_logic_vector(3 downto 0);
    signal addr: std_logic_vector(19 downto 2);
    signal data_in: std_logic_vector(31 downto 0);

begin

    --
    -- R_phase strobe write R_phase' R_cur_port' R_wc' R_ready' R_a' R_d' R_wel'
    --    0	  0	*	0	new	  0	   0	R_a  R_d    1
    --    0	  1	0	1    R_cur_port	 write	   0	new  new    1
    --    0	  1	1	1    R_cur_port	 write	   1	new  new    0
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
	    if i = R_cur_port then
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
	    R_ready <= '1';
	    R_cur_port <= next_port;
	    R_data_out <= R_data_out + 1;
	    R_wel <= '1';
	    R_d <= (others => 'Z');
	end if;
    end process;

    sram_d <= R_d;
    sram_a <= R_a;
    sram_wel <= R_wel;
    sram_lbl <= R_lbl;
    sram_ubl <= R_ubl;

    data_out <= R_data_out;

end Structure;
