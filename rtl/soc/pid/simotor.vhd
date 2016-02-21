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
  generic(
    prescaler      : integer := 0; -- slow down the time
    motor_power    : integer := 512; -- acceleration
    motor_speed    : integer := 12;  -- inverse log2 friction proportional to speed
    -- larger motor_speed values allow higher motor top speed
    motor_friction : integer := 60   -- static friction
    -- when motor_power > motor_friction it starts to move
  );
  port
  (
    clock   : in  std_logic;
    bridge  : in  std_logic_vector(1 downto 0);
    encoder : out std_logic_vector(1 downto 0)
  );
end simotor;

architecture syn of simotor is
  component simotor_v
    generic (
      prescaler      : integer := 0;
      motor_power    : integer := 512; -- acceleration
      motor_speed    : integer := 12;  -- inverse log2 friction proportional to speed
      -- larger motor_speed values allow higher motor top speed
      motor_friction : integer := 60   -- static friction
      -- when motor_power > motor_friction it starts to move
    );
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
  generic map(
    prescaler => prescaler,
    motor_power => motor_power,
    motor_speed => motor_speed,
    motor_friction => motor_friction
  )
  port map(
    CLOCK => clock,
    F => bridge(0), R => bridge(1),
    A => encoder(0), B => encoder(1)
  );

end syn;
