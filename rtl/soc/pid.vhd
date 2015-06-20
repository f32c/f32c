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

entity pid is
    generic (
        C_addr_bits: integer := 3; -- don't touch: number of address bits for the registers
	C_bits: integer range 2 to 32 := 32  -- number of pid bits (pins)
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 registers of 32-bit
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0)
    );
end pid;

architecture arch of pid is
    constant C_registers: integer := 6; -- total number of pid registers

    -- normal registers
    -- type pid_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type pid_regs_type is array (C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: pid_regs_type; -- register access from mmapped I/O  R: active register, Rtmp temporary

    -- *** REGISTERS ***
    -- named constants for pid registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_output:     integer   := 0; -- output value
    constant C_direction:  integer   := 1; -- direction 0=input 1=output
    constant C_rising_if:  integer   := 2; -- rising edge interrupt flag
    constant C_rising_ie:  integer   := 3; -- rising edge interrupt enable
    constant C_falling_if: integer   := 4; -- falling edge interrupt flag
    constant C_falling_ie: integer   := 5; -- falling edge interrupt enable
    constant C_input:      integer   := 0; -- input value (overlay at output register value) 

    -- edge detection related registers
    constant C_edge_sync_depth: integer := 3; -- number of shift register stages (default 3) for icp clock synchronization
    type T_edge_sync_shift is array (0 to C_bits-1) of std_logic_vector(C_edge_sync_depth-1 downto 0); -- edge detect synchronizer type
    signal R_edge_sync_shift: T_edge_sync_shift;
    signal R_rising_edge, R_falling_edge: std_logic_vector(C_bits-1 downto 0);

begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <= 
        ext(R(conv_integer(C_input)), 32)
          when C_input,
        ext(R(conv_integer(addr)),32)
          when others;

    -- CPU core writes registers
    writereg: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' then
            if ce = '1' and bus_write = '1' then
              -- normal write for every other register
              R(conv_integer(addr))(8*i+7 downto 8*i) <=  bus_in(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;

end;
