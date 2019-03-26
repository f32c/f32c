
-- TODO: When working make this a template

--
-- MenloPark Innovation LLC:
--
-- Created from bram_rds.vhd as a 16 bit PCM/SDR synthesizer table ram.
--
-- 03/25/2019
--
-- Synthesizer for sine waves. Also called an NCO, or Numerically
-- controlled oscillator.
--
-- This is used to generate test tones, tone modulated CW, and
-- base carrier waves for signal processing.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.bram_synth_data.all; -- Initial data constants file for synth BRAM

entity sine_synth is
    generic(
        c_reg_count: integer range 2 to 256    := 4; -- 32 bit word registers
        c_reg_addr_bits: integer range 1 to 16 := 2  -- address bits of BRAM
    );
    port(
	clk: in std_logic;
	reg_addr: in std_logic_vector(c_reg_addr_bits-1 downto 0);
	reg_byte_sel: in std_logic_vector(3 downto 0);
	reg_write: in std_logic;
	bus_in: out std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	pcm_out: out std_logic_vector(15 downto 0)
    );
end sine_synth;

architecture arch of sine_synth is
    -- Local variables and signals

begin

end arch;
