library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package font_block_pack is
  type font8_block_type  is array(0 to (256*8)-1)  of std_logic_vector(7 downto 0);
  type font16_block_type is array(0 to (256*16)-1) of std_logic_vector(7 downto 0);
end font_block_pack;
