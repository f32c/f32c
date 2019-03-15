
--
--
-- 03/12/2019 Menlo Park Innovation LLC
--
-- Parameterized clock generator..
--
-- Ideas from F32C project and 
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/vvd.html#sec-modmcounter
--
-- Parameterized clock generator takes an input clock frequency and a desired
-- output frequency and generates a counter that provides that frequency.
--
-- The number of bits defined in the counter scales to the ratio of
-- clock_frequency / output_frequency which represents the number of
-- clock ticks per count.
--
-- The counter is static in that its frequency value and number of bits
-- is determined at compile time so extra logic to perform runtime updates
-- is eliminated. This is useful for critical timing paths where a single
-- fixed frequency is required.
--

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- For log2, ceil
use ieee.math_real.all;

entity param_clk_gen is
    generic (
            InputClockRate : integer := 100;
            OutputFrequency : integer := 10
    );
    port(
            clk : in std_logic;
            reset : in std_logic;
            clk_out : out std_logic
    );
end param_clk_gen;

architecture arch of param_clk_gen is

    constant MaxCount : integer :=
      integer( (real(InputClockRate) / real(OutputFrequency)) / real(2));

    -- Calculate number of bits required to hold the max count value
    constant N : integer := integer(ceil(log2(real(MaxCount))));

    signal count_reg : unsigned(N-1 downto 0);
    signal count_next : unsigned(N-1 downto 0);
    signal clk_reg : std_logic;

begin

    clk_out <= clk_reg;

    count_next <= (others => '0') when count_reg = MaxCount else (count_reg + 1);
    
    process(clk, reset)
    begin
        -- async reset
        if reset = '1' then 
            count_reg <= (others => '0');
            clk_reg <= '0';
        elsif   rising_edge(clk) then
            count_reg <= count_next;

            if (count_reg = MaxCount) then
                if (clk_reg = '0') then
                    clk_reg <= '1';
                else
                    clk_reg <= '0';
                end if;
            end if;
        end if;
    end process;
    
end arch; -- param_clk_gen
