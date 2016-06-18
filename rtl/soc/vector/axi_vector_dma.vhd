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
    C_burst_max: integer := 64
  );
  port
  (
    clk: in std_logic;

    -- vector processor control
    addr: in std_logic_vector(29 downto 2) := (others => '0'); -- vector struct address in RAM
    request: in std_logic := '0'; -- hold request while data available, release to cancel I/O operation
    store_mode: in std_logic := '0'; -- '1' write to RAM (vector store mode), '0' read from RAM (vector load mode)
    done: out std_logic := '0';

    -- bram interface
    bram_we: out std_logic := '0'; -- bram write enable
    bram_addr: out std_logic_vector(C_vaddr_bits-1 downto 0);
    bram_wdata: out std_logic_vector(C_vdata_bits-1 downto 0);
    bram_rdata: in std_logic_vector(C_vdata_bits-1 downto 0);

    -- AXI ram interface
    axi_in: in T_axi_miso;
    axi_out: out T_axi_mosi
  );
end axi_vector_dma;

architecture arch of axi_vector_dma is
  signal R_store_mode: std_logic;
  signal R_addr: std_logic_vector(29 downto 2);
  signal R_bram_addr: std_logic_vector(C_vaddr_bits downto 0) := (others => '1'); -- external counter for RAM load/store
  signal R_state: integer range 0 to 1 := 0;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if R_state=0 then
        if request='1' then
          R_addr <= addr;
          R_store_mode <= store_mode;
          R_bram_addr <= (others => '0');
          R_state <= 1;
        end if;
      end if;
      if R_state=1 then
        if R_bram_addr(C_vaddr_bits)='1' then
          R_state <= 0;
        else
          R_bram_addr <= R_bram_addr + 1;
        end if;
      end if;
    end if;
  end process;
  axi_out.araddr <= "00" & R_addr & "00";
  bram_wdata <= axi_in.rdata;

  axi_out.awaddr <= "00" & R_addr & "00";
  axi_out.wdata <= bram_rdata;
  
  bram_addr <= R_bram_addr(C_vaddr_bits-1 downto 0);
  done <= R_bram_addr(C_vaddr_bits); -- MSB bit of bram addr counter means DONE
end;
