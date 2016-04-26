-- (c)2016 EMARD
-- LICENSE=BSD

-- takes VGA input and prepares output for LCD LVDS output drivers
-- clk_pixel = 36 MHz for 1280x768
-- clk_shift = 7x clk_pixel = 252 MHz
-- currently only SDR mode supported (no DDR) -- use only bit 0 from output

library IEEE;
use IEEE.std_logic_1164.ALL;

entity vga2lcd is
	generic
	(
		C_depth: integer := 8
	);
	port
	(
		clk_pixel      : in std_logic; -- VGA pixel clock, 36 MHz for 1280x768
		clk_shift      : in std_logic; -- SDR: 7x clk_pixel, in phase with clk_pixel
		in_red         : in std_logic_vector(C_depth-1 downto 0);
		in_green       : in std_logic_vector(C_depth-1 downto 0);
		in_blue        : in std_logic_vector(C_depth-1 downto 0);
		in_blank       : in std_logic;
		in_hsync       : in std_logic;
		in_vsync       : in std_logic;
		out_red_green  : out std_logic_vector(1 downto 0);
		out_green_blue : out std_logic_vector(1 downto 0);
		out_blue_sync  : out std_logic_vector(1 downto 0);
		out_clock      : out std_logic_vector(1 downto 0)
	);
end vga2lcd;

architecture Behavioral of vga2lcd is
	signal latched_red_green, latched_green_blue, latched_blue_sync: std_logic_vector(6 downto 0) := (others => '0');
	signal shift_red_green, shift_green_blue, shift_blue_sync: std_logic_vector(6 downto 0) := (others => '0');
	signal shift_clock: std_logic_vector(6 downto 0) := "1100011"; -- this is per spec, the clock

	signal red_d  : std_logic_vector(7 downto 0);
	signal green_d: std_logic_vector(7 downto 0);
	signal blue_d : std_logic_vector(7 downto 0);
begin
	red_d  (7 downto 8-C_depth) <= in_red  (C_depth-1 downto 0);
	green_d(7 downto 8-C_depth) <= in_green(C_depth-1 downto 0);
	blue_d (7 downto 8-C_depth) <= in_blue (C_depth-1 downto 0);

	-- fill vacant low bits with value repeated (so min/max value is always 0 or 255)
	G_bits: for i in 8-C_depth-1 downto 0 generate
		red_d (i)  <= in_red  ((C_depth-1-i) MOD C_depth);
		green_d(i) <= in_green((C_depth-1-i) MOD C_depth);
		blue_d (i) <= in_blue ((C_depth-1-i) MOD C_depth);
	end generate;
	
	process(clk_pixel)
	begin
		if rising_edge(clk_pixel) then 
			latched_red_green  <= red_d(5 downto 0) & green_d(0);
			latched_green_blue <= green_d(5 downto 1) & blue_d(1 downto 0);
			latched_blue_sync  <= blue_d(5 downto 2) & in_hsync & in_vsync & in_blank;
		end if;
	end process;

	process(clk_shift)
	begin
	  if rising_edge(clk_shift) then
		if shift_clock(1 downto 0) = "01" then
			shift_red_green  <= latched_red_green;
			shift_green_blue <= latched_green_blue;
			shift_blue_sync  <= latched_blue_sync;
		else
			shift_red_green  <= "0" & shift_red_green (6 downto 1);
			shift_green_blue <= "0" & shift_green_blue(6 downto 1);
			shift_blue_sync  <= "0" & shift_blue_sync (6 downto 1);
		end if;
		shift_clock <= shift_clock(0) & shift_clock(6 downto 1);
	  end if;
	end process;

	-- use only bit 0 from each out_* channel 
	out_red_green  <= shift_red_green(1 downto 0);
	out_green_blue <= shift_green_blue(1 downto 0);
	out_blue_sync  <= shift_blue_sync(1 downto 0);
	out_clock      <= shift_clock(1 downto 0);

end Behavioral;
