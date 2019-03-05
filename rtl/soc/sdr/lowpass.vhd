-- *********** Low-pass filter ************

-- simulates a simple RC filter
-- input clock and enable signal define the sampling freqency f_sampling
-- low pass frequency is
-- f_lowpass = f_sampling / 2^(C_bits_out-C_bits_in)
-- time factor: RC = 2^(C_bits_out-C_bits_in)
-- at each sample this iteration is done:

-- sum = sum + data_in - sum/RC

-- sum is connected to output

-- RC low pass filter analogy: 
-- voltage difference between input signal and charged capacitor C
-- makes a charging current through resistor R

-- sum = voltage of capacitor
-- data_in - sum/RC = charging current

-- (C)2016 Emard
-- LICENSE=BSD

LIBRARY ieee;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

entity lowpass is
  generic(
    C_bits_in: integer := 12; -- input bits, must be less than C_bits_out
    C_attenuation: integer := 0; -- attenuation factor 2^n
    C_bits_out: integer := 16 -- output bits (integrator sum)
  );
  port(
    clock: in std_logic; -- can run at high freq (CPU)
    enable: in std_logic := '1'; -- enable signal is a way to reduce sampling frequency
    data_in: in signed(C_bits_in-1 downto 0);
    data_out: out signed(C_bits_out-1 downto 0)
  );
end lowpass;
architecture behavior of lowpass is
  signal R_data_in: signed(C_bits_in-1 downto 0);
  signal sum: signed(C_bits_out-1 downto 0);
begin 
  process(clock,enable)
  begin
    if rising_edge(clock) and enable='1' then
      R_data_in <= data_in;
      sum <= sum + R_data_in / 2**C_attenuation - sum / 2**(C_bits_out-C_bits_in);
      data_out <= sum;
    end if;
  end process;
end behavior;	
