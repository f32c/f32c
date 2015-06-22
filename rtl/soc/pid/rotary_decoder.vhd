--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- LICENSE=BSD
--
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.f32c_pack.all;

-- vhdl wrapper for verilog module

entity rotary_decoder is
  port
  (
    clk     : in  std_logic;
    reset   : in  std_logic;
    encoder : in  std_logic_vector(1 downto 0);
    counter : out std_logic_vector(23 downto 0)
  );
end rotary_decoder;

architecture syn of rotary_decoder is
  component rotary_decoder_v
    port (
    clk     : in  std_logic;
    reset   : in  std_logic;
    A       : in  std_logic;
    B       : in  std_logic;
    counter : out std_logic_vector(23 downto 0)
    );
  end component;

begin
  rotary_decoder_inst: rotary_decoder_v
  port map(
    clk => clk,
    reset => reset,
    A => encoder(0), B => encoder(1),
    counter => counter
  );

end syn;
