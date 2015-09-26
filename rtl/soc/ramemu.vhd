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
-- multiport RAM emulation using BRAM
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sram_pack.all;

entity ramemu is
    generic (
	C_ports: integer;
	C_prio_port: integer := -1;
	C_addr_width: integer := 11 -- BRAM size alloc bytes = 2^(n+3)
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
	bus_in: in sram_port_array
    );
end ramemu;

architecture Behavioral of ramemu is
    -- Bus interface signals (resolved from bus_in record via R_cur_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(31 downto 0);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus
    signal data_out, R_data_out: std_logic_vector(31 downto 0);	-- registered output

    -- Arbiter registers
    signal R_cur_port, R_next_port: integer range 0 to (C_ports - 1);
    signal write_byte: std_logic_vector(3 downto 0);	-- from arbiter
    signal R_ready_out: sram_ready_array;

    -- Arbiter internal signals
    signal next_port: integer;
    
begin
    -- Mux for input ports
    addr_strobe <= bus_in(R_next_port).addr_strobe;
    write <= bus_in(R_next_port).write;
    byte_sel <= bus_in(R_next_port).byte_sel;
    addr(17 downto 0) <= bus_in(R_next_port).addr; -- XXX revisit, widen!
    data_in <= bus_in(R_next_port).data_in;

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
    
    ready_out <= R_ready_out;

    ramport_fsm: process(clk)
    begin
        if rising_edge(clk) then
            R_next_port <= next_port;
	    R_ready_out <= (others => '0');
	    R_ready_out(next_port) <= '1';
        end if;
    end process;
    
    -- BRAM storage: 4 blocks of 8 bits
    -- each block separately writeable
    four_bytes: for i in 0 to 3 generate
    write_byte(i) <= write and byte_sel(i); -- and addr_strobe;
    ram_emu_bram: entity work.bram_true2p_1clk
    generic map (
        dual_port => false,
        data_width => 8,
        addr_width => C_addr_width
    )
    port map (
        clk => not clk,
        we_a => write_byte(i),
        addr_a => addr(C_addr_width-1 downto 0),
        data_in_a => data_in(8*i+7 downto 8*i),
        data_out_a => bus_out(8*i+7 downto 8*i)
        --we_b => '0', addr_b => (others => '0'),
        --data_in_b => (others => '0'), data_out_b => open
    );
    end generate;
end Behavioral;
