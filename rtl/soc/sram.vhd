--
-- Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sram_pack.all;


entity sram is
    generic (
	C_ports: integer;
	C_prio_port: integer := -1;
	C_wait_cycles: integer;
	C_pipelined_read: boolean
    );
    port (
	clk: in std_logic;
	-- To internal bus / logic blocks
	data_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
	ready_out: out sram_ready_array; -- one bit per port
	snoop_addr: out std_logic_vector(31 downto 2);
	snoop_cycle: out std_logic;
	-- Inbound multi-port bus connections
	bus_in: in sram_port_array;
	-- To physical SRAM signals
	sram_a: out std_logic_vector(18 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: out std_logic
    );
end sram;

architecture Structure of sram is
    -- State machine constants
    constant C_phase_idle: integer := 0;
    constant C_phase_read_upper_half: integer := C_wait_cycles - 1;
    constant C_phase_read_terminate: integer := C_wait_cycles * 2 - 1;
    constant C_phase_write_upper_half: integer := C_wait_cycles;
    constant C_phase_write_terminate: integer := C_wait_cycles * 2 - 1;

    -- Physical interface registers
    signal R_a: std_logic_vector(18 downto 0);		-- to SRAM
    signal R_d: std_logic_vector(15 downto 0);		-- to SRAM
    signal R_wel, R_lbl, R_ubl: std_logic;		-- to SRAM
    signal R_write_cycle: boolean;			-- internal
    signal R_byte_sel_hi: std_logic_vector(1 downto 0);	-- internal
    signal R_out_word: std_logic_vector(31 downto 0);	-- internal

    -- Bus interface registers
    signal R_bus_out: std_logic_vector(31 downto 0);	-- to CPU bus

    -- Bus interface signals (resolved from bus_in record via R_next_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(19 downto 2);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_phase: integer range 0 to C_phase_read_terminate;
    signal R_cur_port, R_next_port: integer range 0 to (C_ports - 1);
    signal R_last_port: integer range 0 to (C_ports - 1);
    signal R_prio_pending: boolean;
    signal R_ack_bitmap: std_logic_vector(0 to (C_ports - 1));
    signal R_snoop_cycle: std_logic;
    signal R_snoop_addr: std_logic_vector(31 downto 2);

    -- Arbiter internal signals
    signal next_port: integer;

begin
    -- Mux for input ports
    addr_strobe <= bus_in(R_next_port).addr_strobe;
    write <= bus_in(R_next_port).write;
    byte_sel <= bus_in(R_next_port).byte_sel;
    addr <= bus_in(R_next_port).addr(addr'high downto 2);
    data_in <= bus_in(R_next_port).data_in;

    -- Demux for outbound ready signals
    process(R_ack_bitmap)
	variable i: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    ready_out(i) <= R_ack_bitmap(i);
	end loop;
    end process;

    -- Arbiter: round-robin port selection combinatorial logic
    process(bus_in, R_next_port, R_last_port)
	variable i, j, t, n: integer;
    begin
	t := R_last_port;
	for i in 0 to (C_ports - 1) loop
	    for j in 1 to C_ports loop
		if R_last_port = i then
		    n := (i + j) mod C_ports;
		    if bus_in(n).addr_strobe = '1' and n /= C_prio_port then
			t := n;
			exit;
		    end if;
		end if;
	    end loop;
	end loop;
	if R_prio_pending then
	    next_port <= C_prio_port;
	else
	    next_port <= t;
	end if;
    end process;

    process(clk)
    begin
	if C_pipelined_read and falling_edge(clk) then
	    if R_phase = C_phase_read_upper_half + 2 then
		R_bus_out(15 downto 0) <= sram_d;
	    end if;
	    R_bus_out(31 downto 16) <= sram_d;
	end if;

	if not C_pipelined_read and rising_edge(clk) then
	    if R_phase = C_phase_read_upper_half then
		R_bus_out(15 downto 0) <= sram_d;
	    end if;
	    R_bus_out(31 downto 16) <= sram_d;
	end if;

	if rising_edge(clk) then
	    R_ack_bitmap <= (others => '0');
	    R_snoop_cycle <= '0';

	    R_prio_pending <=
	      (R_cur_port /= C_prio_port or R_phase = C_phase_idle) and
	      C_prio_port >= 0 and bus_in(C_prio_port).addr_strobe = '1';

	    if R_phase = C_phase_idle + 1 and R_cur_port /= C_prio_port then
		R_last_port <= R_cur_port;
	    end if;

	    R_next_port <= next_port;
	    if R_phase = C_phase_idle then
		R_write_cycle <= false;
		R_wel <= '1';
		R_ubl <= '0';
		R_lbl <= '0';
		R_d <= (others => 'Z');
		if R_ack_bitmap(R_next_port) = '1' or addr_strobe = '0' then
		    -- idle
		    R_ubl <= '1';
		    R_lbl <= '1';
		else
		    -- start a new transaction
		    R_cur_port <= R_next_port;
		    R_phase <= C_phase_idle + 1;
		    R_byte_sel_hi <= byte_sel(3 downto 2);
		    R_a <= addr & '0';
		    if write = '1' then
			R_write_cycle <= true;
			R_wel <= '0';
			R_out_word <= data_in;
			if byte_sel(1 downto 0) /= "00" then
			    R_ubl <= not byte_sel(1);
			    R_lbl <= not byte_sel(0);
			else
			    R_a <= addr & '1';
			    R_ubl <= not byte_sel(3);
			    R_lbl <= not byte_sel(2);
			    R_phase <= C_phase_write_upper_half;
			end if;
			-- we can safely acknowledge the write immediately
			R_ack_bitmap(R_next_port) <= '1';
			R_snoop_addr(19 downto 2) <= addr; -- XXX
			R_snoop_cycle <= '1';
		    end if;
		end if;
	    elsif not R_write_cycle and R_phase = C_phase_read_upper_half then
		R_phase <= R_phase + 1;
		-- physical signals to SRAM: bump addr
		R_a(0) <= '1';
	    elsif not R_write_cycle and R_phase = C_phase_read_terminate then
		R_ack_bitmap(R_cur_port) <= '1';
		if R_cur_port /= R_next_port and addr_strobe = '1' then
		    -- jump-start a new transaction
		    R_cur_port <= R_next_port;
		    R_phase <= C_phase_idle + 1;
		    R_byte_sel_hi <= byte_sel(3 downto 2);
		    R_a <= addr & '0';
		    if write = '1' then
			R_write_cycle <= true;
			R_wel <= '0';
			R_out_word <= data_in;
			if byte_sel(1 downto 0) /= "00" then
			    R_ubl <= not byte_sel(1);
			    R_lbl <= not byte_sel(0);
			else
			    R_a <= addr & '1';
			    R_ubl <= not byte_sel(3);
			    R_lbl <= not byte_sel(2);
			    R_phase <= C_phase_write_upper_half;
			end if;
			-- we can safely acknowledge the write immediately
			R_ack_bitmap(R_next_port) <= '1';
			R_snoop_addr(19 downto 2) <= addr; -- XXX
			R_snoop_cycle <= '1';
		    end if;
		else
		    R_phase <= C_phase_idle;
		    R_ubl <= '1';
		    R_lbl <= '1';
		end if;
	    elsif R_write_cycle and R_phase = C_phase_idle + 1 then
		R_phase <= R_phase + 1;
		R_d <= R_out_word(15 downto 0);
	    elsif R_write_cycle and R_phase = C_phase_write_upper_half - 1 then
		if R_byte_sel_hi /= "00" then
		    R_phase <= R_phase + 1;
		else
		    R_phase <= C_phase_idle;
		end if;
		-- physical signals to SRAM: terminate 16-bit write
		R_wel <= '1';
		R_ubl <= '1';
		R_lbl <= '1';
		R_d <= (others => 'Z');
	    elsif R_write_cycle and R_phase = C_phase_write_upper_half then
		R_phase <= R_phase + 1;
		-- physical signals to SRAM: bump addr, refill data
		R_a(0) <= '1';
		R_ubl <= not R_byte_sel_hi(1);
		R_lbl <= not R_byte_sel_hi(0);
		R_wel <= '0';
	    elsif R_write_cycle and R_phase = C_phase_write_upper_half + 1 then
		R_phase <= R_phase + 1;
		R_d <= R_out_word(31 downto 16);
	    elsif R_write_cycle and R_phase = C_phase_write_terminate then
		R_phase <= C_phase_idle;
		-- physical signals to SRAM: terminate 16-bit write
		R_wel <= '1';
		R_ubl <= '1';
		R_lbl <= '1';
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
    snoop_addr <= R_snoop_addr;
    snoop_cycle <= R_snoop_cycle;

end Structure;
