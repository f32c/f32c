--
-- AUTHOR=EMARD
-- LICENSE=BSD
--

-- VHDL Wrapper for Verilog

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity i2s is
  generic
  (
    fmt     : integer := 0;
    clk_hz  : integer := 25000000;
    lrck_hz : integer := 48000
  );
  port
  (
    clk     : in  std_logic;
    l,r     : in  std_logic_vector(15 downto 0);
    din     : out std_logic;
    bck     : out std_logic;
    lrck    : out std_logic
  );
end;

architecture syn of i2s is
  component i2s_v -- verilog name and its parameters
  generic
  (
    fmt     : integer := 0;
    clk_hz  : integer := 25000000;
    lrck_hz : integer := 48000
  );
  port
  (
    clk     : in  std_logic;
    l,r     : in  std_logic_vector(15 downto 0);
    din     : out std_logic;
    bck     : out std_logic;
    lrck    : out std_logic
  );
  end component;
begin
  i2s_inst: i2s_v
  generic map
  (
    fmt     => fmt,
    clk_hz  => clk_hz,
    lrck_hz => lrck_hz
  )
  port map
  (
    clk => clk,
    l => l, r => r,
    din => din, bck => bck, lrck => lrck
  );
end syn;
