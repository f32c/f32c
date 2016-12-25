library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.boot_block_pack.all;

package boot_rom_mi32el is

-- empty and non-functional ROM bootloader
-- serves as placeholder when there's not enough
-- place for proper bootloader
constant boot_rom_mi32el : boot_block_type := (
	others => (others => '0')
    );

end boot_rom_mi32el;
