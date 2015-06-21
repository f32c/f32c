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

-- PID controller, CPU interface

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.f32c_pack.all;

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
	bus_out: out std_logic_vector(31 downto 0);
	encoder_out: out std_logic_vector(1 downto 0);
	bridge_out: out std_logic_vector(1 downto 0) -- hardware output to full bridge
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
    constant C_setpoint:   integer   := 0; -- set point value
    constant C_undef1:     integer   := 1; -- undefined
    constant C_pid:        integer   := 2; -- constants 0xPPIIDD
    constant C_undef3:     integer   := 3; -- undefined
    constant C_undef4:     integer   := 4; -- undefined
    constant C_testpwm:    integer   := 5; -- undefined
    constant C_output:     integer   := 6; -- output value to control the motor
    constant C_position:   integer   := 7; -- encoder counter
    
    constant C_clkdivbits: integer   := 11; -- clock divider bits
    
    signal clkcounter : std_logic_vector(C_clkdivbits-1 downto 0);
    signal clk_pid : std_logic;
    signal sp: std_logic_vector(23 downto 0) := 0; -- set point
    signal cv: std_logic_vector(23 downto 0) := 0; -- current value
    signal error: std_logic_vector(23 downto 0); -- error = sp-cv
    signal reset   : std_logic := '0';
    signal m_k_out : std_logic_vector(11 downto 0);
    signal pwm_compare : std_logic_vector(C_clkdivbits-1 downto 0); -- pwm signal
    signal pwm_sign : std_logic; -- sign of output signal
    signal pwm_out : std_logic; -- pwm output signal
    signal bridge_f, bridge_r : std_logic; -- pwm bridge forward reverse
    signal encoder_a, encoder_b : std_logic; -- rotary encoder signals
    
begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <= 
        ext(x"1234", 32)
          when C_position,
        ext(m_k_out, 32)
          when C_output,
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
    
    -- PID clock (kHz range)
    process(clk)
      begin
        if rising_edge(clk) then
          clkcounter <= clkcounter + 1;
        end if;
      end process;
    clk_pid <= clkcounter(C_clkdivbits-1);

    -- rotary decoder provides cv
    rotary_decoder_inst: entity work.rotary_decoder
    port map(
      clk => clk,
      reset => '0',
      a => encoder_a,
      b => encoder_b,
      counter => cv(23 downto 0)
    );
    sp <= R(C_setpoint)(23 downto 0);
    error <= sp - cv;
    
    -- instantiate the PID controller
    pid_inst: entity work.ctrlpid
    port map(
      clk_pid => clk_pid,
      error => error,
      reset => '0',
      m_k_out => m_k_out,
      KP => R(C_pid)(21 downto 16),
      KI => R(C_pid)(13 downto 8), 
      KD => R(C_pid)(5 downto 0)
    );

    -- PWM output
    pwm_compare <= m_k_out(10 downto 0); -- compare value without sign bit of m_k_out
    pwm_sign <= m_k_out(11); -- sign bit of m_k_out defines forward/reverse direction
    --pwm_compare <= R(C_testpwm)(10 downto 0); -- compare value without sign bit of m_k_out
    --pwm_sign <= R(C_testpwm)(11); -- sign bit of m_k_out defines forward/reverse direction
    pwm_out <= '1' when clkcounter < pwm_compare else '0';
    bridge_out <= '0' & pwm_out when pwm_sign = '0' -- forward: m_k_out is positive
             else not(pwm_out) & '0';               -- reverse: m_k_out is negative
    -- bridge_out values description
    -- "00": power off (brake)
    -- "01": full power forward
    -- "10": full power reverse
    -- "11": power off (brake)

    bridge_f <= bridge_out(0);
    bridge_r <= bridge_out(1);

    -- simulated motor
    simulator_inst: entity work.simotor
    port map(
      clock => clk,
      f => bridge_f, r => bridge_r,
      a => encoder_a, b => encoder_b
    );
    
    encoder_out <= encoder_b & encoder_a; -- for encoder display on LED
end;
