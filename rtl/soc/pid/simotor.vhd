--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- LICENSE=BSD
--
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.f32c_pack.all;

-- vhdl wrapper for verilog module

entity simotor is
  port
  (
    clock : in  std_logic;
    f     : in  std_logic;
    r     : in  std_logic;
    a     : out std_logic;
    b     : out std_logic
  );
end simotor;

architecture syn of simotor is
  component simotor_v
    port (
      CLOCK : in  std_logic;
      F     : in  std_logic;
      R     : in  std_logic;
      A     : out std_logic;
      B     : out std_logic
    );
  end component;

begin
  simotor_inst: simotor_v
  port map(
    CLOCK => clock,
    F => f, R => r,
    A => a, B => b
  );

end syn;
