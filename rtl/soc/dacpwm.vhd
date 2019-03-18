-- combines resistor DAC and PWM
-- upper bits using DAC, lower bit using PWM

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all; -- we need signed type

entity dacpwm is
generic
(
  C_pcm_bits: integer := 12; -- input: how many bits PCM (including sign bit)
  C_dac_bits: integer := 4  -- output: how many bits DAC output, unsigned
);
port
(
  clk: in std_logic; -- required to run PWM
  pcm: in std_logic_vector(C_pcm_bits-1 downto 0); -- 12-bit signed PCM input
  dac: out std_logic_vector(C_dac_bits-1 downto 0) -- 4-bit unsigned DAC output
);
end;

architecture behavioral of dacpwm is
    constant C_pwm_bits: integer := C_pcm_bits-C_dac_bits; -- how many bits for PWM to increase DAC resolution
    signal R_dac0, R_dac1: std_logic_vector(C_dac_bits-1 downto 0);
    signal R_pcm_low: std_logic_vector(C_pwm_bits-1 downto 0);
    signal R_pwm_counter: std_logic_vector(C_pwm_bits-1 downto 0);
    signal R_dac_output: std_logic_vector(C_dac_bits-1 downto 0);
begin
    -- generate 2 DAC output optional values: PCM+0 and PCM+1
    process(clk)
    begin
      if rising_edge(clk) then
        R_dac0 <=  (not pcm(C_pcm_bits-1)) & pcm(C_pcm_bits-2 downto C_pcm_bits-C_dac_bits);
        R_dac1 <= ((not pcm(C_pcm_bits-1)) & pcm(C_pcm_bits-2 downto C_pcm_bits-C_dac_bits)) + 1;
        R_pcm_low <= pcm(C_pwm_bits-1 downto 0);
      end if;
    end process;
    
    -- constantly running PWM counter
    process(clk)
    begin
      if rising_edge(clk) then
        R_pwm_counter <= R_pwm_counter + 1; -- constantly running
      end if;
    end process;
    
    -- the comparator
    -- using PWM to switch between dac0 and dac1
    process(clk)
    begin
      if rising_edge(clk) then
        if R_pwm_counter >= R_pcm_low then
          R_dac_output <= R_dac0;
        else
          R_dac_output <= R_dac1;
        end if;
      end if;
    end process;
    dac <= R_dac_output;
end behavioral;
