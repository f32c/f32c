-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- Vector I/O DMA module for f32c bus

-- once activated, this unit will become
-- master to both bram and to external RAM
-- (f32c RAM in this case)

-- using a given ram address, it will
-- load or store vectors to/from ram
-- determine the end of
-- data and provide signal bit when done

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

entity f32c_vector_dma is
  generic
  (
    C_vaddr_bits: integer := 11; -- bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
    C_vdata_bits: integer := 32;
    C_burst_max_bits: integer := 3 -- number of bits to describe burst max
  );
  port
  (
    clk: in std_logic;

    -- vector processor control
    addr: in std_logic_vector(29 downto 2) := (others => '0'); -- vector struct address in RAM
    length: in std_logic_vector(C_vaddr_bits-1 downto 0) := (others => '1'); -- vector length 1 less then actual value (0 -> length 1)
    request: in std_logic := '0'; -- pulse '1' during 1 clock cycle to start
    store_mode: in std_logic := '0'; -- '1' write to RAM (vector store mode), '0' read from RAM (vector load mode)
    done: out std_logic := '0';

    -- bram interface
    bram_we: out std_logic := '0'; -- bram write enable
    bram_next: out std_logic := '0'; -- signal to increment vector index (instead of passing bram_addr)
    bram_addr: out std_logic_vector(C_vaddr_bits downto 0);
    bram_wdata: out std_logic_vector(C_vdata_bits-1 downto 0);
    bram_rdata: in std_logic_vector(C_vdata_bits-1 downto 0);

    -- f32c ram interface
    addr_strobe: out std_logic; -- if using cache discard this strobe, and give strobe='1' to cache
    addr_out: out std_logic_vector(29 downto 2);
    -- suggest burst: number of 32-bit words requrested, value 0 means 1 data, 1 means 2 data etc.
    suggest_burst: out std_logic_vector(C_burst_max_bits-1 downto 0) := (others => '0');
    suggest_cache: out std_logic; -- (currently unused), to cache only data (without headers)
    data_ready: in std_logic; -- RAM indicates data are ready for consuming
    data_write: out std_logic; -- '1' write cycle, '0' read cycle
    data_in: in std_logic_vector(31 downto 0);
    data_out: out std_logic_vector(31 downto 0)
  );
end f32c_vector_dma;

architecture arch of f32c_vector_dma is
  -- State machine constants
  constant C_state_idle: integer := 0;
  constant C_state_wait_read_data_ack: integer := 1;
  constant C_state_wait_write_data_ack: integer := 2;
  constant C_state_max: integer := C_state_wait_write_data_ack;

  signal R_store_mode: std_logic;
  signal R_ram_addr: std_logic_vector(29 downto 2);
  signal R_bram_addr: std_logic_vector(C_vaddr_bits downto 0) := (others => '1'); -- external counter for RAM load/store
  signal R_state: integer range 0 to C_state_max := C_state_idle;
  signal R_done: std_logic := '1';
  signal R_next: std_logic := '0'; -- request next data
  signal S_remaining: std_logic;

  -- f32c bus registers
  signal R_addr_strobe: std_logic := '0';
  signal R_data_write: std_logic := '0';

  -- vector struct handling
  constant C_header_data_length: integer := 2; -- loaded first from ram+0 -- neeed early, can't be loaded last last
  constant C_header_data_addr: integer := 1; -- loaded second from ram+1 -- needer early, can't be loaded last
  constant C_header_next: integer := 0; -- loaded last from ram+2 - needed at end of data, can be loaded last
  constant C_header_max: integer := 3; -- number of 32-bit words in the header
  constant C_header_addr_bits: integer := 2; -- number of bits to describe the header must be C_header_addr_bits <= C_vaddr_bits
  type T_header is array (0 to C_header_max-1) of std_logic_vector(31 downto 0);
  signal R_header: T_header;
  signal R_header_mode: std_logic; -- '1' when we read the header, otherwise the data
  signal R_length_remaining: std_logic_vector(C_vaddr_bits-1 downto 0) := (others => '0'); -- vector length 1 less then actual value (0 -> length 1)
  signal S_burst_remaining: std_logic_vector(C_burst_max_bits-1 downto 0) := (others => '0'); -- 1 less than actual value
  -- the bram_rdata fifo
  constant C_wdata_fifo_bits: integer := 2; -- 2 bits fifo length 2**2 = 4 elements
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
          R_addr_strobe <= '1';
          R_state <= C_state_wait_read_data_ack;
        end if;

      when C_state_wait_read_data_ack =>
        R_wdata_fifo_reset <= '0';
        if data_ready='1' then
          if R_bram_addr(C_vaddr_bits) = '1' -- safety measure
          or R_length_remaining = 0
          then
            -- end of length
            if R_header_mode='1' then
              -- length remaining = 0
              -- if in header mode
              -- header will be complete in the next cycle
              -- (last header element is "next" pointer. it will be available in next cycle)
              -- from previous cycles, we have enough header info to prepare jump to the data
              --R_header(conv_integer(R_length_remaining(C_header_addr_bits-1 downto 0))) <= data_in;
              R_header(C_header_next) <= data_in; -- C_header_next = 0
              R_ram_addr <= R_header(C_header_data_addr)(29 downto 2);
              R_length_remaining <= R_header(C_header_data_length)(C_vaddr_bits-1 downto 0);
              R_header_mode <= '0';
              -- test load/store mode and jump to adequate next state read/write
              if R_store_mode='1' then
                R_bram_addr <= R_bram_addr + 1; -- early prepare bram read address for next data
                R_data_write <= '1';
                R_state <= C_state_wait_write_data_ack;
              else -- R_store_mode='0'
                -- do not increment R_bram_addr, it must stay at 0
                -- when we switch from header mode to
                -- loading register with data read from RAM
                R_state <= C_state_wait_read_data_ack;
              end if;
            else -- R_header_mode='0'
              -- length remaining = 0
              -- not in header mode
              -- check if we have next header
              R_bram_addr <= R_bram_addr + 1; -- increment source address
              if R_header(C_header_next) = 0 then
                -- no next header (null pointer)
                -- return to idle state
                -- so we are at last element. in next cycle, vector will be
                -- fully written
                R_addr_strobe <= '0';
                R_done <= '1';
                R_header_mode <= '1';
                R_next <= '1'; -- help vector to finish loading last element
                R_state <= C_state_idle;
              else -- R_header(C_header_next) > 0
                -- non-zero pointer: we have next header to read
                -- this is vector multi-part continuation
                R_ram_addr <= R_header(C_header_next)(29 downto 2);
                R_length_remaining <= conv_std_logic_vector(C_header_max-1, C_vaddr_bits);
                R_header_mode <= '1';
              end if;
            end if; -- end R_header_mode
          else -- R_length_remaining > 0
            if R_header_mode='1' then
              -- header will be indexed downwards 2,1,0 using decrementing R_length_remaining
              R_header(conv_integer(R_length_remaining(C_header_addr_bits-1 downto 0))) <= data_in;
            else -- R_header_mode='0'
              R_bram_addr <= R_bram_addr + 1; -- increment source address
            end if;
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue reading in the next bursts block
            R_length_remaining <= R_length_remaining - 1;
          end if; -- if length remaining = 0
        end if; -- end data_ready='1'

      when C_state_wait_write_data_ack =>
        if data_ready='1' then
          R_wdata_fifo_index_out <= R_wdata_fifo_index_out+1; -- advance to next data in FIFO
          -- end of write cycle
          if R_bram_addr(C_vaddr_bits) = '1' -- safety measure
          or R_length_remaining = 0
          then
            R_data_write <= '0';
            R_header_mode <= '1';
            if R_header(C_header_next) = 0 then
              -- no next header (null pointer)
              -- so we are at last element. in next cycle, vector will be
              -- fully written
              R_addr_strobe <= '0';
              R_store_mode <= '0';
              R_done <= '1';
              R_next <= '1'; -- this requests one more to fix not written last element
              -- return to idle state
              R_state <= C_state_idle;
            else -- R_header(C_header_next) > 0
              -- non-zero pointer: we have next header to read
              -- this is vector multi-part continuation
              R_ram_addr <= R_header(C_header_next)(29 downto 2);
              R_length_remaining <= conv_std_logic_vector(C_header_max-1, C_vaddr_bits);
              -- jump to read state in header mode
              R_state <= C_state_wait_read_data_ack;
            end if;
          else -- R_length_remaining > 0
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue writing in the next bursts block
            R_length_remaining <= R_length_remaining - 1;
            R_bram_addr <= R_bram_addr + 1; -- increment source address
          end if; -- end R_length_remaining
        end if; -- end data_ready='1'
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

  -- f32c burst remaining
  suggest_burst <= S_burst_remaining;
  addr_out <= R_ram_addr;
  addr_strobe <= R_addr_strobe;
  data_write <= R_data_write;
  data_out <= R_wdata_fifo(conv_integer(R_wdata_fifo_index_out)); -- store mode, write data
  bram_wdata <= data_in;
  bram_we <= data_ready and (not R_store_mode) and (not R_header_mode); -- prevent write during header read and stray rvalid in store mode
  -- bram_next is hacky and experimentally determined
  -- combinatorial logic that makes vector index correctly
  -- advance so vector store can work properly. Difficult
  -- to debug, don't touch until you know what you are doing :)
  S_read_next <= data_ready and (not R_store_mode) and (not R_header_mode);
  S_write_next <= S_need_refill and R_store_mode; -- fifo must start fetching data during header mode
  bram_next <= S_read_next or S_write_next or R_next; -- R_next is workaround for last element during vector load
  bram_addr <= R_bram_addr;
  done <= R_done and not R_next;
  S_remaining <= '0' when R_length_remaining = 0 else '1';
end;

-- TODO
-- [ ] vector store may be signaled as done too early
--     by bram_addr MSB bit while bus is still
--     transferring last word.
-- [ ] R_done could be set 1 cycle earlier? as MSB in R_bram_addr(C_vaddr_bits)
-- [x] first burst maybe shorter, use bit subset of the remaining
-- [*] linked list support
-- [*] burst length power of 2, both read/write bursts equal
-- [*] supports boundary burst conditions
-- [*] only R_length_remaining counted down, the burst length directly
--     derived as bit subset of length
