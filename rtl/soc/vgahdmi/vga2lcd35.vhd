-- (c)2016 EMARD
-- LICENSE=BSD

-- Takes VGA-like digital input and prepares output for small LCDs (works on 3.5" 320x240).
-- On each 19.2 MHz clock cycle one of R,G,B is send as 8-bit parallel bus data.
-- clk_pixel = 19.2 MHz for 320x240 but real pixel clock is actually 19.2/3 = 6.4 MHz

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

entity vga2lcd35 is
	generic
	(
		C_depth: integer := 8 -- input/output pixel depth (bus width for each R,G,B channel)
	);
	port
	(
		clk_pixel      : in std_logic; -- Pixel clock, 6.4 MHz for 320x240
		clk_shift      : in std_logic; -- Pixel shift clock, 19.2 MHz for 320x240
		in_red         : in std_logic_vector(C_depth-1 downto 0);
		in_green       : in std_logic_vector(C_depth-1 downto 0);
		in_blue        : in std_logic_vector(C_depth-1 downto 0);
		in_hsync       : in std_logic; -- resets clk_shift from clk_pixel domain
		out_rgb        : out std_logic_vector(C_depth-1 downto 0)
	);
end;

architecture Behavioral of vga2lcd35 is
	signal latched_rgb, shift_rgb: std_logic_vector(C_depth*3-1 downto 0) := (others => '0');
	constant C_shift_clock_initial: std_logic_vector(2 downto 0) := "100"; -- this is per spec, the clock
	signal R_hsync: std_logic_vector(1 downto 0); -- hsync edge tracker
	signal shift_clock: std_logic_vector(2 downto 0) := C_shift_clock_initial;
	signal R_shift_clock_off_sync: std_logic := '0';
	signal R_shift_clock_synchronizer: std_logic_vector(2 downto 0) := (others => '0');
begin
	process(clk_pixel)
	begin
		if rising_edge(clk_pixel) then 
			latched_rgb <= in_blue & in_green & in_red;
		end if;
	end process;

	process(clk_shift)
	begin
	  if rising_edge(clk_shift) then
		if shift_clock = C_shift_clock_initial then
			shift_rgb <= latched_rgb;
		else
			shift_rgb <= shift_rgb(C_depth-1 downto 0) & shift_rgb(C_depth*3-1 downto C_depth);
		end if;
		-- NOTE clock domain crossing: in_hsync is clk_pixel synchronous
		R_hsync <= in_hsync & R_hsync(1); -- downshift
		if R_hsync = "10" then -- rising edge
			shift_clock <= C_shift_clock_initial;
		else
			shift_clock <= shift_clock(0) & shift_clock(2 downto 1);
		end if;
	  end if;
	end process;
	out_rgb <= shift_rgb(C_depth-1 downto 0);
end Behavioral;
