library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package boot_block_pack is
  type boot_block_type is array(0 to 2047) of std_logic_vector(7 downto 0);
end boot_block_pack;
