-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.axi_pack.all;

-- Vector I/O DMA module for AXI bus

-- once activated, this unit will become
-- master to both bram and to external RAM
-- (AXI in this case)

-- using a given ram address, it will
-- load or store vectors to/from ram
-- determine the end of
-- data and provide signal bit when done

-- FSM for propagating RAM pointer structs
-- should be separated from this module
-- to use in non-axi configuration

-- at rising edge of the request
-- following signals are latched: addr, store_mode

-- multi-part vectors, consisting of segments
-- I/O stops when number of elements exceed vaddr range
-- which is usually 2048 elements

-- struct vector_segment
-- {
--   uint16_t data_length; // length of the data segment (number of elements), maybe n-1 practical?
--   uint16_t data_type; // data type, currently unused
--   void *data_addr; // ptr to sequential vector's data, could be float or int32_t
--   struct vector_segment *next;  // NULL if this is the last
-- }

-- linked list processing:
-- 0. latch all needed input state in internal registers
--    set header countdown to 2 and burst countdown to 2
-- 1. read header (3x32-bit words in burst mode)
--    store the header in register array (3 registers)
--    until header counts 0, then decide if nonzero data pointer
--    continue with the data
-- 2. set ram addr with data pointer, set length, set initial burst
--    and load/store bram to/from data pointer
--

entity axi_vector_dma is
  generic
  (
    C_vaddr_bits: integer := 11; -- bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
    C_vdata_bits: integer := 32;
    C_burst_max_bits: integer := 6 -- number of bits to describe burst max
  );
  port
  (
    clk: in std_logic;

    -- vector processor control
    addr: in std_logic_vector(29 downto 2); -- vector header struct address in RAM
    request: in std_logic; -- pulse '1' during 1 clock cycle to start
    store_mode: in std_logic; -- '1' write to RAM (vector store mode), '0' read from RAM (vector load mode)
    done: out std_logic; -- '1' when done

    -- bram interface
    bram_we: out std_logic := '0'; -- bram write enable
    bram_next: out std_logic := '0';
    bram_addr: out std_logic_vector(C_vaddr_bits downto 0);
    bram_wdata: out std_logic_vector(C_vdata_bits-1 downto 0);
    bram_rdata: in std_logic_vector(C_vdata_bits-1 downto 0);

    -- AXI ram interface
    axi_in: in T_axi_miso;
    axi_out: out T_axi_mosi
  );
end axi_vector_dma;

architecture arch of axi_vector_dma is
  -- State machine constants
  constant C_state_idle: integer := 0;
  constant C_state_wait_ready_to_read: integer := 1;
  constant C_state_wait_read_addr_ack: integer := 2;
  constant C_state_wait_read_data_ack: integer := 3;
  constant C_state_wait_write_data_ack: integer := 4;
  constant C_state_max: integer := C_state_wait_write_data_ack;

  signal R_store_mode: std_logic;
  signal R_ram_addr: std_logic_vector(29 downto 2);
  signal R_bram_addr: std_logic_vector(C_vaddr_bits downto 0) := (others => '1'); -- external counter for RAM load/store
  signal R_state: integer range 0 to C_state_max := C_state_idle;
  signal R_done: std_logic := '1';
  signal R_next: std_logic := '0'; -- request next data

  -- output buffering to sync data coming from axi with clock rising edge
  constant C_register_bram_output: boolean := false;
  signal S_bram_wdata, R_bram_wdata: std_logic_vector(31 downto 0);
  signal S_bram_we, R_bram_we, S_bram_next, R_bram_next: std_logic;

  -- axi registered signaling
  signal R_arvalid: std_logic := '0'; -- read request, valid address
  signal R_awvalid: std_logic := '0'; -- write request, valid address
  signal R_wvalid: std_logic := '0'; -- write, valid data
  -- linked list struct header fields
  constant C_header_data_length: integer := 2; -- loaded first from ram+0 -- neeed early, can't be loaded last last
  constant C_header_data_addr: integer := 1; -- loaded second from ram+1 -- needer early, can't be loaded last
  constant C_header_next: integer := 0; -- loaded last from ram+2 - needed at end of data, can be loaded last
  constant C_header_max: integer := 3; -- number of 32-bit words in the header
  constant C_header_addr_bits: integer := 2; -- number of bits to describe the header must be C_header_addr_bits <= C_vaddr_bits
  type T_header is array (0 to C_header_max-1) of std_logic_vector(31 downto 0);
  signal R_header: T_header;
  signal R_header_mode: std_logic := '1'; -- '1' when we read the header, otherwise the data
  signal R_length_remaining: std_logic_vector(C_vaddr_bits-1 downto 0) := (others => '0'); -- vector length 1 less then actual value (0 -> length 1)
  constant C_burst_bits_pad: std_logic_vector(7-C_burst_max_bits downto 0) := (others => '0');
  signal S_burst_remaining: std_logic_vector(C_burst_max_bits-1 downto 0) := (others => '0'); -- 1 less than actual value
  -- the bram_rdata fifo
  constant C_wdata_fifo_bits: integer := 3; -- 3 bits fifo length 2**3 = 8 elements
  type T_wdata_fifo is array (2**C_wdata_fifo_bits-1 downto 0) of std_logic_vector(C_vdata_bits-1 downto 0);
  signal R_wdata_fifo: T_wdata_fifo;
  signal R_wdata_fifo_reset: std_logic := '0';
  signal S_need_refill: std_logic;
  -- fifo index counters
  signal R_wdata_fifo_index_in: std_logic_vector(C_wdata_fifo_bits-1 downto 0) := (others => '1'); -- stopped
  signal R_wdata_fifo_index_out: std_logic_vector(C_wdata_fifo_bits-1 downto 0) := (others => '0'); -- initial 0
  signal S_wdata_fifo_index_diff: std_logic_vector(C_wdata_fifo_bits-1 downto 0);
  signal R_bram_rdata_ready: std_logic;
  -- bram_next component signals
  signal S_read_next, S_write_next: std_logic;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      R_next <= '0'; -- default
      R_awvalid <= '0'; -- de-activate address request
      case R_state is
      when C_state_idle =>
        if request='1' then
          R_ram_addr <= addr;
          R_bram_addr <= (others => '0');
          R_store_mode <= store_mode;
          R_wdata_fifo_reset <= store_mode; -- start fetching data from the fifo
          R_length_remaining <= conv_std_logic_vector(C_header_max-1, C_vaddr_bits);
          R_header_mode <= '1';
          R_done <= '0';
          R_state <= C_state_wait_ready_to_read;
        end if;

      when C_state_wait_ready_to_read =>
        R_wdata_fifo_reset <= '0';
        if axi_in.arready='1' then
          R_arvalid <= '1'; -- activate address request
          R_state <= C_state_wait_read_addr_ack;
        end if;

      when C_state_wait_read_addr_ack =>
        R_arvalid <= '0'; -- de-activate address request
        if axi_in.arready='1' then
          R_state <= C_state_wait_read_data_ack;
        end if;

      when C_state_wait_read_data_ack =>
        if axi_in.rvalid='1' then
          if R_header_mode='1' then
            -- header will be indexed downwards 2,1,0 using decrementing R_length_remaining
            R_header(conv_integer(R_length_remaining(C_header_addr_bits-1 downto 0))) <= axi_in.rdata;
          else -- R_header_mode='0'
            R_bram_addr <= R_bram_addr + 1; -- increment source address
          end if;
          if axi_in.rlast='1' then
            -- warning: when R_length_remaining=0 also axi_in.rlast='1' must appear.
            -- nomally that should always be the case if both this module and AXI work correctly.
            -- otherwise excessive RAM access may happen
            if R_bram_addr(C_vaddr_bits) = '1' -- safety measure
            or R_length_remaining(C_vaddr_bits-1 downto C_burst_max_bits) = 0
            -- axi_in.rlast='1' should coincide with S_burst_remaining=0 so this "or R_length_.."
            -- should be the same as R_length_remaining = 0
            then
              -- end of burst and end of length
              if R_header_mode='1' then
                -- length remaining = 0
                -- if in header mode
                -- header will be complete in the next cycle
                -- (last header element is "next" pointer. it will be available in next cycle)
                -- from previous cycles, we have enough header info to prepare jump to the data
                R_ram_addr <= R_header(C_header_data_addr)(29 downto 2);
                R_length_remaining <= R_header(C_header_data_length)(C_vaddr_bits-1 downto 0);
                R_header_mode <= '0';
                -- test load/store mode and jump to adequate next state read/write
                if R_store_mode='1' then
                  R_bram_addr <= R_bram_addr + 1; -- early prepare bram read address for next data
                  R_state <= C_state_wait_write_data_ack;
                else -- R_store_mode='0'
                  R_state <= C_state_wait_ready_to_read;
                end if;
              else -- R_header_mode='0'
                -- length remaining = 0
                -- not in header mode
                -- check if we have next header
                if R_header(C_header_next) = 0 then
                  -- no next header (null pointer)
                  -- return to idle state
                  -- so we are at last element. in next cycle, vector will be
                  -- fully written
                  R_header_mode <= '1';
                  R_done <= '1';
                  R_next <= '1'; -- this requests one more to help load last element
                  R_state <= C_state_idle;
                else -- R_header(C_header_next) > 0
                  -- non-zero pointer: we have next header to read
                  -- this is vector multi-part continuation
                  R_ram_addr <= R_header(C_header_next)(29 downto 2);
                  R_length_remaining <= conv_std_logic_vector(C_header_max-1, C_vaddr_bits);
                  R_header_mode <= '1';
                  R_state <= C_state_wait_ready_to_read;
                end if;
              end if;
            else -- R_length_remaining > 0
              -- last in the burst, length remaining > 0
              -- new read request for the new burst
              R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue reading in the next bursts block
              R_length_remaining <= R_length_remaining - 1;
              R_state <= C_state_wait_ready_to_read;
            end if; -- if length remaining = 0
          else -- axi_in.rlast='0'
            -- not the last in the burst, must continue
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue reading in the next bursts block
            R_length_remaining <= R_length_remaining - 1;
            -- continue with bursting data in the same state
          end if; -- end R_burst_remaining
        end if; -- end axi_in.rvalid='1'

      when C_state_wait_write_data_ack =>
        if axi_in.awready='1' and R_wvalid='0' then
          R_awvalid <= '1'; -- address valid: single clock pulse (reset to '0' in next clock)
          R_wvalid <= '1'; -- data valid: activate data valid and keep holding it
        end if;
        if axi_in.wready='1' and R_wvalid='1' then
          R_wdata_fifo_index_out <= R_wdata_fifo_index_out+1;
          -- end of write cycle
          if S_burst_remaining = 0
          then
            if R_bram_addr(C_vaddr_bits) = '1' -- safety measure
            or R_length_remaining(C_vaddr_bits-1 downto C_burst_max_bits) = 0
            -- with S_burst_remaining = 0 this "or R_length_..."
            -- should be the same as R_length_remaining = 0
            then
              R_wvalid <= '0';
              if R_header(C_header_next) = 0 then
                -- no next header (null pointer)
                -- so we are at last element. in next cycle, vector will be
                -- fully written
                R_store_mode <= '0';
                R_header_mode <= '1';
                R_done <= '1';
                R_next <= '1'; -- this requests one more to fix not written last element
                -- return to idle state
                R_state <= C_state_idle;
              else -- R_header(C_header_next) > 0
                -- non-zero pointer: we have next header to read
                -- this is vector multi-part continuation
                R_ram_addr <= R_header(C_header_next)(29 downto 2);
                R_length_remaining <= conv_std_logic_vector(C_header_max-1, C_vaddr_bits);
                R_header_mode <= '1';
                -- jump to read state in header mode
                R_state <= C_state_wait_ready_to_read;
              end if;
            else -- S_burst_remaining = 0 and R_length_remaining > 0
              R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue writing in the next bursts block
              R_bram_addr <= R_bram_addr+1;
              R_length_remaining <= R_length_remaining - 1;
              if axi_in.awready='1' then
                -- handle immediately acknowledgeable awready (burst back-to-back)
                -- by not leaving this state at all, just strobe the awvalid
                R_awvalid <= '1';
              else
                R_wvalid <= '0';
              end if;
            end if;
          else -- S_burst_remaining > 0
            R_bram_addr <= R_bram_addr + 1; -- increment source address
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue writing in the next bursts block
            R_length_remaining <= R_length_remaining - 1;
            -- continue with bursting data in the same state
          end if; -- end else R_burst_remaining = 0
        end if; -- end axi_in.wready='1'
      end case;
    end if; -- rising edge
  end process;

  -- the wdata fifo
  S_wdata_fifo_index_diff <= R_wdata_fifo_index_in - R_wdata_fifo_index_out;
  S_need_refill <= '1' when S_wdata_fifo_index_diff < 2**C_wdata_fifo_bits-2 else '0'; -- -2 as standoff to accept data remaining in bram_rdata pipeline
  process(clk)
  begin
    if rising_edge(clk) then
      if R_wdata_fifo_reset='1' then
        R_wdata_fifo_index_in <= R_wdata_fifo_index_out;
        R_bram_rdata_ready <= '0';
      else
        R_bram_rdata_ready <= S_need_refill; -- one clock delay matches bram_rdata latency
        if R_bram_rdata_ready='1' then
          R_wdata_fifo(conv_integer(R_wdata_fifo_index_in)) <= bram_rdata;
          R_wdata_fifo_index_in <= R_wdata_fifo_index_in+1;
        end if;
      end if;
    end if;
  end process;

  -- from current length remaining, calculate the burst
  S_burst_remaining <= R_length_remaining(C_burst_max_bits-1 downto 0);

  -- read from RAM signaling
  axi_out.arid    <= "0";    -- not used
  axi_out.arlen   <= C_burst_bits_pad & S_burst_remaining;  -- burst length, 0x00 means 1 word, 0x01 means 2 words, etc.
  axi_out.arsize  <= "010";  -- 4 bytes = 32 bits
  axi_out.arburst <= "01";   -- burst type INCR - Incrementing address
  axi_out.arlock  <= '0';    -- Exclusive access not supported
  axi_out.arcache <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
  axi_out.arprot  <= "000";  -- Xilinx IP generally ignores
  axi_out.arqos   <= "0000"; -- QOS not supported
  axi_out.rready  <= '1';    -- always ready to read data
  axi_out.arvalid <= R_arvalid; -- read request start (address valid)
  axi_out.araddr  <= "00" & R_ram_addr & "00"; -- address padded and 4-byte aligned
  S_bram_wdata <= axi_in.rdata;
  S_bram_we <= S_read_next;

  -- write to RAM signaling
  axi_out.awid    <= "0";    -- not used
  axi_out.awlen   <= C_burst_bits_pad & S_burst_remaining;
  axi_out.awsize  <= "010";  -- 4 bytes = 32 bits
  axi_out.awburst <= "01";   -- burst type INCR - Incrementing address
  axi_out.awlock  <= '0';    -- Exclusive access not supported
  axi_out.awcache <= "0011"; -- Xilinx IP generally ignores
  axi_out.awprot  <= "000";  -- Xilinx IP generally ignores
  axi_out.awqos   <= "0000"; -- QOS not supported
  axi_out.bready  <= '1';    -- always ready to read write response (response otherwise ignored)
  axi_out.wstrb   <= "1111"; -- byte select 4-bit vector
  axi_out.awvalid <= R_awvalid; -- write request start (address valid)
  axi_out.awaddr  <= "00" & R_ram_addr & "00"; -- address padded and 4-byte aligned
  axi_out.wvalid  <= R_wvalid; -- write data valid
  axi_out.wlast   <= R_wvalid when S_burst_remaining = 0 else '0';
  axi_out.wdata   <= R_wdata_fifo(conv_integer(R_wdata_fifo_index_out)); -- write data
  S_read_next <= '1' when axi_in.rvalid='1' and R_store_mode='0' and R_header_mode='0' and R_state=C_state_wait_read_data_ack  else '0';
  S_write_next <= S_need_refill and R_store_mode;
  S_bram_next <= S_read_next or S_write_next or R_next; -- R_next is fix, helps for 1st data and last data
  bram_addr <= R_bram_addr;
  done <= R_done and not R_next;

  bram_wdata <= S_bram_wdata;
  bram_next <= S_bram_next;
  bram_we <= S_bram_we;

end;

-- TODO
-- [ ] vector store may be signaled as done too early
--     by bram_addr MSB bit while axi is still
--     transferring last word.
-- [ ] R_done could be set 1 cycle earlier?
-- [x] first burst maybe shorter, use bit subset of the remaining
-- [x] linked list support
-- [x] burst length power of 2, both read/write bursts equal
-- [x] supports boundary burst conditions
-- [x] only R_length_remaining is counted down, the burst length can be directly
--     derived as bit subset of length
