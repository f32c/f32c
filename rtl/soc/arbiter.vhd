----------------------------------------------------------------------------------
-- Copyright (c) 2015 Davor Jadrijevic
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- simple multiport RAM arbiter (no priority)
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sram_pack.all;

entity arbiter is
    generic (
	C_ports: integer;
	C_prio_port: integer := -1
    );
    port (
	clk: in  STD_LOGIC;
	reset: in  STD_LOGIC;
	-- To internal bus / logic blocks
	bus_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
	ready_out: out sram_ready_array; -- one bit per port
	snoop_addr: out std_logic_vector(31 downto 2);
	snoop_cycle: out std_logic;
	-- Inbound multi-port bus connections
	bus_in: in sram_port_array;
	-- external 32-bit RAM interface
        addr_strobe: out std_logic;			-- from CPU bus
        write: out std_logic;				-- from CPU bus
        byte_sel: out std_logic_vector(3 downto 0);	-- from CPU bus
        addr: out std_logic_vector(27 downto 0);		-- from CPU bus
        data_in: out std_logic_vector(31 downto 0); -- write to RAM
        data_out: in std_logic_vector(31 downto 0); -- read from RAM
        -- RAM responds when it will be ready
        ready_next_cycle: in std_logic
    );
end arbiter;

architecture Behavioral of arbiter is
    signal S_addr_strobe: std_logic;			-- from CPU bus

    -- Arbiter registers
    signal R_cur_port, R_next_port: integer range 0 to (C_ports - 1);
    signal R_ready_out: sram_ready_array;

    -- Arbiter internal signals
    signal next_port: integer;

begin
    -- Mux for input ports
    S_addr_strobe <= bus_in(R_next_port).addr_strobe;
    addr_strobe <= S_addr_strobe;
    write <= bus_in(R_next_port).write;
    byte_sel <= bus_in(R_next_port).byte_sel;
    -- addr(27 downto 18) <= '-';
    addr(17 downto 0) <= bus_in(R_next_port).addr; -- XXX revisit, widen!
    data_in <= bus_in(R_next_port).data_in;
    bus_out <= data_out;

    -- Arbiter: round-robin port selection combinatorial logic
    no_priority_arbiter: if C_prio_port < 0 generate
    process(bus_in, R_next_port, R_cur_port)
	variable i, j, t, n: integer;
    begin
	t := R_cur_port;
	for i in 0 to C_ports-1 loop
	    for j in 1 to C_ports loop
		if R_cur_port = i then
		    n := (i + j) mod C_ports;
		    if bus_in(n).addr_strobe = '1' then
			t := n;
			exit;
		    end if;
		end if;
	    end loop;
	end loop;
	next_port <= t;
    end process;
    end generate; -- end of no_priority_arbiter

    ramport_fsm: process(clk)
    begin
        if rising_edge(clk) then
            R_next_port <= next_port;
            if ready_next_cycle = '1' then
                R_cur_port <= R_next_port;
            end if;
	    R_ready_out <= (others => '0'); -- decoder all 0
	    R_ready_out(next_port) <= ready_next_cycle; -- decoder one 1
        end if;
    end process;
    ready_out <= R_ready_out;

end Behavioral;
