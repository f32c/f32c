
--
-- Initial data template for bram_synth.
--
-- MenloPark Innovation LLC
--
-- 03/24/2019
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

package bram_synth_data is
type bram_synth_init_data_type is array(0 to 63) of std_logic_vector(15 downto 0);

constant bram_synth_init_data: bram_synth_init_data_type := (
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",x"0000",
others => (others => '0')
);
end bram_synth_data;
