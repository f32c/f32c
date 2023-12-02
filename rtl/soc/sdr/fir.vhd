-- ***** Low-pass FIR filter
-- ***** Note: For the sake of simplicity, all filter
-- ***** coefficients are equal to allow only shifts and adds 
-- ***** to be utillized
-- (C)2016 Emard
-- LICENSE=BSD

LIBRARY ieee;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.ALL;
use ieee.math_real.all; -- to calculate log2 bit size

entity FIR is
  generic(
    C_bits_x: integer := 12; -- external IN/OUT port bits
    C_fir_stages: integer := 16  -- number of history stages for the FIR sum
  );
  port(
    clock: in std_logic; -- can run at high freq
    enable: in std_logic := '1'; -- math action every strobe cycle can reduce FIR frequency
    reset: in std_logic := '0';
    data_in: in signed(C_bits_x-1 downto 0);
    data_out: out signed(C_bits_x-1 downto 0)
  );
end FIR;
architecture behavior of FIR is
  -- function integer ceiling log2
  -- returns how many bits are needed to represent a number of states
  -- example ceil_log2(255) = 8,  ceil_log2(256) = 8, ceil_log2(257) = 9
  function ceil_log2(x: integer)
    return integer is
  begin
    return integer(ceil((log2(real(x)+1.0E-6))-1.0E-6));
  end ceil_log2;
  constant C_bits_i: integer := C_bits_x + ceil_log2(C_fir_stages); -- internal sum bits: log2(16) = 4
  type T_d is array(0 to C_fir_stages-1) of signed(C_bits_i-1 downto 0);
  signal d: T_d := (others => (others => '0'));
  signal sign_expand: signed(C_bits_i-C_bits_x-1 downto 0);
  signal sum: signed(C_bits_i-1 downto 0);
begin 
  process(reset,clock,enable)
  begin
    if (reset = '1') then
        d <= (others => (others => '0'));
        sum <= (others => '0');
        data_out <= (others => '0');
    elsif rising_edge(clock) and enable='1' then
        -- shifting
        --for i in 1 to d'length-1 loop
        --    d(i) <= d(i-1);
        --end loop;
        --sign_expand <= (others => data_in(C_bits_x-1));
        --d(0) <= sign_expand & data_in; -- fill up MSB bits
        --sum <= sum + d(0) - d(C_fir_stages-1); -- add first entry, subtract last
        sum <= sum + (data_in - sum(C_bits_i-1 downto C_bits_i-C_bits_x));
        data_out <= sum(C_bits_i-1 downto C_bits_i-C_bits_x);
        --data_out <= sum;
    end if;
  end process;
end behavior;	
