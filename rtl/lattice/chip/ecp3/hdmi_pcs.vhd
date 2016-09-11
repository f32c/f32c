
                                                                                                         

--synopsys translate_off

library pcsd_work;
use pcsd_work.all;
library IEEE;
use IEEE.std_logic_1164.all;

entity PCSD is
GENERIC(
  CONFIG_FILE : String;
  QUAD_MODE : String;
  CH0_CDR_SRC   : String := "REFCLK_EXT";
  CH1_CDR_SRC   : String := "REFCLK_EXT";
  CH2_CDR_SRC   : String := "REFCLK_EXT";
  CH3_CDR_SRC   : String := "REFCLK_EXT";
  PLL_SRC   : String
--  CONFIG_FILE : String  := "hdmi_pcs.txt";
--  QUAD_MODE : String := "SINGLE";
--  CH0_CDR_SRC   : String := "REFCLK_EXT";
--  CH1_CDR_SRC   : String := "REFCLK_EXT";
--  CH2_CDR_SRC   : String := "REFCLK_EXT";
--  CH3_CDR_SRC   : String := "REFCLK_EXT";
--  PLL_SRC   : String := "REFCLK_CORE"
  );
port (
  HDINN0             : in std_logic;
  HDINN1             : in std_logic;
  HDINN2             : in std_logic;
  HDINN3             : in std_logic;
  HDINP0             : in std_logic;
  HDINP1             : in std_logic;
  HDINP2             : in std_logic;
  HDINP3             : in std_logic;
  REFCLKN             : in std_logic;
  REFCLKP             : in std_logic;
  CIN0             : in std_logic;
  CIN1             : in std_logic;
  CIN2             : in std_logic;
  CIN3             : in std_logic;
  CIN4             : in std_logic;
  CIN5             : in std_logic;
  CIN6             : in std_logic;
  CIN7             : in std_logic;
  CIN8             : in std_logic;
  CIN9             : in std_logic;
  CIN10             : in std_logic;
  CIN11             : in std_logic;
  CYAWSTN             : in std_logic;
  FF_EBRD_CLK_0             : in std_logic;
  FF_EBRD_CLK_1             : in std_logic;
  FF_EBRD_CLK_2             : in std_logic;
  FF_EBRD_CLK_3             : in std_logic;
  FF_RXI_CLK_0             : in std_logic;
  FF_RXI_CLK_1             : in std_logic;
  FF_RXI_CLK_2             : in std_logic;
  FF_RXI_CLK_3             : in std_logic;
  FF_TX_D_0_0             : in std_logic;
  FF_TX_D_0_1             : in std_logic;
  FF_TX_D_0_2             : in std_logic;
  FF_TX_D_0_3             : in std_logic;
  FF_TX_D_0_4             : in std_logic;
  FF_TX_D_0_5             : in std_logic;
  FF_TX_D_0_6             : in std_logic;
  FF_TX_D_0_7             : in std_logic;
  FF_TX_D_0_8             : in std_logic;
  FF_TX_D_0_9             : in std_logic;
  FF_TX_D_0_10             : in std_logic;
  FF_TX_D_0_11             : in std_logic;
  FF_TX_D_0_12             : in std_logic;
  FF_TX_D_0_13             : in std_logic;
  FF_TX_D_0_14             : in std_logic;
  FF_TX_D_0_15             : in std_logic;
  FF_TX_D_0_16             : in std_logic;
  FF_TX_D_0_17             : in std_logic;
  FF_TX_D_0_18             : in std_logic;
  FF_TX_D_0_19             : in std_logic;
  FF_TX_D_0_20             : in std_logic;
  FF_TX_D_0_21             : in std_logic;
  FF_TX_D_0_22             : in std_logic;
  FF_TX_D_0_23             : in std_logic;
  FF_TX_D_1_0             : in std_logic;
  FF_TX_D_1_1             : in std_logic;
  FF_TX_D_1_2             : in std_logic;
  FF_TX_D_1_3             : in std_logic;
  FF_TX_D_1_4             : in std_logic;
  FF_TX_D_1_5             : in std_logic;
  FF_TX_D_1_6             : in std_logic;
  FF_TX_D_1_7             : in std_logic;
  FF_TX_D_1_8             : in std_logic;
  FF_TX_D_1_9             : in std_logic;
  FF_TX_D_1_10             : in std_logic;
  FF_TX_D_1_11             : in std_logic;
  FF_TX_D_1_12             : in std_logic;
  FF_TX_D_1_13             : in std_logic;
  FF_TX_D_1_14             : in std_logic;
  FF_TX_D_1_15             : in std_logic;
  FF_TX_D_1_16             : in std_logic;
  FF_TX_D_1_17             : in std_logic;
  FF_TX_D_1_18             : in std_logic;
  FF_TX_D_1_19             : in std_logic;
  FF_TX_D_1_20             : in std_logic;
  FF_TX_D_1_21             : in std_logic;
  FF_TX_D_1_22             : in std_logic;
  FF_TX_D_1_23             : in std_logic;
  FF_TX_D_2_0             : in std_logic;
  FF_TX_D_2_1             : in std_logic;
  FF_TX_D_2_2             : in std_logic;
  FF_TX_D_2_3             : in std_logic;
  FF_TX_D_2_4             : in std_logic;
  FF_TX_D_2_5             : in std_logic;
  FF_TX_D_2_6             : in std_logic;
  FF_TX_D_2_7             : in std_logic;
  FF_TX_D_2_8             : in std_logic;
  FF_TX_D_2_9             : in std_logic;
  FF_TX_D_2_10             : in std_logic;
  FF_TX_D_2_11             : in std_logic;
  FF_TX_D_2_12             : in std_logic;
  FF_TX_D_2_13             : in std_logic;
  FF_TX_D_2_14             : in std_logic;
  FF_TX_D_2_15             : in std_logic;
  FF_TX_D_2_16             : in std_logic;
  FF_TX_D_2_17             : in std_logic;
  FF_TX_D_2_18             : in std_logic;
  FF_TX_D_2_19             : in std_logic;
  FF_TX_D_2_20             : in std_logic;
  FF_TX_D_2_21             : in std_logic;
  FF_TX_D_2_22             : in std_logic;
  FF_TX_D_2_23             : in std_logic;
  FF_TX_D_3_0             : in std_logic;
  FF_TX_D_3_1             : in std_logic;
  FF_TX_D_3_2             : in std_logic;
  FF_TX_D_3_3             : in std_logic;
  FF_TX_D_3_4             : in std_logic;
  FF_TX_D_3_5             : in std_logic;
  FF_TX_D_3_6             : in std_logic;
  FF_TX_D_3_7             : in std_logic;
  FF_TX_D_3_8             : in std_logic;
  FF_TX_D_3_9             : in std_logic;
  FF_TX_D_3_10             : in std_logic;
  FF_TX_D_3_11             : in std_logic;
  FF_TX_D_3_12             : in std_logic;
  FF_TX_D_3_13             : in std_logic;
  FF_TX_D_3_14             : in std_logic;
  FF_TX_D_3_15             : in std_logic;
  FF_TX_D_3_16             : in std_logic;
  FF_TX_D_3_17             : in std_logic;
  FF_TX_D_3_18             : in std_logic;
  FF_TX_D_3_19             : in std_logic;
  FF_TX_D_3_20             : in std_logic;
  FF_TX_D_3_21             : in std_logic;
  FF_TX_D_3_22             : in std_logic;
  FF_TX_D_3_23             : in std_logic;
  FF_TXI_CLK_0             : in std_logic;
  FF_TXI_CLK_1             : in std_logic;
  FF_TXI_CLK_2             : in std_logic;
  FF_TXI_CLK_3             : in std_logic;
  FFC_CK_CORE_RX_0         : in std_logic;
  FFC_CK_CORE_RX_1         : in std_logic;
  FFC_CK_CORE_RX_2         : in std_logic;
  FFC_CK_CORE_RX_3         : in std_logic;
  FFC_CK_CORE_TX           : in std_logic;
  FFC_EI_EN_0             : in std_logic;
  FFC_EI_EN_1             : in std_logic;
  FFC_EI_EN_2             : in std_logic;
  FFC_EI_EN_3             : in std_logic;
  FFC_ENABLE_CGALIGN_0             : in std_logic;
  FFC_ENABLE_CGALIGN_1             : in std_logic;
  FFC_ENABLE_CGALIGN_2             : in std_logic;
  FFC_ENABLE_CGALIGN_3             : in std_logic;
  FFC_FB_LOOPBACK_0             : in std_logic;
  FFC_FB_LOOPBACK_1             : in std_logic;
  FFC_FB_LOOPBACK_2             : in std_logic;
  FFC_FB_LOOPBACK_3             : in std_logic;
  FFC_LANE_RX_RST_0             : in std_logic;
  FFC_LANE_RX_RST_1             : in std_logic;
  FFC_LANE_RX_RST_2             : in std_logic;
  FFC_LANE_RX_RST_3             : in std_logic;
  FFC_LANE_TX_RST_0             : in std_logic;
  FFC_LANE_TX_RST_1             : in std_logic;
  FFC_LANE_TX_RST_2             : in std_logic;
  FFC_LANE_TX_RST_3             : in std_logic;
  FFC_MACRO_RST             : in std_logic;
  FFC_PCI_DET_EN_0             : in std_logic;
  FFC_PCI_DET_EN_1             : in std_logic;
  FFC_PCI_DET_EN_2             : in std_logic;
  FFC_PCI_DET_EN_3             : in std_logic;
  FFC_PCIE_CT_0             : in std_logic;
  FFC_PCIE_CT_1             : in std_logic;
  FFC_PCIE_CT_2             : in std_logic;
  FFC_PCIE_CT_3             : in std_logic;
  FFC_PFIFO_CLR_0             : in std_logic;
  FFC_PFIFO_CLR_1             : in std_logic;
  FFC_PFIFO_CLR_2             : in std_logic;
  FFC_PFIFO_CLR_3             : in std_logic;
  FFC_QUAD_RST             : in std_logic;
  FFC_RRST_0             : in std_logic;
  FFC_RRST_1             : in std_logic;
  FFC_RRST_2             : in std_logic;
  FFC_RRST_3             : in std_logic;
  FFC_RXPWDNB_0             : in std_logic;
  FFC_RXPWDNB_1             : in std_logic;
  FFC_RXPWDNB_2             : in std_logic;
  FFC_RXPWDNB_3             : in std_logic;
  FFC_SB_INV_RX_0             : in std_logic;
  FFC_SB_INV_RX_1             : in std_logic;
  FFC_SB_INV_RX_2             : in std_logic;
  FFC_SB_INV_RX_3             : in std_logic;
  FFC_SB_PFIFO_LP_0             : in std_logic;
  FFC_SB_PFIFO_LP_1             : in std_logic;
  FFC_SB_PFIFO_LP_2             : in std_logic;
  FFC_SB_PFIFO_LP_3             : in std_logic;
  FFC_SIGNAL_DETECT_0             : in std_logic;
  FFC_SIGNAL_DETECT_1             : in std_logic;
  FFC_SIGNAL_DETECT_2             : in std_logic;
  FFC_SIGNAL_DETECT_3             : in std_logic;
  FFC_SYNC_TOGGLE             : in std_logic;
  FFC_TRST             : in std_logic;
  FFC_TXPWDNB_0             : in std_logic;
  FFC_TXPWDNB_1             : in std_logic;
  FFC_TXPWDNB_2             : in std_logic;
  FFC_TXPWDNB_3             : in std_logic;
  FFC_RATE_MODE_RX_0        : in std_logic;
  FFC_RATE_MODE_RX_1        : in std_logic;
  FFC_RATE_MODE_RX_2        : in std_logic;
  FFC_RATE_MODE_RX_3        : in std_logic;
  FFC_RATE_MODE_TX_0        : in std_logic;
  FFC_RATE_MODE_TX_1        : in std_logic;
  FFC_RATE_MODE_TX_2        : in std_logic;
  FFC_RATE_MODE_TX_3        : in std_logic;
  FFC_DIV11_MODE_RX_0       : in std_logic;
  FFC_DIV11_MODE_RX_1       : in std_logic;
  FFC_DIV11_MODE_RX_2       : in std_logic;
  FFC_DIV11_MODE_RX_3       : in std_logic;
  FFC_DIV11_MODE_TX_0       : in std_logic;
  FFC_DIV11_MODE_TX_1       : in std_logic;
  FFC_DIV11_MODE_TX_2       : in std_logic;
  FFC_DIV11_MODE_TX_3       : in std_logic;
  LDR_CORE2TX_0             : in std_logic;
  LDR_CORE2TX_1             : in std_logic;
  LDR_CORE2TX_2             : in std_logic;
  LDR_CORE2TX_3             : in std_logic;
  FFC_LDR_CORE2TX_EN_0      : in std_logic;
  FFC_LDR_CORE2TX_EN_1      : in std_logic;
  FFC_LDR_CORE2TX_EN_2      : in std_logic;
  FFC_LDR_CORE2TX_EN_3      : in std_logic;
  PCIE_POWERDOWN_0_0      : in std_logic;
  PCIE_POWERDOWN_0_1      : in std_logic;
  PCIE_POWERDOWN_1_0      : in std_logic;
  PCIE_POWERDOWN_1_1      : in std_logic;
  PCIE_POWERDOWN_2_0      : in std_logic;
  PCIE_POWERDOWN_2_1      : in std_logic;
  PCIE_POWERDOWN_3_0      : in std_logic;
  PCIE_POWERDOWN_3_1      : in std_logic;
  PCIE_RXPOLARITY_0         : in std_logic;
  PCIE_RXPOLARITY_1         : in std_logic;
  PCIE_RXPOLARITY_2         : in std_logic;
  PCIE_RXPOLARITY_3         : in std_logic;
  PCIE_TXCOMPLIANCE_0       : in std_logic;
  PCIE_TXCOMPLIANCE_1       : in std_logic;
  PCIE_TXCOMPLIANCE_2       : in std_logic;
  PCIE_TXCOMPLIANCE_3       : in std_logic;
  PCIE_TXDETRX_PR2TLB_0     : in std_logic;
  PCIE_TXDETRX_PR2TLB_1     : in std_logic;
  PCIE_TXDETRX_PR2TLB_2     : in std_logic;
  PCIE_TXDETRX_PR2TLB_3     : in std_logic;
  SCIADDR0             : in std_logic;
  SCIADDR1             : in std_logic;
  SCIADDR2             : in std_logic;
  SCIADDR3             : in std_logic;
  SCIADDR4             : in std_logic;
  SCIADDR5             : in std_logic;
  SCIENAUX             : in std_logic;
  SCIENCH0             : in std_logic;
  SCIENCH1             : in std_logic;
  SCIENCH2             : in std_logic;
  SCIENCH3             : in std_logic;
  SCIRD                : in std_logic;
  SCISELAUX             : in std_logic;
  SCISELCH0             : in std_logic;
  SCISELCH1             : in std_logic;
  SCISELCH2             : in std_logic;
  SCISELCH3             : in std_logic;
  SCIWDATA0             : in std_logic;
  SCIWDATA1             : in std_logic;
  SCIWDATA2             : in std_logic;
  SCIWDATA3             : in std_logic;
  SCIWDATA4             : in std_logic;
  SCIWDATA5             : in std_logic;
  SCIWDATA6             : in std_logic;
  SCIWDATA7             : in std_logic;
  SCIWSTN               : in std_logic;
  REFCLK_FROM_NQ        : in std_logic;

  HDOUTN0             : out std_logic;
  HDOUTN1             : out std_logic;
  HDOUTN2             : out std_logic;
  HDOUTN3             : out std_logic;
  HDOUTP0             : out std_logic;
  HDOUTP1             : out std_logic;
  HDOUTP2             : out std_logic;
  HDOUTP3             : out std_logic;
  COUT0             : out std_logic;
  COUT1             : out std_logic;
  COUT2             : out std_logic;
  COUT3             : out std_logic;
  COUT4             : out std_logic;
  COUT5             : out std_logic;
  COUT6             : out std_logic;
  COUT7             : out std_logic;
  COUT8             : out std_logic;
  COUT9             : out std_logic;
  COUT10             : out std_logic;
  COUT11             : out std_logic;
  COUT12             : out std_logic;
  COUT13             : out std_logic;
  COUT14             : out std_logic;
  COUT15             : out std_logic;
  COUT16             : out std_logic;
  COUT17             : out std_logic;
  COUT18             : out std_logic;
  COUT19             : out std_logic;
  FF_RX_D_0_0             : out std_logic;
  FF_RX_D_0_1             : out std_logic;
  FF_RX_D_0_2             : out std_logic;
  FF_RX_D_0_3             : out std_logic;
  FF_RX_D_0_4             : out std_logic;
  FF_RX_D_0_5             : out std_logic;
  FF_RX_D_0_6             : out std_logic;
  FF_RX_D_0_7             : out std_logic;
  FF_RX_D_0_8             : out std_logic;
  FF_RX_D_0_9             : out std_logic;
  FF_RX_D_0_10             : out std_logic;
  FF_RX_D_0_11             : out std_logic;
  FF_RX_D_0_12             : out std_logic;
  FF_RX_D_0_13             : out std_logic;
  FF_RX_D_0_14             : out std_logic;
  FF_RX_D_0_15             : out std_logic;
  FF_RX_D_0_16             : out std_logic;
  FF_RX_D_0_17             : out std_logic;
  FF_RX_D_0_18             : out std_logic;
  FF_RX_D_0_19             : out std_logic;
  FF_RX_D_0_20             : out std_logic;
  FF_RX_D_0_21             : out std_logic;
  FF_RX_D_0_22             : out std_logic;
  FF_RX_D_0_23             : out std_logic;
  FF_RX_D_1_0             : out std_logic;
  FF_RX_D_1_1             : out std_logic;
  FF_RX_D_1_2             : out std_logic;
  FF_RX_D_1_3             : out std_logic;
  FF_RX_D_1_4             : out std_logic;
  FF_RX_D_1_5             : out std_logic;
  FF_RX_D_1_6             : out std_logic;
  FF_RX_D_1_7             : out std_logic;
  FF_RX_D_1_8             : out std_logic;
  FF_RX_D_1_9             : out std_logic;
  FF_RX_D_1_10             : out std_logic;
  FF_RX_D_1_11             : out std_logic;
  FF_RX_D_1_12             : out std_logic;
  FF_RX_D_1_13             : out std_logic;
  FF_RX_D_1_14             : out std_logic;
  FF_RX_D_1_15             : out std_logic;
  FF_RX_D_1_16             : out std_logic;
  FF_RX_D_1_17             : out std_logic;
  FF_RX_D_1_18             : out std_logic;
  FF_RX_D_1_19             : out std_logic;
  FF_RX_D_1_20             : out std_logic;
  FF_RX_D_1_21             : out std_logic;
  FF_RX_D_1_22             : out std_logic;
  FF_RX_D_1_23             : out std_logic;
  FF_RX_D_2_0             : out std_logic;
  FF_RX_D_2_1             : out std_logic;
  FF_RX_D_2_2             : out std_logic;
  FF_RX_D_2_3             : out std_logic;
  FF_RX_D_2_4             : out std_logic;
  FF_RX_D_2_5             : out std_logic;
  FF_RX_D_2_6             : out std_logic;
  FF_RX_D_2_7             : out std_logic;
  FF_RX_D_2_8             : out std_logic;
  FF_RX_D_2_9             : out std_logic;
  FF_RX_D_2_10             : out std_logic;
  FF_RX_D_2_11             : out std_logic;
  FF_RX_D_2_12             : out std_logic;
  FF_RX_D_2_13             : out std_logic;
  FF_RX_D_2_14             : out std_logic;
  FF_RX_D_2_15             : out std_logic;
  FF_RX_D_2_16             : out std_logic;
  FF_RX_D_2_17             : out std_logic;
  FF_RX_D_2_18             : out std_logic;
  FF_RX_D_2_19             : out std_logic;
  FF_RX_D_2_20             : out std_logic;
  FF_RX_D_2_21             : out std_logic;
  FF_RX_D_2_22             : out std_logic;
  FF_RX_D_2_23             : out std_logic;
  FF_RX_D_3_0             : out std_logic;
  FF_RX_D_3_1             : out std_logic;
  FF_RX_D_3_2             : out std_logic;
  FF_RX_D_3_3             : out std_logic;
  FF_RX_D_3_4             : out std_logic;
  FF_RX_D_3_5             : out std_logic;
  FF_RX_D_3_6             : out std_logic;
  FF_RX_D_3_7             : out std_logic;
  FF_RX_D_3_8             : out std_logic;
  FF_RX_D_3_9             : out std_logic;
  FF_RX_D_3_10             : out std_logic;
  FF_RX_D_3_11             : out std_logic;
  FF_RX_D_3_12             : out std_logic;
  FF_RX_D_3_13             : out std_logic;
  FF_RX_D_3_14             : out std_logic;
  FF_RX_D_3_15             : out std_logic;
  FF_RX_D_3_16             : out std_logic;
  FF_RX_D_3_17             : out std_logic;
  FF_RX_D_3_18             : out std_logic;
  FF_RX_D_3_19             : out std_logic;
  FF_RX_D_3_20             : out std_logic;
  FF_RX_D_3_21             : out std_logic;
  FF_RX_D_3_22             : out std_logic;
  FF_RX_D_3_23             : out std_logic;
  FF_RX_F_CLK_0             : out std_logic;
  FF_RX_F_CLK_1             : out std_logic;
  FF_RX_F_CLK_2             : out std_logic;
  FF_RX_F_CLK_3             : out std_logic;
  FF_RX_H_CLK_0             : out std_logic;
  FF_RX_H_CLK_1             : out std_logic;
  FF_RX_H_CLK_2             : out std_logic;
  FF_RX_H_CLK_3             : out std_logic;
  FF_TX_F_CLK_0             : out std_logic;
  FF_TX_F_CLK_1             : out std_logic;
  FF_TX_F_CLK_2             : out std_logic;
  FF_TX_F_CLK_3             : out std_logic;
  FF_TX_H_CLK_0             : out std_logic;
  FF_TX_H_CLK_1             : out std_logic;
  FF_TX_H_CLK_2             : out std_logic;
  FF_TX_H_CLK_3             : out std_logic;
  FFS_CC_OVERRUN_0             : out std_logic;
  FFS_CC_OVERRUN_1             : out std_logic;
  FFS_CC_OVERRUN_2             : out std_logic;
  FFS_CC_OVERRUN_3             : out std_logic;
  FFS_CC_UNDERRUN_0             : out std_logic;
  FFS_CC_UNDERRUN_1             : out std_logic;
  FFS_CC_UNDERRUN_2             : out std_logic;
  FFS_CC_UNDERRUN_3             : out std_logic;
  FFS_LS_SYNC_STATUS_0             : out std_logic;
  FFS_LS_SYNC_STATUS_1             : out std_logic;
  FFS_LS_SYNC_STATUS_2             : out std_logic;
  FFS_LS_SYNC_STATUS_3             : out std_logic;
  FFS_CDR_TRAIN_DONE_0             : out std_logic;
  FFS_CDR_TRAIN_DONE_1             : out std_logic;
  FFS_CDR_TRAIN_DONE_2             : out std_logic;
  FFS_CDR_TRAIN_DONE_3             : out std_logic;
  FFS_PCIE_CON_0             : out std_logic;
  FFS_PCIE_CON_1             : out std_logic;
  FFS_PCIE_CON_2             : out std_logic;
  FFS_PCIE_CON_3             : out std_logic;
  FFS_PCIE_DONE_0             : out std_logic;
  FFS_PCIE_DONE_1             : out std_logic;
  FFS_PCIE_DONE_2             : out std_logic;
  FFS_PCIE_DONE_3             : out std_logic;
  FFS_PLOL             : out std_logic;
  FFS_RLOL_0             : out std_logic;
  FFS_RLOL_1             : out std_logic;
  FFS_RLOL_2             : out std_logic;
  FFS_RLOL_3             : out std_logic;
  FFS_RLOS_HI_0             : out std_logic;
  FFS_RLOS_HI_1             : out std_logic;
  FFS_RLOS_HI_2             : out std_logic;
  FFS_RLOS_HI_3             : out std_logic;
  FFS_RLOS_LO_0             : out std_logic;
  FFS_RLOS_LO_1             : out std_logic;
  FFS_RLOS_LO_2             : out std_logic;
  FFS_RLOS_LO_3             : out std_logic;
  FFS_RXFBFIFO_ERROR_0             : out std_logic;
  FFS_RXFBFIFO_ERROR_1             : out std_logic;
  FFS_RXFBFIFO_ERROR_2             : out std_logic;
  FFS_RXFBFIFO_ERROR_3             : out std_logic;
  FFS_TXFBFIFO_ERROR_0             : out std_logic;
  FFS_TXFBFIFO_ERROR_1             : out std_logic;
  FFS_TXFBFIFO_ERROR_2             : out std_logic;
  FFS_TXFBFIFO_ERROR_3             : out std_logic;
  PCIE_PHYSTATUS_0             : out std_logic;
  PCIE_PHYSTATUS_1             : out std_logic;
  PCIE_PHYSTATUS_2             : out std_logic;
  PCIE_PHYSTATUS_3             : out std_logic;
  PCIE_RXVALID_0               : out std_logic;
  PCIE_RXVALID_1               : out std_logic;
  PCIE_RXVALID_2               : out std_logic;
  PCIE_RXVALID_3               : out std_logic;
  FFS_SKP_ADDED_0                  : out std_logic;
  FFS_SKP_ADDED_1                  : out std_logic;
  FFS_SKP_ADDED_2                  : out std_logic;
  FFS_SKP_ADDED_3                  : out std_logic;
  FFS_SKP_DELETED_0                : out std_logic;
  FFS_SKP_DELETED_1                : out std_logic;
  FFS_SKP_DELETED_2                : out std_logic;
  FFS_SKP_DELETED_3                : out std_logic;
  LDR_RX2CORE_0                    : out std_logic;
  LDR_RX2CORE_1                    : out std_logic;
  LDR_RX2CORE_2                    : out std_logic;
  LDR_RX2CORE_3                    : out std_logic;
  REFCK2CORE             : out std_logic;
  SCIINT                : out std_logic;
  SCIRDATA0             : out std_logic;
  SCIRDATA1             : out std_logic;
  SCIRDATA2             : out std_logic;
  SCIRDATA3             : out std_logic;
  SCIRDATA4             : out std_logic;
  SCIRDATA5             : out std_logic;
  SCIRDATA6             : out std_logic;
  SCIRDATA7             : out std_logic;
  REFCLK_TO_NQ          : out std_logic
);

end PCSD;

architecture PCSD_arch of PCSD is


component PCSD_sim
GENERIC(
  CONFIG_FILE : String;
  QUAD_MODE : String;
  CH0_CDR_SRC   : String;
  CH1_CDR_SRC   : String;
  CH2_CDR_SRC   : String;
  CH3_CDR_SRC   : String;
  PLL_SRC   : String
  );
port (
  HDINN0             : in std_logic;
  HDINN1             : in std_logic;
  HDINN2             : in std_logic;
  HDINN3             : in std_logic;
  HDINP0             : in std_logic;
  HDINP1             : in std_logic;
  HDINP2             : in std_logic;
  HDINP3             : in std_logic;
  REFCLKN             : in std_logic;
  REFCLKP             : in std_logic;
  CIN0             : in std_logic;
  CIN1             : in std_logic;
  CIN2             : in std_logic;
  CIN3             : in std_logic;
  CIN4             : in std_logic;
  CIN5             : in std_logic;
  CIN6             : in std_logic;
  CIN7             : in std_logic;
  CIN8             : in std_logic;
  CIN9             : in std_logic;
  CIN10             : in std_logic;
  CIN11             : in std_logic;
  CYAWSTN             : in std_logic;
  FF_EBRD_CLK_0             : in std_logic;
  FF_EBRD_CLK_1             : in std_logic;
  FF_EBRD_CLK_2             : in std_logic;
  FF_EBRD_CLK_3             : in std_logic;
  FF_RXI_CLK_0             : in std_logic;
  FF_RXI_CLK_1             : in std_logic;
  FF_RXI_CLK_2             : in std_logic;
  FF_RXI_CLK_3             : in std_logic;
  FF_TX_D_0_0             : in std_logic;
  FF_TX_D_0_1             : in std_logic;
  FF_TX_D_0_2             : in std_logic;
  FF_TX_D_0_3             : in std_logic;
  FF_TX_D_0_4             : in std_logic;
  FF_TX_D_0_5             : in std_logic;
  FF_TX_D_0_6             : in std_logic;
  FF_TX_D_0_7             : in std_logic;
  FF_TX_D_0_8             : in std_logic;
  FF_TX_D_0_9             : in std_logic;
  FF_TX_D_0_10             : in std_logic;
  FF_TX_D_0_11             : in std_logic;
  FF_TX_D_0_12             : in std_logic;
  FF_TX_D_0_13             : in std_logic;
  FF_TX_D_0_14             : in std_logic;
  FF_TX_D_0_15             : in std_logic;
  FF_TX_D_0_16             : in std_logic;
  FF_TX_D_0_17             : in std_logic;
  FF_TX_D_0_18             : in std_logic;
  FF_TX_D_0_19             : in std_logic;
  FF_TX_D_0_20             : in std_logic;
  FF_TX_D_0_21             : in std_logic;
  FF_TX_D_0_22             : in std_logic;
  FF_TX_D_0_23             : in std_logic;
  FF_TX_D_1_0             : in std_logic;
  FF_TX_D_1_1             : in std_logic;
  FF_TX_D_1_2             : in std_logic;
  FF_TX_D_1_3             : in std_logic;
  FF_TX_D_1_4             : in std_logic;
  FF_TX_D_1_5             : in std_logic;
  FF_TX_D_1_6             : in std_logic;
  FF_TX_D_1_7             : in std_logic;
  FF_TX_D_1_8             : in std_logic;
  FF_TX_D_1_9             : in std_logic;
  FF_TX_D_1_10             : in std_logic;
  FF_TX_D_1_11             : in std_logic;
  FF_TX_D_1_12             : in std_logic;
  FF_TX_D_1_13             : in std_logic;
  FF_TX_D_1_14             : in std_logic;
  FF_TX_D_1_15             : in std_logic;
  FF_TX_D_1_16             : in std_logic;
  FF_TX_D_1_17             : in std_logic;
  FF_TX_D_1_18             : in std_logic;
  FF_TX_D_1_19             : in std_logic;
  FF_TX_D_1_20             : in std_logic;
  FF_TX_D_1_21             : in std_logic;
  FF_TX_D_1_22             : in std_logic;
  FF_TX_D_1_23             : in std_logic;
  FF_TX_D_2_0             : in std_logic;
  FF_TX_D_2_1             : in std_logic;
  FF_TX_D_2_2             : in std_logic;
  FF_TX_D_2_3             : in std_logic;
  FF_TX_D_2_4             : in std_logic;
  FF_TX_D_2_5             : in std_logic;
  FF_TX_D_2_6             : in std_logic;
  FF_TX_D_2_7             : in std_logic;
  FF_TX_D_2_8             : in std_logic;
  FF_TX_D_2_9             : in std_logic;
  FF_TX_D_2_10             : in std_logic;
  FF_TX_D_2_11             : in std_logic;
  FF_TX_D_2_12             : in std_logic;
  FF_TX_D_2_13             : in std_logic;
  FF_TX_D_2_14             : in std_logic;
  FF_TX_D_2_15             : in std_logic;
  FF_TX_D_2_16             : in std_logic;
  FF_TX_D_2_17             : in std_logic;
  FF_TX_D_2_18             : in std_logic;
  FF_TX_D_2_19             : in std_logic;
  FF_TX_D_2_20             : in std_logic;
  FF_TX_D_2_21             : in std_logic;
  FF_TX_D_2_22             : in std_logic;
  FF_TX_D_2_23             : in std_logic;
  FF_TX_D_3_0             : in std_logic;
  FF_TX_D_3_1             : in std_logic;
  FF_TX_D_3_2             : in std_logic;
  FF_TX_D_3_3             : in std_logic;
  FF_TX_D_3_4             : in std_logic;
  FF_TX_D_3_5             : in std_logic;
  FF_TX_D_3_6             : in std_logic;
  FF_TX_D_3_7             : in std_logic;
  FF_TX_D_3_8             : in std_logic;
  FF_TX_D_3_9             : in std_logic;
  FF_TX_D_3_10             : in std_logic;
  FF_TX_D_3_11             : in std_logic;
  FF_TX_D_3_12             : in std_logic;
  FF_TX_D_3_13             : in std_logic;
  FF_TX_D_3_14             : in std_logic;
  FF_TX_D_3_15             : in std_logic;
  FF_TX_D_3_16             : in std_logic;
  FF_TX_D_3_17             : in std_logic;
  FF_TX_D_3_18             : in std_logic;
  FF_TX_D_3_19             : in std_logic;
  FF_TX_D_3_20             : in std_logic;
  FF_TX_D_3_21             : in std_logic;
  FF_TX_D_3_22             : in std_logic;
  FF_TX_D_3_23             : in std_logic;
  FF_TXI_CLK_0             : in std_logic;
  FF_TXI_CLK_1             : in std_logic;
  FF_TXI_CLK_2             : in std_logic;
  FF_TXI_CLK_3             : in std_logic;
  FFC_CK_CORE_RX_0         : in std_logic;
  FFC_CK_CORE_RX_1         : in std_logic;
  FFC_CK_CORE_RX_2         : in std_logic;
  FFC_CK_CORE_RX_3         : in std_logic;
  FFC_CK_CORE_TX           : in std_logic;
  FFC_EI_EN_0             : in std_logic;
  FFC_EI_EN_1             : in std_logic;
  FFC_EI_EN_2             : in std_logic;
  FFC_EI_EN_3             : in std_logic;
  FFC_ENABLE_CGALIGN_0             : in std_logic;
  FFC_ENABLE_CGALIGN_1             : in std_logic;
  FFC_ENABLE_CGALIGN_2             : in std_logic;
  FFC_ENABLE_CGALIGN_3             : in std_logic;
  FFC_FB_LOOPBACK_0             : in std_logic;
  FFC_FB_LOOPBACK_1             : in std_logic;
  FFC_FB_LOOPBACK_2             : in std_logic;
  FFC_FB_LOOPBACK_3             : in std_logic;
  FFC_LANE_RX_RST_0             : in std_logic;
  FFC_LANE_RX_RST_1             : in std_logic;
  FFC_LANE_RX_RST_2             : in std_logic;
  FFC_LANE_RX_RST_3             : in std_logic;
  FFC_LANE_TX_RST_0             : in std_logic;
  FFC_LANE_TX_RST_1             : in std_logic;
  FFC_LANE_TX_RST_2             : in std_logic;
  FFC_LANE_TX_RST_3             : in std_logic;
  FFC_MACRO_RST             : in std_logic;
  FFC_PCI_DET_EN_0             : in std_logic;
  FFC_PCI_DET_EN_1             : in std_logic;
  FFC_PCI_DET_EN_2             : in std_logic;
  FFC_PCI_DET_EN_3             : in std_logic;
  FFC_PCIE_CT_0             : in std_logic;
  FFC_PCIE_CT_1             : in std_logic;
  FFC_PCIE_CT_2             : in std_logic;
  FFC_PCIE_CT_3             : in std_logic;
  FFC_PFIFO_CLR_0             : in std_logic;
  FFC_PFIFO_CLR_1             : in std_logic;
  FFC_PFIFO_CLR_2             : in std_logic;
  FFC_PFIFO_CLR_3             : in std_logic;
  FFC_QUAD_RST             : in std_logic;
  FFC_RRST_0             : in std_logic;
  FFC_RRST_1             : in std_logic;
  FFC_RRST_2             : in std_logic;
  FFC_RRST_3             : in std_logic;
  FFC_RXPWDNB_0             : in std_logic;
  FFC_RXPWDNB_1             : in std_logic;
  FFC_RXPWDNB_2             : in std_logic;
  FFC_RXPWDNB_3             : in std_logic;
  FFC_SB_INV_RX_0             : in std_logic;
  FFC_SB_INV_RX_1             : in std_logic;
  FFC_SB_INV_RX_2             : in std_logic;
  FFC_SB_INV_RX_3             : in std_logic;
  FFC_SB_PFIFO_LP_0             : in std_logic;
  FFC_SB_PFIFO_LP_1             : in std_logic;
  FFC_SB_PFIFO_LP_2             : in std_logic;
  FFC_SB_PFIFO_LP_3             : in std_logic;
  FFC_SIGNAL_DETECT_0             : in std_logic;
  FFC_SIGNAL_DETECT_1             : in std_logic;
  FFC_SIGNAL_DETECT_2             : in std_logic;
  FFC_SIGNAL_DETECT_3             : in std_logic;
  FFC_SYNC_TOGGLE             : in std_logic;
  FFC_TRST             : in std_logic;
  FFC_TXPWDNB_0             : in std_logic;
  FFC_TXPWDNB_1             : in std_logic;
  FFC_TXPWDNB_2             : in std_logic;
  FFC_TXPWDNB_3             : in std_logic;
  FFC_RATE_MODE_RX_0        : in std_logic;
  FFC_RATE_MODE_RX_1        : in std_logic;
  FFC_RATE_MODE_RX_2        : in std_logic;
  FFC_RATE_MODE_RX_3        : in std_logic;
  FFC_RATE_MODE_TX_0        : in std_logic;
  FFC_RATE_MODE_TX_1        : in std_logic;
  FFC_RATE_MODE_TX_2        : in std_logic;
  FFC_RATE_MODE_TX_3        : in std_logic;
  FFC_DIV11_MODE_RX_0       : in std_logic;
  FFC_DIV11_MODE_RX_1       : in std_logic;
  FFC_DIV11_MODE_RX_2       : in std_logic;
  FFC_DIV11_MODE_RX_3       : in std_logic;
  FFC_DIV11_MODE_TX_0       : in std_logic;
  FFC_DIV11_MODE_TX_1       : in std_logic;
  FFC_DIV11_MODE_TX_2       : in std_logic;
  FFC_DIV11_MODE_TX_3       : in std_logic;
  LDR_CORE2TX_0             : in std_logic;
  LDR_CORE2TX_1             : in std_logic;
  LDR_CORE2TX_2             : in std_logic;
  LDR_CORE2TX_3             : in std_logic;
  FFC_LDR_CORE2TX_EN_0      : in std_logic;
  FFC_LDR_CORE2TX_EN_1      : in std_logic;
  FFC_LDR_CORE2TX_EN_2      : in std_logic;
  FFC_LDR_CORE2TX_EN_3      : in std_logic;
  PCIE_POWERDOWN_0_0      : in std_logic;
  PCIE_POWERDOWN_0_1      : in std_logic;
  PCIE_POWERDOWN_1_0      : in std_logic;
  PCIE_POWERDOWN_1_1      : in std_logic;
  PCIE_POWERDOWN_2_0      : in std_logic;
  PCIE_POWERDOWN_2_1      : in std_logic;
  PCIE_POWERDOWN_3_0      : in std_logic;
  PCIE_POWERDOWN_3_1      : in std_logic;
  PCIE_RXPOLARITY_0         : in std_logic;
  PCIE_RXPOLARITY_1         : in std_logic;
  PCIE_RXPOLARITY_2         : in std_logic;
  PCIE_RXPOLARITY_3         : in std_logic;
  PCIE_TXCOMPLIANCE_0       : in std_logic;
  PCIE_TXCOMPLIANCE_1       : in std_logic;
  PCIE_TXCOMPLIANCE_2       : in std_logic;
  PCIE_TXCOMPLIANCE_3       : in std_logic;
  PCIE_TXDETRX_PR2TLB_0     : in std_logic;
  PCIE_TXDETRX_PR2TLB_1     : in std_logic;
  PCIE_TXDETRX_PR2TLB_2     : in std_logic;
  PCIE_TXDETRX_PR2TLB_3     : in std_logic;
  SCIADDR0             : in std_logic;
  SCIADDR1             : in std_logic;
  SCIADDR2             : in std_logic;
  SCIADDR3             : in std_logic;
  SCIADDR4             : in std_logic;
  SCIADDR5             : in std_logic;
  SCIENAUX             : in std_logic;
  SCIENCH0             : in std_logic;
  SCIENCH1             : in std_logic;
  SCIENCH2             : in std_logic;
  SCIENCH3             : in std_logic;
  SCIRD                : in std_logic;
  SCISELAUX             : in std_logic;
  SCISELCH0             : in std_logic;
  SCISELCH1             : in std_logic;
  SCISELCH2             : in std_logic;
  SCISELCH3             : in std_logic;
  SCIWDATA0             : in std_logic;
  SCIWDATA1             : in std_logic;
  SCIWDATA2             : in std_logic;
  SCIWDATA3             : in std_logic;
  SCIWDATA4             : in std_logic;
  SCIWDATA5             : in std_logic;
  SCIWDATA6             : in std_logic;
  SCIWDATA7             : in std_logic;
  SCIWSTN               : in std_logic;
  REFCLK_FROM_NQ        : in std_logic;

  HDOUTN0             : out std_logic;
  HDOUTN1             : out std_logic;
  HDOUTN2             : out std_logic;
  HDOUTN3             : out std_logic;
  HDOUTP0             : out std_logic;
  HDOUTP1             : out std_logic;
  HDOUTP2             : out std_logic;
  HDOUTP3             : out std_logic;
  COUT0             : out std_logic;
  COUT1             : out std_logic;
  COUT2             : out std_logic;
  COUT3             : out std_logic;
  COUT4             : out std_logic;
  COUT5             : out std_logic;
  COUT6             : out std_logic;
  COUT7             : out std_logic;
  COUT8             : out std_logic;
  COUT9             : out std_logic;
  COUT10             : out std_logic;
  COUT11             : out std_logic;
  COUT12             : out std_logic;
  COUT13             : out std_logic;
  COUT14             : out std_logic;
  COUT15             : out std_logic;
  COUT16             : out std_logic;
  COUT17             : out std_logic;
  COUT18             : out std_logic;
  COUT19             : out std_logic;
  FF_RX_D_0_0             : out std_logic;
  FF_RX_D_0_1             : out std_logic;
  FF_RX_D_0_2             : out std_logic;
  FF_RX_D_0_3             : out std_logic;
  FF_RX_D_0_4             : out std_logic;
  FF_RX_D_0_5             : out std_logic;
  FF_RX_D_0_6             : out std_logic;
  FF_RX_D_0_7             : out std_logic;
  FF_RX_D_0_8             : out std_logic;
  FF_RX_D_0_9             : out std_logic;
  FF_RX_D_0_10             : out std_logic;
  FF_RX_D_0_11             : out std_logic;
  FF_RX_D_0_12             : out std_logic;
  FF_RX_D_0_13             : out std_logic;
  FF_RX_D_0_14             : out std_logic;
  FF_RX_D_0_15             : out std_logic;
  FF_RX_D_0_16             : out std_logic;
  FF_RX_D_0_17             : out std_logic;
  FF_RX_D_0_18             : out std_logic;
  FF_RX_D_0_19             : out std_logic;
  FF_RX_D_0_20             : out std_logic;
  FF_RX_D_0_21             : out std_logic;
  FF_RX_D_0_22             : out std_logic;
  FF_RX_D_0_23             : out std_logic;
  FF_RX_D_1_0             : out std_logic;
  FF_RX_D_1_1             : out std_logic;
  FF_RX_D_1_2             : out std_logic;
  FF_RX_D_1_3             : out std_logic;
  FF_RX_D_1_4             : out std_logic;
  FF_RX_D_1_5             : out std_logic;
  FF_RX_D_1_6             : out std_logic;
  FF_RX_D_1_7             : out std_logic;
  FF_RX_D_1_8             : out std_logic;
  FF_RX_D_1_9             : out std_logic;
  FF_RX_D_1_10             : out std_logic;
  FF_RX_D_1_11             : out std_logic;
  FF_RX_D_1_12             : out std_logic;
  FF_RX_D_1_13             : out std_logic;
  FF_RX_D_1_14             : out std_logic;
  FF_RX_D_1_15             : out std_logic;
  FF_RX_D_1_16             : out std_logic;
  FF_RX_D_1_17             : out std_logic;
  FF_RX_D_1_18             : out std_logic;
  FF_RX_D_1_19             : out std_logic;
  FF_RX_D_1_20             : out std_logic;
  FF_RX_D_1_21             : out std_logic;
  FF_RX_D_1_22             : out std_logic;
  FF_RX_D_1_23             : out std_logic;
  FF_RX_D_2_0             : out std_logic;
  FF_RX_D_2_1             : out std_logic;
  FF_RX_D_2_2             : out std_logic;
  FF_RX_D_2_3             : out std_logic;
  FF_RX_D_2_4             : out std_logic;
  FF_RX_D_2_5             : out std_logic;
  FF_RX_D_2_6             : out std_logic;
  FF_RX_D_2_7             : out std_logic;
  FF_RX_D_2_8             : out std_logic;
  FF_RX_D_2_9             : out std_logic;
  FF_RX_D_2_10             : out std_logic;
  FF_RX_D_2_11             : out std_logic;
  FF_RX_D_2_12             : out std_logic;
  FF_RX_D_2_13             : out std_logic;
  FF_RX_D_2_14             : out std_logic;
  FF_RX_D_2_15             : out std_logic;
  FF_RX_D_2_16             : out std_logic;
  FF_RX_D_2_17             : out std_logic;
  FF_RX_D_2_18             : out std_logic;
  FF_RX_D_2_19             : out std_logic;
  FF_RX_D_2_20             : out std_logic;
  FF_RX_D_2_21             : out std_logic;
  FF_RX_D_2_22             : out std_logic;
  FF_RX_D_2_23             : out std_logic;
  FF_RX_D_3_0             : out std_logic;
  FF_RX_D_3_1             : out std_logic;
  FF_RX_D_3_2             : out std_logic;
  FF_RX_D_3_3             : out std_logic;
  FF_RX_D_3_4             : out std_logic;
  FF_RX_D_3_5             : out std_logic;
  FF_RX_D_3_6             : out std_logic;
  FF_RX_D_3_7             : out std_logic;
  FF_RX_D_3_8             : out std_logic;
  FF_RX_D_3_9             : out std_logic;
  FF_RX_D_3_10             : out std_logic;
  FF_RX_D_3_11             : out std_logic;
  FF_RX_D_3_12             : out std_logic;
  FF_RX_D_3_13             : out std_logic;
  FF_RX_D_3_14             : out std_logic;
  FF_RX_D_3_15             : out std_logic;
  FF_RX_D_3_16             : out std_logic;
  FF_RX_D_3_17             : out std_logic;
  FF_RX_D_3_18             : out std_logic;
  FF_RX_D_3_19             : out std_logic;
  FF_RX_D_3_20             : out std_logic;
  FF_RX_D_3_21             : out std_logic;
  FF_RX_D_3_22             : out std_logic;
  FF_RX_D_3_23             : out std_logic;
  FF_RX_F_CLK_0             : out std_logic;
  FF_RX_F_CLK_1             : out std_logic;
  FF_RX_F_CLK_2             : out std_logic;
  FF_RX_F_CLK_3             : out std_logic;
  FF_RX_H_CLK_0             : out std_logic;
  FF_RX_H_CLK_1             : out std_logic;
  FF_RX_H_CLK_2             : out std_logic;
  FF_RX_H_CLK_3             : out std_logic;
  FF_TX_F_CLK_0             : out std_logic;
  FF_TX_F_CLK_1             : out std_logic;
  FF_TX_F_CLK_2             : out std_logic;
  FF_TX_F_CLK_3             : out std_logic;
  FF_TX_H_CLK_0             : out std_logic;
  FF_TX_H_CLK_1             : out std_logic;
  FF_TX_H_CLK_2             : out std_logic;
  FF_TX_H_CLK_3             : out std_logic;
  FFS_CC_OVERRUN_0             : out std_logic;
  FFS_CC_OVERRUN_1             : out std_logic;
  FFS_CC_OVERRUN_2             : out std_logic;
  FFS_CC_OVERRUN_3             : out std_logic;
  FFS_CC_UNDERRUN_0             : out std_logic;
  FFS_CC_UNDERRUN_1             : out std_logic;
  FFS_CC_UNDERRUN_2             : out std_logic;
  FFS_CC_UNDERRUN_3             : out std_logic;
  FFS_LS_SYNC_STATUS_0             : out std_logic;
  FFS_LS_SYNC_STATUS_1             : out std_logic;
  FFS_LS_SYNC_STATUS_2             : out std_logic;
  FFS_LS_SYNC_STATUS_3             : out std_logic;
  FFS_CDR_TRAIN_DONE_0             : out std_logic;
  FFS_CDR_TRAIN_DONE_1             : out std_logic;
  FFS_CDR_TRAIN_DONE_2             : out std_logic;
  FFS_CDR_TRAIN_DONE_3             : out std_logic;
  FFS_PCIE_CON_0             : out std_logic;
  FFS_PCIE_CON_1             : out std_logic;
  FFS_PCIE_CON_2             : out std_logic;
  FFS_PCIE_CON_3             : out std_logic;
  FFS_PCIE_DONE_0             : out std_logic;
  FFS_PCIE_DONE_1             : out std_logic;
  FFS_PCIE_DONE_2             : out std_logic;
  FFS_PCIE_DONE_3             : out std_logic;
  FFS_PLOL             : out std_logic;
  FFS_RLOL_0             : out std_logic;
  FFS_RLOL_1             : out std_logic;
  FFS_RLOL_2             : out std_logic;
  FFS_RLOL_3             : out std_logic;
  FFS_RLOS_HI_0             : out std_logic;
  FFS_RLOS_HI_1             : out std_logic;
  FFS_RLOS_HI_2             : out std_logic;
  FFS_RLOS_HI_3             : out std_logic;
  FFS_RLOS_LO_0             : out std_logic;
  FFS_RLOS_LO_1             : out std_logic;
  FFS_RLOS_LO_2             : out std_logic;
  FFS_RLOS_LO_3             : out std_logic;
  FFS_RXFBFIFO_ERROR_0             : out std_logic;
  FFS_RXFBFIFO_ERROR_1             : out std_logic;
  FFS_RXFBFIFO_ERROR_2             : out std_logic;
  FFS_RXFBFIFO_ERROR_3             : out std_logic;
  FFS_TXFBFIFO_ERROR_0             : out std_logic;
  FFS_TXFBFIFO_ERROR_1             : out std_logic;
  FFS_TXFBFIFO_ERROR_2             : out std_logic;
  FFS_TXFBFIFO_ERROR_3             : out std_logic;
  PCIE_PHYSTATUS_0             : out std_logic;
  PCIE_PHYSTATUS_1             : out std_logic;
  PCIE_PHYSTATUS_2             : out std_logic;
  PCIE_PHYSTATUS_3             : out std_logic;
  PCIE_RXVALID_0               : out std_logic;
  PCIE_RXVALID_1               : out std_logic;
  PCIE_RXVALID_2               : out std_logic;
  PCIE_RXVALID_3               : out std_logic;
  FFS_SKP_ADDED_0                  : out std_logic;
  FFS_SKP_ADDED_1                  : out std_logic;
  FFS_SKP_ADDED_2                  : out std_logic;
  FFS_SKP_ADDED_3                  : out std_logic;
  FFS_SKP_DELETED_0                : out std_logic;
  FFS_SKP_DELETED_1                : out std_logic;
  FFS_SKP_DELETED_2                : out std_logic;
  FFS_SKP_DELETED_3                : out std_logic;
  LDR_RX2CORE_0                    : out std_logic;
  LDR_RX2CORE_1                    : out std_logic;
  LDR_RX2CORE_2                    : out std_logic;
  LDR_RX2CORE_3                    : out std_logic;
  REFCK2CORE             : out std_logic;
  SCIINT                : out std_logic;
  SCIRDATA0             : out std_logic;
  SCIRDATA1             : out std_logic;
  SCIRDATA2             : out std_logic;
  SCIRDATA3             : out std_logic;
  SCIRDATA4             : out std_logic;
  SCIRDATA5             : out std_logic;
  SCIRDATA6             : out std_logic;
  SCIRDATA7             : out std_logic;
  REFCLK_TO_NQ          : out std_logic
);
end component;

begin

PCSD_sim_inst : PCSD_sim
generic map (
  CONFIG_FILE => CONFIG_FILE,
  QUAD_MODE => QUAD_MODE,
  CH0_CDR_SRC => CH0_CDR_SRC,
  CH1_CDR_SRC => CH1_CDR_SRC,
  CH2_CDR_SRC => CH2_CDR_SRC,
  CH3_CDR_SRC => CH3_CDR_SRC,
  PLL_SRC => PLL_SRC
  )
port map (
   HDINN0 => HDINN0,
   HDINN1 => HDINN1,
   HDINN2 => HDINN2,
   HDINN3 => HDINN3,
   HDINP0 => HDINP0,
   HDINP1 => HDINP1,
   HDINP2 => HDINP2,
   HDINP3 => HDINP3,
   REFCLKN => REFCLKN,
   REFCLKP => REFCLKP,
   CIN11 => CIN11,
   CIN10 => CIN10,
   CIN9 => CIN9,
   CIN8 => CIN8,
   CIN7 => CIN7,
   CIN6 => CIN6,
   CIN5 => CIN5,
   CIN4 => CIN4,
   CIN3 => CIN3,
   CIN2 => CIN2,
   CIN1 => CIN1,
   CIN0 => CIN0,
   CYAWSTN => CYAWSTN,
   FF_EBRD_CLK_3 => FF_EBRD_CLK_3,
   FF_EBRD_CLK_2 => FF_EBRD_CLK_2,
   FF_EBRD_CLK_1 => FF_EBRD_CLK_1,
   FF_EBRD_CLK_0 => FF_EBRD_CLK_0,
   FF_RXI_CLK_3 => FF_RXI_CLK_3,
   FF_RXI_CLK_2 => FF_RXI_CLK_2,
   FF_RXI_CLK_1 => FF_RXI_CLK_1,
   FF_RXI_CLK_0 => FF_RXI_CLK_0,
   FF_TX_D_0_0 => FF_TX_D_0_0,
   FF_TX_D_0_1 => FF_TX_D_0_1,
   FF_TX_D_0_2 => FF_TX_D_0_2,
   FF_TX_D_0_3 => FF_TX_D_0_3,
   FF_TX_D_0_4 => FF_TX_D_0_4,
   FF_TX_D_0_5 => FF_TX_D_0_5,
   FF_TX_D_0_6 => FF_TX_D_0_6,
   FF_TX_D_0_7 => FF_TX_D_0_7,
   FF_TX_D_0_8 => FF_TX_D_0_8,
   FF_TX_D_0_9 => FF_TX_D_0_9,
   FF_TX_D_0_10 => FF_TX_D_0_10,
   FF_TX_D_0_11 => FF_TX_D_0_11,
   FF_TX_D_0_12 => FF_TX_D_0_12,
   FF_TX_D_0_13 => FF_TX_D_0_13,
   FF_TX_D_0_14 => FF_TX_D_0_14,
   FF_TX_D_0_15 => FF_TX_D_0_15,
   FF_TX_D_0_16 => FF_TX_D_0_16,
   FF_TX_D_0_17 => FF_TX_D_0_17,
   FF_TX_D_0_18 => FF_TX_D_0_18,
   FF_TX_D_0_19 => FF_TX_D_0_19,
   FF_TX_D_0_20 => FF_TX_D_0_20,
   FF_TX_D_0_21 => FF_TX_D_0_21,
   FF_TX_D_0_22 => FF_TX_D_0_22,
   FF_TX_D_0_23 => FF_TX_D_0_23,
   FF_TX_D_1_0 => FF_TX_D_1_0,
   FF_TX_D_1_1 => FF_TX_D_1_1,
   FF_TX_D_1_2 => FF_TX_D_1_2,
   FF_TX_D_1_3 => FF_TX_D_1_3,
   FF_TX_D_1_4 => FF_TX_D_1_4,
   FF_TX_D_1_5 => FF_TX_D_1_5,
   FF_TX_D_1_6 => FF_TX_D_1_6,
   FF_TX_D_1_7 => FF_TX_D_1_7,
   FF_TX_D_1_8 => FF_TX_D_1_8,
   FF_TX_D_1_9 => FF_TX_D_1_9,
   FF_TX_D_1_10 => FF_TX_D_1_10,
   FF_TX_D_1_11 => FF_TX_D_1_11,
   FF_TX_D_1_12 => FF_TX_D_1_12,
   FF_TX_D_1_13 => FF_TX_D_1_13,
   FF_TX_D_1_14 => FF_TX_D_1_14,
   FF_TX_D_1_15 => FF_TX_D_1_15,
   FF_TX_D_1_16 => FF_TX_D_1_16,
   FF_TX_D_1_17 => FF_TX_D_1_17,
   FF_TX_D_1_18 => FF_TX_D_1_18,
   FF_TX_D_1_19 => FF_TX_D_1_19,
   FF_TX_D_1_20 => FF_TX_D_1_20,
   FF_TX_D_1_21 => FF_TX_D_1_21,
   FF_TX_D_1_22 => FF_TX_D_1_22,
   FF_TX_D_1_23 => FF_TX_D_1_23,
   FF_TX_D_2_0 => FF_TX_D_2_0,
   FF_TX_D_2_1 => FF_TX_D_2_1,
   FF_TX_D_2_2 => FF_TX_D_2_2,
   FF_TX_D_2_3 => FF_TX_D_2_3,
   FF_TX_D_2_4 => FF_TX_D_2_4,
   FF_TX_D_2_5 => FF_TX_D_2_5,
   FF_TX_D_2_6 => FF_TX_D_2_6,
   FF_TX_D_2_7 => FF_TX_D_2_7,
   FF_TX_D_2_8 => FF_TX_D_2_8,
   FF_TX_D_2_9 => FF_TX_D_2_9,
   FF_TX_D_2_10 => FF_TX_D_2_10,
   FF_TX_D_2_11 => FF_TX_D_2_11,
   FF_TX_D_2_12 => FF_TX_D_2_12,
   FF_TX_D_2_13 => FF_TX_D_2_13,
   FF_TX_D_2_14 => FF_TX_D_2_14,
   FF_TX_D_2_15 => FF_TX_D_2_15,
   FF_TX_D_2_16 => FF_TX_D_2_16,
   FF_TX_D_2_17 => FF_TX_D_2_17,
   FF_TX_D_2_18 => FF_TX_D_2_18,
   FF_TX_D_2_19 => FF_TX_D_2_19,
   FF_TX_D_2_20 => FF_TX_D_2_20,
   FF_TX_D_2_21 => FF_TX_D_2_21,
   FF_TX_D_2_22 => FF_TX_D_2_22,
   FF_TX_D_2_23 => FF_TX_D_2_23,
   FF_TX_D_3_0 => FF_TX_D_3_0,
   FF_TX_D_3_1 => FF_TX_D_3_1,
   FF_TX_D_3_2 => FF_TX_D_3_2,
   FF_TX_D_3_3 => FF_TX_D_3_3,
   FF_TX_D_3_4 => FF_TX_D_3_4,
   FF_TX_D_3_5 => FF_TX_D_3_5,
   FF_TX_D_3_6 => FF_TX_D_3_6,
   FF_TX_D_3_7 => FF_TX_D_3_7,
   FF_TX_D_3_8 => FF_TX_D_3_8,
   FF_TX_D_3_9 => FF_TX_D_3_9,
   FF_TX_D_3_10 => FF_TX_D_3_10,
   FF_TX_D_3_11 => FF_TX_D_3_11,
   FF_TX_D_3_12 => FF_TX_D_3_12,
   FF_TX_D_3_13 => FF_TX_D_3_13,
   FF_TX_D_3_14 => FF_TX_D_3_14,
   FF_TX_D_3_15 => FF_TX_D_3_15,
   FF_TX_D_3_16 => FF_TX_D_3_16,
   FF_TX_D_3_17 => FF_TX_D_3_17,
   FF_TX_D_3_18 => FF_TX_D_3_18,
   FF_TX_D_3_19 => FF_TX_D_3_19,
   FF_TX_D_3_20 => FF_TX_D_3_20,
   FF_TX_D_3_21 => FF_TX_D_3_21,
   FF_TX_D_3_22 => FF_TX_D_3_22,
   FF_TX_D_3_23 => FF_TX_D_3_23,
   FF_TXI_CLK_0 => FF_TXI_CLK_0,
   FF_TXI_CLK_1 => FF_TXI_CLK_1,
   FF_TXI_CLK_2 => FF_TXI_CLK_2,
   FF_TXI_CLK_3 => FF_TXI_CLK_3,
   FFC_CK_CORE_RX_0 => FFC_CK_CORE_RX_0,
   FFC_CK_CORE_RX_1 => FFC_CK_CORE_RX_1,
   FFC_CK_CORE_RX_2 => FFC_CK_CORE_RX_2,
   FFC_CK_CORE_RX_3 => FFC_CK_CORE_RX_3,
   FFC_CK_CORE_TX => FFC_CK_CORE_TX,
   FFC_EI_EN_0 => FFC_EI_EN_0,
   FFC_EI_EN_1 => FFC_EI_EN_1,
   FFC_EI_EN_2 => FFC_EI_EN_2,
   FFC_EI_EN_3 => FFC_EI_EN_3,
   FFC_ENABLE_CGALIGN_0 => FFC_ENABLE_CGALIGN_0,
   FFC_ENABLE_CGALIGN_1 => FFC_ENABLE_CGALIGN_1,
   FFC_ENABLE_CGALIGN_2 => FFC_ENABLE_CGALIGN_2,
   FFC_ENABLE_CGALIGN_3 => FFC_ENABLE_CGALIGN_3,
   FFC_FB_LOOPBACK_0 => FFC_FB_LOOPBACK_0,
   FFC_FB_LOOPBACK_1 => FFC_FB_LOOPBACK_1,
   FFC_FB_LOOPBACK_2 => FFC_FB_LOOPBACK_2,
   FFC_FB_LOOPBACK_3 => FFC_FB_LOOPBACK_3,
   FFC_LANE_RX_RST_0 => FFC_LANE_RX_RST_0,
   FFC_LANE_RX_RST_1 => FFC_LANE_RX_RST_1,
   FFC_LANE_RX_RST_2 => FFC_LANE_RX_RST_2,
   FFC_LANE_RX_RST_3 => FFC_LANE_RX_RST_3,
   FFC_LANE_TX_RST_0 => FFC_LANE_TX_RST_0,
   FFC_LANE_TX_RST_1 => FFC_LANE_TX_RST_1,
   FFC_LANE_TX_RST_2 => FFC_LANE_TX_RST_2,
   FFC_LANE_TX_RST_3 => FFC_LANE_TX_RST_3,
   FFC_MACRO_RST => FFC_MACRO_RST,
   FFC_PCI_DET_EN_0 => FFC_PCI_DET_EN_0,
   FFC_PCI_DET_EN_1 => FFC_PCI_DET_EN_1,
   FFC_PCI_DET_EN_2 => FFC_PCI_DET_EN_2,
   FFC_PCI_DET_EN_3 => FFC_PCI_DET_EN_3,
   FFC_PCIE_CT_0 => FFC_PCIE_CT_0,
   FFC_PCIE_CT_1 => FFC_PCIE_CT_1,
   FFC_PCIE_CT_2 => FFC_PCIE_CT_2,
   FFC_PCIE_CT_3 => FFC_PCIE_CT_3,
   FFC_PFIFO_CLR_0 => FFC_PFIFO_CLR_0,
   FFC_PFIFO_CLR_1 => FFC_PFIFO_CLR_1,
   FFC_PFIFO_CLR_2 => FFC_PFIFO_CLR_2,
   FFC_PFIFO_CLR_3 => FFC_PFIFO_CLR_3,
   FFC_QUAD_RST => FFC_QUAD_RST,
   FFC_RRST_0 => FFC_RRST_0,
   FFC_RRST_1 => FFC_RRST_1,
   FFC_RRST_2 => FFC_RRST_2,
   FFC_RRST_3 => FFC_RRST_3,
   FFC_RXPWDNB_0 => FFC_RXPWDNB_0,
   FFC_RXPWDNB_1 => FFC_RXPWDNB_1,
   FFC_RXPWDNB_2 => FFC_RXPWDNB_2,
   FFC_RXPWDNB_3 => FFC_RXPWDNB_3,
   FFC_SB_INV_RX_0 => FFC_SB_INV_RX_0,
   FFC_SB_INV_RX_1 => FFC_SB_INV_RX_1,
   FFC_SB_INV_RX_2 => FFC_SB_INV_RX_2,
   FFC_SB_INV_RX_3 => FFC_SB_INV_RX_3,
   FFC_SB_PFIFO_LP_0 => FFC_SB_PFIFO_LP_0,
   FFC_SB_PFIFO_LP_1 => FFC_SB_PFIFO_LP_1,
   FFC_SB_PFIFO_LP_2 => FFC_SB_PFIFO_LP_2,
   FFC_SB_PFIFO_LP_3 => FFC_SB_PFIFO_LP_3,
   FFC_SIGNAL_DETECT_0 => FFC_SIGNAL_DETECT_0,
   FFC_SIGNAL_DETECT_1 => FFC_SIGNAL_DETECT_1,
   FFC_SIGNAL_DETECT_2 => FFC_SIGNAL_DETECT_2,
   FFC_SIGNAL_DETECT_3 => FFC_SIGNAL_DETECT_3,
   FFC_SYNC_TOGGLE => FFC_SYNC_TOGGLE,
   FFC_TRST => FFC_TRST,
   FFC_TXPWDNB_0 => FFC_TXPWDNB_0,
   FFC_TXPWDNB_1 => FFC_TXPWDNB_1,
   FFC_TXPWDNB_2 => FFC_TXPWDNB_2,
   FFC_TXPWDNB_3 => FFC_TXPWDNB_3,
   FFC_RATE_MODE_RX_0 => FFC_RATE_MODE_RX_0,
   FFC_RATE_MODE_RX_1 => FFC_RATE_MODE_RX_1,
   FFC_RATE_MODE_RX_2 => FFC_RATE_MODE_RX_2,
   FFC_RATE_MODE_RX_3 => FFC_RATE_MODE_RX_3,
   FFC_RATE_MODE_TX_0 => FFC_RATE_MODE_TX_0,
   FFC_RATE_MODE_TX_1 => FFC_RATE_MODE_TX_1,
   FFC_RATE_MODE_TX_2 => FFC_RATE_MODE_TX_2,
   FFC_RATE_MODE_TX_3 => FFC_RATE_MODE_TX_3,
   FFC_DIV11_MODE_RX_0 => FFC_DIV11_MODE_RX_0,
   FFC_DIV11_MODE_RX_1 => FFC_DIV11_MODE_RX_1,
   FFC_DIV11_MODE_RX_2 => FFC_DIV11_MODE_RX_2,
   FFC_DIV11_MODE_RX_3 => FFC_DIV11_MODE_RX_3,
   FFC_DIV11_MODE_TX_0 => FFC_DIV11_MODE_TX_0,
   FFC_DIV11_MODE_TX_1 => FFC_DIV11_MODE_TX_1,
   FFC_DIV11_MODE_TX_2 => FFC_DIV11_MODE_TX_2,
   FFC_DIV11_MODE_TX_3 => FFC_DIV11_MODE_TX_3,
   LDR_CORE2TX_0 => LDR_CORE2TX_0,
   LDR_CORE2TX_1 => LDR_CORE2TX_1,
   LDR_CORE2TX_2 => LDR_CORE2TX_2,
   LDR_CORE2TX_3 => LDR_CORE2TX_3,
   FFC_LDR_CORE2TX_EN_0 => FFC_LDR_CORE2TX_EN_0,
   FFC_LDR_CORE2TX_EN_1 => FFC_LDR_CORE2TX_EN_1,
   FFC_LDR_CORE2TX_EN_2 => FFC_LDR_CORE2TX_EN_2,
   FFC_LDR_CORE2TX_EN_3 => FFC_LDR_CORE2TX_EN_3,
   PCIE_POWERDOWN_0_0 => PCIE_POWERDOWN_0_0,
   PCIE_POWERDOWN_0_1 => PCIE_POWERDOWN_0_1,
   PCIE_POWERDOWN_1_0 => PCIE_POWERDOWN_1_0,
   PCIE_POWERDOWN_1_1 => PCIE_POWERDOWN_1_1,
   PCIE_POWERDOWN_2_0 => PCIE_POWERDOWN_2_0,
   PCIE_POWERDOWN_2_1 => PCIE_POWERDOWN_2_1,
   PCIE_POWERDOWN_3_0 => PCIE_POWERDOWN_3_0,
   PCIE_POWERDOWN_3_1 => PCIE_POWERDOWN_3_1,
   PCIE_RXPOLARITY_0 => PCIE_RXPOLARITY_0,
   PCIE_RXPOLARITY_1 => PCIE_RXPOLARITY_1,
   PCIE_RXPOLARITY_2 => PCIE_RXPOLARITY_2,
   PCIE_RXPOLARITY_3 => PCIE_RXPOLARITY_3,
   PCIE_TXCOMPLIANCE_0 => PCIE_TXCOMPLIANCE_0,
   PCIE_TXCOMPLIANCE_1 => PCIE_TXCOMPLIANCE_1,
   PCIE_TXCOMPLIANCE_2 => PCIE_TXCOMPLIANCE_2,
   PCIE_TXCOMPLIANCE_3 => PCIE_TXCOMPLIANCE_3,
   PCIE_TXDETRX_PR2TLB_0 => PCIE_TXDETRX_PR2TLB_0,
   PCIE_TXDETRX_PR2TLB_1 => PCIE_TXDETRX_PR2TLB_1,
   PCIE_TXDETRX_PR2TLB_2 => PCIE_TXDETRX_PR2TLB_2,
   PCIE_TXDETRX_PR2TLB_3 => PCIE_TXDETRX_PR2TLB_3,
   SCIADDR0 => SCIADDR0,
   SCIADDR1 => SCIADDR1,
   SCIADDR2 => SCIADDR2,
   SCIADDR3 => SCIADDR3,
   SCIADDR4 => SCIADDR4,
   SCIADDR5 => SCIADDR5,
   SCIENAUX => SCIENAUX,
   SCIENCH0 => SCIENCH0,
   SCIENCH1 => SCIENCH1,
   SCIENCH2 => SCIENCH2,
   SCIENCH3 => SCIENCH3,
   SCIRD => SCIRD,
   SCISELAUX => SCISELAUX,
   SCISELCH0 => SCISELCH0,
   SCISELCH1 => SCISELCH1,
   SCISELCH2 => SCISELCH2,
   SCISELCH3 => SCISELCH3,
   SCIWDATA0 => SCIWDATA0,
   SCIWDATA1 => SCIWDATA1,
   SCIWDATA2 => SCIWDATA2,
   SCIWDATA3 => SCIWDATA3,
   SCIWDATA4 => SCIWDATA4,
   SCIWDATA5 => SCIWDATA5,
   SCIWDATA6 => SCIWDATA6,
   SCIWDATA7 => SCIWDATA7,
   SCIWSTN => SCIWSTN,
   HDOUTN0 => HDOUTN0,
   HDOUTN1 => HDOUTN1,
   HDOUTN2 => HDOUTN2,
   HDOUTN3 => HDOUTN3,
   HDOUTP0 => HDOUTP0,
   HDOUTP1 => HDOUTP1,
   HDOUTP2 => HDOUTP2,
   HDOUTP3 => HDOUTP3,
   COUT19 => COUT19,
   COUT18 => COUT18,
   COUT17 => COUT17,
   COUT16 => COUT16,
   COUT15 => COUT15,
   COUT14 => COUT14,
   COUT13 => COUT13,
   COUT12 => COUT12,
   COUT11 => COUT11,
   COUT10 => COUT10,
   COUT9 => COUT9,
   COUT8 => COUT8,
   COUT7 => COUT7,
   COUT6 => COUT6,
   COUT5 => COUT5,
   COUT4 => COUT4,
   COUT3 => COUT3,
   COUT2 => COUT2,
   COUT1 => COUT1,
   COUT0 => COUT0,
   FF_RX_D_0_0 => FF_RX_D_0_0,
   FF_RX_D_0_1 => FF_RX_D_0_1,
   FF_RX_D_0_2 => FF_RX_D_0_2,
   FF_RX_D_0_3 => FF_RX_D_0_3,
   FF_RX_D_0_4 => FF_RX_D_0_4,
   FF_RX_D_0_5 => FF_RX_D_0_5,
   FF_RX_D_0_6 => FF_RX_D_0_6,
   FF_RX_D_0_7 => FF_RX_D_0_7,
   FF_RX_D_0_8 => FF_RX_D_0_8,
   FF_RX_D_0_9 => FF_RX_D_0_9,
   FF_RX_D_0_10 => FF_RX_D_0_10,
   FF_RX_D_0_11 => FF_RX_D_0_11,
   FF_RX_D_0_12 => FF_RX_D_0_12,
   FF_RX_D_0_13 => FF_RX_D_0_13,
   FF_RX_D_0_14 => FF_RX_D_0_14,
   FF_RX_D_0_15 => FF_RX_D_0_15,
   FF_RX_D_0_16 => FF_RX_D_0_16,
   FF_RX_D_0_17 => FF_RX_D_0_17,
   FF_RX_D_0_18 => FF_RX_D_0_18,
   FF_RX_D_0_19 => FF_RX_D_0_19,
   FF_RX_D_0_20 => FF_RX_D_0_20,
   FF_RX_D_0_21 => FF_RX_D_0_21,
   FF_RX_D_0_22 => FF_RX_D_0_22,
   FF_RX_D_0_23 => FF_RX_D_0_23,
   FF_RX_D_1_0 => FF_RX_D_1_0,
   FF_RX_D_1_1 => FF_RX_D_1_1,
   FF_RX_D_1_2 => FF_RX_D_1_2,
   FF_RX_D_1_3 => FF_RX_D_1_3,
   FF_RX_D_1_4 => FF_RX_D_1_4,
   FF_RX_D_1_5 => FF_RX_D_1_5,
   FF_RX_D_1_6 => FF_RX_D_1_6,
   FF_RX_D_1_7 => FF_RX_D_1_7,
   FF_RX_D_1_8 => FF_RX_D_1_8,
   FF_RX_D_1_9 => FF_RX_D_1_9,
   FF_RX_D_1_10 => FF_RX_D_1_10,
   FF_RX_D_1_11 => FF_RX_D_1_11,
   FF_RX_D_1_12 => FF_RX_D_1_12,
   FF_RX_D_1_13 => FF_RX_D_1_13,
   FF_RX_D_1_14 => FF_RX_D_1_14,
   FF_RX_D_1_15 => FF_RX_D_1_15,
   FF_RX_D_1_16 => FF_RX_D_1_16,
   FF_RX_D_1_17 => FF_RX_D_1_17,
   FF_RX_D_1_18 => FF_RX_D_1_18,
   FF_RX_D_1_19 => FF_RX_D_1_19,
   FF_RX_D_1_20 => FF_RX_D_1_20,
   FF_RX_D_1_21 => FF_RX_D_1_21,
   FF_RX_D_1_22 => FF_RX_D_1_22,
   FF_RX_D_1_23 => FF_RX_D_1_23,
   FF_RX_D_2_0 => FF_RX_D_2_0,
   FF_RX_D_2_1 => FF_RX_D_2_1,
   FF_RX_D_2_2 => FF_RX_D_2_2,
   FF_RX_D_2_3 => FF_RX_D_2_3,
   FF_RX_D_2_4 => FF_RX_D_2_4,
   FF_RX_D_2_5 => FF_RX_D_2_5,
   FF_RX_D_2_6 => FF_RX_D_2_6,
   FF_RX_D_2_7 => FF_RX_D_2_7,
   FF_RX_D_2_8 => FF_RX_D_2_8,
   FF_RX_D_2_9 => FF_RX_D_2_9,
   FF_RX_D_2_10 => FF_RX_D_2_10,
   FF_RX_D_2_11 => FF_RX_D_2_11,
   FF_RX_D_2_12 => FF_RX_D_2_12,
   FF_RX_D_2_13 => FF_RX_D_2_13,
   FF_RX_D_2_14 => FF_RX_D_2_14,
   FF_RX_D_2_15 => FF_RX_D_2_15,
   FF_RX_D_2_16 => FF_RX_D_2_16,
   FF_RX_D_2_17 => FF_RX_D_2_17,
   FF_RX_D_2_18 => FF_RX_D_2_18,
   FF_RX_D_2_19 => FF_RX_D_2_19,
   FF_RX_D_2_20 => FF_RX_D_2_20,
   FF_RX_D_2_21 => FF_RX_D_2_21,
   FF_RX_D_2_22 => FF_RX_D_2_22,
   FF_RX_D_2_23 => FF_RX_D_2_23,
   FF_RX_D_3_0 => FF_RX_D_3_0,
   FF_RX_D_3_1 => FF_RX_D_3_1,
   FF_RX_D_3_2 => FF_RX_D_3_2,
   FF_RX_D_3_3 => FF_RX_D_3_3,
   FF_RX_D_3_4 => FF_RX_D_3_4,
   FF_RX_D_3_5 => FF_RX_D_3_5,
   FF_RX_D_3_6 => FF_RX_D_3_6,
   FF_RX_D_3_7 => FF_RX_D_3_7,
   FF_RX_D_3_8 => FF_RX_D_3_8,
   FF_RX_D_3_9 => FF_RX_D_3_9,
   FF_RX_D_3_10 => FF_RX_D_3_10,
   FF_RX_D_3_11 => FF_RX_D_3_11,
   FF_RX_D_3_12 => FF_RX_D_3_12,
   FF_RX_D_3_13 => FF_RX_D_3_13,
   FF_RX_D_3_14 => FF_RX_D_3_14,
   FF_RX_D_3_15 => FF_RX_D_3_15,
   FF_RX_D_3_16 => FF_RX_D_3_16,
   FF_RX_D_3_17 => FF_RX_D_3_17,
   FF_RX_D_3_18 => FF_RX_D_3_18,
   FF_RX_D_3_19 => FF_RX_D_3_19,
   FF_RX_D_3_20 => FF_RX_D_3_20,
   FF_RX_D_3_21 => FF_RX_D_3_21,
   FF_RX_D_3_22 => FF_RX_D_3_22,
   FF_RX_D_3_23 => FF_RX_D_3_23,
   FF_RX_F_CLK_0 => FF_RX_F_CLK_0,
   FF_RX_F_CLK_1 => FF_RX_F_CLK_1,
   FF_RX_F_CLK_2 => FF_RX_F_CLK_2,
   FF_RX_F_CLK_3 => FF_RX_F_CLK_3,
   FF_RX_H_CLK_0 => FF_RX_H_CLK_0,
   FF_RX_H_CLK_1 => FF_RX_H_CLK_1,
   FF_RX_H_CLK_2 => FF_RX_H_CLK_2,
   FF_RX_H_CLK_3 => FF_RX_H_CLK_3,
   FF_TX_F_CLK_0 => FF_TX_F_CLK_0,
   FF_TX_F_CLK_1 => FF_TX_F_CLK_1,
   FF_TX_F_CLK_2 => FF_TX_F_CLK_2,
   FF_TX_F_CLK_3 => FF_TX_F_CLK_3,
   FF_TX_H_CLK_0 => FF_TX_H_CLK_0,
   FF_TX_H_CLK_1 => FF_TX_H_CLK_1,
   FF_TX_H_CLK_2 => FF_TX_H_CLK_2,
   FF_TX_H_CLK_3 => FF_TX_H_CLK_3,
   FFS_CC_OVERRUN_0 => FFS_CC_OVERRUN_0,
   FFS_CC_OVERRUN_1 => FFS_CC_OVERRUN_1,
   FFS_CC_OVERRUN_2 => FFS_CC_OVERRUN_2,
   FFS_CC_OVERRUN_3 => FFS_CC_OVERRUN_3,
   FFS_CC_UNDERRUN_0 => FFS_CC_UNDERRUN_0,
   FFS_CC_UNDERRUN_1 => FFS_CC_UNDERRUN_1,
   FFS_CC_UNDERRUN_2 => FFS_CC_UNDERRUN_2,
   FFS_CC_UNDERRUN_3 => FFS_CC_UNDERRUN_3,
   FFS_LS_SYNC_STATUS_0 => FFS_LS_SYNC_STATUS_0,
   FFS_LS_SYNC_STATUS_1 => FFS_LS_SYNC_STATUS_1,
   FFS_LS_SYNC_STATUS_2 => FFS_LS_SYNC_STATUS_2,
   FFS_LS_SYNC_STATUS_3 => FFS_LS_SYNC_STATUS_3,
   FFS_CDR_TRAIN_DONE_0 => FFS_CDR_TRAIN_DONE_0,
   FFS_CDR_TRAIN_DONE_1 => FFS_CDR_TRAIN_DONE_1,
   FFS_CDR_TRAIN_DONE_2 => FFS_CDR_TRAIN_DONE_2,
   FFS_CDR_TRAIN_DONE_3 => FFS_CDR_TRAIN_DONE_3,
   FFS_PCIE_CON_0 => FFS_PCIE_CON_0,
   FFS_PCIE_CON_1 => FFS_PCIE_CON_1,
   FFS_PCIE_CON_2 => FFS_PCIE_CON_2,
   FFS_PCIE_CON_3 => FFS_PCIE_CON_3,
   FFS_PCIE_DONE_0 => FFS_PCIE_DONE_0,
   FFS_PCIE_DONE_1 => FFS_PCIE_DONE_1,
   FFS_PCIE_DONE_2 => FFS_PCIE_DONE_2,
   FFS_PCIE_DONE_3 => FFS_PCIE_DONE_3,
   FFS_PLOL => FFS_PLOL,
   FFS_RLOL_0 => FFS_RLOL_0,
   FFS_RLOL_1 => FFS_RLOL_1,
   FFS_RLOL_2 => FFS_RLOL_2,
   FFS_RLOL_3 => FFS_RLOL_3,
   FFS_RLOS_HI_0 => FFS_RLOS_HI_0,
   FFS_RLOS_HI_1 => FFS_RLOS_HI_1,
   FFS_RLOS_HI_2 => FFS_RLOS_HI_2,
   FFS_RLOS_HI_3 => FFS_RLOS_HI_3,
   FFS_RLOS_LO_0 => FFS_RLOS_LO_0,
   FFS_RLOS_LO_1 => FFS_RLOS_LO_1,
   FFS_RLOS_LO_2 => FFS_RLOS_LO_2,
   FFS_RLOS_LO_3 => FFS_RLOS_LO_3,
   FFS_RXFBFIFO_ERROR_0 => FFS_RXFBFIFO_ERROR_0,
   FFS_RXFBFIFO_ERROR_1 => FFS_RXFBFIFO_ERROR_1,
   FFS_RXFBFIFO_ERROR_2 => FFS_RXFBFIFO_ERROR_2,
   FFS_RXFBFIFO_ERROR_3 => FFS_RXFBFIFO_ERROR_3,
   FFS_TXFBFIFO_ERROR_0 => FFS_TXFBFIFO_ERROR_0,
   FFS_TXFBFIFO_ERROR_1 => FFS_TXFBFIFO_ERROR_1,
   FFS_TXFBFIFO_ERROR_2 => FFS_TXFBFIFO_ERROR_2,
   FFS_TXFBFIFO_ERROR_3 => FFS_TXFBFIFO_ERROR_3,
   PCIE_PHYSTATUS_0 => PCIE_PHYSTATUS_0,
   PCIE_PHYSTATUS_1 => PCIE_PHYSTATUS_1,
   PCIE_PHYSTATUS_2 => PCIE_PHYSTATUS_2,
   PCIE_PHYSTATUS_3 => PCIE_PHYSTATUS_3,
   PCIE_RXVALID_0 => PCIE_RXVALID_0,
   PCIE_RXVALID_1 => PCIE_RXVALID_1,
   PCIE_RXVALID_2 => PCIE_RXVALID_2,
   PCIE_RXVALID_3 => PCIE_RXVALID_3,
   FFS_SKP_ADDED_0 => FFS_SKP_ADDED_0,
   FFS_SKP_ADDED_1 => FFS_SKP_ADDED_1,
   FFS_SKP_ADDED_2 => FFS_SKP_ADDED_2,
   FFS_SKP_ADDED_3 => FFS_SKP_ADDED_3,
   FFS_SKP_DELETED_0 => FFS_SKP_DELETED_0,
   FFS_SKP_DELETED_1 => FFS_SKP_DELETED_1,
   FFS_SKP_DELETED_2 => FFS_SKP_DELETED_2,
   FFS_SKP_DELETED_3 => FFS_SKP_DELETED_3,
   LDR_RX2CORE_0 => LDR_RX2CORE_0,
   LDR_RX2CORE_1 => LDR_RX2CORE_1,
   LDR_RX2CORE_2 => LDR_RX2CORE_2,
   LDR_RX2CORE_3 => LDR_RX2CORE_3,
   REFCK2CORE => REFCK2CORE,
   SCIINT => SCIINT,
   SCIRDATA0 => SCIRDATA0,
   SCIRDATA1 => SCIRDATA1,
   SCIRDATA2 => SCIRDATA2,
   SCIRDATA3 => SCIRDATA3,
   SCIRDATA4 => SCIRDATA4,
   SCIRDATA5 => SCIRDATA5,
   SCIRDATA6 => SCIRDATA6,
   SCIRDATA7 => SCIRDATA7,
   REFCLK_FROM_NQ => REFCLK_FROM_NQ,
   REFCLK_TO_NQ => REFCLK_TO_NQ
   );

end PCSD_arch;

--synopsys translate_on


--THIS MODULE IS INSTANTIATED PER TX  QUAD
--TX Reset Sequence state machine--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
                                                                                              
entity hdmi_pcstx_reset_sm is
generic (count_index: integer :=18);
port (
   rst_n          : in std_logic;
   refclkdiv2      : in std_logic;
   tx_pll_lol_qd_s : in std_logic;
   rst_qd_c    : out std_logic;
   tx_pcs_rst_ch_c : out std_logic
   );
end hdmi_pcstx_reset_sm;
                                                                                              
architecture tx_reset_sm_arch of hdmi_pcstx_reset_sm is
                                                                                              
type statetype is (QUAD_RESET, WAIT_FOR_TIMER1, CHECK_PLOL, WAIT_FOR_TIMER2, NORMAL);
                                                                                              
signal   cs:      statetype;  -- current state of lsm
signal   ns:      statetype;  -- next state of lsm
attribute syn_encoding : string;
attribute syn_encoding of cs : signal is "safe";
attribute syn_encoding of ns : signal is "safe";
                                                                                              
signal   tx_pll_lol_qd_s_int  : std_logic;
signal   tx_pcs_rst_ch_c_int  : std_logic_vector(3 downto 0);
signal   rst_qd_c_int      : std_logic;
                                                                                              
signal   reset_timer1:  std_logic;
signal   reset_timer2:  std_logic;
                                                                                              
signal   counter1:      std_logic_vector(2 downto 0);
signal   TIMER1:        std_logic;
                                                                                              
signal   counter2:      std_logic_vector(18 downto 0);
signal   TIMER2:        std_logic;

signal   rstn_m1:       std_logic;                                                                                  
signal   rstn_m2:       std_logic;                                                                                              
signal   sync_rst_n:       std_logic;                                                                                              
begin

process (refclkdiv2, rst_n)
begin
   if rst_n = '0' then
      rstn_m1 <= '0';
      rstn_m2 <= '0';
   else if rising_edge(refclkdiv2) then
      rstn_m1 <= '1';
      rstn_m2 <= rstn_m1;
   end if;
   end if;
end process;
   
   sync_rst_n <= rstn_m2;                                                                                           
process (refclkdiv2, sync_rst_n)
begin
   if sync_rst_n = '0' then
      cs <= QUAD_RESET;
      tx_pll_lol_qd_s_int <= '1';
      tx_pcs_rst_ch_c <= '1';
      rst_qd_c <= '1';
   else if rising_edge(refclkdiv2) then
      cs <= ns;
      tx_pll_lol_qd_s_int <= tx_pll_lol_qd_s;
      tx_pcs_rst_ch_c <= tx_pcs_rst_ch_c_int(0);
      rst_qd_c <= rst_qd_c_int;
   end if;
   end if;
end process;
--TIMER1 = 20ns;
--Fastest REFLCK =312 MHZ, or 3 ns. We need 8 REFCLK cycles or 4 REFCLKDIV2 cycles
-- A 2 bit counter ([1:0]) counts 4 cycles, so a 3 bit ([2:0]) counter will do if we set TIMER1 = bit[2]
                                                                                              
                                                                                              
process (refclkdiv2, reset_timer1)
begin
   if rising_edge(refclkdiv2) then
      if reset_timer1 = '1' then
         counter1 <= "000";
         TIMER1 <= '0';
      else
         if counter1(2) = '1' then
            TIMER1 <= '1';
         else
            TIMER1 <='0';
            counter1 <= counter1 + 1 ;
         end if;
      end if;
   end if;
end process;
                                                                                              
                                                                                              
--TIMER2 = 1,400,000 UI;
--WORST CASE CYCLES is with smallest multipier factor.
-- This would be with X8 clock multiplier in DIV2 mode
-- IN this casse, 1 UI = 2/8 REFCLK  CYCLES = 1/8 REFCLKDIV2 CYCLES
-- SO 1,400,000 UI =1,400,000/8 = 175,000 REFCLKDIV2 CYCLES
-- An 18 bit counter ([17:0]) counts 262144 cycles, so a 19 bit ([18:0]) counter will do if we set TIMER2 = bit[18]
                                                                                              
                                                                                              
process(refclkdiv2, reset_timer2)
begin
   if rising_edge(refclkdiv2) then
      if reset_timer2 = '1' then
         counter2 <= "0000000000000000000";
         TIMER2 <= '0';
      else
         if counter2(count_index) = '1' then
            TIMER2 <='1';
         else
            TIMER2 <='0';
            counter2 <= counter2 + 1 ;
         end if;
      end if;
   end if;
end process;
                                                                                              
process(cs, TIMER1, TIMER2, tx_pll_lol_qd_s_int)
begin
                                                                                              
      reset_timer1 <= '0';
      reset_timer2 <= '0';
                                                                                              
   case cs is
                                                                                              
      when QUAD_RESET   =>
      tx_pcs_rst_ch_c_int <= "1111";
      rst_qd_c_int <= '1';
      reset_timer1 <= '1';
         ns <= WAIT_FOR_TIMER1;
                                                                                              
      when WAIT_FOR_TIMER1 =>
      tx_pcs_rst_ch_c_int <= "1111";
      rst_qd_c_int <= '1';
      if TIMER1 = '1' then
         ns <= CHECK_PLOL;
      else
         ns <= WAIT_FOR_TIMER1;
         end if;
                                                                                              
      when CHECK_PLOL   =>
      tx_pcs_rst_ch_c_int <= "1111";
      rst_qd_c_int <= '0';
      reset_timer2 <= '1';
         ns <= WAIT_FOR_TIMER2;
                                                                                              
      when WAIT_FOR_TIMER2 =>
      tx_pcs_rst_ch_c_int <= "1111";
      rst_qd_c_int <= '0';
      if TIMER2 = '1' then
         if tx_pll_lol_qd_s_int = '1' then
            ns <= QUAD_RESET;
         else
            ns <= NORMAL;
         end if;
      else
            ns <= WAIT_FOR_TIMER2;
            end if;
                                                                                              
   when NORMAL =>
      tx_pcs_rst_ch_c_int <= "0000";
      rst_qd_c_int <= '0';
      if tx_pll_lol_qd_s_int = '1' then
         ns <= QUAD_RESET;
      else
         ns <= NORMAL;
         end if;
                                                                                              
   when others =>
      ns <=    QUAD_RESET;
                                                                                              
   end case;
                                                                                              
end process;
                                                                                              
end tx_reset_sm_arch;


--synopsys translate_off
library ECP3;
use ECP3.components.all;
--synopsys translate_on


library IEEE, STD;
use IEEE.std_logic_1164.all;
use STD.TEXTIO.all;

entity hdmi_pcs is
   GENERIC (USER_CONFIG_FILE    :  String := "hdmi_pcs.txt");
 port (
------------------
-- CH0 --
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    txiclk_ch0    :   in std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    txdata_ch0    :   in std_logic_vector (9 downto 0);
    tx_pwrup_ch0_c    :   in std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    txiclk_ch1    :   in std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    txdata_ch1    :   in std_logic_vector (9 downto 0);
    tx_pwrup_ch1_c    :   in std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    txiclk_ch2    :   in std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    txdata_ch2    :   in std_logic_vector (9 downto 0);
    tx_pwrup_ch2_c    :   in std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    txiclk_ch3    :   in std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    txdata_ch3    :   in std_logic_vector (9 downto 0);
    tx_pwrup_ch3_c    :   in std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    refclk2fpga   :   out std_logic;
    rst_n      :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end hdmi_pcs;


architecture hdmi_pcs_arch of hdmi_pcs is

component VLO
port (
   Z : out std_logic);
end component;

component VHI
port (
   Z : out std_logic);
end component;


component hdmi_pcstx_reset_sm
generic (count_index: integer :=18);
port (
   rst_n          : in std_logic;
   refclkdiv2      : in std_logic;
   tx_pll_lol_qd_s : in std_logic;
   rst_qd_c    : out std_logic;
   tx_pcs_rst_ch_c : out std_logic
   );
end component;

component PCSD
--synopsys translate_off
GENERIC(
  CONFIG_FILE : String;
  QUAD_MODE : String;
  CH0_CDR_SRC   : String := "REFCLK_EXT";
  CH1_CDR_SRC   : String := "REFCLK_EXT";
  CH2_CDR_SRC   : String := "REFCLK_EXT";
  CH3_CDR_SRC   : String := "REFCLK_EXT";
  PLL_SRC   : String
  );
--synopsys translate_on
port (
  HDINN0             : in std_logic;
  HDINN1             : in std_logic;
  HDINN2             : in std_logic;
  HDINN3             : in std_logic;
  HDINP0             : in std_logic;
  HDINP1             : in std_logic;
  HDINP2             : in std_logic;
  HDINP3             : in std_logic;
  REFCLKN             : in std_logic;
  REFCLKP             : in std_logic;
  CIN0             : in std_logic;
  CIN1             : in std_logic;
  CIN2             : in std_logic;
  CIN3             : in std_logic;
  CIN4             : in std_logic;
  CIN5             : in std_logic;
  CIN6             : in std_logic;
  CIN7             : in std_logic;
  CIN8             : in std_logic;
  CIN9             : in std_logic;
  CIN10             : in std_logic;
  CIN11             : in std_logic;
  CYAWSTN             : in std_logic;
  FF_EBRD_CLK_0             : in std_logic;
  FF_EBRD_CLK_1             : in std_logic;
  FF_EBRD_CLK_2             : in std_logic;
  FF_EBRD_CLK_3             : in std_logic;
  FF_RXI_CLK_0             : in std_logic;
  FF_RXI_CLK_1             : in std_logic;
  FF_RXI_CLK_2             : in std_logic;
  FF_RXI_CLK_3             : in std_logic;
  FF_TX_D_0_0             : in std_logic;
  FF_TX_D_0_1             : in std_logic;
  FF_TX_D_0_2             : in std_logic;
  FF_TX_D_0_3             : in std_logic;
  FF_TX_D_0_4             : in std_logic;
  FF_TX_D_0_5             : in std_logic;
  FF_TX_D_0_6             : in std_logic;
  FF_TX_D_0_7             : in std_logic;
  FF_TX_D_0_8             : in std_logic;
  FF_TX_D_0_9             : in std_logic;
  FF_TX_D_0_10             : in std_logic;
  FF_TX_D_0_11             : in std_logic;
  FF_TX_D_0_12             : in std_logic;
  FF_TX_D_0_13             : in std_logic;
  FF_TX_D_0_14             : in std_logic;
  FF_TX_D_0_15             : in std_logic;
  FF_TX_D_0_16             : in std_logic;
  FF_TX_D_0_17             : in std_logic;
  FF_TX_D_0_18             : in std_logic;
  FF_TX_D_0_19             : in std_logic;
  FF_TX_D_0_20             : in std_logic;
  FF_TX_D_0_21             : in std_logic;
  FF_TX_D_0_22             : in std_logic;
  FF_TX_D_0_23             : in std_logic;
  FF_TX_D_1_0             : in std_logic;
  FF_TX_D_1_1             : in std_logic;
  FF_TX_D_1_2             : in std_logic;
  FF_TX_D_1_3             : in std_logic;
  FF_TX_D_1_4             : in std_logic;
  FF_TX_D_1_5             : in std_logic;
  FF_TX_D_1_6             : in std_logic;
  FF_TX_D_1_7             : in std_logic;
  FF_TX_D_1_8             : in std_logic;
  FF_TX_D_1_9             : in std_logic;
  FF_TX_D_1_10             : in std_logic;
  FF_TX_D_1_11             : in std_logic;
  FF_TX_D_1_12             : in std_logic;
  FF_TX_D_1_13             : in std_logic;
  FF_TX_D_1_14             : in std_logic;
  FF_TX_D_1_15             : in std_logic;
  FF_TX_D_1_16             : in std_logic;
  FF_TX_D_1_17             : in std_logic;
  FF_TX_D_1_18             : in std_logic;
  FF_TX_D_1_19             : in std_logic;
  FF_TX_D_1_20             : in std_logic;
  FF_TX_D_1_21             : in std_logic;
  FF_TX_D_1_22             : in std_logic;
  FF_TX_D_1_23             : in std_logic;
  FF_TX_D_2_0             : in std_logic;
  FF_TX_D_2_1             : in std_logic;
  FF_TX_D_2_2             : in std_logic;
  FF_TX_D_2_3             : in std_logic;
  FF_TX_D_2_4             : in std_logic;
  FF_TX_D_2_5             : in std_logic;
  FF_TX_D_2_6             : in std_logic;
  FF_TX_D_2_7             : in std_logic;
  FF_TX_D_2_8             : in std_logic;
  FF_TX_D_2_9             : in std_logic;
  FF_TX_D_2_10             : in std_logic;
  FF_TX_D_2_11             : in std_logic;
  FF_TX_D_2_12             : in std_logic;
  FF_TX_D_2_13             : in std_logic;
  FF_TX_D_2_14             : in std_logic;
  FF_TX_D_2_15             : in std_logic;
  FF_TX_D_2_16             : in std_logic;
  FF_TX_D_2_17             : in std_logic;
  FF_TX_D_2_18             : in std_logic;
  FF_TX_D_2_19             : in std_logic;
  FF_TX_D_2_20             : in std_logic;
  FF_TX_D_2_21             : in std_logic;
  FF_TX_D_2_22             : in std_logic;
  FF_TX_D_2_23             : in std_logic;
  FF_TX_D_3_0             : in std_logic;
  FF_TX_D_3_1             : in std_logic;
  FF_TX_D_3_2             : in std_logic;
  FF_TX_D_3_3             : in std_logic;
  FF_TX_D_3_4             : in std_logic;
  FF_TX_D_3_5             : in std_logic;
  FF_TX_D_3_6             : in std_logic;
  FF_TX_D_3_7             : in std_logic;
  FF_TX_D_3_8             : in std_logic;
  FF_TX_D_3_9             : in std_logic;
  FF_TX_D_3_10             : in std_logic;
  FF_TX_D_3_11             : in std_logic;
  FF_TX_D_3_12             : in std_logic;
  FF_TX_D_3_13             : in std_logic;
  FF_TX_D_3_14             : in std_logic;
  FF_TX_D_3_15             : in std_logic;
  FF_TX_D_3_16             : in std_logic;
  FF_TX_D_3_17             : in std_logic;
  FF_TX_D_3_18             : in std_logic;
  FF_TX_D_3_19             : in std_logic;
  FF_TX_D_3_20             : in std_logic;
  FF_TX_D_3_21             : in std_logic;
  FF_TX_D_3_22             : in std_logic;
  FF_TX_D_3_23             : in std_logic;
  FF_TXI_CLK_0             : in std_logic;
  FF_TXI_CLK_1             : in std_logic;
  FF_TXI_CLK_2             : in std_logic;
  FF_TXI_CLK_3             : in std_logic;
  FFC_CK_CORE_RX_0         : in std_logic;
  FFC_CK_CORE_RX_1         : in std_logic;
  FFC_CK_CORE_RX_2         : in std_logic;
  FFC_CK_CORE_RX_3         : in std_logic;
  FFC_CK_CORE_TX           : in std_logic;
  FFC_EI_EN_0             : in std_logic;
  FFC_EI_EN_1             : in std_logic;
  FFC_EI_EN_2             : in std_logic;
  FFC_EI_EN_3             : in std_logic;
  FFC_ENABLE_CGALIGN_0             : in std_logic;
  FFC_ENABLE_CGALIGN_1             : in std_logic;
  FFC_ENABLE_CGALIGN_2             : in std_logic;
  FFC_ENABLE_CGALIGN_3             : in std_logic;
  FFC_FB_LOOPBACK_0             : in std_logic;
  FFC_FB_LOOPBACK_1             : in std_logic;
  FFC_FB_LOOPBACK_2             : in std_logic;
  FFC_FB_LOOPBACK_3             : in std_logic;
  FFC_LANE_RX_RST_0             : in std_logic;
  FFC_LANE_RX_RST_1             : in std_logic;
  FFC_LANE_RX_RST_2             : in std_logic;
  FFC_LANE_RX_RST_3             : in std_logic;
  FFC_LANE_TX_RST_0             : in std_logic;
  FFC_LANE_TX_RST_1             : in std_logic;
  FFC_LANE_TX_RST_2             : in std_logic;
  FFC_LANE_TX_RST_3             : in std_logic;
  FFC_MACRO_RST             : in std_logic;
  FFC_PCI_DET_EN_0             : in std_logic;
  FFC_PCI_DET_EN_1             : in std_logic;
  FFC_PCI_DET_EN_2             : in std_logic;
  FFC_PCI_DET_EN_3             : in std_logic;
  FFC_PCIE_CT_0             : in std_logic;
  FFC_PCIE_CT_1             : in std_logic;
  FFC_PCIE_CT_2             : in std_logic;
  FFC_PCIE_CT_3             : in std_logic;
  FFC_PFIFO_CLR_0             : in std_logic;
  FFC_PFIFO_CLR_1             : in std_logic;
  FFC_PFIFO_CLR_2             : in std_logic;
  FFC_PFIFO_CLR_3             : in std_logic;
  FFC_QUAD_RST             : in std_logic;
  FFC_RRST_0             : in std_logic;
  FFC_RRST_1             : in std_logic;
  FFC_RRST_2             : in std_logic;
  FFC_RRST_3             : in std_logic;
  FFC_RXPWDNB_0             : in std_logic;
  FFC_RXPWDNB_1             : in std_logic;
  FFC_RXPWDNB_2             : in std_logic;
  FFC_RXPWDNB_3             : in std_logic;
  FFC_SB_INV_RX_0             : in std_logic;
  FFC_SB_INV_RX_1             : in std_logic;
  FFC_SB_INV_RX_2             : in std_logic;
  FFC_SB_INV_RX_3             : in std_logic;
  FFC_SB_PFIFO_LP_0             : in std_logic;
  FFC_SB_PFIFO_LP_1             : in std_logic;
  FFC_SB_PFIFO_LP_2             : in std_logic;
  FFC_SB_PFIFO_LP_3             : in std_logic;
  FFC_SIGNAL_DETECT_0             : in std_logic;
  FFC_SIGNAL_DETECT_1             : in std_logic;
  FFC_SIGNAL_DETECT_2             : in std_logic;
  FFC_SIGNAL_DETECT_3             : in std_logic;
  FFC_SYNC_TOGGLE             : in std_logic;
  FFC_TRST             : in std_logic;
  FFC_TXPWDNB_0             : in std_logic;
  FFC_TXPWDNB_1             : in std_logic;
  FFC_TXPWDNB_2             : in std_logic;
  FFC_TXPWDNB_3             : in std_logic;
  FFC_RATE_MODE_RX_0        : in std_logic;
  FFC_RATE_MODE_RX_1        : in std_logic;
  FFC_RATE_MODE_RX_2        : in std_logic;
  FFC_RATE_MODE_RX_3        : in std_logic;
  FFC_RATE_MODE_TX_0        : in std_logic;
  FFC_RATE_MODE_TX_1        : in std_logic;
  FFC_RATE_MODE_TX_2        : in std_logic;
  FFC_RATE_MODE_TX_3        : in std_logic;
  FFC_DIV11_MODE_RX_0       : in std_logic;
  FFC_DIV11_MODE_RX_1       : in std_logic;
  FFC_DIV11_MODE_RX_2       : in std_logic;
  FFC_DIV11_MODE_RX_3       : in std_logic;
  FFC_DIV11_MODE_TX_0       : in std_logic;
  FFC_DIV11_MODE_TX_1       : in std_logic;
  FFC_DIV11_MODE_TX_2       : in std_logic;
  FFC_DIV11_MODE_TX_3       : in std_logic;
  LDR_CORE2TX_0             : in std_logic;
  LDR_CORE2TX_1             : in std_logic;
  LDR_CORE2TX_2             : in std_logic;
  LDR_CORE2TX_3             : in std_logic;
  FFC_LDR_CORE2TX_EN_0      : in std_logic;
  FFC_LDR_CORE2TX_EN_1      : in std_logic;
  FFC_LDR_CORE2TX_EN_2      : in std_logic;
  FFC_LDR_CORE2TX_EN_3      : in std_logic;
  PCIE_POWERDOWN_0_0      : in std_logic;
  PCIE_POWERDOWN_0_1      : in std_logic;
  PCIE_POWERDOWN_1_0      : in std_logic;
  PCIE_POWERDOWN_1_1      : in std_logic;
  PCIE_POWERDOWN_2_0      : in std_logic;
  PCIE_POWERDOWN_2_1      : in std_logic;
  PCIE_POWERDOWN_3_0      : in std_logic;
  PCIE_POWERDOWN_3_1      : in std_logic;
  PCIE_RXPOLARITY_0         : in std_logic;
  PCIE_RXPOLARITY_1         : in std_logic;
  PCIE_RXPOLARITY_2         : in std_logic;
  PCIE_RXPOLARITY_3         : in std_logic;
  PCIE_TXCOMPLIANCE_0       : in std_logic;
  PCIE_TXCOMPLIANCE_1       : in std_logic;
  PCIE_TXCOMPLIANCE_2       : in std_logic;
  PCIE_TXCOMPLIANCE_3       : in std_logic;
  PCIE_TXDETRX_PR2TLB_0     : in std_logic;
  PCIE_TXDETRX_PR2TLB_1     : in std_logic;
  PCIE_TXDETRX_PR2TLB_2     : in std_logic;
  PCIE_TXDETRX_PR2TLB_3     : in std_logic;
  SCIADDR0             : in std_logic;
  SCIADDR1             : in std_logic;
  SCIADDR2             : in std_logic;
  SCIADDR3             : in std_logic;
  SCIADDR4             : in std_logic;
  SCIADDR5             : in std_logic;
  SCIENAUX             : in std_logic;
  SCIENCH0             : in std_logic;
  SCIENCH1             : in std_logic;
  SCIENCH2             : in std_logic;
  SCIENCH3             : in std_logic;
  SCIRD                : in std_logic;
  SCISELAUX             : in std_logic;
  SCISELCH0             : in std_logic;
  SCISELCH1             : in std_logic;
  SCISELCH2             : in std_logic;
  SCISELCH3             : in std_logic;
  SCIWDATA0             : in std_logic;
  SCIWDATA1             : in std_logic;
  SCIWDATA2             : in std_logic;
  SCIWDATA3             : in std_logic;
  SCIWDATA4             : in std_logic;
  SCIWDATA5             : in std_logic;
  SCIWDATA6             : in std_logic;
  SCIWDATA7             : in std_logic;
  SCIWSTN               : in std_logic;
  REFCLK_FROM_NQ        : in std_logic;
  HDOUTN0             : out std_logic;
  HDOUTN1             : out std_logic;
  HDOUTN2             : out std_logic;
  HDOUTN3             : out std_logic;
  HDOUTP0             : out std_logic;
  HDOUTP1             : out std_logic;
  HDOUTP2             : out std_logic;
  HDOUTP3             : out std_logic;
  COUT0             : out std_logic;
  COUT1             : out std_logic;
  COUT2             : out std_logic;
  COUT3             : out std_logic;
  COUT4             : out std_logic;
  COUT5             : out std_logic;
  COUT6             : out std_logic;
  COUT7             : out std_logic;
  COUT8             : out std_logic;
  COUT9             : out std_logic;
  COUT10             : out std_logic;
  COUT11             : out std_logic;
  COUT12             : out std_logic;
  COUT13             : out std_logic;
  COUT14             : out std_logic;
  COUT15             : out std_logic;
  COUT16             : out std_logic;
  COUT17             : out std_logic;
  COUT18             : out std_logic;
  COUT19             : out std_logic;
  FF_RX_D_0_0             : out std_logic;
  FF_RX_D_0_1             : out std_logic;
  FF_RX_D_0_2             : out std_logic;
  FF_RX_D_0_3             : out std_logic;
  FF_RX_D_0_4             : out std_logic;
  FF_RX_D_0_5             : out std_logic;
  FF_RX_D_0_6             : out std_logic;
  FF_RX_D_0_7             : out std_logic;
  FF_RX_D_0_8             : out std_logic;
  FF_RX_D_0_9             : out std_logic;
  FF_RX_D_0_10             : out std_logic;
  FF_RX_D_0_11             : out std_logic;
  FF_RX_D_0_12             : out std_logic;
  FF_RX_D_0_13             : out std_logic;
  FF_RX_D_0_14             : out std_logic;
  FF_RX_D_0_15             : out std_logic;
  FF_RX_D_0_16             : out std_logic;
  FF_RX_D_0_17             : out std_logic;
  FF_RX_D_0_18             : out std_logic;
  FF_RX_D_0_19             : out std_logic;
  FF_RX_D_0_20             : out std_logic;
  FF_RX_D_0_21             : out std_logic;
  FF_RX_D_0_22             : out std_logic;
  FF_RX_D_0_23             : out std_logic;
  FF_RX_D_1_0             : out std_logic;
  FF_RX_D_1_1             : out std_logic;
  FF_RX_D_1_2             : out std_logic;
  FF_RX_D_1_3             : out std_logic;
  FF_RX_D_1_4             : out std_logic;
  FF_RX_D_1_5             : out std_logic;
  FF_RX_D_1_6             : out std_logic;
  FF_RX_D_1_7             : out std_logic;
  FF_RX_D_1_8             : out std_logic;
  FF_RX_D_1_9             : out std_logic;
  FF_RX_D_1_10             : out std_logic;
  FF_RX_D_1_11             : out std_logic;
  FF_RX_D_1_12             : out std_logic;
  FF_RX_D_1_13             : out std_logic;
  FF_RX_D_1_14             : out std_logic;
  FF_RX_D_1_15             : out std_logic;
  FF_RX_D_1_16             : out std_logic;
  FF_RX_D_1_17             : out std_logic;
  FF_RX_D_1_18             : out std_logic;
  FF_RX_D_1_19             : out std_logic;
  FF_RX_D_1_20             : out std_logic;
  FF_RX_D_1_21             : out std_logic;
  FF_RX_D_1_22             : out std_logic;
  FF_RX_D_1_23             : out std_logic;
  FF_RX_D_2_0             : out std_logic;
  FF_RX_D_2_1             : out std_logic;
  FF_RX_D_2_2             : out std_logic;
  FF_RX_D_2_3             : out std_logic;
  FF_RX_D_2_4             : out std_logic;
  FF_RX_D_2_5             : out std_logic;
  FF_RX_D_2_6             : out std_logic;
  FF_RX_D_2_7             : out std_logic;
  FF_RX_D_2_8             : out std_logic;
  FF_RX_D_2_9             : out std_logic;
  FF_RX_D_2_10             : out std_logic;
  FF_RX_D_2_11             : out std_logic;
  FF_RX_D_2_12             : out std_logic;
  FF_RX_D_2_13             : out std_logic;
  FF_RX_D_2_14             : out std_logic;
  FF_RX_D_2_15             : out std_logic;
  FF_RX_D_2_16             : out std_logic;
  FF_RX_D_2_17             : out std_logic;
  FF_RX_D_2_18             : out std_logic;
  FF_RX_D_2_19             : out std_logic;
  FF_RX_D_2_20             : out std_logic;
  FF_RX_D_2_21             : out std_logic;
  FF_RX_D_2_22             : out std_logic;
  FF_RX_D_2_23             : out std_logic;
  FF_RX_D_3_0             : out std_logic;
  FF_RX_D_3_1             : out std_logic;
  FF_RX_D_3_2             : out std_logic;
  FF_RX_D_3_3             : out std_logic;
  FF_RX_D_3_4             : out std_logic;
  FF_RX_D_3_5             : out std_logic;
  FF_RX_D_3_6             : out std_logic;
  FF_RX_D_3_7             : out std_logic;
  FF_RX_D_3_8             : out std_logic;
  FF_RX_D_3_9             : out std_logic;
  FF_RX_D_3_10             : out std_logic;
  FF_RX_D_3_11             : out std_logic;
  FF_RX_D_3_12             : out std_logic;
  FF_RX_D_3_13             : out std_logic;
  FF_RX_D_3_14             : out std_logic;
  FF_RX_D_3_15             : out std_logic;
  FF_RX_D_3_16             : out std_logic;
  FF_RX_D_3_17             : out std_logic;
  FF_RX_D_3_18             : out std_logic;
  FF_RX_D_3_19             : out std_logic;
  FF_RX_D_3_20             : out std_logic;
  FF_RX_D_3_21             : out std_logic;
  FF_RX_D_3_22             : out std_logic;
  FF_RX_D_3_23             : out std_logic;
  FF_RX_F_CLK_0             : out std_logic;
  FF_RX_F_CLK_1             : out std_logic;
  FF_RX_F_CLK_2             : out std_logic;
  FF_RX_F_CLK_3             : out std_logic;
  FF_RX_H_CLK_0             : out std_logic;
  FF_RX_H_CLK_1             : out std_logic;
  FF_RX_H_CLK_2             : out std_logic;
  FF_RX_H_CLK_3             : out std_logic;
  FF_TX_F_CLK_0             : out std_logic;
  FF_TX_F_CLK_1             : out std_logic;
  FF_TX_F_CLK_2             : out std_logic;
  FF_TX_F_CLK_3             : out std_logic;
  FF_TX_H_CLK_0             : out std_logic;
  FF_TX_H_CLK_1             : out std_logic;
  FF_TX_H_CLK_2             : out std_logic;
  FF_TX_H_CLK_3             : out std_logic;
  FFS_CC_OVERRUN_0             : out std_logic;
  FFS_CC_OVERRUN_1             : out std_logic;
  FFS_CC_OVERRUN_2             : out std_logic;
  FFS_CC_OVERRUN_3             : out std_logic;
  FFS_CC_UNDERRUN_0             : out std_logic;
  FFS_CC_UNDERRUN_1             : out std_logic;
  FFS_CC_UNDERRUN_2             : out std_logic;
  FFS_CC_UNDERRUN_3             : out std_logic;
  FFS_LS_SYNC_STATUS_0             : out std_logic;
  FFS_LS_SYNC_STATUS_1             : out std_logic;
  FFS_LS_SYNC_STATUS_2             : out std_logic;
  FFS_LS_SYNC_STATUS_3             : out std_logic;
  FFS_CDR_TRAIN_DONE_0             : out std_logic;
  FFS_CDR_TRAIN_DONE_1             : out std_logic;
  FFS_CDR_TRAIN_DONE_2             : out std_logic;
  FFS_CDR_TRAIN_DONE_3             : out std_logic;
  FFS_PCIE_CON_0             : out std_logic;
  FFS_PCIE_CON_1             : out std_logic;
  FFS_PCIE_CON_2             : out std_logic;
  FFS_PCIE_CON_3             : out std_logic;
  FFS_PCIE_DONE_0             : out std_logic;
  FFS_PCIE_DONE_1             : out std_logic;
  FFS_PCIE_DONE_2             : out std_logic;
  FFS_PCIE_DONE_3             : out std_logic;
  FFS_PLOL             : out std_logic;
  FFS_RLOL_0             : out std_logic;
  FFS_RLOL_1             : out std_logic;
  FFS_RLOL_2             : out std_logic;
  FFS_RLOL_3             : out std_logic;
  FFS_RLOS_HI_0             : out std_logic;
  FFS_RLOS_HI_1             : out std_logic;
  FFS_RLOS_HI_2             : out std_logic;
  FFS_RLOS_HI_3             : out std_logic;
  FFS_RLOS_LO_0             : out std_logic;
  FFS_RLOS_LO_1             : out std_logic;
  FFS_RLOS_LO_2             : out std_logic;
  FFS_RLOS_LO_3             : out std_logic;
  FFS_RXFBFIFO_ERROR_0             : out std_logic;
  FFS_RXFBFIFO_ERROR_1             : out std_logic;
  FFS_RXFBFIFO_ERROR_2             : out std_logic;
  FFS_RXFBFIFO_ERROR_3             : out std_logic;
  FFS_TXFBFIFO_ERROR_0             : out std_logic;
  FFS_TXFBFIFO_ERROR_1             : out std_logic;
  FFS_TXFBFIFO_ERROR_2             : out std_logic;
  FFS_TXFBFIFO_ERROR_3             : out std_logic;
  PCIE_PHYSTATUS_0             : out std_logic;
  PCIE_PHYSTATUS_1             : out std_logic;
  PCIE_PHYSTATUS_2             : out std_logic;
  PCIE_PHYSTATUS_3             : out std_logic;
  PCIE_RXVALID_0               : out std_logic;
  PCIE_RXVALID_1               : out std_logic;
  PCIE_RXVALID_2               : out std_logic;
  PCIE_RXVALID_3               : out std_logic;
  FFS_SKP_ADDED_0                  : out std_logic;
  FFS_SKP_ADDED_1                  : out std_logic;
  FFS_SKP_ADDED_2                  : out std_logic;
  FFS_SKP_ADDED_3                  : out std_logic;
  FFS_SKP_DELETED_0                : out std_logic;
  FFS_SKP_DELETED_1                : out std_logic;
  FFS_SKP_DELETED_2                : out std_logic;
  FFS_SKP_DELETED_3                : out std_logic;
  LDR_RX2CORE_0                    : out std_logic;
  LDR_RX2CORE_1                    : out std_logic;
  LDR_RX2CORE_2                    : out std_logic;
  LDR_RX2CORE_3                    : out std_logic;
  REFCK2CORE             : out std_logic;
  SCIINT                : out std_logic;
  SCIRDATA0             : out std_logic;
  SCIRDATA1             : out std_logic;
  SCIRDATA2             : out std_logic;
  SCIRDATA3             : out std_logic;
  SCIRDATA4             : out std_logic;
  SCIRDATA5             : out std_logic;
  SCIRDATA6             : out std_logic;
  SCIRDATA7             : out std_logic;
  REFCLK_TO_NQ          : out std_logic
);
end component;
   attribute CONFIG_FILE: string;
   attribute CONFIG_FILE of PCSD_INST : label is USER_CONFIG_FILE;
   attribute QUAD_MODE: string;
   attribute QUAD_MODE of PCSD_INST : label is "SINGLE";
   attribute PLL_SRC: string;
   attribute PLL_SRC of PCSD_INST : label is "REFCLK_CORE";
   attribute CH0_CDR_SRC: string;
   attribute CH0_CDR_SRC of PCSD_INST : label is "REFCLK_EXT";
   attribute CH1_CDR_SRC: string;
   attribute CH1_CDR_SRC of PCSD_INST : label is "REFCLK_EXT";
   attribute CH2_CDR_SRC: string;
   attribute CH2_CDR_SRC of PCSD_INST : label is "REFCLK_EXT";
   attribute CH3_CDR_SRC: string;
   attribute CH3_CDR_SRC of PCSD_INST : label is "REFCLK_EXT";
   attribute FREQUENCY_PIN_FF_RX_F_CLK_0: string;
   attribute FREQUENCY_PIN_FF_RX_F_CLK_0 of PCSD_INST : label is "250.000";
   attribute FREQUENCY_PIN_FF_RX_F_CLK_1: string;
   attribute FREQUENCY_PIN_FF_RX_F_CLK_1 of PCSD_INST : label is "250.000";
   attribute FREQUENCY_PIN_FF_RX_F_CLK_2: string;
   attribute FREQUENCY_PIN_FF_RX_F_CLK_2 of PCSD_INST : label is "250.000";
   attribute FREQUENCY_PIN_FF_RX_F_CLK_3: string;
   attribute FREQUENCY_PIN_FF_RX_F_CLK_3 of PCSD_INST : label is "250.000";
   attribute FREQUENCY_PIN_FF_RX_H_CLK_0: string;
   attribute FREQUENCY_PIN_FF_RX_H_CLK_0 of PCSD_INST : label is "125.000";
   attribute FREQUENCY_PIN_FF_RX_H_CLK_1: string;
   attribute FREQUENCY_PIN_FF_RX_H_CLK_1 of PCSD_INST : label is "125.000";
   attribute FREQUENCY_PIN_FF_RX_H_CLK_2: string;
   attribute FREQUENCY_PIN_FF_RX_H_CLK_2 of PCSD_INST : label is "125.000";
   attribute FREQUENCY_PIN_FF_RX_H_CLK_3: string;
   attribute FREQUENCY_PIN_FF_RX_H_CLK_3 of PCSD_INST : label is "125.000";
   attribute FREQUENCY_PIN_FF_TX_F_CLK_0: string;
   attribute FREQUENCY_PIN_FF_TX_F_CLK_0 of PCSD_INST : label is "150.000";
   attribute FREQUENCY_PIN_FF_TX_F_CLK_1: string;
   attribute FREQUENCY_PIN_FF_TX_F_CLK_1 of PCSD_INST : label is "150.000";
   attribute FREQUENCY_PIN_FF_TX_F_CLK_2: string;
   attribute FREQUENCY_PIN_FF_TX_F_CLK_2 of PCSD_INST : label is "150.000";
   attribute FREQUENCY_PIN_FF_TX_F_CLK_3: string;
   attribute FREQUENCY_PIN_FF_TX_F_CLK_3 of PCSD_INST : label is "150.000";
   attribute FREQUENCY_PIN_FF_TX_H_CLK_0: string;
   attribute FREQUENCY_PIN_FF_TX_H_CLK_0 of PCSD_INST : label is "75.0000";
   attribute FREQUENCY_PIN_FF_TX_H_CLK_1: string;
   attribute FREQUENCY_PIN_FF_TX_H_CLK_1 of PCSD_INST : label is "75.0000";
   attribute FREQUENCY_PIN_FF_TX_H_CLK_2: string;
   attribute FREQUENCY_PIN_FF_TX_H_CLK_2 of PCSD_INST : label is "75.0000";
   attribute FREQUENCY_PIN_FF_TX_H_CLK_3: string;
   attribute FREQUENCY_PIN_FF_TX_H_CLK_3 of PCSD_INST : label is "75.0000";
   attribute FREQUENCY_PIN_REFCK2CORE: string;
   attribute FREQUENCY_PIN_REFCK2CORE of PCSD_INST : label is "150.0";
   attribute black_box_pad_pin: string;
   attribute black_box_pad_pin of PCSD : component is "HDINP0, HDINN0, HDINP1, HDINN1, HDINP2, HDINN2, HDINP3, HDINN3, HDOUTP0, HDOUTN0, HDOUTP1, HDOUTN1, HDOUTP2, HDOUTN2, HDOUTP3, HDOUTN3, REFCLKP, REFCLKN";

signal refclk_from_nq : std_logic := '0';
signal fpsc_vlo : std_logic := '0';
signal fpsc_vhi : std_logic := '1';
signal cin : std_logic_vector (11 downto 0) := "000000000000";
signal cout : std_logic_vector (19 downto 0);
signal    tx_full_clk_ch0_sig   :   std_logic;
signal    tx_full_clk_ch1_sig   :   std_logic;
signal    tx_full_clk_ch2_sig   :   std_logic;
signal    tx_full_clk_ch3_sig   :   std_logic;

signal    refclk2fpga_sig  :   std_logic;
signal    tx_pll_lol_qd_sig  :   std_logic;
signal    rx_los_low_ch0_sig  :   std_logic;
signal    rx_los_low_ch1_sig  :   std_logic;
signal    rx_los_low_ch2_sig  :   std_logic;
signal    rx_los_low_ch3_sig  :   std_logic;
signal    rx_cdr_lol_ch0_sig  :   std_logic;
signal    rx_cdr_lol_ch1_sig  :   std_logic;
signal    rx_cdr_lol_ch2_sig  :   std_logic;
signal    rx_cdr_lol_ch3_sig  :   std_logic;



signal    refclkdiv2_tx_ch  :   std_logic;
signal    tx_pcs_rst_ch_c   :   std_logic;
signal    rst_qd_c   :   std_logic;


begin

vlo_inst : VLO port map(Z => fpsc_vlo);
vhi_inst : VHI port map(Z => fpsc_vhi);

  refclk2fpga <= refclk2fpga_sig;
  tx_pll_lol_qd_s <= tx_pll_lol_qd_sig;
  tx_full_clk_ch0 <= tx_full_clk_ch0_sig;
  tx_full_clk_ch1 <= tx_full_clk_ch1_sig;
  tx_full_clk_ch2 <= tx_full_clk_ch2_sig;
  tx_full_clk_ch3 <= tx_full_clk_ch3_sig;

-- pcs_quad instance
PCSD_INST : PCSD
--synopsys translate_off
  generic map (CONFIG_FILE => USER_CONFIG_FILE,
               QUAD_MODE => "SINGLE",
               CH0_CDR_SRC => "REFCLK_EXT",
               CH1_CDR_SRC => "REFCLK_EXT",
               CH2_CDR_SRC => "REFCLK_EXT",
               CH3_CDR_SRC => "REFCLK_EXT",
               PLL_SRC  => "REFCLK_CORE"
  )
--synopsys translate_on
port map  (
  REFCLKP => fpsc_vlo,
  REFCLKN => fpsc_vlo,

----- CH0 -----
  HDOUTP0 => hdoutp_ch0,
  HDOUTN0 => hdoutn_ch0,
  HDINP0 => fpsc_vlo,
  HDINN0 => fpsc_vlo,
  PCIE_TXDETRX_PR2TLB_0 => fpsc_vlo,
  PCIE_TXCOMPLIANCE_0 => fpsc_vlo,
  PCIE_RXPOLARITY_0 => fpsc_vlo,
  PCIE_POWERDOWN_0_0 => fpsc_vlo,
  PCIE_POWERDOWN_0_1 => fpsc_vlo,
  PCIE_RXVALID_0 => open,
  PCIE_PHYSTATUS_0 => open,
  SCISELCH0 => fpsc_vlo,
  SCIENCH0 => fpsc_vlo,
  FF_RXI_CLK_0 => fpsc_vlo,
  FF_TXI_CLK_0 => txiclk_ch0,
  FF_EBRD_CLK_0 => fpsc_vlo,
  FF_RX_F_CLK_0 => open,
  FF_RX_H_CLK_0 => open,
  FF_TX_F_CLK_0 => tx_full_clk_ch0_sig,
  FF_TX_H_CLK_0 => tx_half_clk_ch0,
  FFC_CK_CORE_RX_0 => fpsc_vlo,
  FF_TX_D_0_0 => txdata_ch0(0),
  FF_TX_D_0_1 => txdata_ch0(1),
  FF_TX_D_0_2 => txdata_ch0(2),
  FF_TX_D_0_3 => txdata_ch0(3),
  FF_TX_D_0_4 => txdata_ch0(4),
  FF_TX_D_0_5 => txdata_ch0(5),
  FF_TX_D_0_6 => txdata_ch0(6),
  FF_TX_D_0_7 => txdata_ch0(7),
  FF_TX_D_0_8 => txdata_ch0(8),
  FF_TX_D_0_9 => txdata_ch0(9),
  FF_TX_D_0_10 => fpsc_vlo,
  FF_TX_D_0_11 => fpsc_vlo,
  FF_TX_D_0_12 => fpsc_vlo,
  FF_TX_D_0_13 => fpsc_vlo,
  FF_TX_D_0_14 => fpsc_vlo,
  FF_TX_D_0_15 => fpsc_vlo,
  FF_TX_D_0_16 => fpsc_vlo,
  FF_TX_D_0_17 => fpsc_vlo,
  FF_TX_D_0_18 => fpsc_vlo,
  FF_TX_D_0_19 => fpsc_vlo,
  FF_TX_D_0_20 => fpsc_vlo,
  FF_TX_D_0_21 => fpsc_vlo,
  FF_TX_D_0_22 => fpsc_vlo,
  FF_TX_D_0_23 => fpsc_vlo,
  FF_RX_D_0_0 => open,
  FF_RX_D_0_1 => open,
  FF_RX_D_0_2 => open,
  FF_RX_D_0_3 => open,
  FF_RX_D_0_4 => open,
  FF_RX_D_0_5 => open,
  FF_RX_D_0_6 => open,
  FF_RX_D_0_7 => open,
  FF_RX_D_0_8 => open,
  FF_RX_D_0_9 => open,
  FF_RX_D_0_10 => open,
  FF_RX_D_0_11 => open,
  FF_RX_D_0_12 => open,
  FF_RX_D_0_13 => open,
  FF_RX_D_0_14 => open,
  FF_RX_D_0_15 => open,
  FF_RX_D_0_16 => open,
  FF_RX_D_0_17 => open,
  FF_RX_D_0_18 => open,
  FF_RX_D_0_19 => open,
  FF_RX_D_0_20 => open,
  FF_RX_D_0_21 => open,
  FF_RX_D_0_22 => open,
  FF_RX_D_0_23 => open,

  FFC_RRST_0 => fpsc_vlo,
  FFC_SIGNAL_DETECT_0 => fpsc_vlo,
  FFC_SB_PFIFO_LP_0 => fpsc_vlo,
  FFC_PFIFO_CLR_0 => fpsc_vlo,
  FFC_SB_INV_RX_0 => fpsc_vlo,
  FFC_PCIE_CT_0 => fpsc_vlo,
  FFC_PCI_DET_EN_0 => fpsc_vlo,
  FFC_FB_LOOPBACK_0 => fpsc_vlo,
  FFC_ENABLE_CGALIGN_0 => fpsc_vlo,
  FFC_EI_EN_0 => fpsc_vlo,
  FFC_LANE_TX_RST_0 => tx_pcs_rst_ch_c,
  FFC_TXPWDNB_0 => tx_pwrup_ch0_c,
  FFC_LANE_RX_RST_0 => fpsc_vlo,
  FFC_RXPWDNB_0 => fpsc_vlo,
  FFS_RLOS_LO_0 => open,
  FFS_RLOS_HI_0 => open,
  FFS_PCIE_CON_0 => open,
  FFS_PCIE_DONE_0 => open,
  FFS_LS_SYNC_STATUS_0 => open,
  FFS_CC_OVERRUN_0 => open,
  FFS_CC_UNDERRUN_0 => open,
  FFS_SKP_ADDED_0 => open,
  FFS_SKP_DELETED_0 => open,
  FFS_RLOL_0 => open,
  FFS_RXFBFIFO_ERROR_0 => open,
  FFS_TXFBFIFO_ERROR_0 => open,
  LDR_CORE2TX_0 => fpsc_vlo,
  FFC_LDR_CORE2TX_EN_0 => fpsc_vlo,
  LDR_RX2CORE_0 => open,
  FFS_CDR_TRAIN_DONE_0 => open,
  FFC_DIV11_MODE_TX_0 => fpsc_vlo,
  FFC_RATE_MODE_TX_0 => tx_div2_mode_ch0_c,
  FFC_DIV11_MODE_RX_0 => fpsc_vlo,
  FFC_RATE_MODE_RX_0 => fpsc_vlo,

----- CH1 -----
  HDOUTP1 => hdoutp_ch1,
  HDOUTN1 => hdoutn_ch1,
  HDINP1 => fpsc_vlo,
  HDINN1 => fpsc_vlo,
  PCIE_TXDETRX_PR2TLB_1 => fpsc_vlo,
  PCIE_TXCOMPLIANCE_1 => fpsc_vlo,
  PCIE_RXPOLARITY_1 => fpsc_vlo,
  PCIE_POWERDOWN_1_0 => fpsc_vlo,
  PCIE_POWERDOWN_1_1 => fpsc_vlo,
  PCIE_RXVALID_1 => open,
  PCIE_PHYSTATUS_1 => open,
  SCISELCH1 => fpsc_vlo,
  SCIENCH1 => fpsc_vlo,
  FF_RXI_CLK_1 => fpsc_vlo,
  FF_TXI_CLK_1 => txiclk_ch1,
  FF_EBRD_CLK_1 => fpsc_vlo,
  FF_RX_F_CLK_1 => open,
  FF_RX_H_CLK_1 => open,
  FF_TX_F_CLK_1 => tx_full_clk_ch1_sig,
  FF_TX_H_CLK_1 => tx_half_clk_ch1,
  FFC_CK_CORE_RX_1 => fpsc_vlo,
  FF_TX_D_1_0 => txdata_ch1(0),
  FF_TX_D_1_1 => txdata_ch1(1),
  FF_TX_D_1_2 => txdata_ch1(2),
  FF_TX_D_1_3 => txdata_ch1(3),
  FF_TX_D_1_4 => txdata_ch1(4),
  FF_TX_D_1_5 => txdata_ch1(5),
  FF_TX_D_1_6 => txdata_ch1(6),
  FF_TX_D_1_7 => txdata_ch1(7),
  FF_TX_D_1_8 => txdata_ch1(8),
  FF_TX_D_1_9 => txdata_ch1(9),
  FF_TX_D_1_10 => fpsc_vlo,
  FF_TX_D_1_11 => fpsc_vlo,
  FF_TX_D_1_12 => fpsc_vlo,
  FF_TX_D_1_13 => fpsc_vlo,
  FF_TX_D_1_14 => fpsc_vlo,
  FF_TX_D_1_15 => fpsc_vlo,
  FF_TX_D_1_16 => fpsc_vlo,
  FF_TX_D_1_17 => fpsc_vlo,
  FF_TX_D_1_18 => fpsc_vlo,
  FF_TX_D_1_19 => fpsc_vlo,
  FF_TX_D_1_20 => fpsc_vlo,
  FF_TX_D_1_21 => fpsc_vlo,
  FF_TX_D_1_22 => fpsc_vlo,
  FF_TX_D_1_23 => fpsc_vlo,
  FF_RX_D_1_0 => open,
  FF_RX_D_1_1 => open,
  FF_RX_D_1_2 => open,
  FF_RX_D_1_3 => open,
  FF_RX_D_1_4 => open,
  FF_RX_D_1_5 => open,
  FF_RX_D_1_6 => open,
  FF_RX_D_1_7 => open,
  FF_RX_D_1_8 => open,
  FF_RX_D_1_9 => open,
  FF_RX_D_1_10 => open,
  FF_RX_D_1_11 => open,
  FF_RX_D_1_12 => open,
  FF_RX_D_1_13 => open,
  FF_RX_D_1_14 => open,
  FF_RX_D_1_15 => open,
  FF_RX_D_1_16 => open,
  FF_RX_D_1_17 => open,
  FF_RX_D_1_18 => open,
  FF_RX_D_1_19 => open,
  FF_RX_D_1_20 => open,
  FF_RX_D_1_21 => open,
  FF_RX_D_1_22 => open,
  FF_RX_D_1_23 => open,

  FFC_RRST_1 => fpsc_vlo,
  FFC_SIGNAL_DETECT_1 => fpsc_vlo,
  FFC_SB_PFIFO_LP_1 => fpsc_vlo,
  FFC_PFIFO_CLR_1 => fpsc_vlo,
  FFC_SB_INV_RX_1 => fpsc_vlo,
  FFC_PCIE_CT_1 => fpsc_vlo,
  FFC_PCI_DET_EN_1 => fpsc_vlo,
  FFC_FB_LOOPBACK_1 => fpsc_vlo,
  FFC_ENABLE_CGALIGN_1 => fpsc_vlo,
  FFC_EI_EN_1 => fpsc_vlo,
  FFC_LANE_TX_RST_1 => tx_pcs_rst_ch_c,
  FFC_TXPWDNB_1 => tx_pwrup_ch1_c,
  FFC_LANE_RX_RST_1 => fpsc_vlo,
  FFC_RXPWDNB_1 => fpsc_vlo,
  FFS_RLOS_LO_1 => open,
  FFS_RLOS_HI_1 => open,
  FFS_PCIE_CON_1 => open,
  FFS_PCIE_DONE_1 => open,
  FFS_LS_SYNC_STATUS_1 => open,
  FFS_CC_OVERRUN_1 => open,
  FFS_CC_UNDERRUN_1 => open,
  FFS_SKP_ADDED_1 => open,
  FFS_SKP_DELETED_1 => open,
  FFS_RLOL_1 => open,
  FFS_RXFBFIFO_ERROR_1 => open,
  FFS_TXFBFIFO_ERROR_1 => open,
  LDR_CORE2TX_1 => fpsc_vlo,
  FFC_LDR_CORE2TX_EN_1 => fpsc_vlo,
  LDR_RX2CORE_1 => open,
  FFS_CDR_TRAIN_DONE_1 => open,
  FFC_DIV11_MODE_TX_1 => fpsc_vlo,
  FFC_RATE_MODE_TX_1 => tx_div2_mode_ch1_c,
  FFC_DIV11_MODE_RX_1 => fpsc_vlo,
  FFC_RATE_MODE_RX_1 => fpsc_vlo,

----- CH2 -----
  HDOUTP2 => hdoutp_ch2,
  HDOUTN2 => hdoutn_ch2,
  HDINP2 => fpsc_vlo,
  HDINN2 => fpsc_vlo,
  PCIE_TXDETRX_PR2TLB_2 => fpsc_vlo,
  PCIE_TXCOMPLIANCE_2 => fpsc_vlo,
  PCIE_RXPOLARITY_2 => fpsc_vlo,
  PCIE_POWERDOWN_2_0 => fpsc_vlo,
  PCIE_POWERDOWN_2_1 => fpsc_vlo,
  PCIE_RXVALID_2 => open,
  PCIE_PHYSTATUS_2 => open,
  SCISELCH2 => fpsc_vlo,
  SCIENCH2 => fpsc_vlo,
  FF_RXI_CLK_2 => fpsc_vlo,
  FF_TXI_CLK_2 => txiclk_ch2,
  FF_EBRD_CLK_2 => fpsc_vlo,
  FF_RX_F_CLK_2 => open,
  FF_RX_H_CLK_2 => open,
  FF_TX_F_CLK_2 => tx_full_clk_ch2_sig,
  FF_TX_H_CLK_2 => tx_half_clk_ch2,
  FFC_CK_CORE_RX_2 => fpsc_vlo,
  FF_TX_D_2_0 => txdata_ch2(0),
  FF_TX_D_2_1 => txdata_ch2(1),
  FF_TX_D_2_2 => txdata_ch2(2),
  FF_TX_D_2_3 => txdata_ch2(3),
  FF_TX_D_2_4 => txdata_ch2(4),
  FF_TX_D_2_5 => txdata_ch2(5),
  FF_TX_D_2_6 => txdata_ch2(6),
  FF_TX_D_2_7 => txdata_ch2(7),
  FF_TX_D_2_8 => txdata_ch2(8),
  FF_TX_D_2_9 => txdata_ch2(9),
  FF_TX_D_2_10 => fpsc_vlo,
  FF_TX_D_2_11 => fpsc_vlo,
  FF_TX_D_2_12 => fpsc_vlo,
  FF_TX_D_2_13 => fpsc_vlo,
  FF_TX_D_2_14 => fpsc_vlo,
  FF_TX_D_2_15 => fpsc_vlo,
  FF_TX_D_2_16 => fpsc_vlo,
  FF_TX_D_2_17 => fpsc_vlo,
  FF_TX_D_2_18 => fpsc_vlo,
  FF_TX_D_2_19 => fpsc_vlo,
  FF_TX_D_2_20 => fpsc_vlo,
  FF_TX_D_2_21 => fpsc_vlo,
  FF_TX_D_2_22 => fpsc_vlo,
  FF_TX_D_2_23 => fpsc_vlo,
  FF_RX_D_2_0 => open,
  FF_RX_D_2_1 => open,
  FF_RX_D_2_2 => open,
  FF_RX_D_2_3 => open,
  FF_RX_D_2_4 => open,
  FF_RX_D_2_5 => open,
  FF_RX_D_2_6 => open,
  FF_RX_D_2_7 => open,
  FF_RX_D_2_8 => open,
  FF_RX_D_2_9 => open,
  FF_RX_D_2_10 => open,
  FF_RX_D_2_11 => open,
  FF_RX_D_2_12 => open,
  FF_RX_D_2_13 => open,
  FF_RX_D_2_14 => open,
  FF_RX_D_2_15 => open,
  FF_RX_D_2_16 => open,
  FF_RX_D_2_17 => open,
  FF_RX_D_2_18 => open,
  FF_RX_D_2_19 => open,
  FF_RX_D_2_20 => open,
  FF_RX_D_2_21 => open,
  FF_RX_D_2_22 => open,
  FF_RX_D_2_23 => open,

  FFC_RRST_2 => fpsc_vlo,
  FFC_SIGNAL_DETECT_2 => fpsc_vlo,
  FFC_SB_PFIFO_LP_2 => fpsc_vlo,
  FFC_PFIFO_CLR_2 => fpsc_vlo,
  FFC_SB_INV_RX_2 => fpsc_vlo,
  FFC_PCIE_CT_2 => fpsc_vlo,
  FFC_PCI_DET_EN_2 => fpsc_vlo,
  FFC_FB_LOOPBACK_2 => fpsc_vlo,
  FFC_ENABLE_CGALIGN_2 => fpsc_vlo,
  FFC_EI_EN_2 => fpsc_vlo,
  FFC_LANE_TX_RST_2 => tx_pcs_rst_ch_c,
  FFC_TXPWDNB_2 => tx_pwrup_ch2_c,
  FFC_LANE_RX_RST_2 => fpsc_vlo,
  FFC_RXPWDNB_2 => fpsc_vlo,
  FFS_RLOS_LO_2 => open,
  FFS_RLOS_HI_2 => open,
  FFS_PCIE_CON_2 => open,
  FFS_PCIE_DONE_2 => open,
  FFS_LS_SYNC_STATUS_2 => open,
  FFS_CC_OVERRUN_2 => open,
  FFS_CC_UNDERRUN_2 => open,
  FFS_SKP_ADDED_2 => open,
  FFS_SKP_DELETED_2 => open,
  FFS_RLOL_2 => open,
  FFS_RXFBFIFO_ERROR_2 => open,
  FFS_TXFBFIFO_ERROR_2 => open,
  LDR_CORE2TX_2 => fpsc_vlo,
  FFC_LDR_CORE2TX_EN_2 => fpsc_vlo,
  LDR_RX2CORE_2 => open,
  FFS_CDR_TRAIN_DONE_2 => open,
  FFC_DIV11_MODE_TX_2 => fpsc_vlo,
  FFC_RATE_MODE_TX_2 => tx_div2_mode_ch2_c,
  FFC_DIV11_MODE_RX_2 => fpsc_vlo,
  FFC_RATE_MODE_RX_2 => fpsc_vlo,

----- CH3 -----
  HDOUTP3 => hdoutp_ch3,
  HDOUTN3 => hdoutn_ch3,
  HDINP3 => fpsc_vlo,
  HDINN3 => fpsc_vlo,
  PCIE_TXDETRX_PR2TLB_3 => fpsc_vlo,
  PCIE_TXCOMPLIANCE_3 => fpsc_vlo,
  PCIE_RXPOLARITY_3 => fpsc_vlo,
  PCIE_POWERDOWN_3_0 => fpsc_vlo,
  PCIE_POWERDOWN_3_1 => fpsc_vlo,
  PCIE_RXVALID_3 => open,
  PCIE_PHYSTATUS_3 => open,
  SCISELCH3 => fpsc_vlo,
  SCIENCH3 => fpsc_vlo,
  FF_RXI_CLK_3 => fpsc_vlo,
  FF_TXI_CLK_3 => txiclk_ch3,
  FF_EBRD_CLK_3 => fpsc_vlo,
  FF_RX_F_CLK_3 => open,
  FF_RX_H_CLK_3 => open,
  FF_TX_F_CLK_3 => tx_full_clk_ch3_sig,
  FF_TX_H_CLK_3 => tx_half_clk_ch3,
  FFC_CK_CORE_RX_3 => fpsc_vlo,
  FF_TX_D_3_0 => txdata_ch3(0),
  FF_TX_D_3_1 => txdata_ch3(1),
  FF_TX_D_3_2 => txdata_ch3(2),
  FF_TX_D_3_3 => txdata_ch3(3),
  FF_TX_D_3_4 => txdata_ch3(4),
  FF_TX_D_3_5 => txdata_ch3(5),
  FF_TX_D_3_6 => txdata_ch3(6),
  FF_TX_D_3_7 => txdata_ch3(7),
  FF_TX_D_3_8 => txdata_ch3(8),
  FF_TX_D_3_9 => txdata_ch3(9),
  FF_TX_D_3_10 => fpsc_vlo,
  FF_TX_D_3_11 => fpsc_vlo,
  FF_TX_D_3_12 => fpsc_vlo,
  FF_TX_D_3_13 => fpsc_vlo,
  FF_TX_D_3_14 => fpsc_vlo,
  FF_TX_D_3_15 => fpsc_vlo,
  FF_TX_D_3_16 => fpsc_vlo,
  FF_TX_D_3_17 => fpsc_vlo,
  FF_TX_D_3_18 => fpsc_vlo,
  FF_TX_D_3_19 => fpsc_vlo,
  FF_TX_D_3_20 => fpsc_vlo,
  FF_TX_D_3_21 => fpsc_vlo,
  FF_TX_D_3_22 => fpsc_vlo,
  FF_TX_D_3_23 => fpsc_vlo,
  FF_RX_D_3_0 => open,
  FF_RX_D_3_1 => open,
  FF_RX_D_3_2 => open,
  FF_RX_D_3_3 => open,
  FF_RX_D_3_4 => open,
  FF_RX_D_3_5 => open,
  FF_RX_D_3_6 => open,
  FF_RX_D_3_7 => open,
  FF_RX_D_3_8 => open,
  FF_RX_D_3_9 => open,
  FF_RX_D_3_10 => open,
  FF_RX_D_3_11 => open,
  FF_RX_D_3_12 => open,
  FF_RX_D_3_13 => open,
  FF_RX_D_3_14 => open,
  FF_RX_D_3_15 => open,
  FF_RX_D_3_16 => open,
  FF_RX_D_3_17 => open,
  FF_RX_D_3_18 => open,
  FF_RX_D_3_19 => open,
  FF_RX_D_3_20 => open,
  FF_RX_D_3_21 => open,
  FF_RX_D_3_22 => open,
  FF_RX_D_3_23 => open,

  FFC_RRST_3 => fpsc_vlo,
  FFC_SIGNAL_DETECT_3 => fpsc_vlo,
  FFC_SB_PFIFO_LP_3 => fpsc_vlo,
  FFC_PFIFO_CLR_3 => fpsc_vlo,
  FFC_SB_INV_RX_3 => fpsc_vlo,
  FFC_PCIE_CT_3 => fpsc_vlo,
  FFC_PCI_DET_EN_3 => fpsc_vlo,
  FFC_FB_LOOPBACK_3 => fpsc_vlo,
  FFC_ENABLE_CGALIGN_3 => fpsc_vlo,
  FFC_EI_EN_3 => fpsc_vlo,
  FFC_LANE_TX_RST_3 => tx_pcs_rst_ch_c,
  FFC_TXPWDNB_3 => tx_pwrup_ch3_c,
  FFC_LANE_RX_RST_3 => fpsc_vlo,
  FFC_RXPWDNB_3 => fpsc_vlo,
  FFS_RLOS_LO_3 => open,
  FFS_RLOS_HI_3 => open,
  FFS_PCIE_CON_3 => open,
  FFS_PCIE_DONE_3 => open,
  FFS_LS_SYNC_STATUS_3 => open,
  FFS_CC_OVERRUN_3 => open,
  FFS_CC_UNDERRUN_3 => open,
  FFS_SKP_ADDED_3 => open,
  FFS_SKP_DELETED_3 => open,
  FFS_RLOL_3 => open,
  FFS_RXFBFIFO_ERROR_3 => open,
  FFS_TXFBFIFO_ERROR_3 => open,
  LDR_CORE2TX_3 => fpsc_vlo,
  FFC_LDR_CORE2TX_EN_3 => fpsc_vlo,
  LDR_RX2CORE_3 => open,
  FFS_CDR_TRAIN_DONE_3 => open,
  FFC_DIV11_MODE_TX_3 => fpsc_vlo,
  FFC_RATE_MODE_TX_3 => tx_div2_mode_ch3_c,
  FFC_DIV11_MODE_RX_3 => fpsc_vlo,
  FFC_RATE_MODE_RX_3 => fpsc_vlo,

----- Auxilliary ----
  SCIWDATA7 => fpsc_vlo,
  SCIWDATA6 => fpsc_vlo,
  SCIWDATA5 => fpsc_vlo,
  SCIWDATA4 => fpsc_vlo,
  SCIWDATA3 => fpsc_vlo,
  SCIWDATA2 => fpsc_vlo,
  SCIWDATA1 => fpsc_vlo,
  SCIWDATA0 => fpsc_vlo,
  SCIADDR5 => fpsc_vlo,
  SCIADDR4 => fpsc_vlo,
  SCIADDR3 => fpsc_vlo,
  SCIADDR2 => fpsc_vlo,
  SCIADDR1 => fpsc_vlo,
  SCIADDR0 => fpsc_vlo,
  SCIRDATA7 => open,
  SCIRDATA6 => open,
  SCIRDATA5 => open,
  SCIRDATA4 => open,
  SCIRDATA3 => open,
  SCIRDATA2 => open,
  SCIRDATA1 => open,
  SCIRDATA0 => open,
  SCIENAUX => fpsc_vlo,
  SCISELAUX => fpsc_vlo,
  SCIRD => fpsc_vlo,
  SCIWSTN => fpsc_vlo,
  CYAWSTN => fpsc_vlo,
  SCIINT => open,
  FFC_CK_CORE_TX => fpga_txrefclk,
  FFC_MACRO_RST => serdes_rst_qd_c,
  FFC_QUAD_RST => rst_qd_c,
  FFC_TRST => tx_serdes_rst_c,
  FFS_PLOL => tx_pll_lol_qd_sig,
  FFC_SYNC_TOGGLE => tx_sync_qd_c,
  REFCK2CORE => refclk2fpga_sig,
  CIN0 => fpsc_vlo,
  CIN1 => fpsc_vlo,
  CIN2 => fpsc_vlo,
  CIN3 => fpsc_vlo,
  CIN4 => fpsc_vlo,
  CIN5 => fpsc_vlo,
  CIN6 => fpsc_vlo,
  CIN7 => fpsc_vlo,
  CIN8 => fpsc_vlo,
  CIN9 => fpsc_vlo,
  CIN10 => fpsc_vlo,
  CIN11 => fpsc_vlo,
  COUT0 => open,
  COUT1 => open,
  COUT2 => open,
  COUT3 => open,
  COUT4 => open,
  COUT5 => open,
  COUT6 => open,
  COUT7 => open,
  COUT8 => open,
  COUT9 => open,
  COUT10 => open,
  COUT11 => open,
  COUT12 => open,
  COUT13 => open,
  COUT14 => open,
  COUT15 => open,
  COUT16 => open,
  COUT17 => open,
  COUT18 => open,
  COUT19 => open,
  REFCLK_FROM_NQ => refclk_from_nq,
  REFCLK_TO_NQ => open);

                                                                                              
                                                                                              
  P5 : PROCESS(fpga_txrefclk, rst_n)
  BEGIN
     IF (rst_n = '0') THEN
         refclkdiv2_tx_ch <= '0';
     ELSIF (fpga_txrefclk'event and fpga_txrefclk = '1') THEN
         refclkdiv2_tx_ch <= not refclkdiv2_tx_ch;
     END IF;
  END PROCESS;

-- reset sequence for tx
tx_reset_sm_ch : hdmi_pcstx_reset_sm 
--synopsys translate_off
  generic map (count_index => 4)
--synopsys translate_on
port map  (
  rst_n => rst_n,
  refclkdiv2 => refclkdiv2_tx_ch,
  tx_pll_lol_qd_s => tx_pll_lol_qd_sig,
  rst_qd_c => rst_qd_c,
  tx_pcs_rst_ch_c => tx_pcs_rst_ch_c
  );
                                                                                              
                                                                                              
--synopsys translate_off
file_read : PROCESS
VARIABLE open_status : file_open_status;
FILE config : text;
BEGIN
   file_open (open_status, config, USER_CONFIG_FILE, read_mode);
   IF (open_status = name_error) THEN
      report "Auto configuration file for PCS module not found.  PCS internal configuration registers will not be initialized correctly during simulation!"
      severity ERROR;
   END IF;
   wait;
END PROCESS;
--synopsys translate_on
end hdmi_pcs_arch ;
