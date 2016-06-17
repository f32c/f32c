-- (c)EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.axi_pack.all;

-- Vector I/O DMA module for AXI bus

-- at rising edge of the strobe
-- following signals are latched: addr, wr
-- store_data must remain on the bus until next_data becomes 1
-- after 1 in next cycle store_data must change into the next value

-- the RAM is dereferenced and when next data are needed,
-- the request_next is set to '1'

-- vector.vhd module must in next clock cycle respond to next_data signal
-- either by providing next data to store
-- or consuming provided load data storing them into vector

entity axi_vector_dma is
  generic
  (
    C_burst_max: integer := 64
  );
  port
  (
    clk: in std_logic;
--    addr: in std_logic_vector(29 downto 2) := (others => '0'); -- vector struct address
--    strobe: in std_logic := '0'; -- hold strobe while data available, release to cancel I/O operation
--    store: in std_logic := '0'; -- '1' write to RAM (store mode), '0' read from RAM (load mode)
--    next_data: out std_logic; -- at '1' upstream module must provide next store data, or be ready to accept next load data
--    store_data: in std_logic_vector(31 downto 0) := (others => '0'); -- vector to RAM
--    load_data: out std_logic_vector(31 downto 0); -- RAM to vector
    axi_in: in T_axi_miso; -- axi bus interface
    axi_out: out T_axi_mosi
  );
end axi_vector_dma;

architecture arch of axi_vector_dma is
  signal R_a: std_logic_vector(15 downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      R_a <= R_a + 1;
    end if;
    axi_out.araddr <= (others => '0');
  end process;
end;
