
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
	-- ISSI SRAM:
	-- C_wait_cycles: integer := 13 -- ne stigne iscrtat sliku
	-- C_wait_cycles: integer := 7 -- neispravno! R_a(6) je uvijek 1 !?!
	-- C_wait_cycles: integer := 6 -- neispravno! R_a(6) je uvijek 1 !?!
	-- C_wait_cycles: integer := 2 -- prebrzi timing, neispravno citanje
	-- Alliance SRAM:
	-- C_wait_cycles: integer := 13 -- ne stigne iscrtat sliku
	-- C_wait_cycles: integer := 8 -- ne stigne i crtat i pricat s CPU
	-- C_wait_cycles: integer := 2 -- prebrzi timing, neispravno citanje
	C_wait_cycles: integer := 3
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
    -- State machine constants
    constant C_phase_idle: integer := 0;
    constant C_phase_read_upper_half: integer := 1 + C_wait_cycles;
    constant C_phase_read_terminate: integer := 2 + C_wait_cycles * 2;
    constant C_phase_write_upper_half: integer := C_wait_cycles;
    constant C_phase_write_terminate: integer := C_wait_cycles * 2;

    -- Physical interface registers
    signal R_a: std_logic_vector(18 downto 0);		-- to SRAM
    signal R_d: std_logic_vector(15 downto 0);		-- to SRAM
    signal R_wel, R_lbl, R_ubl: std_logic;		-- to SRAM
    signal R_byte_sel_hi: std_logic_vector(1 downto 0);	-- internal
    signal R_high_word: std_logic_vector(15 downto 0);	-- internal

    -- Bus interface registers
    signal R_bus_out: std_logic_vector(31 downto 0);	-- to CPU bus

    -- Bus interface signals (resolved from bus_in record via R_cur_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(19 downto 2);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_phase: integer range 0 to C_phase_read_terminate;
    signal R_cur_port: integer range 0 to (C_ports - 1);
    signal R_ack_bitmap: std_logic_vector(0 to (C_ports - 1));

    -- Arbiter internal signals
    signal next_port: integer;

begin

    --
    -- R_phase strobe write R_phase' R_cur_port' R_ack' R_a' R_d' R_wel'
    --    0	  0	*	0	new	    0	R_a  R_d    1
    --    0	  1	0	1    R_cur_port	    0	new   Z   !write
    --    0	  1	1	1    R_cur_port	    1	new  new  !write
    --	  1	  *	*	2    R_cur_port     0   R_a  R_d  R_wel
    --

    -- Mux for input ports
    addr_strobe <= bus_in(R_cur_port).addr_strobe;
    write <= bus_in(R_cur_port).write;
    byte_sel <= bus_in(R_cur_port).byte_sel;
    addr <= bus_in(R_cur_port).addr;
    data_in <= bus_in(R_cur_port).data_in;

    -- Demux for outbound ready signals
    process(R_ack_bitmap)
	variable i: integer;
    begin
	for i in 0 to (C_ports - 1) loop
	    ready_out(i) <= R_ack_bitmap(i);
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
	if falling_edge(clk) then
	    if R_phase = C_phase_read_upper_half + 1 then
		R_bus_out(15 downto 0) <= sram_d;
	    elsif R_phase = 0 then
		R_bus_out(31 downto 16) <= sram_d;
	    end if;
	end if;

	if rising_edge(clk) then
	    if R_phase = C_phase_idle then
		R_wel <= '1';
		R_ubl <= '0';
		R_lbl <= '0';
		R_d <= (others => 'Z');
		if R_ack_bitmap(R_cur_port) = '1' or addr_strobe = '0' then
		    -- idle
		    R_cur_port <= next_port;
		else
		    -- start new transaction
		    R_phase <= R_phase + 1;
		    R_a <= addr & '0';
		    R_wel <= not write;
		    if write = '1' then
			R_ubl <= not byte_sel(1);
			R_lbl <= not byte_sel(0);
			R_d <= data_in(15 downto 0);
			R_byte_sel_hi <= byte_sel(3 downto 2);
			R_high_word <= data_in(31 downto 16);
		    else
			R_ubl <= '0';
			R_lbl <= '0';
			R_d <= (others => 'Z');
		    end if;
		end if;
		R_ack_bitmap <= (others => '0');
	    elsif R_wel = '1' and R_phase = C_phase_read_upper_half then
		R_phase <= R_phase + 1;
		-- physical signals to SRAM: bump addr
		R_a(0) <= '1';
	    elsif R_wel = '1' and R_phase = C_phase_read_terminate then
		R_ack_bitmap(R_cur_port) <= '1';
		R_phase <= C_phase_idle;
		R_cur_port <= next_port;
	    elsif R_wel = '0' and R_phase = C_phase_write_upper_half - 1 then
		R_phase <= R_phase + 1;
		-- physical signals to SRAM: terminate 16-bit write
		R_ubl <= '1';
		R_lbl <= '1';
	    elsif R_wel = '0' and R_phase = C_phase_write_upper_half then
		R_phase <= R_phase + 1;
		-- physical signals to SRAM: bump addr, refill data
		R_a(0) <= '1';
		R_ubl <= not R_byte_sel_hi(1);
		R_lbl <= not R_byte_sel_hi(0);
		R_d <= R_high_word;
	    elsif R_wel = '0' and R_phase = C_phase_write_terminate then
		R_ack_bitmap(R_cur_port) <= '1';
		R_phase <= C_phase_idle;
		R_cur_port <= next_port;
		-- physical signals to SRAM: terminate 16-bit write
		R_ubl <= '1';
		R_lbl <= '1';
	    else
		R_phase <= R_phase + 1;
	    end if;
	end if;
    end process;

    sram_d <= R_d;
    sram_a <= R_a(9 downto 0) & R_a(18 downto 10); -- XXX bezuspjesni ISSI hack
    sram_wel <= R_wel;
    sram_lbl <= R_lbl;
    sram_ubl <= R_ubl;

    data_out <= R_bus_out;

end Structure;
