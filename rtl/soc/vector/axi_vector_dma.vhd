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

entity axi_vector_dma is
  generic
  (
    C_vaddr_bits: integer := 11; -- bits that represent max vector length e.g. 11 -> 2^11 -> 2048 elements
    C_vdata_bits: integer := 32;
    C_burst_read_max: integer := 1;
    C_burst_write_max: integer := 1
  );
  port
  (
    clk: in std_logic;

    -- vector processor control
    addr: in std_logic_vector(29 downto 2) := (others => '0'); -- vector struct address in RAM
    request: in std_logic := '0'; -- pulse '1' during 1 clock cycle to start
    store_mode: in std_logic := '0'; -- '1' write to RAM (vector store mode), '0' read from RAM (vector load mode)
    done: out std_logic := '0';

    -- bram interface
    bram_we: out std_logic := '0'; -- bram write enable
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
  constant C_state_wait_read_addr_ack: integer := 1;
  constant C_state_wait_read_data_ack: integer := 2;
  constant C_state_wait_write_addr_ack: integer := 3;
  constant C_state_wait_write_data_ack: integer := 4;
  constant C_state_max: integer := C_state_wait_write_data_ack;

  signal R_store_mode: std_logic;
  signal R_ram_addr: std_logic_vector(29 downto 2);
  signal R_bram_addr: std_logic_vector(C_vaddr_bits downto 0) := (others => '1'); -- external counter for RAM load/store
  signal R_state: integer range 0 to C_state_max := C_state_idle;
  signal R_done: std_logic := '1';

  -- axi registered signaling
  signal R_arvalid: std_logic := '0'; -- read request, valid address
  signal R_awvalid: std_logic := '0'; -- write request, valid address
  signal R_wvalid: std_logic := '0'; -- write, valid data
  signal R_wdata: std_logic_vector(C_vdata_bits-1 downto 0);
  constant C_burst_max_bits: integer := 6; -- number of bits to describe burst max
  constant C_burst_bits_pad: std_logic_vector(7-C_burst_max_bits downto 0) := (others => '0');
  signal R_burst_remaining: std_logic_vector(C_burst_max_bits-1 downto 0) := (others => '0'); -- 1 less than actual value
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if R_state = C_state_idle then
        if request='1' then
          R_ram_addr <= addr;
          R_bram_addr <= (others => '0');
          R_store_mode <= store_mode;
          R_done <= '0';
          if store_mode='1' then
            R_awvalid <= '1'; -- write request starts with address
            R_burst_remaining <= conv_std_logic_vector(C_burst_write_max-1, C_burst_max_bits);
            R_state <= C_state_wait_write_addr_ack;
          else
            R_arvalid <= '1'; -- read request starts with address
            R_burst_remaining <= conv_std_logic_vector(C_burst_read_max-1, C_burst_max_bits);
            R_state <= C_state_wait_read_addr_ack;
          end if;
        end if;
      end if;

      if R_state = C_state_wait_read_addr_ack then
        if axi_in.arready='1' then
          R_arvalid <= '0'; -- de-activate address request
          R_state <= C_state_wait_read_data_ack;
        end if;
      end if; -- end phase wait read addr ack

      if R_state = C_state_wait_read_data_ack then
        if axi_in.rvalid='1' then
          -- end of write cycle
          if R_bram_addr(C_vaddr_bits)='1' then
            -- we should normally never get here
            -- but if we do, go to idle
            R_done <= '1';
            R_state <= C_state_idle;
          else
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue reading in the next bursts block
            R_bram_addr <= R_bram_addr + 1; -- increment source address
            -- if R_burst_remaining = 0 or axi_in.rlast='1' then
            if axi_in.rlast='1' then
              if conv_integer(not R_bram_addr(C_vaddr_bits-1 downto 0)) = 0
                -- or conv_integer(not R_bram_addr(C_vaddr_bits-2 downto 1)) = 0 -- debug, early terminate
                then
                -- if all vaddr bits of R_bram_addr are '1'
                -- so we are at last element and in next cycle vector will be
                -- fully written, return to idle state
                R_done <= '1';
                R_state <= C_state_idle;
              else
                R_arvalid <= '1'; -- write request starts with address
                R_burst_remaining <= conv_std_logic_vector(C_burst_read_max-1, C_burst_max_bits);
                R_state <= C_state_wait_read_addr_ack;
              end if;
            else
              R_burst_remaining <= R_burst_remaining - 1;
              -- continue with bursting data in the same state
            end if; -- end R_burst_remaining
          end if; -- end else R_bram_addr(C_vaddr_bits)='1'
        end if; -- end axi_in.rvalid='1'
      end if; -- end phase wait read data ack

      if R_state = C_state_wait_write_addr_ack then
        if axi_in.awready = '1' then
          R_awvalid <= '0'; -- de-activate address request
          R_wvalid <= '1'; -- activate data valid, try if this could be activated on earlier phase
          R_state <= C_state_wait_write_data_ack;
          R_wdata <= bram_rdata;
          R_bram_addr <= R_bram_addr+1; -- early prepare bram read address for next data
        end if;
      end if; -- end phase wait write addr ack

      if R_state = C_state_wait_write_data_ack then
        if axi_in.wready='1' then
            -- end of write cycle
            R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue writing in the next burst
            if R_burst_remaining = 0 then
              R_wvalid <= '0';
              if R_bram_addr(C_vaddr_bits) = '1' then
                -- we are at last element and in next cycle vector will be
                -- fully written, return to idle state
                R_done <= '1';
                R_state <= C_state_idle;
              else
                R_awvalid <= '1'; -- write request starts with address
                --R_ram_addr <= R_ram_addr + 1;
                R_burst_remaining <= conv_std_logic_vector(C_burst_write_max-1, C_burst_max_bits);
                R_state <= C_state_wait_write_addr_ack;
              end if;
            else
              R_ram_addr <= R_ram_addr + 1; -- destination address will be ready to continue writing in the next bursts block
              R_wdata <= bram_rdata;
              R_bram_addr <= R_bram_addr + 1; -- increment source address
              R_burst_remaining <= R_burst_remaining - 1;
              -- continue with bursting data in the same state
            end if; -- end else R_burst_remaining = 0
        end if; -- end axi_in.wready='1'
      end if; -- end phase wait write data ack
    end if; -- rising edge
  end process;

  -- read from RAM signaling
  axi_out.arid    <= "0";    -- not used
  axi_out.arlen   <= C_burst_bits_pad & R_burst_remaining;  -- burst length, 0x00 means 1 word, 0x01 means 2 words, etc.
  axi_out.arsize  <= "010";  -- 32 bits, resp. 4 bytes
  axi_out.arburst <= "01";   -- burst type INCR - Incrementing address
  axi_out.arlock  <= '0';    -- Exclusive access not supported
  axi_out.arcache <= "0011"; -- Xilinx IP generally ignores, but 'modifiable'[1] bit required?
  axi_out.arprot  <= "000";  -- Xilinx IP generally ignores
  axi_out.arqos   <= "0000"; -- QOS not supported
  axi_out.rready  <= '1';    -- always ready to read data
  axi_out.arvalid <= R_arvalid; -- read request start (address valid)
  axi_out.araddr  <= "00" & R_ram_addr & "00"; -- address padded and 4-byte aligned
  bram_wdata <= axi_in.rdata;
  --bram_we <= axi_in.rvalid;
  bram_we <= axi_in.rvalid and not R_store_mode; -- prevent accidental write by rvalid in store mode

  -- write to RAM signaling
  axi_out.awid    <= "0";    -- not used
  axi_out.awlen   <= C_burst_bits_pad & R_burst_remaining;
  axi_out.awsize  <= "010";  -- 32 bits, resp. 4 bytes
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
  axi_out.wlast   <= R_wvalid when R_burst_remaining = 0 else '0';
  axi_out.wdata   <= R_wdata; -- write data
  --axi_out.wdata   <= x"00000" & R_bram_addr; -- debug
  bram_addr <= R_bram_addr;
  --done <= R_bram_addr(C_vaddr_bits); -- MSB bit of bram addr counter means DONE
  done <= R_done;

end;

-- TODO
-- [ ] support boundary burst conditions
-- [ ] axi is probably not well initialized, (reset handling missing?)
--     sometimes after first write burst vector axi port stops working
--     other axi ports (cpu, video) keep working
--     if this happens, reload the bitstream and try again
-- [ ] vector store may be signaled as done too early
--     by bram_addr MSB bit while axi is still
--     transferring last word.
-- [ ] first burst (or the last) must be allowed to be shorter
-- [ ] linked list support
-- [ ] R_done could be set 1 cycle earlier? as MSB in R_bram_addr(C_vaddr_bits)
-- [ ] input value of vector length for store mode
