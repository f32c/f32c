--
-- Copyright (c) Davor Jadrijevic
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

-- CPU bus interface which glues together
-- fmrds, fmgen, bram_rds

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all; -- we need signed type from here
use ieee.math_real.all; -- to calculate log2 bit size

entity fm is
    generic (
        C_stereo: boolean := false;
        C_filter: boolean := false;
        C_downsample: boolean := false; -- LO-FI LUT-saving option as default
        C_rds_msg_len: integer range 2 to 2048 := 273; -- allocates RAM for RDS binary message
        -- some useful values for C_rds_msg_len
        --  13 =        1*13 (CT)
        --  52 =        4*13 (PS)
        -- 260 =   (16+4)*13 (PS+RT)
        -- 273 = (16+4+1)*13 (PS+RT+CT)
        -- PS:  4 groups, main display 8 characters
        -- RT: 16 groups, long display 64 characters
        -- CT:  1 group,  time information
        -- 1 group is 13 bytes long
        C_readable_reg: boolean := false; -- make registers readable (can work without, LUT saving)
        C_fmdds_hz: integer;           -- Hz clk_fmdds (>2*108 MHz, e.g. 250 MHz, 325 MHz)
        C_rds_clock_multiply: integer; -- multiply and divide from cpu clk 81.25 MHz
        C_rds_clock_divide: integer    -- to get 1.824 MHz for RDS logic
    );
    port (
	ce, clk: in std_logic;
	bus_write: in std_logic;
	addr: in std_logic_vector(1 downto 0); -- address max 4 registers of 32-bit
	byte_sel: in std_logic_vector(3 downto 0);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	fm_irq: out std_logic; -- interrupt request line (active level high)
	clk_fmdds: in std_logic; -- DDS clock, must be > 2x max cw_freq, normally > 216 MHz
	pcm_in_left, pcm_in_right: in ieee.numeric_std.signed(15 downto 0) := (others => '0'); -- PCM audio input
	pwm_out_left, pwm_out_right: out std_logic;
	fm_antenna: out std_logic -- pyhsical output
    );
end fm;

architecture arch of fm is
    constant C_registers: integer := 3; -- # of registers with memory <= (less or equal of) # of all registers
    constant C_bits: integer := 32;     -- don't touch, default bit size of memory registers

    constant C_addr_bits: integer := integer(ceil((log2(real(C_rds_msg_len)+1.0E-6))-1.0E-6));

    -- normal registers
    -- type fm_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type fm_regs_type is array (C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: fm_regs_type; -- register access from mmapped I/O  R: active register, Rtmp temporary

    -- *** REGISTERS ***
    -- named constants for fm registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_cw_freq:    integer   := 0; -- input: 32-bit set cw frequency, writing resets rds_addr
    constant C_rds_data:   integer   := 1; -- input:  8-bit RDS data sent in circular C_rds_msg_len
    constant C_rds_addr:   integer   := 2; -- output: address currently being sent by RDS, input: address of wraparound

    -- FM/RDS RADIO
    signal rds_pcm: ieee.numeric_std.signed(15 downto 0); -- modulated PCM with audio and RDS
    signal rds_addr: std_logic_vector(C_addr_bits-1 downto 0); -- RDS modulator reads BRAM from this addr during transmission
    signal rds_data: std_logic_vector(7 downto 0); -- BRAM returns value to RDS for transmission
    signal rds_bram_write: std_logic; -- decoded address -> write signal for BRAM
    signal R_rds_bram_write: std_logic := '0'; -- 1 clock delayed write signal to offload timing constraints
    signal from_fmrds: std_logic_vector(31 downto 0); -- debugging for subcarrier phase, not used

begin
    -- CPU core reads registers
    readable_registers: if C_readable_reg generate -- LUT saving
    with conv_integer(addr) select
      bus_out <= 
        ext(rds_addr, 32)
          when C_rds_addr,
        ext(R(conv_integer(addr)), 32)
          when others;
    end generate;

    -- CPU core writes registers
    writereg_intrflags: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' and ce = '1' and bus_write = '1' then
            R(conv_integer(addr))(8*i+7 downto 8*i) <=  bus_in(8*i+7 downto 8*i);
          end if;
        end if;
      end process;
    end generate;

    -- write to circular RDS memory
    rds_bram_write <= '1'
                 when byte_sel(0) = '1'
                  and ce = '1'
                  and bus_write = '1'
                  and conv_integer(addr) = C_rds_data
                 else '0';

    -- RAM write delay 1 clock cycle
    process(clk)
    begin
      if rising_edge(clk) then
        R_rds_bram_write <= rds_bram_write;
      end if;
    end process;

    rds_modulator: entity work.rds
    generic map (
      c_addr_bits => C_addr_bits, -- number of address bits for RDS message RAM
      -- multiply/divide to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide,
      -- example settings for 25 MHz clock
      -- c_rds_clock_multiply => 228,
      -- c_rds_clock_divide => 3125,
      -- settings for super slow (100Hz debug) clock
      -- c_rds_clock_multiply => 1,
      -- c_rds_clock_divide => 812500,
      c_filter => C_filter,
      c_downsample => C_downsample,
      c_stereo => C_stereo
    )
    port map (
      clk => clk, -- RDS and PCM processing clock, same as CPU clock
      rds_msg_len => R(C_rds_addr)(C_addr_bits-1 downto 0),
      addr => rds_addr,
      data => rds_data,
      pcm_in_left => pcm_in_left,
      pcm_in_right => pcm_in_right,
      debug => from_fmrds,
      out_l => pwm_out_left,
      out_r => pwm_out_right,
      pcm_out => rds_pcm
    );
    fm_modulator: entity work.fmgen
    generic map (
      c_fdds => real(C_fmdds_hz)
    )
    port map (
      clk_pcm => clk, -- PCM processing clock, same as CPU clock
      clk_dds => clk_fmdds, -- DDS clock must be > 2x cw_freq 
      cw_freq => R(C_cw_freq), -- Hz FM carrier wave frequency, e.g. 107900000
      pcm_in => rds_pcm,
      fm_out => fm_antenna
    );

    rdsbram: entity work.bram_rds
    generic map (
	c_mem_bytes => C_rds_msg_len, -- allocate RAM for max message size
        c_addr_bits => C_addr_bits -- number of address bits for RDS message RAM
    )
    port map (
	clk => clk,
	imem_addr => rds_addr,
	imem_data_out => rds_data,
	dmem_write => R_rds_bram_write,
	dmem_addr => R(C_rds_data)(16+C_addr_bits-1 downto 16),
	dmem_data_out => open, dmem_data_in => R(C_rds_data)(7 downto 0)
    );

end;
-- registers:
-- 0: 32-bit CW frequency (write only)
-- 1: rds data (write only)
--    byte 0:    8-bit address data to write
--    byte 2-3: 11-bit address where to write
-- 2: byte 0-1: 11-bit address of current byte send (read)
--    byte 0-1: 11-bit RDS message length, address wraparound (write)

-- todo:
-- [ ] interrupt
-- [ ] reading from circular memory
