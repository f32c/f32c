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
-- this is 32-bit axi, to be renamed T_axi32_miso
type T_axi_miso is
record
  -- write addr
  awready        : std_logic; -- not used
  wready         : std_logic; -- not used
  -- write response
  bid            : std_logic_vector(0 downto 0); -- not used
  bresp          : std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
  bvalid         : std_logic;                    -- not used
  -- read data
  rid            : std_logic_vector(0 downto 0); -- not used
  rdata          : std_logic_vector(31 downto 0);
  rresp          : std_logic_vector(1 downto 0); -- not used, (1): error?, (0): data transfer?
  rlast          : std_logic;
  rvalid         : std_logic;
  arready        : std_logic;
end record;

-- Zero-intializer for the inactive default
constant C_axi_miso_0: T_axi_miso :=
(
  awready => '0',
  wready => '0',
  bid => (others => '0'),
  bresp => (others => '0'),
  bvalid => '0',
  rid => (others => '0'),
  rdata => (others => '0'),
  rresp => (others => '0'),
  rlast => '0',
  rvalid => '0',
  arready => '0'
);

-- Outputs: Module -> AXI
-- direction from module to AXI bus, from bus master point of view.
-- slave has i/o reversed
-- this is 32-bit axi, to be renamed T_axi32_mosi
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

-- Zero-intializer for the inactive default
constant C_axi_mosi_0: T_axi_mosi :=
(
  awid => (others => '0'),
  awaddr => (others => '0'),
  awlen => (others => '0'),
  awsize => (others => '0'),
  awburst => (others => '0'),
  awlock => '0',
  awcache => (others => '0'),
  awprot => (others => '0'),
  awqos => (others => '0'),
  awvalid => '0',
  -- write data
  wdata => (others => '0'),
  wstrb => (others => '0'),
  wlast => '0',
  wvalid => '0',
  -- write response
  bready => '0',
  -- read addr
  arid => (others => '0'),
  araddr => (others => '0'),
  arlen => (others => '0'),
  arsize => (others => '0'),
  arburst => (others => '0'),
  arlock => '0',
  arcache => (others => '0'),
  arprot => (others => '0'),
  arqos => (others => '0'),
  arvalid => '0',
  -- read data
  rready => '0'
);


-- Inputs: Module <- AXI
-- direction from AXI bus to module, from bus master point of view.
-- slave has i/o reversed.
type T_axi64_miso is
record
  -- write addr
  awready        : std_logic; -- not used
  wready         : std_logic; -- not used
  -- write response
  bid            : std_logic_vector(3 downto 0); -- not used
  bresp          : std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
  bvalid         : std_logic;                    -- not used
  -- read data
  rid            : std_logic_vector(3 downto 0); -- not used
  rdata          : std_logic_vector(63 downto 0);
  rresp          : std_logic_vector(1 downto 0); -- not used, (1): error?, (0): data transfer?
  rlast          : std_logic;
  rvalid         : std_logic;
  arready        : std_logic;
end record;


-- Outputs: Module -> AXI
-- direction from module to AXI bus, from bus master point of view.
-- slave has i/o reversed
-- this is 32-bit axi
type T_axi64_mosi is
record
  -- write addr
  awid           : std_logic_vector(3 downto 0);
  awaddr         : std_logic_vector(31 downto 0);
  awlen          : std_logic_vector(7 downto 0);
  awsize         : std_logic_vector(2 downto 0);
  awburst        : std_logic_vector(1 downto 0);
  awlock         : std_logic;
  awcache        : std_logic_vector(3 downto 0); -- enable write cache on ACP
  awprot         : std_logic_vector(2 downto 0);
  awqos          : std_logic_vector(3 downto 0);
  awvalid        : std_logic;
  -- write data
  wdata          : std_logic_vector(63 downto 0);
  wstrb          : std_logic_vector(7 downto 0); -- byte select
  wlast          : std_logic;
  wvalid         : std_logic;
  -- write response
  bready         : std_logic;
  -- read addr
  arid           : std_logic_vector(3 downto 0);
  araddr         : std_logic_vector(31 downto 0);
  arlen          : std_logic_vector(7 downto 0);
  arsize         : std_logic_vector(2 downto 0);
  arburst        : std_logic_vector(1 downto 0);
  arlock         : std_logic;
  arcache        : std_logic_vector(3 downto 0); -- enable read cache on ACP
  arprot         : std_logic_vector(2 downto 0);
  arqos          : std_logic_vector(3 downto 0);
  arvalid        : std_logic;
  -- read data
  rready         : std_logic;
end record;


-- Inputs: Module <- AXI
-- direction from AXI bus to module, from bus master point of view.
-- slave has i/o reversed.
type T_axi128_miso is
record
  -- write addr
  awready        : std_logic; -- not used
  wready         : std_logic; -- not used
  -- write response
  bid            : std_logic_vector(0 downto 0); -- not used
  bresp          : std_logic_vector(1 downto 0); -- not used (0: ok, 3: addr unknown)
  bvalid         : std_logic;                    -- not used
  -- read data
  rid            : std_logic_vector(0 downto 0); -- not used
  rdata          : std_logic_vector(127 downto 0);
  rresp          : std_logic_vector(1 downto 0); -- not used, (1): error?, (0): data transfer?
  rlast          : std_logic;
  rvalid         : std_logic;
  arready        : std_logic;
end record;


-- Outputs: Module -> AXI
-- direction from module to AXI bus, from bus master point of view.
-- slave has i/o reversed
-- this is 32-bit axi
type T_axi128_mosi is
record
  -- write addr
  awid           : std_logic_vector(0 downto 0);
  awaddr         : std_logic_vector(31 downto 0);
  awlen          : std_logic_vector(7 downto 0);
  awsize         : std_logic_vector(2 downto 0);
  awburst        : std_logic_vector(1 downto 0);
  awlock         : std_logic;
  awcache        : std_logic_vector(3 downto 0); -- enable write cache on ACP
  awprot         : std_logic_vector(2 downto 0);
  awqos          : std_logic_vector(3 downto 0);
  awvalid        : std_logic;
  -- write data
  wdata          : std_logic_vector(127 downto 0);
  wstrb          : std_logic_vector(15 downto 0); -- byte select
  wlast          : std_logic;
  wvalid         : std_logic;
  -- write response
  bready         : std_logic;
  -- read addr
  arid           : std_logic_vector(0 downto 0);
  araddr         : std_logic_vector(127 downto 0);
  arlen          : std_logic_vector(7 downto 0);
  arsize         : std_logic_vector(2 downto 0);
  arburst        : std_logic_vector(1 downto 0);
  arlock         : std_logic;
  arcache        : std_logic_vector(3 downto 0); -- enable read cache on ACP
  arprot         : std_logic_vector(2 downto 0);
  arqos          : std_logic_vector(3 downto 0);
  arvalid        : std_logic;
  -- read data
  rready         : std_logic;
end record;

end;
