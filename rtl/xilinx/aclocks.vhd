
--   Target Chip: Xilinx
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity inp_ds_port is
   port(
      i_in_p    : in     std_logic;
      i_in_n    : in     std_logic;
      o_out     : out    std_logic
   );
end entity inp_ds_port;

architecture synthesis of inp_ds_port is
begin

-- IBUFDS: Differential Input Buffer
-- 7 Series
-- Xilinx HDL Libraries Guide, version 2014.4
IBUFDS_1 : IBUFDS
--generic map (
--   DIFF_TERM => FALSE, -- Differential Termination
--   IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--   IOSTANDARD => "DEFAULT")
port map (
   O 	=> o_out,  -- Buffer output
   I 	=> i_in_p, -- Diff_p buffer input (connect directly to top-level port)
   IB 	=> i_in_n  -- Diff_n buffer input (connect directly to top-level port)
);
-- End of IBUFDS_inst instantiation

end architecture synthesis;

-- eof

