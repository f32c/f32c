-- Copyright (c) 2015, Smart Energy Instruments Inc.
-- All rights reserved.  For details, see COPYING in the top level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package config is
  constant CFG_CLK_BITLINK_PERIOD_NS : integer := 8;
  constant CFG_CLK_CPU_DIVIDE : integer := 20;
  constant CFG_CLK_CPU_PERIOD_NS : integer := 20;
  constant CFG_CLK_MEM_2X_DIVIDE : integer := 10;
  constant CFG_CLK_MEM_PERIOD_NS : integer := 20;
  constant CFG_DDRDQ_WIDTH : integer := 16;
  constant CFG_DDR_CK_CYCLE : integer := 20;
  constant CFG_DDR_READ_SAMPLE_TM : integer := 2;
  constant CFG_SA_WIDTH : integer := 13;
end package;
