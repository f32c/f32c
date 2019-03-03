--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

-- EMARD GPIO with interrupts

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity gpio is
    generic (
        C_addr_bits: integer := 3; -- don't touch: number of address bits for the registers
        C_bits: integer range 2 to 32 := 32;  -- number of gpio bits (pins)
        C_pullup: boolean := false
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 registers of 32-bit
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	gpio_irq: out std_logic; -- interrupt request line (active level high)
	gpio_phys: inout std_logic_vector(C_bits-1 downto 0); -- pyhsical gpio pins
	gpio_pullup: inout std_logic_vector(C_bits-1 downto 0) -- pyhsical gpio pull-up pins
    );
end gpio;

architecture arch of gpio is
    constant C_registers: integer := 6; -- total number of gpio registers

    -- normal registers
    -- type gpio_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type gpio_regs_type is array (C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: gpio_regs_type; -- register access from mmapped I/O  R: active register, Rtmp temporary

    -- *** REGISTERS ***
    -- named constants for gpio registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_output:     integer   := 0; -- output value
    constant C_direction:  integer   := 1; -- direction 0=input 1=output
    constant C_rising_if:  integer   := 2; -- rising edge interrupt flag
    constant C_rising_ie:  integer   := 3; -- rising edge interrupt enable
    constant C_falling_if: integer   := 4; -- falling edge interrupt flag
    constant C_falling_ie: integer   := 5; -- falling edge interrupt enable
    constant C_input:      integer   := 6; -- input value

    -- edge detection related registers
    constant C_edge_sync_depth: integer := 2; -- number of shift register stages (default 3) for icp clock synchronization
    type T_edge_sync_shift is array (0 to C_bits-1) of std_logic_vector(C_edge_sync_depth-1 downto 0); -- edge detect synchronizer type
    signal R_edge_sync_shift: T_edge_sync_shift;
    signal R_rising_edge, R_falling_edge: std_logic_vector(C_bits-1 downto 0);
begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <= 
        ext(gpio_phys, 32)
          when C_input,
        ext(R(conv_integer(addr)),32)
          when others;

    -- CPU core writes registers
    -- and edge interrupt flags handling
    -- interrupt flags can be written only 0, writing 1 is nop -> logical and
    writereg_intrflags: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' and ce = '1' and bus_write = '1'
          then
            case conv_integer(addr) is
            when C_rising_if | C_falling_if => -- interrupt flag registers: logical "and"
              R(conv_integer(addr))(8*i+7 downto 8*i) <= -- only can clear intr. flag, never set
              R(conv_integer(addr))(8*i+7 downto 8*i) and not bus_in(8*i+7 downto 8*i); -- write 0's to clear flags
            when C_input => -- write to input register toggles output bit when input bit is set (like on AVR)
              R(C_output)(8*i+7 downto 8*i) <= R(C_output)(8*i+7 downto 8*i) XOR bus_in(8*i+7 downto 8*i);
            when others => -- normal write for every other register
              R(conv_integer(addr))(8*i+7 downto 8*i) <= bus_in(8*i+7 downto 8*i);
            end case;
          else
            R(C_rising_if)(8*i+7 downto 8*i) <= -- only can set intr. flag, never clear
            R(C_rising_if)(8*i+7 downto 8*i) or R_rising_edge(8*i+7 downto 8*i);
            R(C_falling_if)(8*i+7 downto 8*i) <= -- only can set intr. flag, never clear
            R(C_falling_if)(8*i+7 downto 8*i) or R_falling_edge(8*i+7 downto 8*i);
          end if;
        end if;
      end process;
    end generate;
    
    each_bit: for i in 0 to C_bits-1 generate
      -- physical output to pins with 3-state handling
      gpio_phys(i) <= R(C_output)(i) when R(C_direction)(i) = '1' else 'Z';
      each_pullup: if C_pullup generate
        gpio_pullup(i) <= '1' when R(C_output)(i) = '1' AND R(C_direction)(i) = '0' else 'Z';	-- set programmatic pull-up (like ATmega328)
      end generate;

      -- *** edge detect synchronizer (3 or more stage shift register) ***
      -- here is theory and schematics about 3-stage shift register
      -- https://www.doulos.com/knowhow/fpga/synchronisation/
      -- here is vhdl implementation of the 3-stage shift register
      -- http://www.bitweenie.com/listings/vhdl-shift-register/
      process(clk)
      begin
        if rising_edge(clk) then
          R_edge_sync_shift(i) <= gpio_phys(i) & R_edge_sync_shift(i)(C_edge_sync_depth-1 downto 1);
        end if;
      end process;
      -- difference in 2 last bits of the shift register detect synchronous rising/falling edge
      -- rising edge when at bit0 is 0, and one clock earlier at bit1 is 1
      R_rising_edge(i) <=
           (not R_edge_sync_shift(i)(0))  -- it was 0
       and (    R_edge_sync_shift(i)(1)); -- 1 is coming after 0
      -- falling edge similar, bit0 is 1 and bit1 is 0
      R_falling_edge(i) <=
           (    R_edge_sync_shift(i)(0))  -- it was 1
       and (not R_edge_sync_shift(i)(1)); -- 0 is coming after 1
    end generate;

    -- join all interrupt request bits into one bit
    gpio_irq <= '1' when
                    (  ( R(C_rising_ie)  and R(C_rising_if)  )
                    or ( R(C_falling_ie) and R(C_falling_if) )
                    ) /= ext("0",C_bits) else '0';

end;
-- todo: level interrupts (they are rarely needed)
