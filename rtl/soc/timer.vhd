library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity timer is
    generic (
	C_bits: integer := 32
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0)
    );
end timer;

architecture arch of timer is
    signal R_counter: std_logic_vector(31 downto 0);

begin
    bus_out <= R_counter;
    process(clk)
    begin
    if rising_edge(clk) then
        if ce = '1' and bus_write = '1' then
            if byte_sel(0) = '1' then
              R_counter(7 downto 0) <= bus_in(7 downto 0);
            end if;
            if byte_sel(1) = '1' then
              R_counter(15 downto 8) <= bus_in(15 downto 8);
            end if;
            if byte_sel(2) = '1' then
              R_counter(23 downto 16) <= bus_in(23 downto 16);
            end if;
            if byte_sel(3) = '1' then
              R_counter(31 downto 24) <= bus_in(31 downto 24);
            end if;
        else
            R_counter <= R_counter + 1;
        end if;
        -- debug purpose: increment when reading LSB
        -- if ce = '1' and bus_write = '0' and byte_sel(0) = '1' then
        --     R_counter <= R_counter + 1;
        -- end if;
    end if;
    end process;
end;

-- todo

-- timer control register
-- R_timer_control
-- bit 0: timer run/stop 0-stop 1-run
-- bit 1: output compare 1 filter 1=and 0=or
-- bit 2: output compare 2 filter 1=and 0=or
-- bit 3: output compare 3 filter 1=and 0=or
-- bit 4: output compare 4 filter 1=and 0=or
-- bit 5: input capture filter 1=and 0=or
-- bit 6: interrupt 1-enable 0-disable
-- bit 7: interrupt flag 1=pending 0=resolved

-- bit 8: update lock 1-locked, 0-unlocked
--        all registers can changed during lock = 1 state,
--        changes will be committed when lock bit is set to 0

-- output mux - join 2 outputcompares with and/or

-- timer period (max value)
-- R_period

-- input capture register
-- R_icp input capture register

-- filter for input capture (lower and upper limit register)
-- input capture will happen in selectable and/or condtion
-- when counter is within this range
-- R_icp_low <= counter < R_icp_high

-- output compare filter
-- allow for 4 phase output, each completely selectable 360 phase deg
-- R_ocr1_low <= counter < R_ocr1_high
-- R_ocr2_low <= counter < R_ocr2_high
-- R_ocr3_low <= counter < R_ocr3_high
-- R_ocr4_low <= counter < R_ocr4_high
