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

entity fm is
    generic (
        C_stereo: boolean := false;
        C_rds_msg_len: integer := 260; -- bytes of RDS binary message, usually 52 (8-char PS) or 260 (8 PS + 64 RT)
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
	pcm_in_left, pcm_in_right: signed(15 downto 0) := (others => '0'); -- PCM audio input
	fm_antenna: out std_logic -- pyhsical output
    );
end fm;

architecture arch of fm is
    constant C_registers: integer := 2; -- # of registers with memory <= (less or equal of) # of all registers
    constant C_bits: integer := 32;     -- don't touch, default bit size of memory registers

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
    constant C_rds_addr:   integer   := 2; -- output: address currently being sent by RDS

    -- FM/RDS RADIO
    signal rds_pcm: signed(15 downto 0); -- modulated PCM with audio and RDS
    signal rds_addr: std_logic_vector(8 downto 0); -- RDS modulator reads BRAM from this addr during transmission
    signal rds_data: std_logic_vector(7 downto 0); -- BRAM returns value to RDS for transmission
    signal rds_bram_write: std_logic; -- decoded address -> write signal for BRAM
    signal R_rds_bram_write: std_logic := '0'; -- 1 clock delayed write signal to offload timing constraints
    signal from_fmrds: std_logic_vector(31 downto 0); -- debugging for subcarrier phase, not used

    signal R_rds_addr: std_logic_vector(8 downto 0) := (others => '0'); -- circular RDS write address register

begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <= 
        ext(rds_addr, 32)
          when C_rds_addr,
        ext(R(conv_integer(addr)), 32)
          when others;

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

    process(clk)
    begin
      if rising_edge(clk) then
        R_rds_bram_write <= rds_bram_write;
        if R_rds_bram_write = '1' then
          if conv_integer(R_rds_addr) = C_rds_msg_len-1 then -- wraparound RDS message size
            R_rds_addr <= (others => '0'); -- reset address (wraparound)
          else
            R_rds_addr <= R_rds_addr + 1; -- next address
          end if;
        end if;
      end if;
    end process;

    rds_modulator: entity work.rds
    generic map (
      c_stereo => C_stereo,
      -- multiply/divide to produce 1.824 MHz clock
      c_rds_clock_multiply => C_rds_clock_multiply,
      c_rds_clock_divide => C_rds_clock_divide,
      -- example settings for 25 MHz clock
      -- c_rds_clock_multiply => 228,
      -- c_rds_clock_divide => 3125,
      -- settings for super slow (100Hz debug) clock
      -- c_rds_clock_multiply => 1,
      -- c_rds_clock_divide => 812500,
      c_rds_msg_len => C_rds_msg_len
    )
    port map (
      clk => clk, -- RDS and PCM processing clock, same as CPU clock
      addr => rds_addr,
      data => rds_data,
      pcm_in_left => pcm_in_left,
      pcm_in_right => pcm_in_left,
      debug => from_fmrds,
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
    port map (
	clk => clk,
	imem_addr => rds_addr,
	imem_data_out => rds_data,
	dmem_write => R_rds_bram_write,
	dmem_byte_sel => x"1", dmem_addr => R_rds_addr,
	dmem_data_out => open, dmem_data_in => R(C_rds_data)(7 downto 0)
    );

end;
-- todo:
-- [ ] on/off RDS
-- [ ] register to set number of RDS message bytes
-- [ ] interrupt
-- [ ] reading R(C_rds_data), like writing should increment R_rds_addr
-- [ ] writing R(C_cw_freq) should reset R_rds_addr
-- [ ] reading from circular memory
-- [ ] complete readback optional
