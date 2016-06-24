--
-- Copyright (c) 2016 EMARD
-- All rights reserved.
--
-- LICENSE=BSD
--
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- vhdl wrapper for verilog module

-- fpu_op=3'b000;  // Add
-- fpu_op=3'b001;  // Sub
-- fpu_op=3'b010;  // Mul
-- fpu_op=3'b011;  // Div
-- fpu_op=3'b100;  // i2f
-- fpu_op=3'b101;  // f2i
-- fpu_op=3'b110;  // rem

entity fpu_vhd is
  port
  (
    clk     : in  std_logic;
    rmode   : in  std_logic_vector(1 downto 0);
    fpu_op  : in  std_logic_vector(2 downto 0);
    opa,opb : in  std_logic_vector(31 downto 0);
    result  : out std_logic_vector(31 downto 0)
  );
end fpu_vhd;

architecture rtl of fpu_vhd is
  component fpu
  port
  (
    clk     : in  std_logic;
    rmode   : in  std_logic_vector(1 downto 0);
    fpu_op  : in  std_logic_vector(2 downto 0);
    opa,opb : in  std_logic_vector(31 downto 0);
    result  : out std_logic_vector(31 downto 0);
    inf, snan, qnan, ine, overflow, underflow, zero, div_by_zero: out std_logic
  );
  end component;
begin
  I_fpu: fpu
  port map(
    clk => clk,
    rmode => rmode,
    fpu_op => fpu_op,
    opa => opa, opb => opb,
    result => result
  );
end rtl;
