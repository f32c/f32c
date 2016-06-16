-- (c)EMARD
-- License=BSD

-- vector processor unit (dummy, future todo, work in progress)
-- this is glue module wich also does memory mapped I/O and interrupt handling

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vector is
  generic
  (
    C_addr_bits: integer := 3; -- don't touch: number of address bits for the registers
    C_bits: integer range 2 to 32 := 32  -- number of bits in each mmio register
  );
  port
  (
    ce, clk: in std_logic;
    bus_write: in std_logic;
    addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 registers of 32-bit
    byte_sel: in std_logic_vector(3 downto 0);
    bus_in: in std_logic_vector(31 downto 0);
    bus_out: out std_logic_vector(31 downto 0);
    vector_irq: out std_logic
  );
end vector;

architecture arch of vector is
    constant C_mmio_registers: integer := 6; -- total number of mmio registers

    constant C_vectors: integer := 4; -- total number of vector registers (BRAM blocks)
    constant C_vaddr_bits: integer := 11; -- number of address bits for BRAM vector
    constant C_vdata_bits: integer := 32; -- number of data bits for each vector

    -- normal registers
    -- type gpio_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type mmio_regs_type is array (C_mmio_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: mmio_regs_type; -- register access from mmapped I/O  R: active register

    -- *** REGISTERS ***
    -- named constants for gpio registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_output:     integer   := 0; -- output value
    constant C_direction:  integer   := 1; -- direction 0=input 1=output
    constant C_rising_if:  integer   := 2; -- rising edge interrupt flag
    constant C_rising_ie:  integer   := 3; -- rising edge interrupt enable
    constant C_input:      integer   := 4; -- input value

    -- edge detection related registers (unused, just 0)
    signal R_rising_edge: std_logic_vector(C_bits-1 downto 0) := (others => '0');

begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <=
        ext(x"DEBA66AA", 32)
          when C_input,
        ext(R(conv_integer(addr)),32)
          when others;

    -- CPU core writes registers
    -- and edge interrupt flags handling
    -- interrupt flags can be written only 1, writing 0 is nop -> logical and not
    writereg_intrflags: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' then
            if ce = '1' and bus_write = '1' then
              if conv_integer(addr) = C_rising_if
              then -- logical and for interrupt flag registers
                R(conv_integer(addr))(8*i+7 downto 8*i) <= -- only can clear intr. flag, never set
                R(conv_integer(addr))(8*i+7 downto 8*i) and not bus_in(8*i+7 downto 8*i);
              else -- normal write for every other register
                R(conv_integer(addr))(8*i+7 downto 8*i) <=  bus_in(8*i+7 downto 8*i);
              end if;
            else
              R(C_rising_if)(8*i+7 downto 8*i) <= -- only can set intr. flag, never clear
              R(C_rising_if)(8*i+7 downto 8*i) or R_rising_edge(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;

    -- join all interrupt request bits into one bit
    vector_irq <= '1' when
                    (  ( R(C_rising_ie)  and R(C_rising_if)  )
                    ) /= ext("0",C_bits) else '0';

end;
