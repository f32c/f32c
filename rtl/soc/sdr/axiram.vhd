-- (c)Emard
-- License=BSD

-- AXI Master read/write 
-- with integrated f32c compatible multiport arbiter

-- currently it doesn't support burst.
-- AXI read and write can happen simultaneously
-- but this module does either write or read at a time,
-- to make sure that after new value is written, subsequent
-- read will return new value, not the old.

-- bus errors not handled
-- timeouts not handled. if something gets stuck
-- at AXI slave side, this module will get stuck too.

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
    constant C_phase_wait_read_addr_ack: integer := 1;
    constant C_phase_wait_read_data_ack: integer := 2;
    constant C_phase_wait_write_addr_ack: integer := 3;
    constant C_phase_wait_write_data_ack: integer := 4;
    constant C_phase_max: integer := C_phase_wait_write_data_ack;

    -- Physical interface registers
    signal R_a: std_logic_vector(29 downto 2); -- to SRAM
    --signal R_en: std_logic := '0'; -- not used on axi?
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
    signal R_phase: integer range 0 to C_phase_max;
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
	R_prio_pending <= R_cur_port /= C_prio_port and C_prio_port >= 0 
	              and bus_in(C_prio_port).addr_strobe = '1';

        case R_phase is

        when C_phase_idle =>
          if R_ack_bitmap(R_cur_port) = '1' or addr_strobe = '0' then
            -- idle
            R_cur_port <= next_port;
          else
            -- start a new transaction when slave ready
            if (axi_in.arready='1' and write='0') or (axi_in.awready='1' and write='1') then
              R_a <= addr;
              if write = '1' then
                R_awvalid <= '1'; -- write request starts with address
                R_out_word <= data_in; -- latch data to be written
                R_byte_sel <= byte_sel; -- latch byte select to be written
                -- we can safely acknowledge the write immediately
                R_ack_bitmap(R_cur_port) <= '1';
                R_phase <= C_phase_wait_write_addr_ack;
              else
                R_arvalid <= '1'; -- read request starts with address
                R_phase <= C_phase_wait_read_addr_ack;
              end if;
            end if;
          end if;
        -- end phase idle

        when C_phase_wait_read_addr_ack =>
          R_arvalid <= '0'; -- de-activate address request
          if R_cur_port /= C_prio_port then
            R_last_port <= R_cur_port;
          end if;
          if axi_in.arready = '1' then
            --R_arvalid <= '0'; -- de-activate address request
            R_phase <= C_phase_wait_read_data_ack;
          end if;
        -- end phase wait read addr ack

        when C_phase_wait_read_data_ack =>
          if axi_in.rvalid = '1' and axi_in.rlast = '1' then
            -- end of read cycle
            R_bus_out <= axi_in.rdata; -- latch data and place on the f32c bus
            R_ack_bitmap(R_cur_port) <= '1'; -- read ack, must be removed in next cycle
            R_cur_port <= next_port;
            R_phase <= C_phase_idle;
          end if;
	-- end phase wait read data ack

        when C_phase_wait_write_addr_ack =>
          R_awvalid <= '0'; -- de-activate address request
          if axi_in.awready = '1' then
            --R_awvalid <= '0'; -- de-activate address request
            R_wvalid <= '1'; -- activate data valid, try if this could be activated on earlier phase
            R_phase <= C_phase_wait_write_data_ack;
          end if;
        -- end phase wait write addr ack

        when C_phase_wait_write_data_ack =>
          if axi_in.wready = '1' then
            -- end of write cycle
            --R_byte_sel <= x"0"; -- de-activate all byte selects to double-sure prevent of unwanted writes
            R_wvalid <= '0'; -- de-activate data valid signal
            R_cur_port <= next_port;
            R_phase <= C_phase_idle;
          end if;
	-- end phase wait write data ack
        end case;

      end if; -- rising edge clk
    end process;

    -- read signaling
    axi_out.arid    <= "0";    -- not used
    axi_out.arlen   <= x"00";  -- 1x 32-bit only (no burst) burst length, 00 means 1 word, 01 means 2 words, etc.
    axi_out.arsize  <= "010";  -- 32 bits, resp. 4 bytes
    axi_out.arburst <= "01";   -- burst type INCR - Incrementing address
    axi_out.arlock  <= '0';    -- Exclusive access not supported
    axi_out.arcache <= "1111"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
    axi_out.arprot  <= "000";  -- Xilinx IP generally ignores
    axi_out.arqos   <= "0000"; -- QOS not supported
    axi_out.rready  <= '1';    -- always ready to read data
    axi_out.arvalid <= R_arvalid; -- read request start (address valid)
    axi_out.araddr  <= "00" & R_a & "00"; -- address padded and 4-byte aligned

    -- write signaling
    axi_out.awid    <= "0";    -- not used
    axi_out.awlen   <= x"00";  -- data beats-1 (single access) (no burst)
    axi_out.awsize  <= "010";  -- 32 bits, resp. 4 bytes
    axi_out.awburst <= "01";   -- burst type INCR - Incrementing address
    axi_out.awlock  <= '0';    -- Exclusive access not supported
    axi_out.awcache <= "1111"; -- Xilinx IP generally ignores
    axi_out.awprot  <= "000";  -- Xilinx IP generally ignores
    axi_out.awqos   <= "0000"; -- QOS not supported
    axi_out.bready  <= '1';    -- always ready to read write response (response otherwise ignored)
    axi_out.awvalid <= R_awvalid; -- write request start (address valid)
    axi_out.awaddr  <= "00" & R_a & "00"; -- address padded and 4-byte aligned
    axi_out.wvalid  <= R_wvalid; -- write data valid
    axi_out.wlast   <= R_wvalid; -- last is same as valid because we currently don't support burst
    axi_out.wdata   <= R_out_word; -- write data
    axi_out.wstrb   <= R_byte_sel; -- byte select 4-bit vector

    -- f32c bus out
    data_out <= R_bus_out;
    snoop_addr <= R_snoop_addr;
    snoop_cycle <= R_snoop_cycle;

end Structure;
