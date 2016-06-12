-- (c)Emard
-- License=BSD

-- AXI Master read/write 
-- with integrated f32c compatible multiport arbiter

-- todo: byte_sel is currently ignored

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.sram_pack.all;
use work.axi_pack.all;

entity axiram is
  generic
  (
    C_ports: integer;
    C_wait_cycles: integer range 2 to 65535 := 2; -- unused
    C_prio_port: integer := -1
  );
  port
  (
    clk: in std_logic;
    -- To internal bus / logic blocks
    data_out: out std_logic_vector(31 downto 0); -- XXX rename to bus_out!
    ready_out: out sram_ready_array; -- one bit per port
    snoop_addr: out std_logic_vector(31 downto 2);
    snoop_cycle: out std_logic := '0';
    -- Inbound multi-port bus connections
    bus_in: in sram_port_array;
    -- AXI Master
    axi_aresetn: in std_logic := '1';
    axi_in: in T_axi_miso;
    axi_out: out T_axi_mosi
  );
end axiram;

architecture Structure of axiram is
    -- State machine constants
    constant C_phase_idle: integer := 0;
    constant C_phase_wait_addr_unready: integer := 1;
    constant C_phase_wait_addr_ack: integer := 2;
    constant C_phase_wait_data_ack: integer := 3;
    constant C_phase_wait_write_ack: integer := 4;
    constant C_phase_last: integer := C_phase_wait_write_ack;

    -- Physical interface registers
    signal R_araddr, R_awaddr: std_logic_vector(31 downto 0); -- to SRAM
    --signal R_en: std_logic := '0'; -- not used on axi?
    --signal R_write_cycle: boolean := false; -- internal
    signal R_byte_sel: std_logic_vector(3 downto 0) := x"0"; -- internal
    signal R_out_word: std_logic_vector(31 downto 0); -- internal

    -- Bus interface registers
    signal R_bus_out: std_logic_vector(31 downto 0); -- to CPU bus

    -- Bus interface signals (resolved from bus_in record via R_cur_port)
    signal addr_strobe: std_logic;			-- from CPU bus
    signal write: std_logic;				-- from CPU bus
    signal byte_sel: std_logic_vector(3 downto 0);	-- from CPU bus
    signal addr: std_logic_vector(29 downto 2);		-- from CPU bus
    signal data_in: std_logic_vector(31 downto 0);	-- from CPU bus

    -- Arbiter registers
    signal R_phase: integer range 0 to C_phase_last;
    signal R_cur_port: integer range 0 to (C_ports - 1);
    signal R_last_port: integer range 0 to (C_ports - 1);
    signal R_prio_pending: boolean;
    signal R_ack_bitmap: std_logic_vector(0 to (C_ports - 1)) := (others => '0');
    signal R_snoop_cycle: std_logic := '0';
    signal R_snoop_addr: std_logic_vector(31 downto 2) := (others => '0');
    
    -- axi registered signaling
    signal R_arvalid: std_logic := '0'; -- read request, valid address
    signal R_awvalid: std_logic := '0'; -- write request, valid address
    signal R_wvalid: std_logic := '0'; -- write, valid data
    -- internal read lock
    signal R_read_busy, R_write_busy: std_logic := '0'; -- internal lock allows one request to complete until next is accepted

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
      if axi_aresetn = '0' then
        -- yes reset
        R_read_busy <= '0';
        R_araddr    <= (others => '0');
        R_arvalid   <= '0';
        R_write_busy <= '0';
        R_awaddr    <= (others => '0');
        R_awvalid   <= '0';
      else -- not reset
        R_ack_bitmap <= (others => '0'); -- assure that f32c ack will last only 1 CPU cycle
        -- R_snoop_cycle <= '0';
        R_prio_pending <= R_cur_port /= C_prio_port and C_prio_port >= 0 
	                  and bus_in(C_prio_port).addr_strobe = '1';

        if R_read_busy='0' and R_write_busy='0' and (R_ack_bitmap(R_cur_port) = '1' or addr_strobe = '0') then
          -- idle, check next port
          R_cur_port <= next_port;
        end if;

        -- read cycle
        if write='0' and addr_strobe='1' and R_read_busy='0' and R_arvalid='0' then
          R_araddr <= "00" & addr & "00";
          R_arvalid <= '1';
        else
          if R_arvalid='1' and axi_in.arready='1' then
            R_read_busy <= '1'; -- internal signal: read processing
            R_arvalid <= '0'; -- we got address accepted signal, remove read request
          end if;
        end if;

        -- read completed
        -- axi_in.rlast indicates last word in a burst
        if R_read_busy = '1' and axi_in.rvalid = '1' then
          R_read_busy <= '0';
          R_bus_out <= axi_in.rdata;
          --R_bus_out <= x"C01DEBA6"; -- debugging constant must be seen on every read
          R_ack_bitmap(R_cur_port) <= '1'; -- read ack, must be removed in next cycle
          R_cur_port <= next_port;
        end if;

        -- write cycle
        if write='1' and addr_strobe='1' and R_write_busy='0' and R_awvalid='0' then
          R_awaddr <= "00" & addr & "00";
          R_awvalid <= '1';
          R_out_word <= data_in;
          R_wvalid <= '1';
          -- we can safely acknowledge the write immediately
          R_ack_bitmap(R_cur_port) <= '1';
        else
          if R_awvalid='1' and axi_in.awready='1' then
            R_write_busy <= '1'; -- internal signal: read processing
            R_awvalid <= '0'; -- we got address accepted signal, remove read request
          end if;
        end if;

        -- write completed
        -- axi_in.rlast indicates last word in a burst
        if R_write_busy = '1' and axi_in.wready = '1' then
          R_write_busy <= '0';
          R_wvalid <= '0'; -- de-assert data valid signal
          R_cur_port <= next_port;
        end if;
      end if; -- not axi reset
      end if; -- rising edge clk
    end process;

    -- read signaling
    axi_out.arid    <= "0";    -- not used
    axi_out.arlen   <= x"00";  -- 1x 32-bit only (no burst) burst length, 00 means 1 word, 01 means 2 words, etc.
    axi_out.arsize  <= "010";  -- 32 bits, resp. 4 bytes
    axi_out.arburst <= "01";   -- burst type INCR - Incrementing address
    axi_out.arlock  <= '0';    -- Exclusive access not supported
    axi_out.arcache <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
    axi_out.arprot  <= "000";  -- Xilinx IP generally ignores
    axi_out.arqos   <= "0000"; -- QOS not supported

    axi_out.arvalid <= R_arvalid;
    --axi_out.arvalid <= '0';
    axi_out.araddr  <= R_araddr;

    -- write signaling
    axi_out.awid    <= "0";    -- not used
    axi_out.awlen   <= x"00";  -- data beats-1 (single access) (no burst)
    axi_out.awsize  <= "010";  -- 32 bits, resp. 4 bytes
    axi_out.awburst <= "01";   -- burst type INCR - Incrementing address
    axi_out.awlock  <= '0';    -- Exclusive access not supported
    axi_out.awcache <= "0011"; -- Xilinx IP generally ignores
    axi_out.awprot  <= "000";  -- Xilinx IP generally ignores
    axi_out.awqos   <= "0000"; -- QOS not supported

    axi_out.wstrb   <= (others => '0');
    axi_out.bready  <= '1';

    axi_out.awvalid <= R_awvalid;
    axi_out.awaddr  <= R_awaddr; -- address currently padded and 4-byte aligned
    axi_out.wvalid  <= R_wvalid;
    axi_out.wlast   <= R_wvalid; -- last is same as valid because we currently don't support burst
    axi_out.wdata   <= R_out_word;

    -- f32c bus out
    data_out <= R_bus_out;
    snoop_addr <= R_snoop_addr;
    snoop_cycle <= R_snoop_cycle;

end Structure;
