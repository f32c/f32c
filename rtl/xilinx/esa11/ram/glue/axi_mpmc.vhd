--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_mpmc is
   Port(
      ddr3_dq              : inout std_logic_vector(15 downto 0);
      ddr3_dqs_n           : inout std_logic_vector(1 downto 0);
      ddr3_dqs_p           : inout std_logic_vector(1 downto 0);

      ddr3_addr            : out   std_logic_vector(13 downto 0);
      ddr3_ba              : out   std_logic_vector(2 downto 0);
      ddr3_ras_n           : out   std_logic;
      ddr3_cas_n           : out   std_logic;
      ddr3_we_n            : out   std_logic;
      ddr3_reset_n         : out   std_logic;
      ddr3_ck_p            : out   std_logic_vector(0 downto 0);
      ddr3_ck_n            : out   std_logic_vector(0 downto 0);
      ddr3_cke             : out   std_logic_vector(0 downto 0);
      ddr3_dm              : out   std_logic_vector(1 downto 0);
      ddr3_odt             : out   std_logic_vector(0 downto 0);

      sys_rst              : in    std_logic; -- active high
      sys_clk_i            : in    std_logic; -- also used as clk_ref (200MHz)
      init_calib_complete  : out   std_logic;

      s00_axi_areset_out_n : out   std_logic;
      s00_axi_aclk         : in    std_logic;
      s00_axi_awid         : in    std_logic_vector(0 downto 0);
      s00_axi_awaddr       : in    std_logic_vector(31 downto 0);
      s00_axi_awlen        : in    std_logic_vector(7 downto 0);
      s00_axi_awsize       : in    std_logic_vector(2 downto 0);
      s00_axi_awburst      : in    std_logic_vector(1 downto 0);
      s00_axi_awlock       : in    std_logic;
      s00_axi_awcache      : in    std_logic_vector(3 downto 0);
      s00_axi_awprot       : in    std_logic_vector(2 downto 0);
      s00_axi_awqos        : in    std_logic_vector(3 downto 0);
      s00_axi_awvalid      : in    std_logic;
      s00_axi_awready      : out   std_logic;
      s00_axi_wdata        : in    std_logic_vector(31 downto 0);
      s00_axi_wstrb        : in    std_logic_vector(3 downto 0);
      s00_axi_wlast        : in    std_logic;
      s00_axi_wvalid       : in    std_logic;
      s00_axi_wready       : out   std_logic;
      s00_axi_bid          : out   std_logic_vector(0 downto 0);
      s00_axi_bresp        : out   std_logic_vector(1 downto 0);
      s00_axi_bvalid       : out   std_logic;
      s00_axi_bready       : in    std_logic;
      s00_axi_arid         : in    std_logic_vector(0 downto 0);
      s00_axi_araddr       : in    std_logic_vector(31 downto 0);
      s00_axi_arlen        : in    std_logic_vector(7 downto 0);
      s00_axi_arsize       : in    std_logic_vector(2 downto 0);
      s00_axi_arburst      : in    std_logic_vector(1 downto 0);
      s00_axi_arlock       : in    std_logic;
      s00_axi_arcache      : in    std_logic_vector(3 downto 0);
      s00_axi_arprot       : in    std_logic_vector(2 downto 0);
      s00_axi_arqos        : in    std_logic_vector(3 downto 0);
      s00_axi_arvalid      : in    std_logic;
      s00_axi_arready      : out   std_logic;
      s00_axi_rid          : out   std_logic_vector(0 downto 0);
      s00_axi_rdata        : out   std_logic_vector(31 downto 0);
      s00_axi_rresp        : out   std_logic_vector(1 downto 0);
      s00_axi_rlast        : out   std_logic;
      s00_axi_rvalid       : out   std_logic;
      s00_axi_rready       : in    std_logic;
      
      s01_axi_areset_out_n : out   std_logic;
      s01_axi_aclk         : in    std_logic;
      s01_axi_awid         : in    std_logic_vector(0 downto 0);
      s01_axi_awaddr       : in    std_logic_vector(31 downto 0);
      s01_axi_awlen        : in    std_logic_vector(7 downto 0);
      s01_axi_awsize       : in    std_logic_vector(2 downto 0);
      s01_axi_awburst      : in    std_logic_vector(1 downto 0);
      s01_axi_awlock       : in    std_logic;
      s01_axi_awcache      : in    std_logic_vector(3 downto 0);
      s01_axi_awprot       : in    std_logic_vector(2 downto 0);
      s01_axi_awqos        : in    std_logic_vector(3 downto 0);
      s01_axi_awvalid      : in    std_logic;
      s01_axi_awready      : out   std_logic;
      s01_axi_wdata        : in    std_logic_vector(31 downto 0);
      s01_axi_wstrb        : in    std_logic_vector(3 downto 0);
      s01_axi_wlast        : in    std_logic;
      s01_axi_wvalid       : in    std_logic;
      s01_axi_wready       : out   std_logic;
      s01_axi_bid          : out   std_logic_vector(0 downto 0);
      s01_axi_bresp        : out   std_logic_vector(1 downto 0);
      s01_axi_bvalid       : out   std_logic;
      s01_axi_bready       : in    std_logic;
      s01_axi_arid         : in    std_logic_vector(0 downto 0);
      s01_axi_araddr       : in    std_logic_vector(31 downto 0);
      s01_axi_arlen        : in    std_logic_vector(7 downto 0);
      s01_axi_arsize       : in    std_logic_vector(2 downto 0);
      s01_axi_arburst      : in    std_logic_vector(1 downto 0);
      s01_axi_arlock       : in    std_logic;
      s01_axi_arcache      : in    std_logic_vector(3 downto 0);
      s01_axi_arprot       : in    std_logic_vector(2 downto 0);
      s01_axi_arqos        : in    std_logic_vector(3 downto 0);
      s01_axi_arvalid      : in    std_logic;
      s01_axi_arready      : out   std_logic;
      s01_axi_rid          : out   std_logic_vector(0 downto 0);
      s01_axi_rdata        : out   std_logic_vector(31 downto 0);
      s01_axi_rresp        : out   std_logic_vector(1 downto 0);
      s01_axi_rlast        : out   std_logic;
      s01_axi_rvalid       : out   std_logic;
      s01_axi_rready       : in    std_logic;

      s02_axi_areset_out_n : out   std_logic;
      s02_axi_aclk         : in    std_logic;
      s02_axi_awid         : in    std_logic_vector(0 downto 0);
      s02_axi_awaddr       : in    std_logic_vector(31 downto 0);
      s02_axi_awlen        : in    std_logic_vector(7 downto 0);
      s02_axi_awsize       : in    std_logic_vector(2 downto 0);
      s02_axi_awburst      : in    std_logic_vector(1 downto 0);
      s02_axi_awlock       : in    std_logic;
      s02_axi_awcache      : in    std_logic_vector(3 downto 0);
      s02_axi_awprot       : in    std_logic_vector(2 downto 0);
      s02_axi_awqos        : in    std_logic_vector(3 downto 0);
      s02_axi_awvalid      : in    std_logic;
      s02_axi_awready      : out   std_logic;
      s02_axi_wdata        : in    std_logic_vector(31 downto 0);
      s02_axi_wstrb        : in    std_logic_vector(3 downto 0);
      s02_axi_wlast        : in    std_logic;
      s02_axi_wvalid       : in    std_logic;
      s02_axi_wready       : out   std_logic;
      s02_axi_bid          : out   std_logic_vector(0 downto 0);
      s02_axi_bresp        : out   std_logic_vector(1 downto 0);
      s02_axi_bvalid       : out   std_logic;
      s02_axi_bready       : in    std_logic;
      s02_axi_arid         : in    std_logic_vector(0 downto 0);
      s02_axi_araddr       : in    std_logic_vector(31 downto 0);
      s02_axi_arlen        : in    std_logic_vector(7 downto 0);
      s02_axi_arsize       : in    std_logic_vector(2 downto 0);
      s02_axi_arburst      : in    std_logic_vector(1 downto 0);
      s02_axi_arlock       : in    std_logic;
      s02_axi_arcache      : in    std_logic_vector(3 downto 0);
      s02_axi_arprot       : in    std_logic_vector(2 downto 0);
      s02_axi_arqos        : in    std_logic_vector(3 downto 0);
      s02_axi_arvalid      : in    std_logic;
      s02_axi_arready      : out   std_logic;
      s02_axi_rid          : out   std_logic_vector(0 downto 0);
      s02_axi_rdata        : out   std_logic_vector(31 downto 0);
      s02_axi_rresp        : out   std_logic_vector(1 downto 0);
      s02_axi_rlast        : out   std_logic;
      s02_axi_rvalid       : out   std_logic;
      s02_axi_rready       : in    std_logic
   );

end axi_mpmc;

architecture logic of axi_mpmc is

   component axi_interconnect_0 is
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
         M00_AXI_WDATA        : out std_logic_vector(127 downto 0);
         M00_AXI_WSTRB        : out std_logic_vector(15 downto 0);
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
         M00_AXI_RDATA        : in  std_logic_vector(127 downto 0);
         M00_AXI_RRESP        : in  std_logic_vector(1 downto 0);
         M00_AXI_RLAST        : in  std_logic;
         M00_AXI_RVALID       : in  std_logic;
         M00_AXI_RREADY       : out std_logic
      );

   end component axi_interconnect_0;

   component mig_7series_1 is
      Port(
         ddr3_dq              : inout std_logic_vector(15 downto 0);
         ddr3_dqs_n           : inout std_logic_vector(1 downto 0);
         ddr3_dqs_p           : inout std_logic_vector(1 downto 0);

         ddr3_addr            : out   std_logic_vector(13 downto 0);
         ddr3_ba              : out   std_logic_vector(2 downto 0);
         ddr3_ras_n           : out   std_logic;
         ddr3_cas_n           : out   std_logic;
         ddr3_we_n            : out   std_logic;
         ddr3_reset_n         : out   std_logic;
         ddr3_ck_p            : out   std_logic_vector(0 downto 0);
         ddr3_ck_n            : out   std_logic_vector(0 downto 0);
         ddr3_cke             : out   std_logic_vector(0 downto 0);
         ddr3_dm              : out   std_logic_vector(1 downto 0);
         ddr3_odt             : out   std_logic_vector(0 downto 0);

         sys_clk_i            : in    std_logic;
         sys_rst              : in    std_logic;
         init_calib_complete  : out   std_logic;

         ui_clk               : out   std_logic;
         ui_clk_sync_rst      : out   std_logic;
         mmcm_locked          : out   std_logic;
         aresetn              : in    std_logic;
         app_sr_req           : in    std_logic;
         app_ref_req          : in    std_logic;
         app_zq_req           : in    std_logic;
         app_sr_active        : out   std_logic;
         app_ref_ack          : out   std_logic;
         app_zq_ack           : out   std_logic;

         s_axi_awid           : in    std_logic_vector(3 downto 0);
         s_axi_awaddr         : in    std_logic_vector(27 downto 0);
         s_axi_awlen          : in    std_logic_vector(7 downto 0);
         s_axi_awsize         : in    std_logic_vector(2 downto 0);
         s_axi_awburst        : in    std_logic_vector(1 downto 0);
         s_axi_awlock         : in    std_logic_vector(0 downto 0);
         s_axi_awcache        : in    std_logic_vector(3 downto 0);
         s_axi_awprot         : in    std_logic_vector(2 downto 0);
         s_axi_awqos          : in    std_logic_vector(3 downto 0);
         s_axi_awvalid        : in    std_logic;
         s_axi_awready        : out   std_logic;

         s_axi_wdata          : in    std_logic_vector(127 downto 0);
         s_axi_wstrb          : in    std_logic_vector(15 downto 0);
         s_axi_wlast          : in    std_logic;
         s_axi_wvalid         : in    std_logic;
         s_axi_wready         : out   std_logic;

         s_axi_bready         : in    std_logic;
         s_axi_bid            : out   std_logic_vector(3 downto 0);
         s_axi_bresp          : out   std_logic_vector(1 downto 0);
         s_axi_bvalid         : out   std_logic;

         s_axi_arid           : in    std_logic_vector(3 downto 0);
         s_axi_araddr         : in    std_logic_vector(27 downto 0);
         s_axi_arlen          : in    std_logic_vector(7 downto 0);
         s_axi_arsize         : in    std_logic_vector(2 downto 0);
         s_axi_arburst        : in    std_logic_vector(1 downto 0);
         s_axi_arlock         : in    std_logic_vector(0 downto 0);
         s_axi_arcache        : in    std_logic_vector(3 downto 0);
         s_axi_arprot         : in    std_logic_vector(2 downto 0);
         s_axi_arqos          : in    std_logic_vector(3 downto 0);
         s_axi_arvalid        : in    std_logic;
         s_axi_arready        : out   std_logic;

         s_axi_rready         : in    std_logic;
         s_axi_rid            : out   std_logic_vector(3 downto 0);
         s_axi_rdata          : out   std_logic_vector(127 downto 0);
         s_axi_rresp          : out   std_logic_vector(1 downto 0);
         s_axi_rlast          : out   std_logic;
         s_axi_rvalid         : out   std_logic
      );
   end component mig_7series_1;


   signal l00_axi_aresetn     : std_logic;
   signal l00_axi_awid        : std_logic_vector(3 downto 0);
   signal l00_axi_awaddr      : std_logic_vector(31 downto 0);
   signal l00_axi_awlen       : std_logic_vector(7 downto 0);
   signal l00_axi_awsize      : std_logic_vector(2 downto 0);
   signal l00_axi_awburst     : std_logic_vector(1 downto 0);
   signal l00_axi_awlock      : std_logic_vector(0 downto 0);
   signal l00_axi_awcache     : std_logic_vector(3 downto 0);
   signal l00_axi_awprot      : std_logic_vector(2 downto 0);
   signal l00_axi_awqos       : std_logic_vector(3 downto 0);
   signal l00_axi_awvalid     : std_logic;
   signal l00_axi_awready     : std_logic;
   signal l00_axi_wdata       : std_logic_vector(127 downto 0);
   signal l00_axi_wstrb       : std_logic_vector(15 downto 0);
   signal l00_axi_wlast       : std_logic;
   signal l00_axi_wvalid      : std_logic;
   signal l00_axi_wready      : std_logic;
   signal l00_axi_bready      : std_logic;
   signal l00_axi_bid         : std_logic_vector(3 downto 0);
   signal l00_axi_bresp       : std_logic_vector(1 downto 0);
   signal l00_axi_bvalid      : std_logic;
   signal l00_axi_arid        : std_logic_vector(3 downto 0);
   signal l00_axi_araddr      : std_logic_vector(31 downto 0) := (others => '0');
   signal l00_axi_arlen       : std_logic_vector(7 downto 0);
   signal l00_axi_arsize      : std_logic_vector(2 downto 0);
   signal l00_axi_arburst     : std_logic_vector(1 downto 0);
   signal l00_axi_arlock      : std_logic_vector(0 downto 0);
   signal l00_axi_arcache     : std_logic_vector(3 downto 0);
   signal l00_axi_arprot      : std_logic_vector(2 downto 0);
   signal l00_axi_arqos       : std_logic_vector(3 downto 0);
   signal l00_axi_arvalid     : std_logic;
   signal l00_axi_arready     : std_logic;
   signal l00_axi_rready      : std_logic;
   signal l00_axi_rid         : std_logic_vector(3 downto 0);
   signal l00_axi_rdata       : std_logic_vector(127 downto 0);
   signal l00_axi_rresp       : std_logic_vector(1 downto 0);
   signal l00_axi_rlast       : std_logic;
   signal l00_axi_rvalid      : std_logic;

   signal ui_clk              : std_logic; -- must be a half or quarter of the DRAM clock. (DRAM clock? sys_clk_i?)
   signal ui_clk_sync_rst     : std_logic; -- active high
   signal mmcm_locked         : std_logic;
   signal aresetn             : std_logic;
   signal app_sr_req          : std_logic := '0';
   signal app_ref_req         : std_logic := '0';
   signal app_zq_req          : std_logic := '0';
   signal app_sr_active       : std_logic;
   signal app_ref_ack         : std_logic;
   signal app_zq_ack          : std_logic;
   
   signal rst_cnt             : unsigned(5 downto 0);
   signal init_calib_compl    : std_logic;

begin

	sync_reset_proc: process(ui_clk)
	begin
		if rising_edge(ui_clk) then
			if ui_clk_sync_rst = '1' then
				rst_cnt <= (others => '0');
			else
				if rst_cnt(5) = '0' and init_calib_compl = '1' then
					rst_cnt <= rst_cnt + "1";
				end if;
			end if;
		end if;
	end process;
	
   aresetn <= std_logic(rst_cnt(5)); -- not ui_clk_sync_rst;
   init_calib_complete <= init_calib_compl;
   
   the_mcb : mig_7series_1
      port map(
         ddr3_dq              => ddr3_dq,
         ddr3_dqs_n           => ddr3_dqs_n,
         ddr3_dqs_p           => ddr3_dqs_p,
         ddr3_addr            => ddr3_addr,
         ddr3_ba              => ddr3_ba,
         ddr3_ras_n           => ddr3_ras_n,
         ddr3_cas_n           => ddr3_cas_n,
         ddr3_we_n            => ddr3_we_n,
         ddr3_reset_n         => ddr3_reset_n,
         ddr3_ck_p            => ddr3_ck_p,
         ddr3_ck_n            => ddr3_ck_n,
         ddr3_cke             => ddr3_cke,
         ddr3_dm              => ddr3_dm,
         ddr3_odt             => ddr3_odt,
         sys_clk_i            => sys_clk_i,
         sys_rst              => sys_rst,
         init_calib_complete  => init_calib_compl,

         ui_clk               => ui_clk,
         ui_clk_sync_rst      => ui_clk_sync_rst,

         mmcm_locked          => mmcm_locked,
         aresetn              => l00_axi_aresetn, -- aresetn,

         app_sr_req           => app_sr_req,
         app_ref_req          => app_ref_req,
         app_zq_req           => app_zq_req,
         app_sr_active        => app_sr_active,
         app_ref_ack          => app_ref_ack,
         app_zq_ack           => app_zq_ack,

         s_axi_awid           => l00_axi_awid,
         s_axi_awaddr         => l00_axi_awaddr(27 downto 0),
         s_axi_awlen          => l00_axi_awlen,
         s_axi_awsize         => l00_axi_awsize,
         s_axi_awburst        => l00_axi_awburst,
         s_axi_awlock         => l00_axi_awlock,
         s_axi_awcache        => l00_axi_awcache,
         s_axi_awprot         => l00_axi_awprot,
         s_axi_awqos          => l00_axi_awqos,
         s_axi_awvalid        => l00_axi_awvalid,
         s_axi_awready        => l00_axi_awready,
         s_axi_wdata          => l00_axi_wdata,
         s_axi_wstrb          => l00_axi_wstrb,
         s_axi_wlast          => l00_axi_wlast,
         s_axi_wvalid         => l00_axi_wvalid,
         s_axi_wready         => l00_axi_wready,
         s_axi_bready         => l00_axi_bready,
         s_axi_bid            => l00_axi_bid,
         s_axi_bresp          => l00_axi_bresp,
         s_axi_bvalid         => l00_axi_bvalid,
         s_axi_arid           => l00_axi_arid,
         s_axi_araddr         => l00_axi_araddr(27 downto 0),
         s_axi_arlen          => l00_axi_arlen,
         s_axi_arsize         => l00_axi_arsize,
         s_axi_arburst        => l00_axi_arburst,
         s_axi_arlock         => l00_axi_arlock,
         s_axi_arcache        => l00_axi_arcache,
         s_axi_arprot         => l00_axi_arprot,
         s_axi_arqos          => l00_axi_arqos,
         s_axi_arvalid        => l00_axi_arvalid,
         s_axi_arready        => l00_axi_arready,
         s_axi_rready         => l00_axi_rready,
         s_axi_rid            => l00_axi_rid,
         s_axi_rdata          => l00_axi_rdata,
         s_axi_rresp          => l00_axi_rresp,
         s_axi_rlast          => l00_axi_rlast,
         s_axi_rvalid         => l00_axi_rvalid
      );

   the_ic : axi_interconnect_0
      port map(
         INTERCONNECT_ACLK    => ui_clk,
         INTERCONNECT_ARESETN => aresetn,

         S00_AXI_ARESET_OUT_N => s00_axi_areset_out_n,
         S00_AXI_ACLK         => s00_axi_aclk,
         S00_AXI_AWID         => s00_axi_awid,
         S00_AXI_AWADDR       => s00_axi_awaddr,
         S00_AXI_AWLEN        => s00_axi_awlen,
         S00_AXI_AWSIZE       => s00_axi_awsize,
         S00_AXI_AWBURST      => s00_axi_awburst,
         S00_AXI_AWLOCK       => s00_axi_awlock,
         S00_AXI_AWCACHE      => s00_axi_awcache,
         S00_AXI_AWPROT       => s00_axi_awprot,
         S00_AXI_AWQOS        => s00_axi_awqos,
         S00_AXI_AWVALID      => s00_axi_awvalid,
         S00_AXI_AWREADY      => s00_axi_awready,
         S00_AXI_WDATA        => s00_axi_wdata,
         S00_AXI_WSTRB        => s00_axi_wstrb,
         S00_AXI_WLAST        => s00_axi_wlast,
         S00_AXI_WVALID       => s00_axi_wvalid,
         S00_AXI_WREADY       => s00_axi_wready,
         S00_AXI_BID          => s00_axi_bid,
         S00_AXI_BRESP        => s00_axi_bresp,
         S00_AXI_BVALID       => s00_axi_bvalid,
         S00_AXI_BREADY       => s00_axi_bready,
         S00_AXI_ARID         => s00_axi_arid,
         S00_AXI_ARADDR       => s00_axi_araddr,
         S00_AXI_ARLEN        => s00_axi_arlen,
         S00_AXI_ARSIZE       => s00_axi_arsize,
         S00_AXI_ARBURST      => s00_axi_arburst,
         S00_AXI_ARLOCK       => s00_axi_arlock,
         S00_AXI_ARCACHE      => s00_axi_arcache,
         S00_AXI_ARPROT       => s00_axi_arprot,
         S00_AXI_ARQOS        => s00_axi_arqos,
         S00_AXI_ARVALID      => s00_axi_arvalid,
         S00_AXI_ARREADY      => s00_axi_arready,
         S00_AXI_RID          => s00_axi_rid,
         S00_AXI_RDATA        => s00_axi_rdata,
         S00_AXI_RRESP        => s00_axi_rresp,
         S00_AXI_RLAST        => s00_axi_rlast,
         S00_AXI_RVALID       => s00_axi_rvalid,
         S00_AXI_RREADY       => s00_axi_rready,
         
         S01_AXI_ARESET_OUT_N => s01_axi_areset_out_n,
         S01_AXI_ACLK         => s01_axi_aclk,
         S01_AXI_AWID         => s01_axi_awid,
         S01_AXI_AWADDR       => s01_axi_awaddr,
         S01_AXI_AWLEN        => s01_axi_awlen,
         S01_AXI_AWSIZE       => s01_axi_awsize,
         S01_AXI_AWBURST      => s01_axi_awburst,
         S01_AXI_AWLOCK       => s01_axi_awlock,
         S01_AXI_AWCACHE      => s01_axi_awcache,
         S01_AXI_AWPROT       => s01_axi_awprot,
         S01_AXI_AWQOS        => s01_axi_awqos,
         S01_AXI_AWVALID      => s01_axi_awvalid,
         S01_AXI_AWREADY      => s01_axi_awready,
         S01_AXI_WDATA        => s01_axi_wdata,
         S01_AXI_WSTRB        => s01_axi_wstrb,
         S01_AXI_WLAST        => s01_axi_wlast,
         S01_AXI_WVALID       => s01_axi_wvalid,
         S01_AXI_WREADY       => s01_axi_wready,
         S01_AXI_BID          => s01_axi_bid,
         S01_AXI_BRESP        => s01_axi_bresp,
         S01_AXI_BVALID       => s01_axi_bvalid,
         S01_AXI_BREADY       => s01_axi_bready,
         S01_AXI_ARID         => s01_axi_arid,
         S01_AXI_ARADDR       => s01_axi_araddr,
         S01_AXI_ARLEN        => s01_axi_arlen,
         S01_AXI_ARSIZE       => s01_axi_arsize,
         S01_AXI_ARBURST      => s01_axi_arburst,
         S01_AXI_ARLOCK       => s01_axi_arlock,
         S01_AXI_ARCACHE      => s01_axi_arcache,
         S01_AXI_ARPROT       => s01_axi_arprot,
         S01_AXI_ARQOS        => s01_axi_arqos,
         S01_AXI_ARVALID      => s01_axi_arvalid,
         S01_AXI_ARREADY      => s01_axi_arready,
         S01_AXI_RID          => s01_axi_rid,
         S01_AXI_RDATA        => s01_axi_rdata,
         S01_AXI_RRESP        => s01_axi_rresp,
         S01_AXI_RLAST        => s01_axi_rlast,
         S01_AXI_RVALID       => s01_axi_rvalid,
         S01_AXI_RREADY       => s01_axi_rready,

         S02_AXI_ARESET_OUT_N => s02_axi_areset_out_n,
         S02_AXI_ACLK         => s02_axi_aclk,
         S02_AXI_AWID         => s02_axi_awid,
         S02_AXI_AWADDR       => s02_axi_awaddr,
         S02_AXI_AWLEN        => s02_axi_awlen,
         S02_AXI_AWSIZE       => s02_axi_awsize,
         S02_AXI_AWBURST      => s02_axi_awburst,
         S02_AXI_AWLOCK       => s02_axi_awlock,
         S02_AXI_AWCACHE      => s02_axi_awcache,
         S02_AXI_AWPROT       => s02_axi_awprot,
         S02_AXI_AWQOS        => s02_axi_awqos,
         S02_AXI_AWVALID      => s02_axi_awvalid,
         S02_AXI_AWREADY      => s02_axi_awready,
         S02_AXI_WDATA        => s02_axi_wdata,
         S02_AXI_WSTRB        => s02_axi_wstrb,
         S02_AXI_WLAST        => s02_axi_wlast,
         S02_AXI_WVALID       => s02_axi_wvalid,
         S02_AXI_WREADY       => s02_axi_wready,
         S02_AXI_BID          => s02_axi_bid,
         S02_AXI_BRESP        => s02_axi_bresp,
         S02_AXI_BVALID       => s02_axi_bvalid,
         S02_AXI_BREADY       => s02_axi_bready,
         S02_AXI_ARID         => s02_axi_arid,
         S02_AXI_ARADDR       => s02_axi_araddr,
         S02_AXI_ARLEN        => s02_axi_arlen,
         S02_AXI_ARSIZE       => s02_axi_arsize,
         S02_AXI_ARBURST      => s02_axi_arburst,
         S02_AXI_ARLOCK       => s02_axi_arlock,
         S02_AXI_ARCACHE      => s02_axi_arcache,
         S02_AXI_ARPROT       => s02_axi_arprot,
         S02_AXI_ARQOS        => s02_axi_arqos,
         S02_AXI_ARVALID      => s02_axi_arvalid,
         S02_AXI_ARREADY      => s02_axi_arready,
         S02_AXI_RID          => s02_axi_rid,
         S02_AXI_RDATA        => s02_axi_rdata,
         S02_AXI_RRESP        => s02_axi_rresp,
         S02_AXI_RLAST        => s02_axi_rlast,
         S02_AXI_RVALID       => s02_axi_rvalid,
         S02_AXI_RREADY       => s02_axi_rready,
          
         M00_AXI_ARESET_OUT_N => l00_axi_aresetn,
         M00_AXI_ACLK         => ui_clk,
         M00_AXI_AWID         => l00_axi_awid,
         M00_AXI_AWADDR       => l00_axi_awaddr,
         M00_AXI_AWLEN        => l00_axi_awlen,
         M00_AXI_AWSIZE       => l00_axi_awsize,
         M00_AXI_AWBURST      => l00_axi_awburst,
         M00_AXI_AWLOCK       => l00_axi_awlock(0),
         M00_AXI_AWCACHE      => l00_axi_awcache,
         M00_AXI_AWPROT       => l00_axi_awprot,
         M00_AXI_AWQOS        => l00_axi_awqos,
         M00_AXI_AWVALID      => l00_axi_awvalid,
         M00_AXI_AWREADY      => l00_axi_awready,
         M00_AXI_WDATA        => l00_axi_wdata,
         M00_AXI_WSTRB        => l00_axi_wstrb,
         M00_AXI_WLAST        => l00_axi_wlast,
         M00_AXI_WVALID       => l00_axi_wvalid,
         M00_AXI_WREADY       => l00_axi_wready,
         M00_AXI_BID          => l00_axi_bid,
         M00_AXI_BRESP        => l00_axi_bresp,
         M00_AXI_BVALID       => l00_axi_bvalid,
         M00_AXI_BREADY       => l00_axi_bready,
         M00_AXI_ARID         => l00_axi_arid,
         M00_AXI_ARADDR       => l00_axi_araddr,
         M00_AXI_ARLEN        => l00_axi_arlen,
         M00_AXI_ARSIZE       => l00_axi_arsize,
         M00_AXI_ARBURST      => l00_axi_arburst,
         M00_AXI_ARLOCK       => l00_axi_arlock(0),
         M00_AXI_ARCACHE      => l00_axi_arcache,
         M00_AXI_ARPROT       => l00_axi_arprot,
         M00_AXI_ARQOS        => l00_axi_arqos,
         M00_AXI_ARVALID      => l00_axi_arvalid,
         M00_AXI_ARREADY      => l00_axi_arready,
         M00_AXI_RID          => l00_axi_rid,
         M00_AXI_RDATA        => l00_axi_rdata,
         M00_AXI_RRESP        => l00_axi_rresp,
         M00_AXI_RLAST        => l00_axi_rlast,
         M00_AXI_RVALID       => l00_axi_rvalid,
         M00_AXI_RREADY       => l00_axi_rready
      );

end logic;
