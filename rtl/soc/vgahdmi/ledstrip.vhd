-- Copyright (c) 2016 Davor Jadrijevic
-- All rights reserved.

-- rotating LED strip video generation
-- uses persistence of vision effect

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

library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
-- use ieee.numeric_std.all;

entity ledstrip is
  generic (
    C_clk_Hz: integer; -- Hz CPU core frequency
    C_addr_bits: integer := 2; -- don't touch: number of address bits for the registers
    C_bits: integer := 32; -- number of bits in the registers
    -- which address is external RAM mapped to
    C_xram_base: std_logic_vector(31 downto 28) := x"8"; -- x"8" maps RAM to 0x80000000
    -- LED strip ws2812 POV simple 144x480 bitmap only
    C_ledstrip_full_circle: integer := 100; -- count of pulses per full circle of rotation
    C_width: integer; -- example 72 strip length
    C_height: integer; -- example 50 number of scan lines
    C_data_width: integer range 8 to 32 := 8;
    C_addr_width: integer := 11
  );
  port (
    -- interface to CPU for iomap registers
    ce, clk: in std_logic;
    bus_write: in std_logic;
    addr: in std_logic_vector(C_addr_bits-1 downto 0); -- address max 8 registers of 32-bit
    byte_sel: in std_logic_vector(3 downto 0);
    bus_in: in std_logic_vector(31 downto 0);
    bus_out: out std_logic_vector(31 downto 0);

    -- video frame interrupt output
    video_frame: out std_logic;

    -- interface to multiport RAM arbiter
    video_addr_strobe: out std_logic; -- FIFO requests to read from external RAM
    video_addr: out std_logic_vector(29 downto 2); -- address where to read
    video_data_ready: in std_logic; -- RAM responds data ready -> FIFO should read
    from_xram: in std_logic_vector(31 downto 0); -- data from external RAM

    -- interface to led strip POV hardware
    rotation_sensor: in std_logic; -- input which produces C_ledstrip_full_circle pulses per full rotation
    ledstrip_out: out std_logic -- the bit connected to data input of led strip
  );
end ledstrip;

architecture behavioral of ledstrip is
    constant C_registers: integer := 4; -- total number of ledstrip registers

    -- normal registers
    -- type gpio_reg_type  is std_logic_vector(C_bits-1 downto 0);
    type gpio_regs_type is array (C_registers-1 downto 0) of std_logic_vector(C_bits-1 downto 0);
    signal R: gpio_regs_type; -- register access from mmapped I/O

    -- *** REGISTERS ***
    -- named constants for gpio registers
    -- this improves code readability
    -- and provides flexible register (re)numbering
    constant C_base:       integer   := 0; -- base address for the video
    constant C_capture:    integer   := 1; -- output cepture line number and bit number, sampledd on each full rotation
    constant C_counter:    integer   := 2; -- output motor pulse counter

    -- internal signals
    signal video_data, video_data_from_fifo: std_logic_vector(31 downto 0);
    signal vga_fetch_next, S_vga_fetch_enabled: std_logic; -- video module requests next data from fifo
    signal S_vga_active_enabled: std_logic;
    signal S_vga_enable: std_logic;
    signal S_ledstrip_active: std_logic;
    signal S_ledstrip_pixel_data: std_logic_vector(23 downto 0) := (others => '0');
    signal S_ledstrip_counter, S_ledstrip_counter2: std_logic_vector(15 downto 0);
    signal S_ledstrip_line, S_ledstrip_bit: std_logic_vector(15 downto 0);
    signal S_ledstrip_wraparound: std_logic;
    signal R_ledstrip_wraparound_shift: std_logic_vector(2 downto 0);
    signal R_ledstrip_capture: std_logic_vector(31 downto 0);
begin
    -- CPU core reads registers
    with conv_integer(addr) select
      bus_out <= 
          ext(R_ledstrip_capture, 32)
            when C_capture,
          ext(S_ledstrip_counter2, 32)
            when C_counter,
          ext(R(conv_integer(addr)),32)
            when others;

    -- CPU core writes registers (code example, unused)
    writereg: for i in 0 to C_bits/8-1 generate
      process(clk)
      begin
        if rising_edge(clk) then
          if byte_sel(i) = '1' then
            if ce = '1' and bus_write = '1' then
              R(conv_integer(addr))(8*i+7 downto 8*i) <= bus_in(8*i+7 downto 8*i);
            end if;
          end if;
        end if;
      end process;
    end generate;

    -- pulse counter from the motor that rotates
    -- the led strip
    ledstrip_counter: entity work.pulse_counter
    generic map
    (
      C_bits => 16,
      C_wraparound => C_ledstrip_full_circle -- number of pulses per rotation
    )
    port map
    (
      clk => clk,
      pulse => rotation_sensor,
      count => S_ledstrip_counter
    );

    ledstrip_counter_nowrap: entity work.pulse_counter
    generic map
    (
      C_bits => 16,
      C_wraparound => 65536 -- number of pulses per rotation
    )
    port map
    (
      clk => clk,
      pulse => rotation_sensor,
      count => S_ledstrip_counter2
    );

    -- condition which detects full rotation cycle
    S_ledstrip_wraparound <= '1' when S_ledstrip_counter = 0 else '0'; 

    -- counter capture as feedback for synchronizer
    -- motor power should be adjusted to keep this
    -- value fluctuate around arbitrary constant value 
    -- (0 for example), which will indicate a sync condition
    -- when rotation speed is locked to the video frame rate
    process(clk)
    begin
      if rising_edge(clk) then
        -- the rising edge synchronizer detector
        R_ledstrip_wraparound_shift <= S_ledstrip_wraparound & R_ledstrip_wraparound_shift(2 downto 1);
        -- on the rising edge capture
        if R_ledstrip_wraparound_shift(0) = '0' and R_ledstrip_wraparound_shift(1) = '1' then
          R_ledstrip_capture <= S_ledstrip_line & S_ledstrip_bit;
        end if;
      end if;
    end process;
        
    -- expand RRRGGGBB to 24-bit true color for led strip
    -- note that due to slow PWM on individual ledstrip leds
    -- true color is not useable for POV
    S_ledstrip_pixel_data(15 downto 13) <= video_data_from_fifo(7 downto 5); -- R
    S_ledstrip_pixel_data(12 downto 8)  <= (others => video_data_from_fifo(5)); -- R lsb expand
    S_ledstrip_pixel_data(23 downto 21) <= video_data_from_fifo(4 downto 2); -- G
    S_ledstrip_pixel_data(20 downto 16) <= (others => video_data_from_fifo(2)); -- G lsb expand
    S_ledstrip_pixel_data(7  downto 6)  <= video_data_from_fifo(1 downto 0); -- B
    S_ledstrip_pixel_data(5  downto 0)  <= (others => video_data_from_fifo(0)); -- B lsb expand

    led_strip: entity work.ws2812b
    generic map
    (
      -- C_clk_Hz => 25000000,
      C_clk_Hz => C_clk_Hz, -- module timing needs to know clk freq in Hz
      --C_t0h => 325, -- ns
      --C_t1h => 650, -- ns
      C_tbit => 1100, -- ns
      C_tres => 51, -- us
      C_free_running => false,
      C_striplen => C_width,
      C_lines_per_frame => C_height
    )
    port map
    (
      clk => clk,
      fetch_next => vga_fetch_next,
      external_trigger => rotation_sensor,
      active => S_ledstrip_active,
      input_data => S_ledstrip_pixel_data,
      line => S_ledstrip_line, -- output line counter
      bit => S_ledstrip_bit, -- output bit counter
      dout => ledstrip_out
    );

    S_vga_enable <= '1' when R(C_base)(31 downto 28) = C_xram_base else '0';
    S_vga_fetch_enabled <= S_vga_enable and vga_fetch_next; -- drain fifo into display
    S_vga_active_enabled <= S_vga_enable and S_ledstrip_active; -- frame active, pre-fill fifo
    -- S_vga_fetch_enabled <= S_vga_enable and vga_fetch_next; -- drain fifo into display
    -- S_vga_active_enabled <= S_vga_enable; -- frame active, pre-fill fifo
    ledstrip_comp_fifo: entity work.compositing2_fifo
    generic map (
      C_width => C_width,
      C_height => C_height,
      C_data_width => C_data_width,
      C_addr_width => C_addr_width
    )
    port map (
      clk => clk,
      clk_pixel => clk,
      addr_strobe => video_addr_strobe,
      addr_out => video_addr,
      data_ready => video_data_ready, -- data valid for read acknowledge from RAM
      data_in => video_data, -- from SDRAM or BRAM
      -- data_in => x"00000001", -- test pattern vertical lines
      -- data_in(7 downto 0) => video_addr(9 downto 2), -- test if address is in sync with video frame
      -- data_in(31 downto 8) => (others => '0'),
      base_addr => R(C_base)(29 downto 2),
      active => S_vga_active_enabled,
      frame => video_frame,
      data_out => video_data_from_fifo(C_data_width-1 downto 0),
      fetch_next => S_vga_fetch_enabled
    );
    video_data <= from_xram; -- pulls content data from xram
end;
