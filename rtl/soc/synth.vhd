-- Tonewheel synthesizer
-- (c) Davor Jadrijevic
-- LICENSE=BSD

-- this module generates multiple-voice polyphonic sound
-- bus interface updates a set of 128 volumes by writing a
-- 32-bit data for to any address
-- 0xVVVTT    VVVV-volume signed 11-bit, TT-MIDI tone number 7-bit
-- 0x20045    Plays MIDI tone 69, note A4 (440 Hz) at volume 256 (half max)

library ieee;
use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all; -- replaced by ieee.numeric_std.all
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

entity synth is
generic
(
  C_clk_freq: integer := 25000000; -- Hz system clock
  C_addr_bits: integer := 1; -- don't touch: number of bus address bits for the registers
  C_data_bits: integer := 32; -- don't touch: number of bus data bits
  C_ref_freq: real := 440.0; -- Hz reference tone frequency (usually 440Hz for tone A4)
  C_ref_octave: integer := 5; -- reference octave (default 5)
  C_ref_tone: integer := 9; -- reference tone (default 9, tone A)
  C_slow_octave: integer := 7; -- octaves above this need to slow rise of the volume to avoid clicks
  C_voice_addr_bits: integer := 7; -- bits voices (2^n voices, phase accumulators, volume multipliers)
  C_voice_vol_bits: integer := 11; -- bits signed data for volume of each voice
  C_wav_addr_bits: integer := 10;  -- bits unsigned address for wave time base (time resolution)
  C_wav_data_bits: integer := 12; -- bits signed wave amplitude resolution
  C_pa_data_bits: integer := 32; -- bits of data in phase accumulator BRAM
  C_amplify: integer := 0; -- bits louder output but reduces max number of voices by 2^n (clipping)
  C_multiplier: boolean := true; -- true: true signed multiplier, false: simple off/on
  C_multiplier_sign_fix: boolean := false; -- true: fix if unsigned multiplier is incorrectly infered for signed arguments
  C_keyboard: boolean := false; -- false: CPU bus input, true: keyboard input (generates tone A4 (440 Hz) and few others)
  C_bus_freq_write: boolean := true; -- true: CPU bus writes frequency
  C_zero_cross: boolean := false; -- updates volume at zero cross (remove clicks) expense 1 extra BRAM
  C_vol_velocity_bits: integer := 6; -- 2^n voice volume velocity above slow octave (step at zero cross) 0-3:slow no click, 4:normal small click, 5:normal mild click, >=6: fast strong click
  C_out_bits: integer := 24 -- bits of signed PCM output data
);
port
(
  clk, io_ce, io_bus_write: in std_logic;
  io_addr: in std_logic_vector(C_addr_bits-1 downto 0);
  io_byte_sel: in std_logic_vector(3 downto 0);
  io_bus_in: in std_logic_vector(C_data_bits-1 downto 0);
  keyboard: in std_logic_vector(6 downto 0) := (others => '0'); -- simple keyboard
  pcm_out: out signed(C_out_bits-1 downto 0) -- to audio output
);
end;

architecture RTL of synth is
    constant C_tones_per_octave: integer := 12; -- tones per octave
    constant C_cents_per_octave: real := 1200.0; -- cents (tuning) per octave

    -- meantone temperament:
    -- tone cents table f=2^(x/1200), 0-1200 scale for full octave of 12 tones
    type T_meantone_temperament is array (0 to C_tones_per_octave-1) of real;
    -- if temperament starts with C it will match standard MIDI
    -- key numbering (key 0 is C-1, key 69 is A4 (440 Hz), key 127 is G9)

    -- see https://en.wikipedia.org/wiki/Semitone
    -- http://www.kylegann.com/tuning.html

    -- classical 16-century music quarter-comma meantone temperament, chromatic scale
    constant C_quarter_comma_temperament: T_meantone_temperament :=
    (
         0.0, --  0 C
        76.0, --  1 C#
       193.2, --  2 D
       310.3, --  3 Eb
       386.3, --  4 E
       503.4, --  5 F
       579.5, --  6 F#
       696.6, --  7 G
       772.6, --  8 G#
       889.7, --  9 A
      1006.8, -- 10 Bb
      1082.9  -- 11 B
    );
    
    -- Ben Johnston's Suite for Microtonal Piano (1977)
    constant C_microtonal_piano_temperament: T_meantone_temperament :=
    (
         0.0, --  0 C
       105.0, --  1 C#
       203.9, --  2 D
       297.5, --  3 Eb
       386.3, --  4 E
       470.8, --  5 F
       551.3, --  6 F#
       702.0, --  7 G
       840.5, --  8 G#
       905.9, --  9 A
       968.8, -- 10 Bb
      1088.3  -- 11 B
    );

    -- Hammond temperament targets equal-temperament, but 
    -- due to constructional reasons, some tones are slightly off-tune
    constant C_hammond_temperament: T_meantone_temperament :=
    (
         0.0,        --  0 C
        99.89267627, --  1 C#
       200.7760963,  --  2 D
       300.488157,   --  3 Eb
       400.180858,   --  4 E
       499.8955969,  --  5 F
       600.6025772,  --  6 F#
       700.5966375,  --  7 G
       799.8695005,  --  8 G#
       900.5764808,  --  9 A
      1000.29122,    -- 10 Bb
      1099.983921    -- 11 B
    );

    -- equal temperament aka EDO-12 is default for MIDI instruments
    constant C_equal_temperament: T_meantone_temperament :=
    (
         0.0, --  0 C
       100.0, --  1 C#
       200.0, --  2 D
       300.0, --  3 Eb
       400.0, --  4 E
       500.0, --  5 F
       600.0, --  6 F#
       700.0, --  7 G
       800.0, --  8 G#
       900.0, --  9 A
      1000.0, -- 10 Bb
      1100.0  -- 11 B
    );

    -- Select which temperament to use 
    constant C_temperament: T_meantone_temperament := C_hammond_temperament;

    -- tuning math:
    -- input: C_clk_freq, C_ref_freq, C_ref_octave, C_ref_note, C_pa_data_bits, C_voice_addr_bits
    -- output: C_shift_octave, C_tuning_cents

    -- calculate base frequency, this is lowest possible A, meantone_temperament #9
    -- downshifting by (C_voice_addr_bits+C_pa_data_bits) is moved to C_shift_octave to avoid floating underflow here
    constant C_base_freq: real := real(C_clk_freq)*2.0**(C_temperament(C_ref_tone)/C_cents_per_octave);
    -- calculate how many octaves (floating point) we need to go up to reach C_ref_freq
    constant C_octave_to_ref: real := log(C_ref_freq/C_base_freq)/log(2.0);
    -- convert real C_octave_to_ref into octave integer and cents tuning
    -- now shift by (C_voice_addr_bits+C_pa_data_bits)
    constant C_shift_octave: integer := integer(C_octave_to_ref)+C_voice_addr_bits+C_pa_data_bits-C_ref_octave;
    constant C_tuning_cents: real := C_cents_per_octave*(C_octave_to_ref-floor(C_octave_to_ref));
    constant C_accu_bits: integer := C_voice_vol_bits+C_wav_data_bits+C_voice_addr_bits-C_amplify-1; -- accumulator register width

    -- Hardware Registration:
    -- Can be changed only at compile time.
    -- Allows independent and consistent tuning of each key for
    -- non-equal temperaments, odd harmonics 5,7,9,... and user-defined waveforms.
    -- For software (CPU-controlled) registration like in original hammond,
    -- 9 sinewave voices are mixed with drawbar 2^n volume coefficients,
    -- see http://www.jessedeanefreeman.com/hammondstuff.html
    -- hardware registration should be set to:
    -- C_temperament = C_hammond_temperament (or C_equal_temperament)
    -- C_drawbar_registration = C_drawbar_sinewave
    constant C_drawbar_len: integer := 9; -- number of Hammond style drawbars
    type T_drawbar_table is array (0 to C_drawbar_len-1) of integer;
    constant C_drawbar_harmonic:   T_drawbar_table := (1,3, 2,4,6,8, 10,12,16);
    -- Hammond common registrations see http://www.keyboardservice.com/Drawbars.asp
    constant C_drawbar_sinewave:   T_drawbar_table := (8,0, 0,0,0,0, 0,0,0);
    constant C_drawbar_rockorgan:  T_drawbar_table := (8,8, 8,2,0,0, 0,0,0);
    constant C_drawbar_metalorgan: T_drawbar_table := (8,7, 5,0,5,0, 0,0,0);
    constant C_drawbar_sawtooth:   T_drawbar_table := (8,3, 4,2,1,1, 1,0,0);
    constant C_drawbar_squarewave: T_drawbar_table := (0,0, 8,0,3,0, 2,0,0);
    constant C_drawbar_fullbright: T_drawbar_table := (8,8, 8,8,8,8, 8,8,8);
    constant C_drawbar_englishorn: T_drawbar_table := (0,0, 3,5,7,7, 5,4,0);
    constant C_drawbar_brojack:    T_drawbar_table := (8,0, 0,0,0,0, 8,8,8);
    constant C_drawbar_vocalist:   T_drawbar_table := (7,8, 4,3,0,0, 0,0,0);
    constant C_drawbar_stringensamble: T_drawbar_table := (4,0, 5,5,4,5, 3,3,6);
    constant C_drawbar_silky:      T_drawbar_table := (8,0, 8,0,0,0, 0,0,8);
    constant C_drawbar_fatt:       T_drawbar_table := (8,8, 8,0,0,0, 8,8,8);
    constant C_drawbar_evilways:   T_drawbar_table := (8,8, 6,4,0,0, 0,0,0);
    constant C_drawbar_itsonlylove:T_drawbar_table := (6,4, 8,8,4,8, 4,4,8);
    constant C_drawbar_whitershadeofpale: T_drawbar_table := (6,8, 8,6,0,0, 0,0,0);
    -- choose hardware registration
    constant C_drawbar_registration: T_drawbar_table := C_drawbar_sinewave;

    constant C_wav_table_len: integer := 2**C_wav_addr_bits;
    type T_wav_table is array (0 to C_wav_table_len-1) of signed(C_wav_data_bits-1 downto 0);
    function F_wav_table(len: integer; drawbar_harmonic: T_drawbar_table; drawbar_registration: T_drawbar_table; bits: integer)
      return T_wav_table is
        variable i,j: integer;
        variable w: real; -- omega angular frequency
        variable sum: real; -- sum o wave functions
        variable normalize: real; -- normalize amplitude
        variable y: T_wav_table;
    begin
      normalize := 0.0;
      for j in 0 to drawbar_registration'length-1 loop
        normalize := normalize + real(2**drawbar_registration(j)/2);
      end loop;
      for i in 0 to len - 1 loop
        w := 2.0*3.141592653589793*real(i)/real(len); -- w = 2*pi*f
        sum := 0.0;
        for j in 0 to drawbar_registration'length-1 loop
          sum := sum + real(2**drawbar_registration(j)/2) * sin(real(drawbar_harmonic(j))*w);
        end loop;
        y(i) := to_signed(integer( sum/normalize * (2.0**real(bits-1)-1.0)), bits);
      end loop;
      return y;
    end F_wav_table;
    constant C_wav_table: T_wav_table := F_wav_table(C_wav_table_len, C_drawbar_harmonic, C_drawbar_registration, C_wav_data_bits); -- wave table initializer len, amplitude
    
    -- the data type and initializer for the frequencies table
    constant C_voice_table_len: integer := 2**C_voice_addr_bits;
    constant C_phase_const_bits: integer := C_shift_octave+C_voice_table_len/C_tones_per_octave+2; -- bits for phase accumulator addition constants
    type T_freq_table is array (0 to C_voice_table_len-1) of unsigned(C_phase_const_bits-1 downto 0);
    function F_freq_table(len: integer; temperament: T_meantone_temperament; tuning: real; tones_per_octave: integer; cents_per_octave: real; transpose:integer;  bits: integer)
      return T_freq_table is
        variable i, j: integer;
        variable octave, tone: integer;
        variable y: T_freq_table;
    begin
      for i in 0 to len - 1 loop
        j := (i + transpose) mod len;
        octave := i / tones_per_octave; -- octave number
        tone := i mod tones_per_octave; -- meantone number
        y(j) := to_unsigned(integer(2.0**(real(C_shift_octave+octave)+(temperament(tone)+tuning)/cents_per_octave)+0.5), bits);
      end loop;
      return y;
    end F_freq_table;
    -- wave table initializer len, freq, transposed by 1 to match hardware pipeline delay
    constant C_freq_table: T_freq_table := F_freq_table(C_voice_table_len, C_temperament, C_tuning_cents, C_tones_per_octave, C_cents_per_octave, 1, C_phase_const_bits);
    constant C_zc_low_freq_bits: integer := C_shift_octave + C_slow_octave;

    constant C_voice_max_volume: integer := 2**(C_voice_vol_bits-1)-1;
    constant C_voice_vol0: signed(C_voice_vol_bits-1 downto 0) := (others => '0');

    signal R_voice, R_voice_next, R_voice_prev, R_voice_written, S_pa_write_addr, S_freq_write_addr: std_logic_vector(C_voice_addr_bits-1 downto 0); -- currently processed voice, destination of increment
    signal S_freq_read_data, S_freq_write_data: std_logic_vector(C_phase_const_bits-1 downto 0);
    signal S_pa_read_data, S_pa_write_data: std_logic_vector(C_pa_data_bits-1 downto 0); -- current and next phase
    signal S_bus_freq_write: std_logic;
    signal S_voice_vol, R_voice_vol: signed(C_voice_vol_bits-1 downto 0);
    signal S_avv_read_data, R_avv_write_data: std_logic_vector(C_voice_vol_bits+1 downto 0); -- voice volume + 2 bits zero-cross tracking
    signal S_pvv_read_data, S_pvv_write_data: std_logic_vector(C_voice_vol_bits-1 downto 0); -- voice volume data written by the bus
    signal S_avv_read_signed_data, S_pvv_read_signed_data: signed(C_voice_vol_bits-1 downto 0);
    signal S_vv_read_addr, S_pvv_write_addr, R_avv_write_addr: std_logic_vector(C_voice_addr_bits-1 downto 0); -- voice volume addr
    signal S_bus_vol_write, S_avv_write, S_pvv_write: std_logic;
    signal S_wav_data, R_wav_data: signed(C_wav_data_bits-1 downto 0);
    signal S_wav_zero_cross: std_logic;
    signal S_multiplied, R_multiplied: signed(C_voice_vol_bits+C_wav_data_bits-1 downto 0);
    signal R_accu: signed(C_accu_bits-1 downto 0);
    signal R_output: signed(C_out_bits-1 downto 0); 
begin
    -- increment voice number that is currently processed
    process(clk)
    begin
      if rising_edge(clk) then
        R_voice <= R_voice + 1;
        R_voice_prev <= R_voice; -- 1 clock delay
      end if;
    end process;

    yes_bus_freq_write: if C_bus_freq_write generate
    S_bus_freq_write <= '1' when io_bus_write = '1' and io_ce = '1' and io_addr(0) = '1' and io_byte_sel = "1111" else '0';
    S_freq_write_addr <= R_voice_written; -- from updating voice volume
    S_freq_write_data <= io_bus_in(C_phase_const_bits-1 downto 0);
    bus_written_frequency: entity work.bram_true2p_1clk
    generic map
    (
        dual_port => true,
        addr_width => C_voice_addr_bits,
        data_width => C_phase_const_bits
    )
    port map
    (
        clk => clk,
        we_a => S_bus_freq_write,
        addr_a => S_freq_write_addr,
        data_in_a => S_freq_write_data,
        we_b => '0', -- always read
        addr_b => R_voice, -- valid data will appear 1 cycle after R_voice
        data_out_b => S_freq_read_data
    );
    -- increment the array of phase accumulators in the BRAM
    S_pa_write_data <= S_pa_read_data + S_freq_read_data;
    end generate;

    no_bus_freq_write: if not C_bus_freq_write generate
    -- increment the array of phase accumulators in the BRAM
    S_pa_write_data <= S_pa_read_data + to_integer(C_freq_table(conv_integer(R_voice))); -- next time base incremented with frequency
    end generate;

    -- next value is written on previous address to match register pipeline latency
    S_pa_write_addr <= R_voice_prev;
    phase_accumulator: entity work.bram_true2p_1clk
    generic map
    (
        dual_port => true,
        addr_width => C_voice_addr_bits,
        data_width => C_pa_data_bits
    )
    port map
    (
        clk => clk,
        we_a => '1', -- always write increments
        addr_a => S_pa_write_addr,
        data_in_a => S_pa_write_data,
        we_b => '0', -- always read
        addr_b => R_voice,
        data_out_b => S_pa_read_data
    );

    -- Voice Volume BRAM
    -- bus write, synth read from addressed BRAM the volume of current voice
    yes_test_keyboard: if C_keyboard generate
      S_pvv_write <= '1'; -- debug testing to generate some tone
      S_pvv_write_addr <= R_voice;
      S_pvv_write_data(C_voice_vol_bits-1 downto 0) <= std_logic_vector(to_unsigned(C_voice_max_volume, C_voice_vol_bits)) -- max volume
        when (conv_integer(R_voice) = 5*12+9  and keyboard(0) = '1') -- A4 (440 Hz)
        or   (conv_integer(R_voice) = 3*12+11 and keyboard(1) = '1') -- B2
        or   (conv_integer(R_voice) = 4*12+0  and keyboard(2) = '1') -- C3
        or   (conv_integer(R_voice) = 4*12+2  and keyboard(3) = '1') -- D3
        or   (conv_integer(R_voice) = 4*12+4  and keyboard(4) = '1') -- E3
        or   (conv_integer(R_voice) = 4*12+5  and keyboard(5) = '1') -- F3
        or   (conv_integer(R_voice) = 4*12+6  and keyboard(6) = '1') -- G3
        else (others => '0');
    end generate;
    no_test_keyboard: if not C_keyboard generate
      -- if CPU is not writing to the bus:
      -- detect volume zero-cross by tracking sign bit
      -- and update new volume value during the zero cross.
      -- for zer-cross update, we need to provide voice address
      -- previous than current voice address in order that the read data
      -- can be compared (fresh written volume = current volume) and
      -- written to the same address
      S_bus_vol_write <= '1' when io_bus_write = '1' and io_ce = '1' and io_addr(0) = '0' and io_byte_sel = "1111" else '0';
      S_pvv_write <= S_bus_vol_write;
      S_pvv_write_addr <= io_bus_in(C_voice_addr_bits-1 downto 0);
      S_pvv_write_data <= io_bus_in(C_voice_vol_bits+7 downto 8);
      process(clk)
      begin
        if rising_edge(clk) then
          if S_bus_vol_write = '1' then
            R_voice_written <= S_pvv_write_addr; -- remember last voice written for optional pitch bend
          end if;
        end if;
      end process;
    end generate;

    yes_zero_cross_detection: if C_zero_cross generate
    S_wav_zero_cross <= S_avv_read_data(C_voice_vol_bits+1) xor S_avv_read_data(C_voice_vol_bits);
    S_avv_read_signed_data <= to_signed(conv_integer(S_avv_read_data(C_voice_vol_bits-1 downto 0)), C_voice_vol_bits);
    S_pvv_read_signed_data <= to_signed(conv_integer(S_pvv_read_data), C_voice_vol_bits);
    process(clk)
    begin
      if rising_edge(clk) then
        R_avv_write_addr <= R_voice_prev;
        if S_wav_zero_cross = '0' then
          R_avv_write_data(C_voice_vol_bits-1 downto 0) <= S_avv_read_data(C_voice_vol_bits-1 downto 0); -- not zero cross: no change, write same as read
        elsif S_avv_read_signed_data(C_voice_vol_bits-1 downto C_vol_velocity_bits) = S_pvv_read_signed_data(C_voice_vol_bits-1 downto C_vol_velocity_bits) -- difference is small
        or conv_integer(S_freq_read_data(C_phase_const_bits-1 downto C_zc_low_freq_bits)) = 0 then  -- if high freq bits are 0, this is low freq and can change abruptly without click
          R_avv_write_data(C_voice_vol_bits-1 downto 0) <= S_pvv_read_data(C_voice_vol_bits-1 downto 0); -- abrupt change
        elsif S_avv_read_signed_data < S_pvv_read_signed_data then
          R_avv_write_data(C_voice_vol_bits-1 downto C_vol_velocity_bits) <= S_avv_read_data(C_voice_vol_bits-1 downto C_vol_velocity_bits)+1; -- increment avv towardes pvv
        else
          R_avv_write_data(C_voice_vol_bits-1 downto C_vol_velocity_bits) <= S_avv_read_data(C_voice_vol_bits-1 downto C_vol_velocity_bits)-1; -- decrement avv towards pvv
        end if;
        R_avv_write_data(C_voice_vol_bits+1) <= S_avv_read_data(C_voice_vol_bits); -- shift sign bit up
        R_avv_write_data(C_voice_vol_bits) <= S_wav_data(C_wav_data_bits-1); -- sign bit of the wave
      end if;
    end process;
    bus_written_voice_volume: entity work.bram_true2p_1clk
    generic map
    (
        dual_port => true,
        addr_width => C_voice_addr_bits,
        data_width => C_voice_vol_bits
    )
    port map
    (
        clk => clk,
        we_a => S_pvv_write,
        addr_a => S_pvv_write_addr,
        data_in_a => S_pvv_write_data,
        we_b => '0', -- always read 
        addr_b => S_vv_read_addr,
        data_out_b => S_pvv_read_data
    );
    S_avv_write <= '1';
    end generate;

    no_zero_cross_detection: if not C_zero_cross generate
      S_avv_write <= S_pvv_write;
      -- misnomer warning: in this case, R_* are signals, not registers
      R_avv_write_addr <= S_pvv_write_addr;
      R_avv_write_data(C_voice_vol_bits-1 downto 0) <= S_pvv_write_data;
    end generate;

    S_vv_read_addr <= R_voice;
    S_voice_vol <= to_signed(conv_integer(S_avv_read_data), C_voice_vol_bits);
    active_voice_volume: entity work.bram_true2p_1clk
    generic map
    (
        dual_port => true,
        addr_width => C_voice_addr_bits,
        data_width => C_voice_vol_bits+2 -- 2 extra bits for vol sign bit tracking
    )
    port map
    (
        clk => clk,
        we_a => S_avv_write,
        addr_a => R_avv_write_addr,
        data_in_a => R_avv_write_data,
        we_b => '0', -- always read 
        addr_b => S_vv_read_addr,
        data_out_b => S_avv_read_data
    );

    -- waveform data reading (delayed 1 clock, address R_voice-1)
    S_wav_data <= C_wav_table(conv_integer(S_pa_read_data(C_pa_data_bits-1 downto C_pa_data_bits-C_wav_addr_bits)));

    yes_multiplier_normal: if C_multiplier and not C_multiplier_sign_fix generate
      S_multiplied <= R_voice_vol * R_wav_data;
    end generate;
    yes_multiplier_sign_fix: if C_multiplier and C_multiplier_sign_fix generate
      -- hopfully this expression will optimize down to a single multiplier
      S_multiplied <= -(R_voice_vol * (-R_wav_data)) when R_wav_data < 0 else R_voice_vol * R_wav_data;
    end generate;
    no_multiplier: if not C_multiplier generate
      S_multiplied <= (others => '0') when R_voice_vol = 0 else R_wav_data & C_voice_vol0;
    end generate;

    -- multiply, store result to register and add register to accumulator
    process(clk)
    begin
      if rising_edge(clk) then
        -- S_voice_vol must be signed, then max amplitude is 2x smaller
        -- consider this when designing R_accu large enough to avoid clipping
        -- registering inputs to the multiplier reduces noise at low volumes
        R_voice_vol <= S_voice_vol;
        R_wav_data <= S_wav_data;
        R_multiplied <= S_multiplied; -- signed R_voice_vol * R_wav_data, with optional synthesys bug fixes
        if conv_integer(R_voice) = 3 then -- output-ready R_accu appears with 3 clocks delay
          R_output <= R_accu(C_accu_bits-1 downto C_accu_bits-C_out_bits);
          R_accu <= (others => '0'); -- reset accumulator
        else
          R_accu <= R_accu + R_multiplied;
        end if;
      end if;
    end process;

    pcm_out <= R_output(R_output'length-1 downto R_output'length-pcm_out'length);
end;

-- todo
-- [x] shift volume by 1 place, the lowest tone (now 127) should be tone 0
-- [x] apply 12 meantone temperament using 1200 cents table
-- [x] fix tuning math to work for other than 128 voices
-- [ ] given the max cents error calculate number of phase accumulator bits
-- [x] f32c CPU bus interface to alter voice amplitudes
-- [x] bus interface to upload waveforms (or a way of changing drawbar registrations)
-- [x] zero cross volume updates
-- [ ] preload BRAM with some sane data (keyboard won't work with bus freq update enabled)
-- [ ] additional bit in the volume for abrupt change instead of slow transition, currently sign bit is used
