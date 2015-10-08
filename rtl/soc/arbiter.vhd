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
-- Simple multiport RAM arbiter (no priority)
-- This arbiter works only with d-cache.
-- It doesn't work for instructions,
-- no matter if i-cache is enabled or not
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sram_pack.all;

entity arbiter is

    generic (
	C_ports: integer;
	C_back2back: boolean := true; -- true:  back2back enabled (only this works for now).
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
    signal request_completed: boolean := false;
    -- Arbiter internal signals
    signal next_port: integer;
begin
    -- Mux for input ports
    S_addr_strobe <= bus_in(R_cur_port).addr_strobe;
    addr_strobe <= S_addr_strobe;
    write <= bus_in(R_cur_port).write;
    byte_sel <= bus_in(R_cur_port).byte_sel;
    -- addr(27 downto 18) <= '-';
    addr(bus_in(R_cur_port).addr'high-2 downto 0) <= bus_in(R_cur_port).addr;
    data_in <= bus_in(R_cur_port).data_in;
    bus_out <= data_out;
    -- Arbiter: round-robin port selection combinatorial logic
    no_priority_arbiter: if C_prio_port < 0 generate
    process(bus_in, R_cur_port)
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

    dont_back2back: if not C_back2back generate
    -- due to currently unclear reason
    -- this arbiter without back-2-back doesn't work
    ramport_fsm_dont_b2b: process(clk)
    begin
        if rising_edge(clk) then
            R_ready_out <= (others => '0');
            if request_completed then
              -- upon completed request switch to next port
              -- this line enforces servicing of the next port
              -- and prevents starvation
              R_cur_port <= next_port;
              request_completed <= false;
            else
              -- if request is pending on current port
              -- wait for ready signal and when it arrives
              -- send it back to current port, which requested it
              if ready_next_cycle = '1' then
                R_ready_out(R_cur_port) <= ready_next_cycle;
                request_completed <= true;
              end if;
            end if;
        end if;
    end process;
    end generate;

    do_back2back: if C_back2back generate
    -- rudimental priority - if reuqests keep recurring
    -- on current port, it will be serviced all the way
    -- until there's no request on that that port
    -- this policy can lead to starvation of requests
    -- pending on other ports
    ramport_fsm_do_b2b: process(clk)
    begin
        if rising_edge(clk) then
            R_ready_out <= (others => '0');
            R_ready_out(R_cur_port) <= ready_next_cycle;
            if S_addr_strobe = '0' or ready_next_cycle = '1' then
                -- if no request on current port, switch to next port
                R_cur_port <= next_port;
            end if;
        end if;
    end process;
    end generate;

    ready_out <= R_ready_out;
end Behavioral;
