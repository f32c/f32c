
-- $Id$

--
-- Cmd byte encoding: 1 S A C  C C C C
--	S - argument size (1 or 4 bytes)
--	A - argument count (1 or 2)
--	CCCCC - command code
--
-- Commands:
--	9d	enable / disable debugger (arg: ed / dd)
--	a0	read register(s) (arg1: start, arg2: count)
--	a1	write register(s) (arg1: start, arg2: count)
--	e2	read memory (arg1: start, arg2: count)
--	e3	write memory (arg1: start, arg2: count)
--	c8	step (arg: number of clock ticks)
--
-- Ideally, those commands should permit synthesizing the following:
--
--   Primitives, inspired by the GDB serial remote protocol:
--	halt (enter debug state, freezing the pipeline?)
--	continue (let the instruction flow run)
--	read register(s)
--	write register(s)
--	read memory (byte oriented)
--	write memory (byte oriented)
--	step (execute a single instruction to completion)
--
--   Non-GDB primitives:
--	single clock (let the pipeline flow)
--	cycle step (execute exactly N instructions, or N clock cycles?)
--	stop
--	set up a hardware breakpoint
--	clear a hardware breakpoint
--	set up a hardware memory watchpoint
--	clear a hardware memory watchpoint
--	detect a "plain" break instruction?
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.f32c_pack.all;


entity debug is
    generic (
	C_debug: boolean := true
    );
    port (
	clk: in std_logic;
	ctrl_in_data: in std_logic_vector(7 downto 0);
	ctrl_in_strobe: in std_logic;
	ctrl_in_busy: out std_logic;
	ctrl_out_data: out std_logic_vector(7 downto 0);
	ctrl_out_strobe: out std_logic;
	ctrl_out_busy: in std_logic;
	trace_active: out std_logic;
	trace_op: out std_logic_vector(3 downto 0);
	trace_addr: out std_logic_vector(31 downto 0);
	trace_data_out: out std_logic_vector(31 downto 0);
	trace_data_in: in std_logic_vector(31 downto 0)
    );
end debug;

architecture x of debug is
    -- Request processing FSMD states
    constant DEB_REQ_IDLE: integer := 0;
    constant DEB_REQ_ARG1: integer := 1;
    constant DEB_REQ_ARG2: integer := 2;
    constant DEB_REQ_EXEC: integer := 3;

    -- Commands
    constant DEB_CMD_ACTIVE: std_logic_vector := x"9d";
    constant DEB_CMD_REG_RD: std_logic_vector := x"a0";
    constant DEB_CMD_REG_WR: std_logic_vector := x"a1";
    constant DEB_CMD_MEM_RD: std_logic_vector := x"a2";
    constant DEB_CMD_MEM_WR: std_logic_vector := x"a3";

    -- Debugger enabled flag
    signal R_debug_active: std_logic := '0';

    -- Request processing FSMD registers
    signal R_req_state: integer;
    signal R_cmd: std_logic_vector(7 downto 0);
    signal R_arg1, R_arg2: std_logic_vector(31 downto 0);
    signal R_argcnt: std_logic_vector(1 downto 0);

    -- Output data & control
    signal R_ctrl_out: std_logic_vector(7 downto 0);
    signal R_ctrl_out_strobe: std_logic;

begin
    ctrl_in_busy <= '0';
    ctrl_out_strobe <= R_ctrl_out_strobe;
    ctrl_out_data <= R_ctrl_out;

    trace_active <= R_debug_active;
    trace_addr <= R_arg1;

    process(clk)
    begin
	if C_debug and rising_edge(clk) then
	    R_ctrl_out_strobe <= '0';

	    --
	    -- FSMD for receiving a cmd with variable length args
	    --
	    if ctrl_in_strobe = '1' then
		case R_req_state is
		when DEB_REQ_IDLE =>
		    if R_debug_active = '0' and
		      ctrl_in_data /= DEB_CMD_ACTIVE then
			-- do nothing
		    elsif ctrl_in_data(7) = '1' then
			R_cmd <= ctrl_in_data;
			R_req_state <= DEB_REQ_ARG1;
			if ctrl_in_data(6) = '1' then
			    R_argcnt <= "11";
			else
			    R_argcnt <= "00";
			end if;
		    end if;
		when DEB_REQ_ARG1 =>
		    R_arg1(31 downto 8) <= R_arg1(23 downto 0);
		    R_arg1(7 downto 0) <= ctrl_in_data;
		    if R_argcnt = "00" then
			if R_cmd(6) = '1' then
			    R_argcnt <= "11";
			else
			    R_argcnt <= "00";
			end if;
			if R_cmd(5) = '1' then
			    R_req_state <= DEB_REQ_ARG2;
			else
			    R_req_state <= DEB_REQ_EXEC;
			end if;
		    else
			R_argcnt <= R_argcnt - 1;
		    end if;
		when DEB_REQ_ARG2 =>
		    R_arg2(31 downto 8) <= R_arg2(23 downto 0);
		    R_arg2(7 downto 0) <= ctrl_in_data;
		    if R_argcnt = "00" then
			R_req_state <= DEB_REQ_EXEC;
		    else
			R_argcnt <= R_argcnt - 1;
		    end if;
		when others =>
		    R_req_state <= DEB_REQ_IDLE;
		end case;
	    end if;

	    --
	    -- Process the received cmd
	    --
	    if R_req_state = DEB_REQ_EXEC and R_debug_active = '0' then
		if R_arg1(7 downto 0) = x"ed" then
		    R_debug_active <= '1';
		end if;
		R_req_state <= DEB_REQ_IDLE;
	    elsif R_req_state = DEB_REQ_EXEC and R_debug_active = '1' then
		case R_cmd is
		when DEB_CMD_ACTIVE =>
		    if R_arg1(7 downto 0) = x"dd" then
			R_debug_active <= '0';
		    end if;
		    R_req_state <= DEB_REQ_IDLE;
		when DEB_CMD_REG_RD =>
		    if ctrl_out_busy = '0' and R_ctrl_out_strobe = '0' then
			case R_argcnt is
			when "00" =>
			    R_ctrl_out <= trace_data_in(7 downto 0);
			when "01" =>
			    R_ctrl_out <= trace_data_in(15 downto 8);
			when "10" =>
			    R_ctrl_out <= trace_data_in(23 downto 16);
			when others =>
			    R_ctrl_out <= trace_data_in(31 downto 24);
			    if R_arg2(7 downto 0) = x"00" then
				R_req_state <= DEB_REQ_IDLE;
			    else
				R_arg2 <= R_arg2 - 1;
				R_arg1 <= R_arg1 + 1;
			    end if;
			end case;
			R_argcnt <= R_argcnt + 1;
			R_ctrl_out_strobe <= '1';
		    end if;
		when DEB_CMD_MEM_RD =>
		    if ctrl_out_busy = '0' and R_ctrl_out_strobe = '0' then
			case R_arg1(1 downto 0) is
			when "00" =>
			    R_ctrl_out <= trace_data_in(7 downto 0);
			when "01" =>
			    R_ctrl_out <= trace_data_in(15 downto 8);
			when "10" =>
			    R_ctrl_out <= trace_data_in(23 downto 16);
			when others =>
			    R_ctrl_out <= trace_data_in(31 downto 24);
			end case;
			if R_arg2 = x"00000000" then
			    R_req_state <= DEB_REQ_IDLE;
			else
			    R_arg2 <= R_arg2 - 1;
			    R_arg1 <= R_arg1 + 1;
			end if;
			R_ctrl_out_strobe <= '1';
		    end if;
		when others =>
		    -- XXX testing only - nothing should be sent here
		    -- R_ctrl_out_strobe <= '1';
		    -- R_ctrl_out <= R_cmd + 1;
		    R_req_state <= DEB_REQ_IDLE;
		end case;
	    end if;
	end if;
    end process;
end x;
