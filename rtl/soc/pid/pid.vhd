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
use ieee.math_real.all;
use work.f32c_pack.all;

-- library pid_library;

entity pid is
    generic (
        C_pwm_bits: integer range 11 to 32 := 12; -- clock divider bits define PWM output frequency (min 11 => 40kHz @ 81.25MHz)
        C_addr_unit_bits: integer range 1 to 3 := 1; -- number of bits to address PID units
	C_pids: integer range 2 to 8 := 2;  -- number of pid units
	C_simulator: std_logic_vector(7 downto 0) := (others => '0'); -- 1: simulate motors (no real motors), 0: normal mode for real motors
	C_prescaler: integer range 10 to 26 := 18; -- control loop frequency
	C_fp: integer range 0 to 26 := 8; -- control loop frequency (26-C_prescaler)
	C_precision: integer range 0 to 8 := 1; -- fixed point PID precision
        C_addr_bits: integer := 2; -- don't touch: number of address bits to address one PID unit
        C_bits: integer range 2 to 32 := 32 -- memory register bit width
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	addr: in std_logic_vector(C_addr_unit_bits+C_addr_bits-1 downto 0); -- address for registers (32-bit each)
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	setpoint: in std_logic_vector(23 downto 0) := (others => '0'); -- external setpoint, added to all PID setpoints
	encoder_a_in:  in  std_logic_vector(C_pids-1 downto 0) := (others => '-');
	encoder_b_in:  in  std_logic_vector(C_pids-1 downto 0) := (others => '-');
	encoder_a_out: out std_logic_vector(C_pids-1 downto 0);
	encoder_b_out: out std_logic_vector(C_pids-1 downto 0);
	bridge_f_out:  out std_logic_vector(C_pids-1 downto 0); -- hardware output to full bridge, forward
	bridge_r_out:  out std_logic_vector(C_pids-1 downto 0)  -- hardware output to full bridge, reverse
    );
end pid;

architecture arch of pid is
    constant C_registers: integer := 2; -- total number of 32-bit memory registers for single PID
    constant C_reg_addr_bits: integer := 1;
    constant C_output_bits: integer := 12; -- number of bits in PID output value
    
    -- normal registers
    -- type pid_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type pid_regs_type is array (C_pids*C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: pid_regs_type; -- register access from mmapped I/O  R: active register, Rtmp temporary

    -- *** REGISTERS ***
    -- named constants for pid registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_setpoint:   integer   := 0; -- set point value
    constant C_pid:        integer   := 1; -- constants 0xPPIIDD
    constant C_output:     integer   := 2; -- output value to control the motor
    constant C_position:   integer   := 3; -- encoder counter
    
    signal clkcounter : std_logic_vector(C_pwm_bits-1 downto 0);
    signal sp: std_logic_vector(23 downto 0); -- set point
    signal cv: std_logic_vector(23 downto 0); -- current value
    type counter_value_type is array (C_pids-1 downto 0) of std_logic_vector(23 downto 0);
    signal counter_value: counter_value_type;
    signal error_value: counter_value_type;
    signal error: std_logic_vector(23 downto 0); -- error = sp-cv
    signal reset   : std_logic := '0';
    signal m_k_out : std_logic_vector(C_output_bits-1 downto 0);
    type output_value_type is array (C_pids-1 downto 0) of std_logic_vector(C_output_bits-1 downto 0);
    signal output_value : output_value_type;
    type pwm_compare_type is array (C_pids-1 downto 0) of std_logic_vector(C_output_bits-2 downto 0);
    signal pwm_compare : pwm_compare_type; -- pwm signal
    signal pwm_sign : std_logic_vector(C_pids-1 downto 0); -- sign of output signal
    signal pwm_out : std_logic_vector(C_pids-1 downto 0); -- pwm output signal
    type bridge_type is array (C_pids-1 downto 0) of std_logic_vector(1 downto 0);
    signal bridge : bridge_type; -- pwm LSB=formward MSB=reverse
    signal bridge_f, bridge_r : std_logic_vector(C_pids-1 downto 0); -- pwm bridge forward reverse
    type encoder_type is array (C_pids-1 downto 0) of std_logic_vector(1 downto 0);
    signal encoder : encoder_type;
    signal encoder_a, encoder_b : std_logic_vector(C_pids-1 downto 0); -- rotary encoder signals
    signal kp, ki, kd: std_logic_vector(5 downto 0);

    signal unit_addr : std_logic_vector(C_addr_unit_bits-1 downto 0);
    signal unit_switch_addr : std_logic_vector(C_addr_unit_bits-1 downto 0); -- time sharing PID unit switch address
    signal pid_reg_addr : std_logic_vector(C_reg_addr_bits-1 downto 0);
    signal pid_available : std_logic;
    
begin
    -- address of the PID unit
    unit_addr <= addr(C_addr_unit_bits+C_addr_bits-1 downto C_addr_bits);
    -- address of individual memory backed register within one PID unit
    pid_reg_addr <= addr(C_addr_bits-2 downto 0);
    -- CPU core reads registers
    with conv_integer(addr(C_addr_bits-1 downto 0)) select
      bus_out <= 
        ext(counter_value(conv_integer(unit_addr)), 32)
          when C_position,
        ext(output_value(conv_integer(unit_addr)), 32)
          when C_output,
        ext(R(conv_integer(unit_addr & pid_reg_addr)),32)
          when others;

    -- CPU core writes registers
    writereg: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' then
            if ce = '1' and bus_write = '1' then
              -- normal write for every other register
              R(conv_integer(unit_addr & pid_reg_addr))(8*i+7 downto 8*i) <=  bus_in(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;
    
    -- PID slow clock enable (kHz range)
    process(clk)
      begin
        if rising_edge(clk) then
          clkcounter <= clkcounter + 1;
        end if;
      end process;

    -- instantiate the PID controller
    pid_inst: entity work.ctrlpid
    generic map(
      psc => C_prescaler,
      precision => C_precision,
      fp => C_fp,
      an => C_pids,
      aw => C_addr_unit_bits -- 1: 2 PID units, 2: 4 PID units
    )
    port map(
      clk_pid => clk, -- system CPU clock
      ce => pid_available, -- PID data available
      error => error,
      reset => '0',
      a => unit_switch_addr, -- PID selects address
      m_k_out => m_k_out,
      KP => kp,
      KI => ki, 
      KD => kd
    );
    -- get currently switched error value    
    error <= error_value(conv_integer(unit_switch_addr));
    -- get currently switched PID parameters
    kp <= R(conv_integer(unit_switch_addr)*C_registers + C_pid)(21 downto 16);
    ki <= R(conv_integer(unit_switch_addr)*C_registers + C_pid)(13 downto 8);
    kd <= R(conv_integer(unit_switch_addr)*C_registers + C_pid)(5 downto 0);

    -- on rising edge of PID clock
    -- (copy when m_k_out is stable)
    -- memorize result (for pwm out and cpu read)
    -- and switch to next PID unit
    process(clk)
      begin
        if rising_edge(clk) then
          if(pid_available = '1') then
            output_value(conv_integer(unit_switch_addr)) <= m_k_out;
          end if;
        end if;
      end process;

    multiple_units: for i in 0 to C_pids-1 generate
    -- rotary decoder provides cv (current value = counter value)
    rotary_decoder_inst: entity work.rotary_decoder
    port map(
      clk => clk,
      reset => '0',
      encoder => encoder(i),
      counter => counter_value(i)
    );
    error_value(i) <= setpoint + R(C_registers*i + C_setpoint)(23 downto 0) - counter_value(i);
 
    -- PWM output
    --pwm_compare(i) <= m_k_out(10 downto 0); -- compare value without sign bit of m_k_out
    --pwm_sign(i) <= m_k_out(11); -- sign bit of m_k_out defines forward/reverse direction
    pwm_compare(i) <= output_value(i)(C_output_bits-2 downto 0); -- compare value without sign bit of m_k_out
    pwm_sign(i) <= output_value(i)(C_output_bits-1); -- sign bit of m_k_out defines forward/reverse direction
    --pwm_compare <= R(C_testpwm)(10 downto 0); -- compare value without sign bit of m_k_out
    --pwm_sign <= R(C_testpwm)(11); -- sign bit of m_k_out defines forward/reverse direction
    pwm_out(i) <= '1' when clkcounter(C_pwm_bits-1 downto C_pwm_bits-C_output_bits+1) < pwm_compare(i) else '0';
    bridge(i) <= '0' & pwm_out(i) when pwm_sign(i) = '0' -- forward: m_k_out is positive
             else not(pwm_out(i)) & '0';               -- reverse: m_k_out is negative
    -- bridge_out values description
    -- "00": power off (brake)
    -- "01": full power forward
    -- "10": full power reverse
    -- "11": power off (brake)

    -- bridge_f <= bridge(0);
    -- bridge_r <= bridge(1);

    -- simulated motor
    simulator: if C_simulator(i)='1' generate
    simulator_inst: entity work.simotor
    generic map(
      motor_power => 5,
      motor_speed => 17,
      motor_friction => 2
    )
    port map(
      clock => clk,
      bridge => bridge(i),
      encoder => encoder(i)
    );
    end generate;

    real: if C_simulator(i)='0' generate
      encoder(i) <= encoder_b_in(i) & encoder_a_in(i);
    end generate;

    bridge_f_out(i) <= bridge(i)(0);
    bridge_r_out(i) <= bridge(i)(1);
    encoder_a_out(i) <= encoder(i)(0);
    encoder_b_out(i) <= encoder(i)(1);

    end generate;
end;
