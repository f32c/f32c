-- RDS modulator with DBPSK
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- this module will circulate memory address
-- memory should provide 8-bit data
-- MSB (bit 7) is sent first, LSB (bit 0) sent last

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- use work.message.all; -- RDS message in file message.vhd

entity rds is
generic (
    c_rds_msg_len: integer range 1 to 512 := 260; -- circlar message length in bytes
    -- we need to generate 1.824 MHz for RDS clock strobe
    -- input clock frequency * multiply / divide = 1.824 MHz
    -- example 25 MHz * 228 / 3125 = 1.824 MHz
    c_rds_clock_multiply: integer := 228;
    c_rds_clock_divide: integer := 3125;
    -- 2ch stereo is not yet implemented, only pilot generator
    c_stereo: boolean := false; -- true: generate 19kHz pilot wave
    -- true: spend more LUTs to use 32-point sinewave and multiply 
    -- false: save LUTs, use 4-point multiplexer, no multiply
    c_fine_subc: boolean := false
);
port (
    -- system clock, RDS verified working at 25 MHz
    -- for different clock change multiply/divide
    clk: in std_logic;
    addr: out std_logic_vector(8 downto 0); -- memory address 512 bytes
    data: in std_logic_vector(7 downto 0); -- memory data 8 bit
    pcm_in: in signed(15 downto 0); -- from tone generator
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
    constant C_dbpsk_bits: integer := 8;

    -- DBPSK wave lookup table
    type dbpsk_wav_type is array(0 to 47) of std_logic_vector(7 downto 0);
    constant dbpsk_wav_map: dbpsk_wav_type := (
x"47",x"53",x"5e",x"67",x"6e",x"73",x"75",x"75",x"73",x"6f",x"6a",x"66",x"61",x"5e",x"5c",x"5c",
x"5e",x"62",x"67",x"6d",x"73",x"79",x"7d",x"7f",x"7f",x"7d",x"78",x"71",x"68",x"5e",x"52",x"46",
x"3a",x"2e",x"22",x"18",x"0f",x"08",x"03",x"01",x"01",x"03",x"08",x"0f",x"18",x"22",x"2e",x"3a"
    );
    signal R_rds_cdiv: std_logic_vector(5 downto 0); -- 6-bit divisor 0..47
    signal R_rds_pcm: signed(7 downto 0); -- 8 bit ADC value for RDS waveform
    signal R_rds_msg_index: std_logic_vector(8 downto 0); -- 9 bit index for message
    signal R_rds_byte: std_logic_vector(7 downto 0); -- current byte to send
    signal R_rds_bit_index: std_logic_vector(2 downto 0); -- current bit index 0..7
    signal R_rds_bit: std_logic; -- current bit to send
    signal S_rds_bit: std_logic; -- current bit to send
    signal R_rds_phase: std_logic; -- current phase 0:(+) 1:(-)
    signal R_rds_counter: std_logic_vector(4 downto 0); -- 5-bit wav counter 0..31
    signal S_rds_sign: std_logic; -- current sign of waveform 0:(+) 1:(-)
    signal S_dbpsk_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_dbpsk_wav_value: signed(7 downto 0);
    signal S_rds_pcm: signed(7 downto 0); -- 8 bit ADC value for RDS waveform
    signal S_rds_mod_pcm: signed(15 downto 0);
    signal S_rds_coarse_pcm: signed(7 downto 0);

    signal R_pilot_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal R_pilot_cdiv: std_logic_vector(1 downto 0); -- 2-bit divisor 0..2
    signal S_pilot_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_pilot_wav_value: signed(7 downto 0);
    signal S_pilot_sign: std_logic; -- current sign of waveform 0:(+) 1:(-)
    signal S_pilot_pcm: signed(7 downto 0) := (others => '0'); -- 8 bit ADC value

    signal R_subc_counter: std_logic_vector(4 downto 0) := (others => '0'); -- 5-bit wav counter 0..31
    signal R_subc_cdiv: std_logic_vector(4 downto 0) := (others => '0'); -- divide to 57kHz
    signal S_subc_wav_index: std_logic_vector(5 downto 0); -- 6-bit index 0..63
    signal S_subc_wav_value: signed(7 downto 0);
    signal S_subc_pcm: signed(7 downto 0); -- 8 bit ADC value for 19kHz pilot sine wave

    -- clock multiply must be smaller than clock divide
    -- calculate number of bits for clock divide counter
    -- 1 bit more than clock divide number
    constant C_rds_clkdiv_bits: integer := 1+integer(ceil((log2(real(C_rds_clock_divide)))+1.0E-16));
    signal R_rds_clkdiv: std_logic_vector(C_rds_clkdiv_bits-1 downto 0); -- RDS timer in picoseconds (20 bit max range 1e6 ps)
    signal S_rds_strobe: std_logic; -- 1.824 MHz strobe signal
begin
    -- generate 1.824 MHz RDS clock strobe
    -- RDS needs 57 kHz carrier wave.
    -- lookup table period length is 32 entries
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
    
    -- ****************** PILOT 19kHz (only for stereo, not used for mono) *******************
    generate_pilot_19kHz: if C_stereo generate
    process(clk)
    begin
        if rising_edge(clk) then
            -- clocked at 25 MHz
            -- strobed at 1.824 MHz
	    if S_rds_strobe = '1' then
	        -- pilot 57/3 = 19 kHz generation
	        if R_pilot_cdiv = 0 then
	          R_pilot_cdiv <= 2;
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
    S_pilot_wav_value <= signed(dbpsk_wav_map(conv_integer(S_pilot_wav_index)) - x"40");
    S_pilot_pcm <= S_pilot_wav_value when R_pilot_counter(4) = '1'
             else -S_pilot_wav_value;
    -- S_pilot_pcm range: (-63 .. +63)
    end generate;
    -- ****************** END PILOT 19kHz ***************************

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
    S_subc_wav_value <= signed(dbpsk_wav_map(conv_integer(S_subc_wav_index)) - x"40");
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
                R_rds_cdiv <= 47; -- countdown from 47 to 0
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
                     R_rds_msg_index <= R_rds_msg_index + 1;
                     if R_rds_msg_index >= (C_rds_msg_len-1) then
                       R_rds_msg_index <= 0;
                     end if;
                  end if;
                  if R_rds_bit_index = 7 then
                    R_rds_byte <= data; -- data, new byte
                  else
                    R_rds_byte <= R_rds_byte(6 downto 0) & "0"; -- shift 1 bit left
                  end if;
                  -- R_rds_bit <= rds_msg_map(conv_integer(R_rds_msg_index))(conv_integer(R_rds_bit_index));
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
    S_rds_sign <= R_rds_phase when R_rds_bit='1'
             else not(R_rds_counter(4) xor R_rds_phase);
    S_dbpsk_wav_index <= (not(R_rds_bit))                 -- 32 (sine)
                       & (R_rds_counter(4) and R_rds_bit) -- 0..15 (sine) or 0..31 (phase change)
                       &  R_rds_counter(3 downto 0);      -- 0..15 same for both
    S_dbpsk_wav_value <= signed(dbpsk_wav_map(conv_integer(S_dbpsk_wav_index)) - x"40");

    -- AM modulation of subcarrier with DBPSK wave
    -- do not overmodulate RDS signal
    -- signed value is passed to fmgen modulator
    -- transmits value*2Hz carrier frequency shift
    -- modulated range of cca -4000 ... +4000 works

    fine_subcarrier: if C_fine_subc generate
    S_rds_pcm <= S_dbpsk_wav_value when S_rds_sign = '1'
           else -S_dbpsk_wav_value;
    -- S_rds_pcm range: (-63 .. +63)
    S_rds_mod_pcm <= S_subc_pcm * S_rds_pcm;
    -- S_rds_mod_pcm range: 63*63 = (-3969 .. +3969)
    end generate;

    -- simple 57kHz mixer with multiplexer
    -- using 4 points coarse sampled subcarrier at 228 kHz
    -- no multiplication needed
    coarse_subcarrier: if not C_fine_subc generate
    -- sign manipulation with the multiplexer
    -- avoids calculating double minus
    with S_rds_sign & R_subc_cdiv(4 downto 3) select
    S_rds_coarse_pcm <= S_dbpsk_wav_value when "101" | "011",
                       -S_dbpsk_wav_value when "111" | "001",
                        0 when others;
    S_rds_mod_pcm <= S_rds_coarse_pcm * 64;
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

    -- mixing input audio with RDS DBPSK
    mix_no_pilot:  if not C_stereo generate
    pcm_out <= pcm_in + S_rds_mod_pcm;
    end generate;

    mix_pilot:  if C_stereo generate
    pcm_out <= pcm_in + S_pilot_pcm + S_rds_mod_pcm;
    end generate;
end;
