library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ws2812b is
  generic
  (
    C_clk_Hz: integer := 25000000; -- Hz
    C_channels: integer range 1 to 2 := 1; -- number of output channels (not yet implemented)
    C_striplen: integer; -- channel line width: number of LED pixels in the strip example 72
    C_lines_per_frame: integer; -- number of strip lines per frame to flash example 50
    C_free_running: boolean := true; -- false: external line trigger
    -- timing setup by datasheet (unequal 0/1)
    --  t0h 350+-150 ns, t0l 800+-150 ns  ----_________
    --  t1h 700+-150 ns, t1l 600+-150 ns  --------_____
    --  tres > 50 us
    -- simplified timing within tolerance (equal 0/1)
    C_t0h: integer := 350; -- ns
    C_t1h: integer := 700; -- ns
    C_tbit: integer := 1250; -- ns
    C_tres: integer := 51; -- us
    C_bpp: integer := 24 -- bits per LED pixel (don't touch)
  );
  port
  (
    clk: in std_Logic;
    active, fetch_next: out std_logic;
    external_trigger: in std_logic := '0'; -- external line trigger
    input_data: in std_logic_vector(23 downto 0); -- 24bpp input
    line: out std_logic_vector(15 downto 0); -- current line counter
    bit: out std_logic_vector(15 downto 0); -- current bit counter
    dout: out std_logic
  );
end ws2812b;

architecture Behavioral of ws2812b is
  -- constants to convert nanoseconds, microseconds
  constant C_ns: integer := 1000000000;
  constant C_us: integer := 1000000;

  signal count         : integer range 0 to C_clk_Hz*C_tres/C_us; -- protocol timer
  signal data          : std_logic_vector(C_bpp-1 downto 0) := (others => '0');
  signal bit_count     : integer range 0 to C_bpp*C_striplen-1;
  signal line_count    : integer range 0 to C_lines_per_frame-1;
  signal pixel_bit     : integer range 0 to C_bpp-1;
  signal puls_shift    : std_logic_vector(2 downto 0); -- external trigger rising edge detector
  signal state         : integer range 0 to 2; -- protocol state
begin
  process(clk)
  begin
    if rising_edge(clk) then
      puls_shift <= external_trigger & puls_shift(2 downto 1);
      if count /= C_clk_Hz*C_tres/C_us then
        count <= count + 1; -- sequential, changed later
      end if;
      if count = C_clk_Hz*C_t0h/C_ns then
        if pixel_bit = 0 then
          data <= input_data;
        end if;
        -- state = 0, dout = 1
        -- prepare to send bit
        state <= 1;  -- jump to send bit
      elsif count = C_clk_Hz*C_t1h/C_ns then
        -- state = 1, dout = bit
        -- sends the bit
        state <= 2; -- jump to shift or load
      elsif count = C_clk_Hz*C_tbit/C_ns then
        -- state = 2, dout = 0
        -- send finished, any more bits to send?
        if bit_count /= 0 then
          -- yes, shift data (new bit)
          data <= data(C_bpp-2 downto 0) & '0';
          bit_count <= bit_count - 1;
          if pixel_bit = C_bpp-1 then
            pixel_bit <= 0;
          else
            pixel_bit <= pixel_bit+1;
          end if;
          -- restart protocol
          count <= 0;
          state <= 0;
        end if;
      elsif count = C_clk_Hz*C_tbit/C_ns + 1 then
        -- state = 2, strip line is finished now
        -- starting reset cycle
        -- if all strip lines are finished, de-activate rom now
        if line_count /= C_lines_per_frame-1 then
          line_count <= line_count+1;
        else
          line_count <= 0;
          active <= '0'; -- output de-activate frame, fifo will reset
        end if;
      -- shortens inactive period, fifo will refill early ahead of time
      --elsif count = C_clk_Hz*C_tbit/C_ns + 6 then
      --  active <= '1';
      elsif count = C_clk_Hz*C_tres/C_us then
        -- state = 2, dout = 0
        -- long dout=0 resets the protocol
        -- set address from where to load new data
        if C_free_running or (puls_shift(0)='0' and puls_shift(1)='1') then
          bit_count <= C_bpp*C_striplen-1;
          pixel_bit <= 0;
          count <= 0;
          state <= 0;
          active <= '1'; -- output active (frame starts)
        --else
        --  count <= C_clk_Hz*C_tres/C_us; -- stay here until external trigger
        end if;
      end if;
    end if;
  end process;

  -- when last bit from pixel is sent
  -- at the end of bit time
  -- we request fetch of the next pixel data
  fetch_next <= '1' when count = C_clk_Hz*C_tbit/C_ns and pixel_bit = C_bpp-1 else '0';

  dout <= '1'        when state = 0
    else data(C_bpp-1) when state = 1
    else '0';

  -- output internal line and bit counters
  line <= std_logic_vector(to_unsigned(line_count,16));
  bit <= std_logic_vector(to_unsigned(bit_count,16));

end Behavioral;
