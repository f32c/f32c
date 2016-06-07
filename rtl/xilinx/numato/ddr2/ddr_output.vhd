-- Creates a DDR output with implementations for different platforms.
--
-- TODO: Test the 'asic' architecture. Decide if this is even the right
-- approach for the asic.

library ieee;
use ieee.std_logic_1164.all;

entity ddr_output is
  generic (
    -- DDR_ALIGNMENT = OPPOSITE_EDGE or SAME_EDGE
    DDR_ALIGNMENT : string := "OPPOSITE_EDGE";
    INIT : std_logic := '0';
    -- SRTYPE = ASYNC or SYNC
    SRTYPE : string := "SYNC");
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    d1  : in  std_logic;
    d2  : in  std_logic;
    q   : out std_logic);
begin
  assert DDR_ALIGNMENT = "OPPOSITE_EDGE" or DDR_ALIGNMENT = "SAME_EDGE"
    report "Invalid DDR_ALIGNMENT" severity failure;
  assert SRTYPE = "ASYNC" or SRTYPE = "SYNC"
    report "Invalid SRTYPE" severity failure;
end entity;

-- This 'asic' implementation is untested
architecture asic of ddr_output is
  signal d2_latch : std_logic := INIT;
begin
  oppedge : if DDR_ALIGNMENT = "OPPOSITE_EDGE" generate
    -- synch reset and latches d1 at the rising clk edge and d2 at the
    -- falling edge
    sync_gen : if SRTYPE = "SYNC" generate
      p : process(clk, rst, d1, d2)
      begin
        if clk'event then
          if rst = '1' then
            q <= INIT;
          elsif clk = '1' then
            q <= d1;
          else
            q <= d2;
          end if;
        end if;
      end process;
    end generate;

    async_gen : if SRTYPE = "ASYNC" generate
      -- asynch reset and latches d1 at the rising clk edge and d2 at the
      -- falling edge
      p : process(clk, rst, d1, d2)
      begin
        if rst = '1' then
          q <= INIT;
        elsif clk'event then
          if clk = '1' then
            q <= d1;
          else
            q <= d2;
          end if;
        end if;
      end process;
    end generate;
  end generate;

  sameedge : if DDR_ALIGNMENT = "SAME_EDGE" generate
    sync_gen : if SRTYPE = "SYNC" generate
      -- synch reset and latches d1 and d2 at the rising clk edge
      p : process(clk, rst, d1, d2)
      begin
        if clk'event then
          if rst = '1' then
            q <= INIT;
            d2_latch <= INIT;
          elsif clk = '1' then
            q <= d1;
            d2_latch <= d2;
          else
            q <= d2_latch;
          end if;
        end if;
      end process;
    end generate;

    async_gen : if SRTYPE = "ASYNC" generate
      -- asynch reset and latches d1 and d2 at the rising clk edge
      p : process(clk, rst, d1, d2)
      begin
        if rst = '1' then
          q <= INIT;
          d2_latch <= INIT;
        elsif clk'event then
          if clk = '1' then
            q <= d1;
            d2_latch <= d2;
          else
            q <= d2_latch;
          end if;
        end if;
      end process;
    end generate;
  end generate;
end architecture;
