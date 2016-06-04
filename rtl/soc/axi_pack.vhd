-- (c) EMARD
-- License=BSD

library ieee;
use ieee.std_logic_1164.all;

package axi_pack is

--
-- AXI bus I/O types
--

-- Inputs: Module <- AXI
-- direction from AXI bus to module, from bus master point of view.
-- slave has i/o reversed.
type T_axi_miso is
record
  -- write addr
  awready        : std_logic; -- not used
  wready         : std_logic; -- not used
  -- write response
  bid            : std_logic_vector(0 downto 0); -- not used
  bresp          : std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
  bvalid         : std_logic;                    -- not used
  arready        : std_logic;
  -- read data
  rid            : std_logic_vector(0 downto 0); -- not used
  rdata          : std_logic_vector(31 downto 0);
  rresp          : std_logic_vector(1 downto 0); -- not used, (1): error?, (0): data transfer?
  rlast          : std_logic;
  rvalid         : std_logic;
end record;

-- Outputs: Module -> AXI
-- direction from module to AXI bus, from bus master point of view.
-- slave has i/o reversed
type T_axi_mosi is
record
  -- write addr
  awid           : std_logic_vector(0 downto 0);
  awaddr         : std_logic_vector(31 downto 0);
  awlen          : std_logic_vector(7 downto 0);
  awsize         : std_logic_vector(2 downto 0);
  awburst        : std_logic_vector(1 downto 0);
  awlock         : std_logic;
  awcache        : std_logic_vector(3 downto 0);
  awprot         : std_logic_vector(2 downto 0);
  awqos          : std_logic_vector(3 downto 0);
  awvalid        : std_logic;
  -- write data
  wdata          : std_logic_vector(31 downto 0);
  wstrb          : std_logic_vector(3 downto 0);
  wlast          : std_logic;
  wvalid         : std_logic;
  -- write response
  bready         : std_logic;
  -- read addr
  arid           : std_logic_vector(0 downto 0);
  araddr         : std_logic_vector(31 downto 0);
  arlen          : std_logic_vector(7 downto 0);
  arsize         : std_logic_vector(2 downto 0);
  arburst        : std_logic_vector(1 downto 0);
  arlock         : std_logic;
  arcache        : std_logic_vector(3 downto 0);
  arprot         : std_logic_vector(2 downto 0);
  arqos          : std_logic_vector(3 downto 0);
  arvalid        : std_logic;
  -- read data
  rready         : std_logic;
end record;

end;
