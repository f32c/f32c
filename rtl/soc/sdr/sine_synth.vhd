
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
	addr: in std_logic_vector(c_reg_addr_bits-1 downto 0);
	byte_sel: in std_logic_vector(3 downto 0);
	bus_write: in std_logic;
	reg_ce: in std_logic;
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	pcm_out: out std_logic_vector(15 downto 0)
    );
end sine_synth;

architecture arch of sine_synth is

    constant C_sdr_pcm_synth_cs: integer     := 0; -- Register 0
      constant C_sdr_pcm_synth_enable: integer := 0; -- Bit numbers
      constant C_sdr_pcm_sine_enable:  integer := 1;

    constant C_sdr_pcm_synth_ram: integer       := 1;  -- Address (31 downto 16) Data (16 downto 0)
    constant C_sdr_pcm_synth_freq: integer      := 2;
    constant C_sdr_pcm_synth_amplitude: integer := 3;

    -- Programming Registers
    signal R_sdr_pcm_synth_cs: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_ram: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_freq: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_amplitude: std_logic_vector(31 downto 0);

    -- Synth RAM module
    constant C_synth_ram_len: integer       := 64;  -- 64 words of synth BRAM
    constant C_synth_ram_addr_bits: integer := 6;

    signal synth_bram_addr: std_logic_vector(C_synth_ram_addr_bits-1 downto 0);
    signal synth_bram_data: std_logic_vector(15 downto 0);
    signal synth_bram_write: std_logic;

    -- 1 clock delayed write signal to offload timing constraints
    signal R_synth_bram_write: std_logic := '0';

begin

    --
    -- CPU programming register read process
    --
    -- Only 32 bit reads are supported.
    --
    process(addr)
    begin

        -- Standard latch prevention logic for always_comb
        bus_out <= (others => '0');

        case conv_integer(addr) is

        when C_sdr_pcm_synth_cs =>
            bus_out <= R_sdr_pcm_synth_cs;

        when C_sdr_pcm_synth_ram =>
            bus_out <= R_sdr_pcm_synth_ram;

        when C_sdr_pcm_synth_freq =>
            bus_out <= R_sdr_pcm_synth_freq;

        when C_sdr_pcm_synth_amplitude =>
            bus_out <= R_sdr_pcm_synth_amplitude;

        when others  =>
            -- Undefined registers read as 0
            bus_out <= (others => '0');
        end case;
    end process;

    --
    -- CPU programming register write process.
    --
    -- Only 32 bit writes are supported.
    --
    process(clk)
    begin

        if rising_edge(clk) then
            if byte_sel(0) = '1' and reg_ce = '1' and bus_write = '1'  then

                case conv_integer(addr) is

                when C_sdr_pcm_synth_cs =>
                    R_sdr_pcm_synth_cs <= bus_in;

                when C_sdr_pcm_synth_ram =>
                    R_sdr_pcm_synth_ram <= bus_in;

                when C_sdr_pcm_synth_freq =>
                    R_sdr_pcm_synth_freq <= bus_in;

                when C_sdr_pcm_synth_amplitude =>
                    R_sdr_pcm_synth_amplitude <= bus_in;

                when others  =>
                    -- Undefined registers throw away writes
                end case;
            end if;
        end if;    
    end process;

    --
    -- Synthesizer table BRAM
    --
    -- This is a dual port RAM in which the write port
    -- is updated by the CPU, and the read port is used
    -- by the signal generation logic.
    --
    synthbram: entity work.bram_synth
    generic map (
	c_mem_bytes => C_synth_ram_len,
        c_addr_bits => C_synth_ram_addr_bits
    )
    port map (
	clk => clk,

        -- BRAM read port
	imem_addr => synth_bram_addr,
	imem_data_out => synth_bram_data,

        -- BRAM write port
	dmem_write => R_synth_bram_write,
	dmem_addr => R_sdr_pcm_synth_ram(16+C_synth_ram_addr_bits-1 downto 16),
	dmem_data_out => open, dmem_data_in => R_sdr_pcm_synth_ram(15 downto 0)
    );

    -- Writes to the Synth BRAM.
    synth_bram_write <= '1'
                 when byte_sel(0) = '1'
                  and reg_ce = '1'
                  and bus_write = '1'
                  and conv_integer(addr) = C_sdr_pcm_synth_ram
                 else '0';

    -- Synth BRAM write delay 1 clock cycle after write data register is set.
    process(clk)
    begin
      if rising_edge(clk) then
        R_synth_bram_write <= synth_bram_write;
      end if;
    end process;

    --
    -- Sine synthesis process
    --
    -- The CPU programs the synthesizer table BRAM with pre-calculated
    -- values to generate the desired wave form, with its base amplitude.
    --
    -- The base amplitude is choosen to trade off bit width (16 bits),
    -- number of samples (default 64), and rounding errors for the
    -- generated signal.
    --
    -- There are C_synth_ram_len entries, and represents one complete cycle
    -- of the generated waveform.
    --
    -- When enabled in the control register the synthesizer
    -- table BRAM is read sequentually at the clock rate specified
    -- in the frequency register.
    --
    -- The value in the table is multiplied by the signal amplitude
    -- in the amplitude register and output as pcm_out.
    --
    -- The CPU can update the frequency, amplitude signal at runtime
    -- to apply modulation to the signal.
    --

    -- PCM clock generator

    -- Synthesis process/counter

    -- Amplitude multiply

    -- Output assignment

end arch;
