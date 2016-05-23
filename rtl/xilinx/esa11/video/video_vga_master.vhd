-- -----------------------------------------------------------------------
--
-- Syntiac VHDL support files.
--
-- -----------------------------------------------------------------------
-- Copyright 2005-2009 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com
--
-- -----------------------------------------------------------------------
--
-- VGA Video sync and timing generator
--
-- -----------------------------------------------------------------------
--
-- clk        - video clock
-- clkDiv     - Clock divider. 0=clk, 1=clk/2, 2=clk/3 ... 15=clk/16
-- hSync      - Horizontal sync (sync polarity is set with hSyncPol)
-- vSync      - Vertical sync (sync polarity is set with vSyncPol)
-- endOfPixel - Pixel clock is high each (clkDiv+1) clocks.
--              When clkDiv=0 is stays high continuously
-- endOfLine  - High when the last pixel on the current line is displayed.
-- endOfFrame - High when the last pixel on the last line is displayed.
-- currentX   - X coordinate of current pixel.
-- currentY   - Y coordinate of current pixel.
--
-- -----------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- -----------------------------------------------------------------------

entity video_vga_master is
	generic (
		clkDivBits : integer := 4
	);
	port (
-- System
		clk : in std_logic;
		clkDiv : in unsigned((clkDivBits-1) downto 0);

-- Sync outputs
		hSync : out std_logic;
		vSync : out std_logic;

-- Control outputs
		endOfPixel : out std_logic;
		endOfLine : out std_logic;
		endOfFrame : out std_logic;
		currentX : out unsigned(11 downto 0);
		currentY : out unsigned(11 downto 0);

-- Configuration
		hSyncPol : in std_logic := '1';
		vSyncPol : in std_logic := '1';
		xSize : in unsigned(11 downto 0);
		ySize : in unsigned(11 downto 0);
		xSyncFr : in unsigned(11 downto 0);
		xSyncTo : in unsigned(11 downto 0);
		ySyncFr : in unsigned(11 downto 0);
		ySyncTo : in unsigned(11 downto 0)
	);
end entity;

-- -----------------------------------------------------------------------

architecture rtl of video_vga_master is
	signal clkDivCnt : unsigned(clkDiv'high downto 0) := (others => '0');
--	signal xCounter : unsigned(11 downto 0) := (others => '0');
--	signal yCounter : unsigned(11 downto 0) := (others => '0');
	signal xCounter : unsigned(11 downto 0) := to_unsigned(0, 12);
	signal yCounter : unsigned(11 downto 0) := to_unsigned(499, 12); -- 499 13
	signal newPixel : std_logic := '0';
	signal newLine : std_logic := '0';
begin
-- -----------------------------------------------------------------------
-- Copy of local signals as outputs (for vga-slaves)
	currentX <= xCounter;
	currentY <= yCounter;
	endOfPixel <= newPixel;
	endOfLine <= newLine;

-- -----------------------------------------------------------------------
-- X & Y counters
	process(clk)
	begin
		if rising_edge(clk) then
			newLine <= '0';
			endOfFrame <= '0';
		
			if newPixel = '1' then
				if xCounter >= xSize-1 then
					newLine <= '1';
					xCounter <= (others => '0');
					
					yCounter <= yCounter + 1;
					if yCounter >= ySize then
						endOfFrame <= '1';
						yCounter <= (others => '0');
					end if;
				else
					xCounter <= xCounter + 1;
				end if;
			end if;
		end if;
	end process;

-- -----------------------------------------------------------------------
-- Clock divider
	process(clk)
	begin
		if rising_edge(clk) then
			newPixel <= '0';
			clkDivCnt <= clkDivCnt + 1;
			if clkDivCnt = clkDiv then
				clkDivCnt <= (others => '0');
				newPixel <= '1';
			end if;
		end if;
	end process;

-- -----------------------------------------------------------------------
-- hSync
	process(clk)
	begin
		if rising_edge(clk) then
			hSync <= not hSyncPol;
			if xCounter >= xSyncFr
			and xCounter < xSyncTo then
				hSync <= hSyncPol;
			end if;
		end if;
	end process;

-- -----------------------------------------------------------------------
-- vSync
	process(clk)
	begin
		if rising_edge(clk) then
			vSync <= not vSyncPol;
			if yCounter >= ySyncFr
			and yCounter < ySyncTo then
				vSync <= vSyncPol;
			end if;
		end if;
	end process;
end architecture;
