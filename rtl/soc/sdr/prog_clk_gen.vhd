
--
--
-- 03/27/2019 Menlo Park Innovation LLC
--
-- Programmable clock generator.
--
-- Generates a single output pulse for each clock period.
--
-- clk_counter_max specifies the number of ticks per clock period
-- from the master clock (clk) in real time.
--
-- Generic parameter C_ClockCounterWidth allows the caller to customize
-- the maximum clock ration based on input clock and needs.
--
-- Ideas from F32C project and 
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/vvd.html#sec-modmcounter
--

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- For log2, ceil
use ieee.math_real.all;

entity prog_clk_gen is
    generic (
            C_ClockCounterWidth: integer
    );
    port(
            clk : in std_logic;
            reset : in std_logic;
            clk_counter_max: in std_logic_vector(C_ClockCounterWidth-1 downto 0);
            clk_out : out std_logic
    );
end prog_clk_gen;

architecture arch of prog_clk_gen is

    signal clk_reg : std_logic;
    signal count_reg : unsigned(C_ClockCounterWidth-1 downto 0);
    signal count_next : unsigned(C_ClockCounterWidth-1 downto 0);
    signal R_clk_counter_max : unsigned(C_ClockCounterWidth-1 downto 0);

begin

    clk_out <= clk_reg;

    -- >= Handles the case in which the register is set lower by the external CPU.
    count_next <= (others => '0') when count_reg >= R_clk_counter_max else (count_reg + 1);
    
    process(clk, reset)
    begin
        -- async reset
        if reset = '1' then 
            clk_reg <= '0';
            count_reg <= (others => '0');
            R_clk_counter_max <= (others => '0');
        elsif   rising_edge(clk) then

            -- Resets previous value of clk_reg.
            clk_reg <= '0';

            -- Convert and register current clk_counter_max input
            R_clk_counter_max <= to_unsigned(conv_integer(clk_counter_max), C_ClockCounterWidth);

            -- Register computed combinatorial value
            count_reg <= count_next;

            if (count_reg >= R_clk_counter_max) then
                -- Set clk_reg to '1' for (1) master clk tick.
                -- This relies on the last assignment rule for process/always_ff.
                clk_reg <= '1';
            end if;
        end if;
    end process;
    
end arch; -- prog_clk_gen
