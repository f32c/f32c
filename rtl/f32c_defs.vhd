
library ieee;
use ieee.std_logic_1164.all;

package f32c_pack is

constant MIPS_REG_ZERO:		std_logic_vector := "00000";
constant MIPS_REG_SP:		std_logic_vector := "11111";

constant MIPS_OP_SPECIAL:	std_logic_vector := "000000";
constant MIPS_OP_SPECIAL1:	std_logic_vector := "000001";
constant MIPS_OP_SPECIAL3:	std_logic_vector := "011111";

end;
