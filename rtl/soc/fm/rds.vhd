-- RDS modulator with DBPSK
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- this module will circulate memory address
-- memory should provide 8-bit data
-- MSB (bit 7) is sent first, LSB (bit 0) sent last

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

-- use work.message.all; -- RDS message in file message.vhd

entity rds is
generic (
    -- c_rds_msg_len: integer range 1 to 512 := 260; -- circlar message length in bytes
    -- we need to generate 1.824 MHz for RDS clock strobe
    -- input clock frequency * multiply / divide = 1.824 MHz
    -- example 25 MHz * 228 / 3125 = 1.824 MHz
    c_rds_clock_multiply: integer := 228;
    c_rds_clock_divide: integer := 3125;
    -- 2ch stereo is not yet implemented, only pilot generator
    c_stereo: boolean := false; -- true: use stereo mixing
    -- stereo mixing needs to cut off all input audio frequencies
    -- above 17kHz. It could be done by enabling:
    -- 1. C_filter: lowpass filter (higer audio quality but more LUTs)
    -- 2. C_downsample: 38kHz downsampler before stereo mixer
    --    It does the job at Nyquist cutoff frequency 38/2=19 kHz
    --    with less LUTs than lowpass filter but sacrifices audio quality.
    --    input freqs above 19 kHz are aliased in range below 19 kHz)
    -- both C_filter and C_downsample can be enabled.
    c_filter: boolean := false; -- true: low pass filter (fixme: glitches)
    c_downsample: boolean := false; -- true: downsample to 38kHz before stereo mixing
    c_debug: boolean := false; -- output counters to check subcarriers phases
    c_addr_bits: integer range 1 to 11 := 9; -- number of address bits for RDS message RAM
    -- true: spend more LUTs to use 32-point sinewave and multiply
    -- false: save LUTs, use 4-point multiplexer, no multiply
    c_fine_subc: boolean := false -- use sine and multiplier for 57kHz subcarrier (not needed, saving LUTs)
);
port (
    -- system clock, RDS verified working at 25 MHz
    -- for different clock change multiply/divide
    clk: in std_logic;
    rds_msg_len: in std_logic_vector(c_addr_bits-1 downto 0) := std_logic_vector(to_unsigned(260, c_addr_bits)); -- circular message length in bytes
    addr: out std_logic_vector(c_addr_bits-1 downto 0); -- memory address
    data: in std_logic_vector(7 downto 0); -- memory data 8 bit
    pcm_in_left, pcm_in_right: in signed(15 downto 0); -- from tone generator
    out_l, out_r: out std_logic; -- filtered outputs for debugging
    debug: out std_logic_vector(31 downto 0);
    pcm_out: out signed(15 downto 0) -- to FM transmitter
);
end rds;

architecture RTL of rds is
    -- RDS related registers
    -- get length of RDS message (file message.vhd)
    -- constant C_rds_msg_len: integer := rds_msg_map'length;

    -- DBPSK waveform is used to modulate RDS at 1187.5 Hz
    -- and to generate sine wave for 57kHz subcarrier
    -- 48 elements of 7 bits (range 1..127) in lookup table 
    -- provide sufficient resolution for time and amplitude
    constant C_dbpsk_bits: integer := 7;

    -- DBPSK wave lookup table
    type T_dbpsk_wav_integer is array(0 to 47) of integer;
    constant dbpsk_wav_integer_map: T_dbpsk_wav_integer := (
     7, 19, 30, 39, 46, 51, 53, 53, 51, 47, 42, 38, 33, 30, 28, 28,
    30, 34, 39, 45, 51, 57, 61, 63, 63, 61, 56, 49, 40, 30, 18,  6,
    -6,-18,-30,-40,-49,-56,-61,-63,-63,-61,-56,-49,-40,-30,-18, -6
    );
    type T_dbpsk_wav_signed is array (0 to 47) of signed(C_dbpsk_bits-1 downto 0);
    function dpbsk_int2sign(x: T_dbpsk_wav_integer)
      return T_dbpsk_wav_signed is
        variable i: integer;
        variable y: T_dbpsk_wav_signed;
    begin
      for i in 0 to x'length - 1 loop
        y(i) := to_signed(x(i), C_dbpsk_bits); -- converts integer to 7-bit signed number
      end loop;
      return y;
    end dpbsk_int2sign;
    constant dbpsk_wav_map: T_dbpsk_wav_signed
                          := dpbsk_int2sign(dbpsk_wav_integer_map);

    signal R_rds_cdiv: std_logic_vector(5 downto 0); -- 6-bit divisor 0..47
    signal R_rds_pcm: signed(C_dbpsk_bits-1 downto 0); -- 7 bit ADC value for RDS waveform
    signal R_rds_msg_index: std_logic_vector(c_addr_bits-1 downto 0); -- addr index for message
    constant C_rds_msg_disable: std_logic_vector(c_addr_bits-1 downto 0) := (others => '1'); -- message len -1 disables
    signal R_rds_byte: std_logic_vector(7 downto 0); -- current byte to send
    signal R_rds_bit_index: std_logic_vector(2 downto 0); -- current bit index 0..7
    signal R_rds_bit: std_logic; -- current bit to send
    signal S_rds_bit: std_logic; -- current bit to send
    signal R_rds_phase: std_logic; -- current phase 0:(+) 1:(-)
    signal R_rds_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal S_rds_sign: std_logic; -- current sign of waveform 0:(+) 1:(-)
    signal S_dbpsk_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_dbpsk_wav_value: signed(C_dbpsk_bits-1 downto 0);
    signal S_rds_pcm: signed(C_dbpsk_bits-1 downto 0); -- 7 bit ADC value for RDS waveform
    signal S_rds_mod_pcm: signed(2*C_dbpsk_bits-1 downto 0);
    signal S_rds_coarse_pcm: signed(C_dbpsk_bits-1 downto 0);

    signal R_pilot_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal R_pilot_cdiv: std_logic_vector(1 downto 0); -- 2-bit divisor 0..2
    signal S_pilot_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_pilot_wav_value: signed(C_dbpsk_bits-1 downto 0);
    signal S_pilot_pcm: signed(C_dbpsk_bits-1 downto 0) := (others => '0'); -- 7 bit ADC value
    signal S_stereo_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal S_stereo_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_stereo_wav_value: signed(C_dbpsk_bits-1 downto 0);
    signal S_stereo_pcm: signed(C_dbpsk_bits-1 downto 0) := (others => '0'); -- 7 bit ADC value
    signal S_pcm_stereo: signed(22 downto 0);

    signal R_subc_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal R_subc_cdiv: std_logic_vector(4 downto 0) := -- counter for 57kHz coarse subcarrier
      std_logic_vector(to_unsigned(6, 5)); -- initial value 6 for phase adjust
    signal S_subc_wav_index: std_logic_vector(5 downto 0); -- 6-bit index used 0..47, max 63
    signal S_subc_wav_value: signed(C_dbpsk_bits-1 downto 0);
    signal S_subc_pcm: signed(C_dbpsk_bits-1 downto 0); -- 7 bit ADC value for 19kHz pilot sine wave

    -- debug PWM output for audible test of internal low pass filter
    signal R_pcm_unsigned_data_l, R_pcm_unsigned_data_r: std_logic_vector(15 downto 0);
    signal R_dac_acc_l, R_dac_acc_r: std_logic_vector(16 downto 0);

    signal S_filter_strobe: std_logic;
    signal S_pcm_in_left_filter, S_pcm_in_right_filter: signed(15 downto 0); -- 16-bit low pass filtered
    signal R_pcm_in_left_downsample, R_pcm_in_right_downsample: signed(15 downto 0); -- 16-bit low pass filtered

    -- clock multiply must be smaller than clock divide
    -- calculate number of bits for clock divide counter
    -- 1 bit more than clock divide number
    constant C_rds_clkdiv_bits: integer := 1+integer(ceil((log2(real(C_rds_clock_divide)))+1.0E-16));
    signal R_rds_clkdiv: std_logic_vector(C_rds_clkdiv_bits-1 downto 0); -- RDS timer in picoseconds (20 bit max range 1e6 ps)
    signal S_rds_strobe: std_logic; -- 1.824 MHz strobe signal
begin
    -- generate 1.824 MHz RDS clock strobe
    -- from this frequency we can generate
    -- pilot 19 kHz, stereo 38 kHz,
    -- RDS fine subcarrier 57 kHz,
    -- RDS coarse subcarrier base 228 kHz
    -- for fine sine wave,
    -- lookup sine table period length is 32 entries
    -- so we need strobe frequency of 32*57 kHz = 1.824 MHz
    -- change state on falling edge, so strobe level is
    -- stable when compared at rising edge
    process(clk)
    begin
      if falling_edge(clk) then
        -- MSB bit is mostly 0 and for one cycle becomes 1
        -- small number is added each cycle.
        -- as soon as MSB is detected as 1,
        -- a large number is subtracted so 
        -- MSB again becomes 0
        if R_rds_clkdiv(C_rds_clkdiv_bits-1) = '0' then
          -- add clock multiply
          R_rds_clkdiv <= R_rds_clkdiv + C_rds_clock_multiply;
        else
          -- add clock multiply as always and subtract clock divide
          R_rds_clkdiv <= R_rds_clkdiv + C_rds_clock_multiply - C_rds_clock_divide;
        end if;
      end if;
    end process;
    -- MSB is used as output strobe signal
    S_rds_strobe <= R_rds_clkdiv(C_rds_clkdiv_bits-1);
    
    -- ********** STEREO 19 kHz PILOT and 38 kHz SUBCARRIER ***********
    generate_pilot_19kHz: if C_stereo generate
    process(clk)
    begin
        if rising_edge(clk) then
            -- clocked at 25 MHz
            -- strobed at 1.824 MHz
	    if S_rds_strobe = '1' then
	        -- pilot 57/3 = 19 kHz generation
	        if R_pilot_cdiv = 0 then
	          R_pilot_cdiv <= std_logic_vector(to_unsigned(2, R_pilot_cdiv'length));
	          R_pilot_counter <= R_pilot_counter + 1;
	        else
	          R_pilot_cdiv <= R_pilot_cdiv - 1;
	        end if;
	    end if;
	end if;
    end process;
    S_pilot_wav_index <= "10"                         -- or 32 (sine)
                      &  R_pilot_counter(3 downto 0); -- 0..15 running
    -- dbpsk_wav_map has range 1..127, need to subtract 64
    -- phase warning: negative sine values at index 32..47
    -- pilot should be in phase with 57kHz subcarrier
    -- (rising slope cross 0 at the same point)
    S_pilot_wav_value <= dbpsk_wav_map(conv_integer(S_pilot_wav_index));
    S_pilot_pcm <= S_pilot_wav_value when R_pilot_counter(4) = '1' -- sign at bit 4
             else -S_pilot_wav_value;
    -- S_pilot_pcm range: (-63 .. +63)
    -- pilot 19kHz must have 4.5x lower amplitude than stereo 38 kHz

    -- stereo 38kHz is generated by doubling the 19 kHz counter (shift left)
    -- every 2nd value of the sine table is used.
    -- if something better is ever needed
    -- double strobe frequency can be generated at 3.648 MHz
    -- S_stereo_counter <= R_pilot_counter + 1; -- +1 to adjust phase of stereo 38kHz
    S_stereo_counter <= R_pilot_counter; -- phase ok
    S_stereo_wav_index <= "10"                               -- or 32 (sine)
                       &  S_stereo_counter(2 downto 0) & "0"; -- 0..15 running
    -- dbpsk_wav_map has range 1..127, need to subtract 64
    -- phase warning: negative sine values at index 32..47
    S_stereo_wav_value <= dbpsk_wav_map(conv_integer(S_stereo_wav_index));
    S_stereo_pcm <= S_stereo_wav_value when S_stereo_counter(3) = '1' -- sign at bit 3
              else -S_stereo_wav_value;
    -- S_stereo_pcm range: (-63 .. +63)
    end generate;
    -- *********** END PILOT 19kHz and 38kHz SUBCARRIER *************

    -- **************** FINE SUBCARRIER 57kHz ***********************
    fine_subcarrier_sine: if C_fine_subc generate
    process(clk)
    begin
        if rising_edge(clk) then
            -- clocked at 25 MHz
            -- strobed at 1.824 MHz
	    if S_rds_strobe = '1' then
              -- 57 kHz subcarrier generation
              -- using counter 0..31
              R_subc_counter <= R_subc_counter + 1;
	    end if;
	end if;
    end process;
    S_subc_wav_index <= "10"                         -- or 32 (sine)
                      &  R_subc_counter(3 downto 0); -- 0..15 running
    -- dbpsk_wav_map has range 1..127, need to subtract 64
    -- phase warning: negative sine values at index 32..47
    S_subc_wav_value <= dbpsk_wav_map(conv_integer(S_subc_wav_index));
    S_subc_pcm <= S_subc_wav_value when R_subc_counter(4) = '1'
           else  -S_subc_wav_value;
    -- S_subc_pcm range: (-63 .. +63)
    end generate;
    -- *************** END FINE SUBCARRIER 57kHz ********************

    -- *********** RDS MODULATOR 57 kHz / 1187.5 Hz *****************
    addr <= R_rds_msg_index; -- address of data to read
    R_rds_bit <= R_rds_byte(7); -- MSB bit to send
    process(clk)
    begin
        if rising_edge(clk) then
            -- clocked at 25 MHz
            -- strobed at 1.824 MHz
	    if S_rds_strobe = '1' then
	      -- divide by 32 for 57 kHz coarse subcarrier
	      R_subc_cdiv <= R_subc_cdiv + 1;
	      -- 0-47: divide by 48 to get 1187.5 Hz from 32-element lookup table
              if R_rds_cdiv = 0 then
                R_rds_cdiv <= std_logic_vector(to_unsigned(47, R_rds_cdiv'length)); -- countdown from 47 to 0
	        -- RDS works on 1187.5 bit rate
	        -- 57KHz subcarrier should be AM modulated using RDS
	        -- adjust modulation to obtain
	        -- +-2kHz FM width on the main carrier
                R_rds_counter <= R_rds_counter + 1; -- increment counter 0..31
                if R_rds_counter = 31 then
                  -- fetch new bit
                  -- R_rds_bit <= rds_msg_map(conv_integer(R_rds_msg_index))(conv_integer(R_rds_bit_index));
                  -- R_rds_bit <= not(R_rds_bit);
                  -- R_rds_bit <= '0'; -- test: bit 0 should output 1187.5 kHz
                  -- change phase if bit was 1
                  R_rds_phase <= R_rds_phase xor R_rds_bit; -- change the phase
                  -- take next bit. Send bits from bit 7 downto bit 0
                  R_rds_bit_index <= R_rds_bit_index - 1;
                  if R_rds_bit_index = 0 then
                     -- when bit index is at LSB bit pos 0
                     -- for next clock cycle prepare next byte
                     -- (byte sending start at MSB bit pos 7)
                     if R_rds_msg_index >= rds_msg_len then
                       R_rds_msg_index <= (others => '0');
                     else
                       R_rds_msg_index <= R_rds_msg_index + 1;
                     end if;
                  end if;
                  if R_rds_bit_index = 7 then
                    R_rds_byte <= data; -- data, new byte
                  else
                    R_rds_byte <= R_rds_byte(6 downto 0) & "0"; -- shift 1 bit left
                  end if;
                end if;
              else
                R_rds_cdiv <= R_rds_cdiv - 1; -- countdown from 47 to 0
              end if;
	    end if;
	end if;
    end process;
    -- rds bit 0: continuous sine wave
    -- use lookup table values 32..47
    -- index = (counter and 15) or 32
    -- rds bit 1: phase changing sine wave
    -- use lookup table values 0..31
    -- index = counter and 31
    -- this logic has been changed from sequential
    -- to parallel so some R_rds_bit my be 1 cycle out of time
    -- we should plot S_dbpsk_wav_value in the logic
    -- analyzer
    S_rds_sign <= R_rds_phase when R_rds_bit='1'
             else not(R_rds_counter(4) xor R_rds_phase);
    S_dbpsk_wav_index <= (not(R_rds_bit))                 -- 32 (sine)
                       & (R_rds_counter(4) and R_rds_bit) -- 0..15 (sine) or 0..31 (phase change)
                       &  R_rds_counter(3 downto 0);      -- 0..15 same for both
    S_dbpsk_wav_value <= dbpsk_wav_map(conv_integer(S_dbpsk_wav_index));

    -- AM modulation of subcarrier with DBPSK wave
    -- do not overmodulate RDS signal
    -- signed value is passed to fmgen modulator
    -- transmits value*2Hz carrier frequency shift
    -- modulated range of cca -4000 ... +4000 works

    fine_subcarrier: if C_fine_subc generate
    S_rds_pcm <= S_dbpsk_wav_value when S_rds_sign = '1'
           else -S_dbpsk_wav_value;
    -- S_rds_pcm range: (-63 .. +63)
    S_rds_mod_pcm <= S_subc_pcm * S_rds_pcm when rds_msg_len /= C_rds_msg_disable
                else (others => '0');
    -- S_rds_mod_pcm range: 63*63 = (-3969 .. +3969)
    end generate;

    -- simple 57kHz mixer with multiplexer
    -- using 4 points coarse sampled subcarrier at 228 kHz
    -- no multiplication needed
    coarse_subcarrier: if not C_fine_subc generate
    -- sign manipulation with the multiplexer
    -- xor replaces calculating double minus
    -- with ( '0' xor R_subc_cdiv(4)) & R_subc_cdiv(3 downto 3) select -- debug
    with (S_rds_sign xor R_subc_cdiv(4)) & R_subc_cdiv(3 downto 3) select
    S_rds_coarse_pcm <= S_dbpsk_wav_value when "11",
                       -S_dbpsk_wav_value when "01",
                        to_signed(0, S_rds_coarse_pcm'length) when others;
    S_rds_mod_pcm <= S_rds_coarse_pcm * 64 when rds_msg_len /= C_rds_msg_disable
                else (others => '0');
    -- multiply with 2^n because it is
    -- simple, uses only bit shifting
    -- for *64: S_rds_mod_pcm range: 63*64 = (-4032 .. +4032)
    -- experimental results for various RDS modulation levels
    -- received with redsea RTL-SDR receiver:
    -- *16 works but RDS reception becomes weaker, CRC errors
    -- *32, *64, *128 all work mostly the same
    -- *256 doesn't work (overmodulation)
    end generate;
    -- ****************** END RDS MODULATOR **************

    -- ************** LOW PASS FILTER **************
    no_lowpass_filter: if not C_filter generate
      -- no filtering, input is only divided by 2 to avoid overflows
      -- at stereo mixing
      S_pcm_in_left_filter <= pcm_in_left/2;
      S_pcm_in_right_filter <= pcm_in_right/2;
    end generate; -- no_lowpass_filter

    -- FM standard requires low pass filter for audio
    -- channels to cut off frequencies above 17kHz
    -- we'll try to approximate.
    -- besides filtering we have to attenuate signal (about x2),
    -- this is to aviod overflows at stereo mixing
    lowpass_filter: if C_filter generate
      S_filter_strobe <= '1' when S_rds_strobe = '1' and R_pilot_cdiv = 0 and R_pilot_counter(1 downto 0) = 0 else '0';
      -- select S_filter_strobe frequency:
      -- R_pilot_counter(0 downto 0) = 0 -> 304 kHz
      -- R_pilot_counter(1 downto 0) = 0 -> 152 kHz
      -- R_pilot_counter(2 downto 0) = 0 ->  76 kHz
      -- R_pilot_counter(3 downto 0) = 0 ->  38 kHz
      -- bit difference and strobe frequecy
      -- define lowpass cutoff f_lowpass = f_strobe/2^bit_difference
      -- cutoff at 152/2^4 = 152/16 = 9.5 kHz
      filter_left: entity work.lowpass
      generic map (
        C_bits_in => 12,
        C_attenuation => 1, -- attenuation 2^1 = 2x
        C_bits_out => 16 -- 16-12 = 4-bit difference
      )
      port map (
        clock => clk,
        enable => S_filter_strobe, -- 152 kHz
        data_in => pcm_in_left(15 downto 4),
        data_out => S_pcm_in_left_filter
      );
      filter_right: entity work.lowpass
      generic map (
        C_bits_in => 12,
        C_attenuation => 1, -- attenuation 2^1 = 2x
        C_bits_out => 16 -- 16-12 = 4-bit difference
      )
      port map (
        clock => clk,
        enable => S_filter_strobe, -- 152 kHz
        data_in => pcm_in_right(15 downto 4),
        data_out => S_pcm_in_right_filter
      );
    end generate; -- lowpass_filter
    -- ************ END LOW PASS FILTER **************

    -- **************** DOWNSAMPLE ***************
    no_downsample_38kHz: if not C_downsample generate
      -- signal pass-through (direct wire)
      R_pcm_in_left_downsample <= S_pcm_in_left_filter;
      R_pcm_in_right_downsample <= S_pcm_in_right_filter;
    end generate; -- no_downsample_38kHz

    downsample_38kHz: if C_downsample generate
      process(clk)
      begin
        if rising_edge(clk) then
          if S_rds_strobe = '1' and R_pilot_cdiv = 0 and R_pilot_counter(1 downto 0) = 0 then
            -- pilot counter 4 LSB bits compared to a constant holds true at 38 kHz rate,
            -- at 38 kHz we downsample input PCM signal.
            -- effectively this makes a crude low pass filter,
            -- which aliases frequencies above 19 kHz (nyquist freq)
            R_pcm_in_left_downsample <= S_pcm_in_left_filter;
            R_pcm_in_right_downsample <= S_pcm_in_right_filter;
          end if;
        end if;
      end process;
    end generate; -- downsample_38kHz
    -- ************ END DOWNSAMPLE ***************

    -- output mixing audio and RDS
    mix_mono:  if not C_stereo generate
      -- mixing mono input audio with RDS DBPSK
      pcm_out <= R_pcm_in_left_downsample + R_pcm_in_right_downsample + S_rds_mod_pcm;
    end generate;

    mix_stereo:  if C_stereo generate
      -- mixing stereo input audio with RDS DBPSK
      -- (some filtering is requred by the standard)
      S_pcm_stereo <= (R_pcm_in_left_downsample - R_pcm_in_right_downsample) * S_stereo_pcm;

      -- S_stereo_pcm has range -63 .. +63
      -- pcm_in_left has range -32767 .. +32767
      -- stereo mixing: we should divide by 4 because
      -- we mix L+R + (L-R)*sin(38kHz), that rises max amplitude 4 times
      -- but we divide by 2 and hope for no clipping
      pcm_out <= R_pcm_in_left_downsample + R_pcm_in_right_downsample
               + S_pcm_stereo(21 downto 6) -- normalize S_stereo_pcm, shift divide by 64
               + S_pilot_pcm * 64 -- 16 is too weak, not sure of correct 19kHz pilot amplitude
               + S_rds_mod_pcm;
    end generate; -- mix_stereo

    rds_debug_output: if c_debug generate
      process(clk)
      begin
        if rising_edge(clk) then
	    -- PCM data from RAM normally should have average 0 (removed DC offset)
            -- for purpose of PCM generation here is
            -- conversion to unsigned std_logic_vector
            -- by inverting MSB bit (effectively adding 0x8000)
            R_pcm_unsigned_data_l <= std_logic_vector( (not R_pcm_in_left_downsample(15)) & (R_pcm_in_left_downsample(14 downto 0) ) );
            R_pcm_unsigned_data_r <= std_logic_vector( (not R_pcm_in_right_downsample(15)) & (R_pcm_in_right_downsample(14 downto 0) ) );
	    -- Output 1-bit DAC
	    R_dac_acc_l <= (R_dac_acc_l(16) & R_pcm_unsigned_data_l) + R_dac_acc_l;
	    R_dac_acc_r <= (R_dac_acc_r(16) & R_pcm_unsigned_data_r) + R_dac_acc_r;
	end if;
      end process;
      out_l <= R_dac_acc_l(16);
      out_r <= R_dac_acc_r(16);

      -- out to check phases of subcarriers
      debug <= x"00"
           & "0" & std_logic_vector(S_stereo_pcm) 
           & "0" & std_logic_vector(S_pilot_pcm)
           & "0" & std_logic_vector(S_rds_coarse_pcm);
    end generate;
end;
-- todo
-- [x] when rds_msg_len = 0 disable RDS (only mono/stereo mixing)
-- [x] compare rds with <= when size changes, it will reset if out of range
