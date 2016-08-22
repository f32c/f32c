-- AXI interconect

-- Multiport RAM arbiter
-- 3x32-bit slave ports (to f32c CPU, VECTOR, VIDEO)
-- 1x64-bit master port (to RAM memory)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pack.all;

entity axi_interconnect_1m64_3s32_vhd is
   Port
   (
      aclk                 : in    std_logic; -- also used as clk_ref (200MHz)
      aresetn              : in    std_logic := '1';

      m00_axi_areset_out_n : out   std_logic;
      m00_axi_aclk         : in    std_logic;
      m00_axi_in           : in    T_axi64_miso;
      m00_axi_out          : out   T_axi64_mosi;

      s00_axi_areset_out_n : out   std_logic;
      s00_axi_aclk         : in    std_logic;
      s00_axi_in           : in    T_axi_mosi;
      s00_axi_out          : out   T_axi_miso;

      s01_axi_areset_out_n : out   std_logic;
      s01_axi_aclk         : in    std_logic;
      s01_axi_in           : in    T_axi_mosi;
      s01_axi_out          : out   T_axi_miso;

      s02_axi_areset_out_n : out   std_logic;
      s02_axi_aclk         : in    std_logic;
      s02_axi_in           : in    T_axi_mosi;
      s02_axi_out          : out   T_axi_miso
   );
end;

architecture logic of axi_interconnect_1m64_3s32_vhd is
   component axi_interconnect_1m64_3s32 is
      Port(
         INTERCONNECT_ACLK    : in  std_logic;
         INTERCONNECT_ARESETN : in  std_logic;
         S00_AXI_ARESET_OUT_N : out std_logic;
         S00_AXI_ACLK         : in  std_logic;
         S00_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S00_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S00_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_AWLOCK       : in  std_logic;
         S00_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_AWVALID      : in  std_logic;
         S00_AXI_AWREADY      : out std_logic;
         S00_AXI_WDATA        : in  std_logic_vector(31 downto 0);
         S00_AXI_WSTRB        : in  std_logic_vector(3 downto 0);
         S00_AXI_WLAST        : in  std_logic;
         S00_AXI_WVALID       : in  std_logic;
         S00_AXI_WREADY       : out std_logic;
         S00_AXI_BID          : out std_logic_vector(0 downto 0);
         S00_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_BVALID       : out std_logic;
         S00_AXI_BREADY       : in  std_logic;
         S00_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S00_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S00_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S00_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S00_AXI_ARLOCK       : in  std_logic;
         S00_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S00_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S00_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S00_AXI_ARVALID      : in  std_logic;
         S00_AXI_ARREADY      : out std_logic;
         S00_AXI_RID          : out std_logic_vector(0 downto 0);
         S00_AXI_RDATA        : out std_logic_vector(31 downto 0);
         S00_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S00_AXI_RLAST        : out std_logic;
         S00_AXI_RVALID       : out std_logic;
         S00_AXI_RREADY       : in  std_logic;
         S01_AXI_ARESET_OUT_N : out std_logic;
         S01_AXI_ACLK         : in  std_logic;
         S01_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S01_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S01_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_AWLOCK       : in  std_logic;
         S01_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_AWVALID      : in  std_logic;
         S01_AXI_AWREADY      : out std_logic;
         S01_AXI_WDATA        : in  std_logic_vector(31 downto 0);
         S01_AXI_WSTRB        : in  std_logic_vector(3 downto 0);
         S01_AXI_WLAST        : in  std_logic;
         S01_AXI_WVALID       : in  std_logic;
         S01_AXI_WREADY       : out std_logic;
         S01_AXI_BID          : out std_logic_vector(0 downto 0);
         S01_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_BVALID       : out std_logic;
         S01_AXI_BREADY       : in  std_logic;
         S01_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S01_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S01_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S01_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S01_AXI_ARLOCK       : in  std_logic;
         S01_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S01_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S01_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S01_AXI_ARVALID      : in  std_logic;
         S01_AXI_ARREADY      : out std_logic;
         S01_AXI_RID          : out std_logic_vector(0 downto 0);
         S01_AXI_RDATA        : out std_logic_vector(31 downto 0);
         S01_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S01_AXI_RLAST        : out std_logic;
         S01_AXI_RVALID       : out std_logic;
         S01_AXI_RREADY       : in  std_logic;
         S02_AXI_ARESET_OUT_N : out std_logic;
         S02_AXI_ACLK         : in  std_logic;
         S02_AXI_AWID         : in  std_logic_vector(0 downto 0);
         S02_AXI_AWADDR       : in  std_logic_vector(31 downto 0);
         S02_AXI_AWLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_AWSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_AWLOCK       : in  std_logic;
         S02_AXI_AWCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_AWPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_AWQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_AWVALID      : in  std_logic;
         S02_AXI_AWREADY      : out std_logic;
         S02_AXI_WDATA        : in  std_logic_vector(31 downto 0);
         S02_AXI_WSTRB        : in  std_logic_vector(3 downto 0);
         S02_AXI_WLAST        : in  std_logic;
         S02_AXI_WVALID       : in  std_logic;
         S02_AXI_WREADY       : out std_logic;
         S02_AXI_BID          : out std_logic_vector(0 downto 0);
         S02_AXI_BRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_BVALID       : out std_logic;
         S02_AXI_BREADY       : in  std_logic;
         S02_AXI_ARID         : in  std_logic_vector(0 downto 0);
         S02_AXI_ARADDR       : in  std_logic_vector(31 downto 0);
         S02_AXI_ARLEN        : in  std_logic_vector(7 downto 0);
         S02_AXI_ARSIZE       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARBURST      : in  std_logic_vector(1 downto 0);
         S02_AXI_ARLOCK       : in  std_logic;
         S02_AXI_ARCACHE      : in  std_logic_vector(3 downto 0);
         S02_AXI_ARPROT       : in  std_logic_vector(2 downto 0);
         S02_AXI_ARQOS        : in  std_logic_vector(3 downto 0);
         S02_AXI_ARVALID      : in  std_logic;
         S02_AXI_ARREADY      : out std_logic;
         S02_AXI_RID          : out std_logic_vector(0 downto 0);
         S02_AXI_RDATA        : out std_logic_vector(31 downto 0);
         S02_AXI_RRESP        : out std_logic_vector(1 downto 0);
         S02_AXI_RLAST        : out std_logic;
         S02_AXI_RVALID       : out std_logic;
         S02_AXI_RREADY       : in  std_logic;
         M00_AXI_ARESET_OUT_N : out std_logic;
         M00_AXI_ACLK         : in  std_logic;
         M00_AXI_AWID         : out std_logic_vector(3 downto 0);
         M00_AXI_AWADDR       : out std_logic_vector(31 downto 0);
         M00_AXI_AWLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_AWSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_AWBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_AWLOCK       : out std_logic;
         M00_AXI_AWCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_AWPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_AWQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_AWVALID      : out std_logic;
         M00_AXI_AWREADY      : in  std_logic;
         M00_AXI_WDATA        : out std_logic_vector(63 downto 0);
         M00_AXI_WSTRB        : out std_logic_vector(7 downto 0);
         M00_AXI_WLAST        : out std_logic;
         M00_AXI_WVALID       : out std_logic;
         M00_AXI_WREADY       : in  std_logic;
         M00_AXI_BID          : in  std_logic_vector(3 downto 0);
         M00_AXI_BRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_BVALID       : in  std_logic;
         M00_AXI_BREADY       : out std_logic;
         M00_AXI_ARID         : out std_logic_vector(3 downto 0);
         M00_AXI_ARADDR       : out std_logic_vector(31 downto 0);
         M00_AXI_ARLEN        : out std_logic_vector(7 downto 0);
         M00_AXI_ARSIZE       : out std_logic_vector(2 downto 0);
         M00_AXI_ARBURST      : out std_logic_vector(1 downto 0);
         M00_AXI_ARLOCK       : out std_logic;
         M00_AXI_ARCACHE      : out std_logic_vector(3 downto 0);
         M00_AXI_ARPROT       : out std_logic_vector(2 downto 0);
         M00_AXI_ARQOS        : out std_logic_vector(3 downto 0);
         M00_AXI_ARVALID      : out std_logic;
         M00_AXI_ARREADY      : in  std_logic;
         M00_AXI_RID          : in  std_logic_vector(3 downto 0);
         M00_AXI_RDATA        : in  std_logic_vector(63 downto 0);
         M00_AXI_RRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_RLAST        : in  std_logic;
         M00_AXI_RVALID       : in  std_logic;
         M00_AXI_RREADY       : out std_logic
      );
   end component;
begin
   axi_interconnect: axi_interconnect_1m64_3s32
     port map(
         INTERCONNECT_ACLK    => aclk,
         INTERCONNECT_ARESETN => aresetn,

         S00_AXI_ARESET_OUT_N => s00_axi_areset_out_n,
         S00_AXI_ACLK         => s00_axi_aclk,
         S00_AXI_AWID         => s00_axi_in.awid,
         S00_AXI_AWADDR       => s00_axi_in.awaddr,
         S00_AXI_AWLEN        => s00_axi_in.awlen,
         S00_AXI_AWSIZE       => s00_axi_in.awsize,
         S00_AXI_AWBURST      => s00_axi_in.awburst,
         S00_AXI_AWLOCK       => s00_axi_in.awlock,
         S00_AXI_AWCACHE      => s00_axi_in.awcache,
         S00_AXI_AWPROT       => s00_axi_in.awprot,
         S00_AXI_AWQOS        => s00_axi_in.awqos,
         S00_AXI_AWVALID      => s00_axi_in.awvalid,
         S00_AXI_AWREADY      => s00_axi_out.awready,
         S00_AXI_WDATA        => s00_axi_in.wdata,
         S00_AXI_WSTRB        => s00_axi_in.wstrb,
         S00_AXI_WLAST        => s00_axi_in.wlast,
         S00_AXI_WVALID       => s00_axi_in.wvalid,
         S00_AXI_WREADY       => s00_axi_out.wready,
         S00_AXI_BID          => s00_axi_out.bid,
         S00_AXI_BRESP        => s00_axi_out.bresp,
         S00_AXI_BVALID       => s00_axi_out.bvalid,
         S00_AXI_BREADY       => s00_axi_in.bready,
         S00_AXI_ARID         => s00_axi_in.arid,
         S00_AXI_ARADDR       => s00_axi_in.araddr,
         S00_AXI_ARLEN        => s00_axi_in.arlen,
         S00_AXI_ARSIZE       => s00_axi_in.arsize,
         S00_AXI_ARBURST      => s00_axi_in.arburst,
         S00_AXI_ARLOCK       => s00_axi_in.arlock,
         S00_AXI_ARCACHE      => s00_axi_in.arcache,
         S00_AXI_ARPROT       => s00_axi_in.arprot,
         S00_AXI_ARQOS        => s00_axi_in.arqos,
         S00_AXI_ARVALID      => s00_axi_in.arvalid,
         S00_AXI_ARREADY      => s00_axi_out.arready,
         S00_AXI_RID          => s00_axi_out.rid,
         S00_AXI_RDATA        => s00_axi_out.rdata,
         S00_AXI_RRESP        => s00_axi_out.rresp,
         S00_AXI_RLAST        => s00_axi_out.rlast,
         S00_AXI_RVALID       => s00_axi_out.rvalid,
         S00_AXI_RREADY       => s00_axi_in.rready,
         
         S01_AXI_ARESET_OUT_N => s01_axi_areset_out_n,
         S01_AXI_ACLK         => s01_axi_aclk,
         S01_AXI_AWID         => s01_axi_in.awid,
         S01_AXI_AWADDR       => s01_axi_in.awaddr,
         S01_AXI_AWLEN        => s01_axi_in.awlen,
         S01_AXI_AWSIZE       => s01_axi_in.awsize,
         S01_AXI_AWBURST      => s01_axi_in.awburst,
         S01_AXI_AWLOCK       => s01_axi_in.awlock,
         S01_AXI_AWCACHE      => s01_axi_in.awcache,
         S01_AXI_AWPROT       => s01_axi_in.awprot,
         S01_AXI_AWQOS        => s01_axi_in.awqos,
         S01_AXI_AWVALID      => s01_axi_in.awvalid,
         S01_AXI_AWREADY      => s01_axi_out.awready,
         S01_AXI_WDATA        => s01_axi_in.wdata,
         S01_AXI_WSTRB        => s01_axi_in.wstrb,
         S01_AXI_WLAST        => s01_axi_in.wlast,
         S01_AXI_WVALID       => s01_axi_in.wvalid,
         S01_AXI_WREADY       => s01_axi_out.wready,
         S01_AXI_BID          => s01_axi_out.bid,
         S01_AXI_BRESP        => s01_axi_out.bresp,
         S01_AXI_BVALID       => s01_axi_out.bvalid,
         S01_AXI_BREADY       => s01_axi_in.bready,
         S01_AXI_ARID         => s01_axi_in.arid,
         S01_AXI_ARADDR       => s01_axi_in.araddr,
         S01_AXI_ARLEN        => s01_axi_in.arlen,
         S01_AXI_ARSIZE       => s01_axi_in.arsize,
         S01_AXI_ARBURST      => s01_axi_in.arburst,
         S01_AXI_ARLOCK       => s01_axi_in.arlock,
         S01_AXI_ARCACHE      => s01_axi_in.arcache,
         S01_AXI_ARPROT       => s01_axi_in.arprot,
         S01_AXI_ARQOS        => s01_axi_in.arqos,
         S01_AXI_ARVALID      => s01_axi_in.arvalid,
         S01_AXI_ARREADY      => s01_axi_out.arready,
         S01_AXI_RID          => s01_axi_out.rid,
         S01_AXI_RDATA        => s01_axi_out.rdata,
         S01_AXI_RRESP        => s01_axi_out.rresp,
         S01_AXI_RLAST        => s01_axi_out.rlast,
         S01_AXI_RVALID       => s01_axi_out.rvalid,
         S01_AXI_RREADY       => s01_axi_in.rready,

         S02_AXI_ARESET_OUT_N => s02_axi_areset_out_n,
         S02_AXI_ACLK         => s02_axi_aclk,
         S02_AXI_AWID         => s02_axi_in.awid,
         S02_AXI_AWADDR       => s02_axi_in.awaddr,
         S02_AXI_AWLEN        => s02_axi_in.awlen,
         S02_AXI_AWSIZE       => s02_axi_in.awsize,
         S02_AXI_AWBURST      => s02_axi_in.awburst,
         S02_AXI_AWLOCK       => s02_axi_in.awlock,
         S02_AXI_AWCACHE      => s02_axi_in.awcache,
         S02_AXI_AWPROT       => s02_axi_in.awprot,
         S02_AXI_AWQOS        => s02_axi_in.awqos,
         S02_AXI_AWVALID      => s02_axi_in.awvalid,
         S02_AXI_AWREADY      => s02_axi_out.awready,
         S02_AXI_WDATA        => s02_axi_in.wdata,
         S02_AXI_WSTRB        => s02_axi_in.wstrb,
         S02_AXI_WLAST        => s02_axi_in.wlast,
         S02_AXI_WVALID       => s02_axi_in.wvalid,
         S02_AXI_WREADY       => s02_axi_out.wready,
         S02_AXI_BID          => s02_axi_out.bid,
         S02_AXI_BRESP        => s02_axi_out.bresp,
         S02_AXI_BVALID       => s02_axi_out.bvalid,
         S02_AXI_BREADY       => s02_axi_in.bready,
         S02_AXI_ARID         => s02_axi_in.arid,
         S02_AXI_ARADDR       => s02_axi_in.araddr,
         S02_AXI_ARLEN        => s02_axi_in.arlen,
         S02_AXI_ARSIZE       => s02_axi_in.arsize,
         S02_AXI_ARBURST      => s02_axi_in.arburst,
         S02_AXI_ARLOCK       => s02_axi_in.arlock,
         S02_AXI_ARCACHE      => s02_axi_in.arcache,
         S02_AXI_ARPROT       => s02_axi_in.arprot,
         S02_AXI_ARQOS        => s02_axi_in.arqos,
         S02_AXI_ARVALID      => s02_axi_in.arvalid,
         S02_AXI_ARREADY      => s02_axi_out.arready,
         S02_AXI_RID          => s02_axi_out.rid,
         S02_AXI_RDATA        => s02_axi_out.rdata,
         S02_AXI_RRESP        => s02_axi_out.rresp,
         S02_AXI_RLAST        => s02_axi_out.rlast,
         S02_AXI_RVALID       => s02_axi_out.rvalid,
         S02_AXI_RREADY       => s02_axi_in.rready,

         M00_AXI_ARESET_OUT_N => m00_axi_areset_out_n,
         M00_AXI_ACLK         => m00_axi_aclk,
         M00_AXI_AWID         => m00_axi_out.awid,
         M00_AXI_AWADDR       => m00_axi_out.awaddr,
         M00_AXI_AWLEN        => m00_axi_out.awlen,
         M00_AXI_AWSIZE       => m00_axi_out.awsize,
         M00_AXI_AWBURST      => m00_axi_out.awburst,
         M00_AXI_AWLOCK       => m00_axi_out.awlock,
         M00_AXI_AWCACHE      => m00_axi_out.awcache,
         M00_AXI_AWPROT       => m00_axi_out.awprot,
         M00_AXI_AWQOS        => m00_axi_out.awqos,
         M00_AXI_AWVALID      => m00_axi_out.awvalid,
         M00_AXI_AWREADY      => m00_axi_in.awready,
         M00_AXI_WDATA        => m00_axi_out.wdata,
         M00_AXI_WSTRB        => m00_axi_out.wstrb,
         M00_AXI_WLAST        => m00_axi_out.wlast,
         M00_AXI_WVALID       => m00_axi_out.wvalid,
         M00_AXI_WREADY       => m00_axi_in.wready,
         M00_AXI_BID          => m00_axi_in.bid,
         M00_AXI_BRESP        => m00_axi_in.bresp,
         M00_AXI_BVALID       => m00_axi_in.bvalid,
         M00_AXI_BREADY       => m00_axi_out.bready,
         M00_AXI_ARID         => m00_axi_out.arid,
         M00_AXI_ARADDR       => m00_axi_out.araddr,
         M00_AXI_ARLEN        => m00_axi_out.arlen,
         M00_AXI_ARSIZE       => m00_axi_out.arsize,
         M00_AXI_ARBURST      => m00_axi_out.arburst,
         M00_AXI_ARLOCK       => m00_axi_out.arlock,
         M00_AXI_ARCACHE      => m00_axi_out.arcache,
         M00_AXI_ARPROT       => m00_axi_out.arprot,
         M00_AXI_ARQOS        => m00_axi_out.arqos,
         M00_AXI_ARVALID      => m00_axi_out.arvalid,
         M00_AXI_ARREADY      => m00_axi_in.arready,
         M00_AXI_RID          => m00_axi_in.rid,
         M00_AXI_RDATA        => m00_axi_in.rdata,
         M00_AXI_RRESP        => m00_axi_in.rresp,
         M00_AXI_RLAST        => m00_axi_in.rlast,
         M00_AXI_RVALID       => m00_axi_in.rvalid,
         M00_AXI_RREADY       => m00_axi_out.rready
      );
end logic;
