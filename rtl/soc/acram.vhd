--
-- Copyright (c) 2016 Emard
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
-- adaptation of SRAM driver to work with axi cache
-- todo: get rid of 16-bit support and use axi's full 32 bit bus

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sram_pack.all;


entity acram is
    generic (
	C_ports: integer;
	C_wait_cycles: integer range 2 to 65535 := 2; -- wait cycles before expecting acram_ready=1
	C_prio_port: integer := -1
    );
    port (
	clk: in std_logic;
	-- To internal bus / logic blocks
	data_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
	ready_out: out sram_ready_array; -- one bit per port
	snoop_addr: out std_logic_vector(31 downto 2);
	snoop_cycle: out std_logic := '0';
	-- Inbound multi-port bus connections
	bus_in: in sram_port_array;
	-- To physical SRAM signals
	acram_a: out std_logic_vector(29 downto 2);
	acram_data_wr: out std_logic_vector(31 downto 0);
	acram_data_rd: in std_logic_vector(31 downto 0);
	acram_byte_we: out std_logic_vector(3 downto 0);
	acram_ready: in std_logic := '0';
	acram_en: out std_logic
    );
end acram;

architecture Structure of acram is
    -- State machine constants
    constant C_phase_idle: integer := 0;
    constant C_phase_terminate: integer := C_wait_cycles - 1;

    -- Physical interface registers
    signal R_a: std_logic_vector(29 downto 2);		-- to SRAM
    signal R_en: std_logic := '0';
    signal R_write_cycle: boolean := false;			-- internal
    signal R_byte_sel: std_logic_vector(3 downto 0) := x"0";	-- internal
    signal R_out_word: std_logic_vector(31 downto 0);	-- internal

    -- Bus interface registers
    signal R_bus_out: std_logic_vector(31 downto 0);	-- to CPU bus

    -- Bus interface signals (resolved from bus_in record via R_cur_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(29 downto 2);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_phase: integer range 0 to C_phase_terminate;
    signal R_cur_port: integer range 0 to (C_ports - 1);
    signal R_last_port: integer range 0 to (C_ports - 1);
    signal R_prio_pending: boolean;
    signal R_ack_bitmap: std_logic_vector(0 to (C_ports - 1));
    signal R_snoop_cycle: std_logic;
    signal R_snoop_addr: std_logic_vector(31 downto 2);

    -- Arbiter internal signals
    signal next_port: integer;

begin
    -- Mux for input ports
    addr_strobe <= bus_in(R_cur_port).addr_strobe;
    write <= bus_in(R_cur_port).write;
    byte_sel <= bus_in(R_cur_port).byte_sel;
    addr <= bus_in(R_cur_port).addr(addr'high downto 2);
    data_in <= bus_in(R_cur_port).data_in;

    -- Demux for outbound ready signals
    G_output_ack:
    for i in 0 to (C_ports - 1) generate
    	ready_out(i) <= R_ack_bitmap(i);
    end generate;

    -- Arbiter: round-robin port selection combinatorial logic
    process(bus_in, R_last_port, R_prio_pending)
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
      if rising_edge(clk) then
        R_ack_bitmap <= (others => '0');
	R_snoop_cycle <= '0';

	R_prio_pending <= R_cur_port /= C_prio_port and C_prio_port >= 0 
	              and bus_in(C_prio_port).addr_strobe = '1';

        if R_phase = C_phase_idle + 1 and R_cur_port /= C_prio_port then
          R_last_port <= R_cur_port;
        end if;

        if R_phase = C_phase_idle then
          if R_ack_bitmap(R_cur_port) = '1' or addr_strobe = '0' then
            -- idle
            R_cur_port <= next_port;
          else
            -- start a new transaction when ready
            if acram_ready='1' then
              R_phase <= C_phase_idle + 1;
              R_a <= addr;
              R_en <= '1';
              if write = '1' then
                R_write_cycle <= true;
                R_out_word <= data_in;
                -- we can safely acknowledge the write immediately
                R_ack_bitmap(R_cur_port) <= '1';
                R_snoop_addr(29 downto 2) <= addr; -- XXX
                --R_snoop_cycle <= '1';
                R_byte_sel <= byte_sel; -- write cycle for axi_cache nas non-zero byte_sel        
              else
                R_write_cycle <= false;
                R_byte_sel <= x"0"; -- read cycle for axi_cache is with byte_sel=0
              end if;
            end if;
          end if;
        elsif not R_write_cycle and acram_ready='1' and R_phase = C_phase_terminate then
          -- end of read cycle
          R_bus_out <= acram_data_rd; -- latch data and place on the bus
          R_ack_bitmap(R_cur_port) <= '1';
          --R_byte_sel <= x"0"; -- should be already 0, read cycle has byte_sel=0
          R_en <= '0';
          R_cur_port <= next_port;
          R_phase <= C_phase_idle;
        elsif R_write_cycle and acram_ready='1' and R_phase = C_phase_terminate then
          -- end of write cycle
          --R_ack_bitmap(R_cur_port) <= '1'; -- already acknowledged at start of write cycle
          R_byte_sel <= x"0";
          R_en <= '0';
          R_cur_port <= next_port;
          R_phase <= C_phase_idle;
        else
          if R_phase /= C_phase_terminate then -- prevent wraparound
             R_phase <= R_phase + 1;
          end if;
	end if;
      end if;
    end process;

    acram_data_wr <= R_out_word;
    acram_a <= R_a;
    acram_byte_we <= R_byte_sel;
    acram_en <= R_en;

    data_out <= R_bus_out;
    snoop_addr <= R_snoop_addr;
    snoop_cycle <= R_snoop_cycle;

end Structure;
