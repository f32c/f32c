-- AUTHOR=EMARD
-- LICENSE=BSD

-- Simple serial ROM emulation, used to hold bootloader code
-- Constant: ROM content, array of data size 8 bits
-- Input: reset, next_data
-- Output: valid, data (8, 16, 24, 32 bits)

-- on reset='1' and clk='1' it will zero internal address counter
-- on clk='1' it will increment internal address counter and
-- in clock set after next='1' set valid='0' if data aren't immediately available
-- it will set valid='1' when data are available on output.
-- valid='1' will hold until next='1' or reset='1'
-- but it is not mandatory to hold data if after valid=1 comes valid=0
-- because upstream module will sample it at first clock when valid='1'

-- todo: Internal Function converts from boot block to variable bit 
-- size array suitable for output
-- maybe it's more efficient to keep data in 8-bit form and shift from RTL
-- for 1K bootloader which outputs 32-bit 8K or 16K BRMU must be used.

-- Should normally compile to preloaded BRAM (infer)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.boot_block_pack.all;

entity bootrom_emu is
generic 
(
  C_content: boot_block_type := (others => (others => '0')); -- 8-bit content
  C_data_bits: integer := 8 -- output bits, valid settings 8, 16, 24, 32
);
port 
(
  clk, reset, next_data: in std_logic;
  data: out std_logic_vector(C_data_bits-1 downto 0);
  valid: out std_logic
);
end;

architecture rtl of bootrom_emu is
  constant C_content_length: integer := C_content'length;
  constant C_content_bits: integer := 8; -- C_content(0)'length; -- length in bits of first word, same as all
  constant C_data_length: integer := C_content_length * C_content_bits / C_data_bits;
  constant C_shift_steps: integer := C_data_bits / C_content_bits; -- suppose C_data_bits >= C_content_bits and divisible with remainter = 0
  signal R_addr: integer range 0 to C_content_length-1 := 0;
  signal R_data: std_logic_vector(C_data_bits-1 downto 0);
  signal R_valid: std_logic := '0'; -- initially not valid data
  signal R_shift: integer range 0 to C_shift_steps;

  -- Build a 2-D array type for the ROM (output)
  --  subtype word_t is std_logic_vector(C_data_bits-1 downto 0);
  --  type rom_t is array(C_data_length-1 downto 0) of word_t;
  -- Declare the ROM constant -- this one addressed goes to output
  --
  -- Xilinx ISE 14.7 for Spartan-3 will abort with error about loop 
  -- iteration limit >64 exceeded.  We need 128 iterations here.
  -- If buiding with makefile, edit file xilinx.opt file and
  -- append this line (give sufficiently large limit):
  -- -loop_iteration_limit 2048
  -- In ISE GUI, open the Design tab, right click on Synthesize - XST,
  -- choose Process Properties, choose Property display level: Advanced,
  -- scroll down to the "Other XST Command Line Options" field and
  -- enter: -loop_iteration_limit 2048
  --
--  function boot_block_to_rom(x: boot_block_type)
--    return rom_t is
--    variable y: rom_t;
--    -- variable w: word_t; -- assembled output word
--    variable i, j, k, l, ib, ob, a, na, sh: integer;
--  begin
--    i := 0; -- counts bytes if input bootloader content
--    l := x'length; -- input length in bytes
--    ib := x(0)'length; --'-- input bits (usually 8, byte)
--    y := (others => (others => '0'));
--    j := 0; -- counts output addr of rom_t
--    k := y'length; -- length of output
--    ob := y(0)'length; --'-- output bits per word (1, 8, 32)
--    -- 8-bit output, just copy
--    --if (ob = ib) then
--    --  while (j < y'length and j < x'length) loop
--    --    y(j) := x(j);
--    --    j := j + 1;
--    --  end loop;
--    --end if;
--    -- 16,24,32-bit output, assemble by shifting output
--    -- 8-bit is special case which also should work
--    if (ob >= ib) then
--      na := ob/ib; -- number of shifting steps
--      sh := ob-ib; -- how much bits to shift
--      while (j < y'length) loop
--        a := 0;
--        while (a < na) loop -- shifting loop
--          y(j) := y(j) * 2**sh + x(i); -- shift it up and add
--          i := i + 1;
--          a := a + 1;
--        end loop;
--        j := j + 1;
--      end loop;
--    end if;
--    -- 1-bit output
--    if (ob < ib) then
--      -- not yet implemented
--    end if;
--    return y;
--  end boot_block_to_rom;
--  constant C_rom: rom_t := boot_block_to_rom(C_content);

begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        R_addr <= 0;
      end if;
      if reset = '1' or next_data = '1' then
        R_valid <= '0';
        R_shift <= 0;
      else
        if R_shift /= C_shift_steps then
          if R_shift = C_shift_steps-1 then
            R_valid <= '1';
          end if;
          R_addr <= R_addr+1;
          R_shift <= R_shift+1;
          R_data <= C_content(R_addr)
                  & R_data(C_data_bits-1 downto C_content_bits);
        else
          R_valid <= '1';
        end if;
      end if;
    end if;
  end process;
  data <= R_data(C_data_bits-1 downto 0);
  valid <= R_valid;
end rtl;
