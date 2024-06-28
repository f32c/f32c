----------------------------------------------------------------------------------
-- Copyright (c) 2013 Mike Field <hamster@snap.net.nz>
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
-- Module Name:	SDRAM_Controller - Behavioral
-- Description:	Simple SDRAM controller for a Micron 48LC16M16A2-7E
--		or Micron 48LC4M16A2-7E @ 100MHz
-- Revision:
-- Revision 0.1	- Initial version
-- Revision 0.2	- Removed second clock signal that isn't needed.
-- Revision 0.3	- Added back-to-back reads and writes.
-- Revision 0.4	- Allow refeshes to be delayed till next PRECHARGE is issued,
--		  Unless they get really, really delayed. If a delay occurs
--		  multiple refreshes might get pushed out, but it will have
--		  avioded about 50% of the refresh overhead
-- Revision 0.5	- Add more paramaters to the design, allowing it to work for
--		  both the Papilio Pro and Logi-Pi
-- Revision 0.6	- Fixed bugs in back-to-back reads (thanks Scotty!)
--
-- Worst case performance (single accesses to different rows or banks) is:
-- Writes 16 cycles = 6,250,000 writes/sec = 25.0MB/s (excl. refresh overhead)
-- Reads  17 cycles = 5,882,352 reads/sec  = 23.5MB/s (excl. refresh overhead)
--
-- For 1:1 mixed reads and writes into the same row it is around 88MB/s
-- For reads or writes to the same it can be as high as 184MB/s
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sdram_pack.all;


entity sdram_controller is
    generic (
	C_ports: integer;
	C_prio_port: integer := -1;
	C_ras: integer range 2 to 3 := 2;
	C_cas: integer range 2 to 3 := 2;
	C_pre: integer range 2 to 3 := 2;
	C_clock_range: integer range 0 to 2 := 2;
	sdram_address_width: natural;
	sdram_column_bits: natural;
	sdram_startup_cycles: natural;
	cycles_per_refresh: natural
    );
    port (
	clk: in std_logic;
	reset: in std_logic;

	-- To internal bus / logic blocks
	req: in sdram_req_array;
	resp: out sdram_resp_array;
	snoop_addr: out std_logic_vector(31 downto 2);
	snoop_cycle: out std_logic;

	-- SDRAM signals
	sdram_clk: out std_logic;
	sdram_cke: out std_logic;
	sdram_cs: out std_logic;
	sdram_ras: out std_logic;
	sdram_cas: out std_logic;
	sdram_we: out std_logic;
	sdram_dqm: out std_logic_vector(1 downto 0);
	sdram_addr: out std_logic_vector(12 downto 0);
	sdram_ba: out std_logic_vector(1 downto 0);
	sdram_data: inout std_logic_vector(15 downto 0));
end sdram_controller;

architecture behavioral of sdram_controller is
    -- From page 37 of MT48LC16M16A2 datasheet
    -- Name (Function)       CS# RAS# CAS# WE# DQM  Addr    Data
    -- COMMAND INHIBIT (NOP)  H   X    X    X   X     X       X
    -- NO OPERATION (NOP)     L   H    H    H   X     X       X
    -- ACTIVE                 L   L    H    H   X  Bank/row   X
    -- READ                   L   H    L    H  L/H Bank/col   X
    -- WRITE                  L   H    L    L  L/H Bank/col Valid
    -- BURST TERMINATE        L   H    H    L   X     X     Active
    -- PRECHARGE              L   L    H    L   X   Code      X
    -- AUTO REFRESH           L   L    L    H   X     X       X
    -- LOAD MODE REGISTER     L   L    L    L   X  Op-code    X
    -- Write enable           X   X    X    X   L     X     Active
    -- Write inhibit          X   X    X    X   H     X     High-Z

    -- Here are the commands mapped to constants
    constant CMD_UNSELECTED    : std_logic_vector(3 downto 0) := "1000";
    constant CMD_NOP           : std_logic_vector(3 downto 0) := "0111";
    constant CMD_ACTIVE        : std_logic_vector(3 downto 0) := "0011";
    constant CMD_READ          : std_logic_vector(3 downto 0) := "0101";
    constant CMD_WRITE         : std_logic_vector(3 downto 0) := "0100";
    constant CMD_TERMINATE     : std_logic_vector(3 downto 0) := "0110";
    constant CMD_PRECHARGE     : std_logic_vector(3 downto 0) := "0010";
    constant CMD_REFRESH       : std_logic_vector(3 downto 0) := "0001";
    constant CMD_LOAD_MODE_REG : std_logic_vector(3 downto 0) := "0000";

    constant MODE_REG_CAS_2    : std_logic_vector(12 downto 0) :=
    -- Reserved, wr burst, OpMode, CAS Latency (2), Burst Type, Burst Length (2)
      "000" &   "0"  &  "00"  &    "010"      &     "0"    &   "001";
    constant MODE_REG_CAS_3    : std_logic_vector(12 downto 0) :=
    -- Reserved, wr burst, OpMode, CAS Latency (3), Burst Type, Burst Length (2)
      "000" &   "0"  &  "00"  &    "011"      &     "0"    &   "001";

    signal R_iob_command: std_logic_vector(3 downto 0) := CMD_NOP;
    signal R_iob_address: std_logic_vector(12 downto 0) := (others => '0');
    signal R_iob_data: std_logic_vector(15 downto 0) := (others => '0');
    signal R_iob_dqm: std_logic_vector(1 downto 0) := (others => '0');
    signal R_iob_cke: std_logic := '0';
    signal R_iob_bank: std_logic_vector(1 downto 0) := (others => '0');

    attribute IOB: string;
    attribute IOB of R_iob_command: signal is "true";
    attribute IOB of R_iob_address: signal is "true";
    attribute IOB of R_iob_dqm: signal is "true";
    attribute IOB of R_iob_cke: signal is "true";
    attribute IOB of R_iob_bank: signal is "true";
    attribute IOB of R_iob_data: signal is "true";

    signal R_iob_data_next: std_logic_vector(15 downto 0) := (others => '0');
    signal R_from_sdram_prev, R_from_sdram: std_logic_vector(15 downto 0);
    signal R_ready_out: std_logic_vector(C_ports - 1 downto 0); -- one-hot
    signal R_last_out: std_logic_vector(C_ports - 1 downto 0); -- one-hot
    attribute IOB of R_from_sdram: signal is "true";

    type fsm_state is (
	S_startup,
	S_idle_in_6, S_idle_in_5, S_idle_in_4,
	S_idle_in_3, S_idle_in_2, S_idle_in_1,
	S_idle,
	S_open_in_2, S_open_in_1,
	S_write_1, S_write_2, S_write_3,
	S_read_1, S_read_2, S_read_3, S_read_4,
	S_precharge
    );

    signal R_state: fsm_state := S_startup;
    attribute FSM_ENCODING: string;
    attribute FSM_ENCODING of R_state: signal is "ONE-HOT";

    -- dual purpose counter, it counts up during the startup phase, then is used to trigger refreshes.
    constant C_startup_refresh_max: unsigned(13 downto 0) := (others => '1');
    signal R_startup_refresh_count: unsigned(13 downto 0) :=
      C_startup_refresh_max - to_unsigned(sdram_startup_cycles, 14);

    -- logic to decide when to refresh
    signal pending_refresh: boolean;
    signal forcing_refresh: boolean;

    -- The incoming address is split into these three values
    signal addr_row: std_logic_vector(12 downto 0) := (others => '0');
    signal addr_col: std_logic_vector(12 downto 0) := (others => '0');
    signal addr_bank: std_logic_vector(1 downto 0) := (others => '0');

    signal R_dqm_sr: std_logic_vector(3 downto 0) := (others => '1'); -- an extra two bits in case CAS=3

    -- signals to hold the requested transaction before it is completed
    signal R_save_wr: std_logic := '0';
    signal R_save_row: std_logic_vector(12 downto 0);
    signal R_save_bank: std_logic_vector(1 downto 0);
    signal R_save_col: std_logic_vector(12 downto 0);
    signal R_save_data_in: std_logic_vector(31 downto 0);
    signal R_save_byte_enable: std_logic_vector(3 downto 0);
    signal R_save_burst_len: std_logic_vector(7 downto 0);

    -- control when new transactions are accepted
    signal accepting_new: boolean; -- combinatorial
    signal R_ready_for_new: boolean;
    signal R_can_back_to_back: boolean;

    -- signal to control the Hi-Z state of the DQ bus
    signal R_iob_dq_hiz: boolean := true;

    -- signals for when to read the data off of the bus
    signal R_data_ready_delay, R_data_last_delay:
      std_logic_vector(C_clock_range / 2 + C_cas downto 0);
    signal R_read_done: boolean;

    -- bit indexes used when splitting the address into row/colum/bank.
    constant C_end_of_col: natural := sdram_column_bits - 2;
    constant C_start_of_bank: natural := sdram_column_bits - 1;
    constant C_end_of_bank: natural := sdram_column_bits;
    constant C_start_of_row: natural := sdram_column_bits + 1;
    constant C_end_of_row: natural := sdram_address_width - 2;
    constant C_prefresh_cmd: natural := 10;

    -- Bus interface signals (resolved from req record via R_cur_port)
    signal strobe: std_logic;				-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(31 downto 0);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus
    signal burst_len: std_logic_vector(7 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_cur_port, R_next_port: integer range 0 to (C_ports - 1);

    -- Arbiter internal signals, combinatorial
    signal next_port: integer;

begin
    -- Inbound multiport mux
    strobe <= req(R_next_port).strobe;
    write <= req(R_next_port).write;
    byte_sel <= req(R_next_port).byte_sel;
    addr(req(0).addr'high - 2 downto 0) <= req(R_next_port).addr;
    data_in <= req(R_next_port).data_in;
    burst_len <= req(R_next_port).burst_len;

    -- Outbound multiport demux
    process(R_ready_out, R_last_out, R_from_sdram, R_from_sdram_prev)
    begin
	for i in 0 to (C_ports - 1) loop
	    resp(i).data_out <= R_from_sdram & R_from_sdram_prev;
	    resp(i).data_ready <= R_ready_out(i);
	    resp(i).last <= R_last_out(i);
	end loop;
    end process;

    -- Indicate the need to refresh when the counter is 2048,
    -- Force a refresh when the counter is 4096 - (if a refresh is forced,
    -- multiple refresshes will be forced until the counter is below 2048
    pending_refresh <= R_startup_refresh_count(11) = '1';
    forcing_refresh <= R_startup_refresh_count(12) = '1';

    ----------------------------------------------------------------------------
    -- Seperate the address into row / bank / address
    ----------------------------------------------------------------------------
    addr_row(C_end_of_row - C_start_of_row downto 0) <=
      addr(C_end_of_row downto C_start_of_row);       -- 12:0 <=  22:10
    addr_bank
      <= addr(C_end_of_bank downto C_start_of_bank);  -- 1:0  <=  9:8
    addr_col(sdram_column_bits - 1 downto 0)
      <= addr(C_end_of_col downto 0) & '0';           -- 8:0  <=  7:0 & '0'

    -----------------------------------------------------------
    -- Forward the SDRAM clock to the SDRAM chip - 180 degress
    -- out of phase with the control signals (ensuring setup and holdup
    -----------------------------------------------------------
    sdram_clk <= not clk;

    -----------------------------------------------
    --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    --!! Ensure that all outputs are registered. !!
    --!! Check the pinout report to be sure      !!
    --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -----------------------------------------------
    sdram_cke  <= R_iob_cke;
    sdram_CS   <= R_iob_command(3);
    sdram_RAS  <= R_iob_command(2);
    sdram_CAS  <= R_iob_command(1);
    sdram_WE   <= R_iob_command(0);
    sdram_dqm  <= R_iob_dqm;
    sdram_ba   <= R_iob_bank;
    sdram_addr <= R_iob_address;

    ---------------------------------------------------------------
    -- Explicitly set up the tristate I/O buffers on the DQ signals
    ---------------------------------------------------------------
    sdram_data <= (others => 'Z') when R_iob_dq_hiz else R_iob_data;

    -- Arbiter: round-robin port selection combinatorial logic
    process(req, R_cur_port)
	variable t, n: integer;
    begin
	t := R_cur_port;
	for i in 1 to C_ports loop
	    n := (R_cur_port + i) mod C_ports;
	    if req(n).strobe = '1' then
		t := n;
		exit;
	    end if;
	end loop;
	next_port <= t;
    end process;

    G_capture_falling:
    if C_clock_range = 1 generate
	R_from_sdram <= sdram_data when falling_edge(clk);
	R_from_sdram_prev <= R_from_sdram when falling_edge(clk);
    end generate;

    G_capture_rising:
    if C_clock_range /= 1 generate
	R_from_sdram <= sdram_data when rising_edge(clk);
	R_from_sdram_prev <= R_from_sdram when rising_edge(clk);
    end generate;

    accepting_new <= R_ready_for_new and strobe = '1' and R_read_done
      and R_ready_out(R_next_port) = '0';

    main_proc: process(clk)
    begin
	if rising_edge(clk) then
	    R_next_port <= next_port;

	    ------------------------------------------------
	    -- Default state is to do nothing
	    ------------------------------------------------
	    R_iob_command <= CMD_NOP;
	    R_iob_address <= (others => '0');
	    R_iob_bank <= (others => '0');

	    ------------------------------------------------
	    -- countdown for initialisation & refresh
	    ------------------------------------------------
	    R_startup_refresh_count <= R_startup_refresh_count + 1;

	    ----------------------------------------------------------------------------
	    -- update shift registers used to choose when to present data to/from memory
	    ----------------------------------------------------------------------------
	    if R_data_last_delay(2 downto 0) = "001" then
		R_read_done <= unsigned(R_save_burst_len) = 0;
	    end if;
	    R_data_ready_delay <=
	      '0' & R_data_ready_delay(R_data_ready_delay'high downto 1);
	    R_data_last_delay <=
	      '0' & R_data_last_delay(R_data_last_delay'high downto 1);
	    R_iob_dqm <= R_dqm_sr(1 downto 0);
	    R_dqm_sr <= "11" & R_dqm_sr(R_dqm_sr'high downto 2);

	    -------------------------------------------------------------------
	    -- It we are ready for a new tranasction and one is being presented
	    -- then accept it. Also remember what we are reading or writing,
	    -- and if it can be back-to-backed with the last transaction
	    -------------------------------------------------------------------
	    R_ready_out <= (others => '0');
	    R_last_out <= (others => '0');
	    R_ready_out(R_cur_port) <= R_data_ready_delay(0);
	    R_last_out(R_cur_port) <= R_data_last_delay(0);
	    if accepting_new then
		R_cur_port <= R_next_port;
		R_can_back_to_back <=
		  R_save_bank = addr_bank and R_save_row = addr_row;
		R_save_row <= addr_row;
		R_save_bank <= addr_bank;
		R_save_col <= addr_col;
		R_save_wr <= write;
		R_save_data_in <= data_in;
		R_save_byte_enable <= byte_sel;
		if write = '0' then
		    R_save_burst_len <= burst_len;
		end if;
		R_ready_for_new <= false;
		if write = '1' then
		    R_ready_out(R_next_port) <= '1';
		    R_last_out(R_next_port) <= '1';
		else
		    R_read_done <= false;
		end if;
	    end if;

	    case R_state is
	    when S_startup =>
		------------------------------------------------------------------------
		-- This is the initial startup state, where we wait for at least 100us
		-- before starting the start sequence
		--
		-- The initialisation is sequence is
		--  * de-assert SDRAM_CKE
		--  * 100us wait,
		--  * assert SDRAM_CKE
		--  * wait at least one cycle,
		--  * PRECHARGE
		--  * wait 2 cycles
		--  * REFRESH,
		--  * tREF wait
		--  * REFRESH,
		--  * tREF wait
		--  * LOAD_MODE_REG
		--  * 2 cycles wait
		------------------------------------------------------------------------
		R_iob_CKE <= '1';

		-- All the commands during the startup are NOPS, except these
		if R_startup_refresh_count = C_startup_refresh_max - 31 then
		    -- ensure all rows are closed
		    R_iob_command <= CMD_PRECHARGE;
		    R_iob_address(C_prefresh_cmd) <= '1'; -- all banks
		    R_iob_bank <= (others => '0');
		elsif R_startup_refresh_count = C_startup_refresh_max - 23 then
		    -- these refreshes need to be at least tREF (66ns) apart
		    R_iob_command <= CMD_REFRESH;
		elsif R_startup_refresh_count = C_startup_refresh_max - 15 then
		    R_iob_command <= CMD_REFRESH;
		elsif R_startup_refresh_count = C_startup_refresh_max - 7 then
		    -- Now load the mode register
		    R_iob_command <= CMD_LOAD_MODE_REG;
		    if C_cas = 2 then
			R_iob_address <= MODE_REG_CAS_2;
		    else
			R_iob_address <= MODE_REG_CAS_3;
		    end if;
		end if;

		------------------------------------------------------
		-- if startup is complete then go into idle mode,
		-- get prepared to accept a new command, and schedule
		-- the first refresh cycle
		------------------------------------------------------
		if R_startup_refresh_count = 0 then
		    R_state <= S_idle;
		    R_ready_for_new <= true;
		    R_save_burst_len <= (others => '0');
		    R_read_done <= true;
		    R_startup_refresh_count <=
		      to_unsigned(2048 - cycles_per_refresh + 1, 14);
		end if;

	    when S_idle_in_6 => R_state <= S_idle_in_5;
	    when S_idle_in_5 => R_state <= S_idle_in_4;
	    when S_idle_in_4 => R_state <= S_idle_in_3;
	    when S_idle_in_3 => R_state <= S_idle_in_2;
	    when S_idle_in_2 => R_state <= S_idle_in_1;
	    when S_idle_in_1 => R_state <= S_idle;

	    when S_idle =>
		-- Priority is to issue a refresh if one is outstanding
		if pending_refresh or forcing_refresh then
		    ----------------------------------------------------
		    -- Start the refresh cycle. This tasks tRFC (66ns),
		    -- so 6 idle cycles are needed @ 100MHz
		    ----------------------------------------------------
		    R_state <= S_idle_in_6;
		    R_iob_command <= CMD_REFRESH;
		    R_startup_refresh_count <=
		      R_startup_refresh_count - cycles_per_refresh + 1;
		elsif accepting_new or not R_ready_for_new then
		    --------------------------------
		    -- Start the read or write cycle.
		    -- First task is to open the row
		    --------------------------------
		    if C_ras = 2 then
			R_state <= S_open_in_1;
		    else
			R_state <= S_open_in_2;
		    end if;
		    R_iob_command <= CMD_ACTIVE;
		    if accepting_new then
			R_iob_address <= addr_row;
			R_iob_bank <= addr_bank;
		    else
			R_iob_address <= R_save_row;
			R_iob_bank <= R_save_bank;
		    end if;
		end if;

	    --------------------------------------------
	    -- Opening the row ready for reads or writes
	    --------------------------------------------
	    when S_open_in_2 =>
		R_state <= S_open_in_1;

	    when S_open_in_1 =>
		-- still waiting for row to open
		if R_save_wr = '1' then
		    R_state <= S_write_1;
		    R_iob_dq_hiz <= false;
		    R_iob_data <= R_save_data_in(15 downto 0); -- get the DQ bus out of HiZ early
		else
		    R_iob_dq_hiz <= true;
		    R_state <= S_read_1;
		end if;
		-- will be ready for a new transaction next cycle!
		if R_save_wr = '1' or unsigned(R_save_burst_len) = 0 then
		    R_ready_for_new <= true;
		end if;

	    ----------------------------------
	    -- Processing the read transaction
	    ----------------------------------
	    when S_read_1 =>
		R_state	<= S_read_2;
		R_iob_command <= CMD_READ;
		R_iob_address <= R_save_col;
		R_iob_bank <= R_save_bank;
		R_iob_address(C_prefresh_cmd) <= '0'; -- A10 actually matters - it selects auto precharge

		-- Schedule reading the data values off the bus
		R_data_ready_delay(R_data_ready_delay'high) <= '1';
		if unsigned(R_save_burst_len) = 0 then
		    R_data_last_delay(R_data_last_delay'high) <= '1';
		end if;

		-- Set the data masks to read all bytes
		R_iob_dqm <= (others => '0');
		R_dqm_sr(1 downto 0) <= (others => '0');

	    when S_read_2 =>
		if unsigned(R_save_burst_len) /= 0 then
		    R_state <= S_read_1;
		    R_save_burst_len <=
		      std_logic_vector(unsigned(R_save_burst_len) - 1);
		    R_save_col <= std_logic_vector(unsigned(R_save_col) + 2);
		    R_save_col(sdram_column_bits) <= '0';
		    -- Check if we are crossing row / bank boundary?
		    if std_logic_vector(to_signed(-1, sdram_column_bits - 1))
		      = R_save_col(sdram_column_bits - 1 downto 1) then
			R_state <= S_read_3;
			R_can_back_to_back <= false;
			R_save_bank <=
			  std_logic_vector(unsigned(R_save_bank) + 1);
			if R_save_bank = "11" then
			    R_save_row <=
			      std_logic_vector(unsigned(R_save_row) + 1);
			end if;
		    elsif unsigned(R_save_burst_len) = 1 then
			-- will be ready for a new transaction next cycle!
			R_ready_for_new <= true;
		    end if;
		else
		    R_state <= S_read_3;
		end if;
		if C_cas = 3 then
		    R_dqm_sr(1 downto 0) <= (others => '0');
		end if;

	    when S_read_3 =>
		if forcing_refresh or (accepting_new and
		  (R_save_bank /= addr_bank or R_save_row /= addr_row)) or
		  not R_can_back_to_back then
		    if C_cas = 2 then
			R_state <= S_precharge;
		    else
			R_state <= S_read_4;
		    end if;
		elsif accepting_new then
		    if write = '1' then
			R_state <= S_write_1;
			R_iob_dq_hiz <= false;
			R_iob_data <= data_in(15 downto 0);
			R_ready_for_new <= true;
		    else
			R_state <= S_read_1;
			-- will be ready for a new transaction next cycle!
			if unsigned(burst_len) = 0 then
			    R_ready_for_new <= true;
			end if;
		    end if;
		elsif not R_ready_for_new then
		    if R_save_wr = '1' then
			R_state <= S_write_1;
			R_iob_dq_hiz <= false;
			R_iob_data <= R_save_data_in(15 downto 0);
			R_ready_for_new <= true;
		    else
			R_state <= S_read_1;
			-- will be ready for a new transaction next cycle!
			if unsigned(R_save_burst_len) = 0 then
			    R_ready_for_new <= true;
			end if;
		    end if;
		end if;

	    when S_read_4 =>
		R_state <= S_precharge;

	    ------------------------------------------------------------------
	    -- Processing the write transaction
	    -------------------------------------------------------------------
	    when S_write_1 =>
		R_state	 <= S_write_2;
		R_iob_command <= CMD_WRITE;
		R_iob_address <= R_save_col;
		R_iob_address(C_prefresh_cmd) <= '0'; -- A10 actually matters - it selects auto precharge
		R_iob_bank <= R_save_bank;
		R_iob_dqm <= NOT R_save_byte_enable(1 downto 0);
		R_dqm_sr(1 downto 0) <= NOT R_save_byte_enable(3 downto 2);
		R_iob_data <= R_save_data_in(15 downto 0);
		R_iob_data_next	<= R_save_data_in(31 downto 16);

	    when S_write_2 =>
		R_state	<= S_write_3;
		R_iob_data <= R_iob_data_next;
		-- can we do a back-to-back write?
		if not forcing_refresh and not R_ready_for_new
		  and R_can_back_to_back then
		    if R_save_wr = '1' then
			-- back-to-back write?
			R_state	<= S_write_1;
			R_ready_for_new <= true;
		    end if;
		    -- Although it looks right in simulation you can't go write-to-read
		    -- here due to bus contention, as iob_dq_hiz takes a few ns.
		end if;

	    when S_write_3 =>  -- must wait tRDL, hence the extra idle state
		-- back to back transaction?
		if not forcing_refresh and not R_ready_for_new and
		  R_can_back_to_back then
		    if R_save_wr = '1' then
			-- back-to-back write?
			R_state	<= S_write_1;
			R_ready_for_new <= true;
		    else
			-- write-to-read switch?
			R_state	<= S_read_1;
			R_iob_dq_hiz <= true;
			-- will be ready for a new transaction next cycle!
			if unsigned(R_save_burst_len) = 0 then
			    R_ready_for_new <= true;
			end if;
		    end if;
		else
		    R_iob_dq_hiz <= true;
		    R_state <= S_precharge;
		end if;

	    -------------------------------------------------------------------
	    -- Closing the row off (this closes all banks)
	    -------------------------------------------------------------------
	    when S_precharge =>
		if C_pre = 2 then
		    R_state <= S_idle_in_2;
		else
		    R_state <= S_idle_in_3;
		end if;
		R_iob_command <= CMD_PRECHARGE;
		R_iob_address(C_prefresh_cmd) <= '1'; -- A10 actually matters - it selects all banks or just one

	    -------------------------------------------------------------------
	    -- We should never get here, but if we do then reset the memory
	    -------------------------------------------------------------------
	    when others =>
		R_state <= S_startup;
		R_ready_for_new <= false;
		R_startup_refresh_count <=
		  C_startup_refresh_max - to_unsigned(sdram_startup_cycles, 14);
	    end case;

	    if reset = '1' then  -- Sync reset
		R_state <= S_startup;
		R_ready_for_new <= false;
		R_startup_refresh_count <=
		  C_startup_refresh_max - to_unsigned(sdram_startup_cycles, 14);
	    end if;
	end if;
    end process;
end behavioral;
