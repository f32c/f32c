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
-- RAM emulation using BRAM
-- with constant number of wait states
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_emu is
    generic (
	C_wait_states: integer := 0; -- extra wait states
	C_output_always: boolean := false; -- false: output only during 1-cycle narrow time window
	C_addr_width: integer := 11 -- BRAM size alloc bytes = 2^(n+3)
    );
    port (
	clk: in  STD_LOGIC;
	reset: in  STD_LOGIC;
	-- To internal bus / logic blocks
	request, write: in std_logic;
	addr: in std_logic_vector(27 downto 0);
	byte_sel: in std_logic_vector(3 downto 0);
	data_in: in std_logic_vector(31 downto 0);
	data_out: out std_logic_vector(31 downto 0);
	ready_next_cycle: out std_logic
    );
end ram_emu;

architecture Behavioral of ram_emu is
    signal write_byte: std_logic_vector(3 downto 0);	-- from arbiter
    signal S_ready_next_cycle: std_logic;
    signal R_ready_this_cycle: std_logic;
    signal S_data_out: std_logic_vector(31 downto 0);
    -- delay ready signal to simulate slow ram
    signal wait_states: std_logic_vector(C_wait_states-1 downto 0);
begin
    -- BRAM storage: 4 blocks of 8 bits
    -- each block separately writeable
    four_bytes: for i in 0 to 3 generate
    write_byte(i) <= write and byte_sel(i); -- and request;
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
        data_out_a => S_data_out(8*i+7 downto 8*i)
    );
    end generate;

    -- direct output from ram block,
    -- correct data already at output
    -- before ready signal
    out_always: if C_output_always generate
      data_out <= S_data_out;
    end generate;

    -- for debug, to provoke eventual problems
    -- instead of always otputting data
    -- output data only during 1 cycle
    -- after wait states. otherwise output 0
    out_narrow: if not C_output_always generate
    out_enable: process(clk)
    begin
      if rising_edge(clk) then
          R_ready_this_cycle <= S_ready_next_cycle;
      end if;
    end process;
    data_out <= S_data_out when R_ready_this_cycle = '1'
           else (others => '0');
    end generate;

    no_wait_states: if C_wait_states = 0 generate
    ready_next_cycle <= '1';
    end generate;

    have_wait_states: if C_wait_states > 0 generate
    delay_line: process(clk)
    begin
        if rising_edge(clk) then
            if S_ready_next_cycle = '0' then
              -- shift register
              wait_states <= request
                  & wait_states(wait_states'high downto 1);
            else
              -- after each ready out,
              -- reset wait_states register
              -- to prevent any further ready_next_cycle
              -- (CPU must grab data during 1 clock cycle)
              -- reset is not needed
              -- for C_wait_states = 0-2
              -- but if wait_states register is not reset here,
              -- ram_emu will work for
              -- C_wait_states = 3 or more
              -- only when C_icache_size = 0
              -- or C_icache_expire = true
              wait_states <= (others => '0');
            end if;
        end if;
    end process;
    S_ready_next_cycle <= wait_states(0);
    ready_next_cycle <= S_ready_next_cycle;
    end generate;
end Behavioral;

-- todo:
-- [ ] delay addressing (currently address setups immediately)
-- [ ] delay write (currently writes immediately)
