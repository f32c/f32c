-- Author: EMARD
-- License: BSD

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sigmadelta is
generic
(
  C_bits: integer range 2 to 16 := 12 -- sigma-delta DAC resolution
);
port
(
  clk: in std_logic;
  in_pcm: in signed(15 downto 0); -- 16-bit PCM in
  out_pwm: out std_logic
);
end;

architecture Behavioral of sigmadelta is
  signal R_pcm_unsigned_data: std_logic_vector(C_bits-1 downto 0);
  signal R_dac_acc: std_logic_vector(C_bits downto 0);
begin
  process(clk)
  begin
    if rising_edge(clk) then
      -- PCM data normally should have average 0 (removed DC offset)
      -- for purpose of PCM generation here is
      -- conversion to unsigned std_logic_vector
      -- by inverting MSB bit (effectively adding 0x8000)
      R_pcm_unsigned_data <= std_logic_vector( (not in_pcm(15)) & in_pcm(14 downto 16-C_bits) );
      -- Output 1-bit DAC
      R_dac_acc <= R_dac_acc + (R_dac_acc(C_bits) & R_pcm_unsigned_data);
    end if;
  end process;

  -- PWM output to 3.5mm jack (earphones)
  out_pwm <= R_dac_acc(C_bits);
end Behavioral;
