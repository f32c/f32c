-- Creates a DDR input with implementations for different platforms.
--
-- TODO: Test the 'asic' architecture. Decide if this is even the right
-- approach for the asic.

library ieee;
use ieee.std_logic_1164.all;

entity ddr_input is
  generic (
    -- DDR_ALIGNMENT = OPPOSITE_EDGE or SAME_EDGE
    DDR_ALIGNMENT : string := "OPPOSITE_EDGE";
    INIT_Q1 : std_logic := '0';
    INIT_Q2 : std_logic := '0';
    -- SRTYPE = ASYNC or SYNC
    SRTYPE : string := "SYNC");
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    d   : in  std_logic;
    q1  : out std_logic;
    q2  : out std_logic);
begin
  assert DDR_ALIGNMENT = "OPPOSITE_EDGE" or DDR_ALIGNMENT = "SAME_EDGE"
    report "Invalid DDR_ALIGNMENT" severity failure;
  assert SRTYPE = "ASYNC" or SRTYPE = "SYNC"
    report "Invalid SRTYPE" severity failure;
end entity;

-- This 'asic' implementation is untested
architecture asic of ddr_input is
  signal q2_latch : std_logic := INIT_Q2;
begin
  oppedge : if DDR_ALIGNMENT = "OPPOSITE_EDGE" generate
    -- synch reset and outputs q1 at the rising edge of clk and q2 at the
    -- falling edge
    sync_gen: if SRTYPE = "SYNC" generate
      p : process(rst, clk, d)
      begin
        if clk'event then
          if rst = '1' then
            q1 <= INIT_Q1;
            q2 <= INIT_Q2;
          elsif clk = '1' then
            q1 <= d;
          else
            q2 <= d;
          end if;
        end if;
      end process;
    end generate;

    async_gen: if SRTYPE = "ASYNC" generate
      p : process(rst, clk, d)
      begin
        if rst = '1' then
          q1 <= INIT_Q1;
          q2 <= INIT_Q2;
        elsif clk'event then
          if clk = '1' then
            q1 <= d;
          else
            q2 <= d;
          end if;
        end if;
      end process;
    end generate;
  end generate;

  sameedge : if DDR_ALIGNMENT = "SAME_EDGE" generate
    -- synch reset and outputs q1 at the rising edge of clk and q2 at the
    -- falling edge
    sync_gen: if SRTYPE = "SYNC" generate
      p : process(rst, clk, d)
      begin
        if clk'event then
          if rst = '1' then
            q1 <= INIT_Q1;
            q2 <= INIT_Q2;
          elsif clk = '1' then
            q1 <= d;
            q2 <= q2_latch;
          else
            q2_latch <= d;
          end if;
        end if;
      end process;
    end generate;

    async_gen: if SRTYPE = "ASYNC" generate
      p : process(rst, clk, d)
      begin
        if rst = '1' then
          q1 <= INIT_Q1;
          q2 <= INIT_Q2;
        elsif clk'event then
          if clk = '1' then
            q1 <= d;
            q2 <= q2_latch;
          else
            q2_latch <= d;
          end if;
        end if;
      end process;
    end generate;
  end generate;
end architecture;
