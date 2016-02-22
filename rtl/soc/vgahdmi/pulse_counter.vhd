library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

entity pulse_counter is
  generic
  (
    C_bits: integer := 8;
    C_wraparound: integer := 256 -- pulses per full rotation circle
  );
  port
  (
    clk: in std_Logic;
    pulse: in std_logic;
    count: out std_logic_vector(C_bits-1 downto 0)
  );
end pulse_counter;

architecture Behavioral of pulse_counter is
  signal puls_counter: std_logic_vector(C_bits-1 downto 0);
  signal puls_shift: std_logic_vector(2 downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      puls_shift <= pulse & puls_shift(2 downto 1);
      if (puls_shift(0) xor puls_shift(1)) = '1' then
        if conv_integer(puls_counter) = C_wraparound-1 then
          puls_counter <= (others => '0');
        else
          puls_counter <= puls_counter+1;
        end if;
      end if;
    end if;
  end process;
  count <= std_logic_vector(puls_counter);
  
end Behavioral;
