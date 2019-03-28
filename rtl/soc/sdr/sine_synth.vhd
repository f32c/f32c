
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
-- The number of samples per cycle is controlled by the compile
-- time generic parameter C_synth_ram_len.
--
-- The caller controls the sample clock rate by setting the real time CPU
-- programmable frequency register to the ratio of the input clk and
-- the designed sample clock rate.
--
-- One complete cycle requires C_synth_ram_len sample clocks.
--
-- Output frequency can be calculated by:
--
-- sample_clock = (clk_rate / freq_reqister);
--
-- output_frequency = (sample_clock  / C_synth_ram_len);
--
-- A freq_register value can be calculated by:
--
-- freq_register = clk_rate / (output_frequency * C_synth_ram_len);
--

library ieee; 
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.bram_synth_data.all; -- Initial data constants file for synth BRAM

entity sine_synth is
    generic(
        -- Bits for CPU accessible registers
        C_reg_addr_bits: integer range 1 to 16 := 2; -- address bits of BRAM

        -- Synth RAM module
        -- This controls the number of samples per cycle. --
        C_synth_ram_len: integer       := 64;  -- 64 words of synth BRAM
        C_synth_ram_addr_bits: integer := 6
    );
    port(
	clk: in std_logic;
	addr: in std_logic_vector(C_reg_addr_bits-1 downto 0);
	byte_sel: in std_logic_vector(3 downto 0);
	bus_write: in std_logic;
	reg_ce: in std_logic;
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	pcm_out: out std_logic_vector(15 downto 0)
    );
end sine_synth;

architecture arch of sine_synth is

    -- This supports a lowest frequency of 97.65 Hz with 8Khz PCM
    -- and a 100Mhz input clock.
    constant C_clk_gen_width: integer := 16;

    constant C_sdr_pcm_synth_cs: integer     := 0; -- Register 0
      constant C_sdr_pcm_synth_enable:  integer := 0; -- Bit numbers
      constant C_sdr_pcm_sine_enable:   integer := 1;
      constant C_sdr_pcm_write_protect: integer := 2;

    constant C_sdr_pcm_synth_ram: integer       := 1;  -- Address (31 downto 16) Data (16 downto 0)
    constant C_sdr_pcm_synth_freq: integer      := 2;
    constant C_sdr_pcm_synth_amplitude: integer := 3;

    -- Programming Registers
    signal R_sdr_pcm_synth_cs: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_ram: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_freq: std_logic_vector(31 downto 0);
    signal R_sdr_pcm_synth_amplitude: std_logic_vector(31 downto 0);

    signal synth_bram_data: std_logic_vector(15 downto 0);
    signal synth_bram_write: std_logic;
    signal synth_bram_dmem_data_out: std_logic_vector(15 downto 0);

    -- Synth BRAM Table address/index counter
    signal synth_bram_addr_reg: unsigned(C_synth_ram_addr_bits-1 downto 0);
    signal synth_bram_addr_next : unsigned(C_synth_ram_addr_bits-1 downto 0);

    -- 1 clock delayed write signal to offload timing constraints
    signal R_synth_bram_write: std_logic := '0';

    -- Control signals
    signal synth_enable: std_logic;
    signal sine_enable: std_logic;
    signal write_protect: std_logic;

    signal synth_clk_out: std_logic;

    signal R_pcm_out: std_logic_vector(15 downto 0);

begin

    pcm_out <= R_pcm_out;

    -- When true the synthesizer tables can be read, not written.
    synth_enable <= R_sdr_pcm_synth_cs(C_sdr_pcm_synth_enable);

    sine_enable <= R_sdr_pcm_synth_cs(C_sdr_pcm_sine_enable);
    write_protect <= R_sdr_pcm_synth_cs(C_sdr_pcm_write_protect);

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
            -- Lower 16 bits are the real time data out from the BRAM
            bus_out <= R_sdr_pcm_synth_ram(31 downto 16) & synth_bram_dmem_data_out;

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
                    -- This allows CPU access to the sine table BRAM
                    R_sdr_pcm_synth_ram <= bus_in;

                when C_sdr_pcm_synth_freq =>
                    -- This represents the frequency ratio
                    R_sdr_pcm_synth_freq <= bus_in;

                when C_sdr_pcm_synth_amplitude =>
                    -- This represents the amplitude ratio
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

        -- BRAM read port used by synthesizer
	imem_addr => std_logic_vector(synth_bram_addr_reg),
	imem_data_out => synth_bram_data,

        -- BRAM read/write port used by CPU registers
	dmem_write => R_synth_bram_write,
	dmem_addr => R_sdr_pcm_synth_ram(16+C_synth_ram_addr_bits-1 downto 16),
	dmem_data_out => synth_bram_dmem_data_out,
        dmem_data_in => R_sdr_pcm_synth_ram(15 downto 0)
    );

    -- Writes to the Synth BRAM.
    synth_bram_write <= '1'
                 when byte_sel(0) = '1'
                  and reg_ce = '1'
                  and bus_write = '1'
                  and write_protect = '0'
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
    synth_clock_gen: entity work.prog_clk_gen
        generic map (
          C_ClockCounterWidth => C_clk_gen_width
          )
        port map (
          clk => clk,
          reset => '0',
          clk_counter_max => R_sdr_pcm_synth_freq(C_clk_gen_width-1 downto 0),
          clk_out => synth_clk_out
          );

    -- Synthesis process/counter

    -- This counts through the table entries
    synth_bram_addr_next <= (others => '0')
        when synth_bram_addr_reg = C_synth_ram_len-1
        else synth_bram_addr_reg + 1;

    process(clk)
    begin
        if rising_edge(clk) then

            if synth_clk_out = '1' then
                synth_bram_addr_reg <= synth_bram_addr_next;

                -- Registered output from BRAM output

                -- Amplitude multiply

                R_pcm_out <= synth_bram_data;

            end if;

        end if;
    end process;
end arch;
