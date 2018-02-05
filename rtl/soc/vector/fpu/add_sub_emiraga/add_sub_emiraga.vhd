--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper for emiraga's Verilog adder
-- original source https://github.com/emiraga/ieee754-verilog

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.f32c_pack.all;

-- vhdl wrapper for verilog module rom_generic.v

entity add_sub_emiraga is
--  generic
--  (
--    generic_param1 : integer := 10;
--    generic_param2 : integer := 20
--  );
  port
  (
    clock_in    : in  std_logic;
    add_sub_bit : in  std_logic;
    inputA      : in  std_logic_vector(31 downto 0);
    inputB      : in  std_logic_vector(31 downto 0);
    outputC     : out std_logic_vector(31 downto 0)
  );
end;

architecture syn of add_sub_emiraga is
  component ieee_adder -- verilog name and its parameters
--  generic
--  (
--    generic_param1 : integer := 10;
--    generic_param2 : integer := 20
--  );
    port (
      clock_in    : in  std_logic;
      add_sub_bit : in  std_logic;
      inputA      : in  std_logic_vector(31 downto 0);
      inputB      : in  std_logic_vector(31 downto 0);
      outputC     : out std_logic_vector(31 downto 0)
    );
  end component;

begin
  ieee_adder_inst: ieee_adder
--  generic map
--  (
--    generic_param1 => 10,
--    generic_param2 => 20
--  )
  port map (
      clock_in => clock_in,
      add_sub_bit => add_sub_bit,
      inputA => inputA,
      inputB => inputB,
      outputC => outputC
  );
end syn;
