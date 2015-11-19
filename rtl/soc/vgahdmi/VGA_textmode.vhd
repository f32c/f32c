-- VGA_textmode.vhd
--
-- Copyright (c) 2015 Ken Jordan
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

-- VGA/DVI/HDMI color text mode with optional SRAM/SDRAM bitmap

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VGA_textmode is
	Generic (
		C_vgatext_mode: integer := 0;				-- 0=640x480, 1=800x600 (you must still provide proper pixel clock for mode)
		C_vgatext_bits: integer := 2;				-- bits per R G B for output (1 to 8)
		C_vgatext_text: boolean := true;			-- enable text generation
		C_vgatext_text_fifo: boolean := false;		-- true to use videofifo, else SRAM port
		C_vgatext_font_height: integer := 8;		-- font data height 8 (doubled vertically) or 16
		C_vgatext_font_depth: integer := 7;			-- font char bits (7=128, 8=256 characters)
		C_vgatext_char_height: integer := 19;		-- font cell height (text lines will be vmode(C_vgatext_mode).visible_height / C_vgatext_char_height rounded down, 19=25 lines on 480p)
		C_vgatext_monochrome: boolean := false;		-- 4K ram mode (one color byte for entire screen)
		C_vgatext_palette: boolean := false;		-- false=fixed 16 color VGA palette or 16 writable 24-bit palette registers
		C_vgatext_bitmap: boolean := false;			-- true for bitmap from sram/sdram
		C_vgatext_bitmap_fifo: boolean := false;	-- true to use videofifo, else SRAM port
		C_vgatext_bitmap_depth: integer := 1		-- bits per pixel (1, 2, 4, 8)
	);
	Port (
		clk:		in std_logic;
		ce:			in std_logic;
		bus_write:	in std_logic;
		addr:		in std_logic_vector(2 downto 0);		-- address space for 8 registers
		byte_sel:	in std_logic_vector(3 downto 0);
		bus_in:		in std_logic_vector(31 downto 0);
		bus_out:	out std_logic_vector(31 downto 0);

		clk_pixel:	in std_logic;							-- VGA pixel clock (25MHz)

		text_addr:	out std_logic_vector(29 downto 2); 		-- text+color buffer fifo start address
		text_data:	in std_logic_vector(31 downto 0);		-- data from text+color fifo
		text_strobe:	out std_logic;						-- fetch next data from fifo
		text_rewind:	out std_logic;						-- "rewind" fifo to replay last scan-line data

		bram_addr:	out std_logic_vector(12 downto 2); 		-- font (or text+color) bram address
		bram_data:	in std_logic_vector(31 downto 0);		-- font (or text+color) bram data

		bitmap_addr:	out std_logic_vector(29 downto 2);	-- bitmap buffer (start address with fifo)
		bitmap_data:	in std_logic_vector(31 downto 0);	-- from sram or fifo
		bitmap_strobe:	out std_logic;						-- request data (or fetch next with fifo)
		bitmap_ready:	in std_logic;						-- sram data ready (not used with fifo)

		hsync:	out std_logic;
		vsync:	out std_logic;
		R:		out STD_LOGIC_VECTOR (7 downto 8-C_vgatext_bits);
		G:		out STD_LOGIC_VECTOR (7 downto 8-C_vgatext_bits);
		B:		out STD_LOGIC_VECTOR (7 downto 8-C_vgatext_bits);
		nblank:	out std_logic
	);
end VGA_textmode;

architecture Behavioral of VGA_textmode is
	type video_mode_t is
	record
		pixel_clock_Hz:								integer;
		visible_width,	visible_height:				integer;
		h_front_porch, h_sync_pulse, h_back_porch:	integer;
		v_front_porch, v_sync_pulse, v_back_porch:	integer;
		h_sync_polarity, v_sync_polarity:			std_logic;
	end record;
	type video_mode_array_t is array (0 to 1) of video_mode_t;
	constant vmode: video_mode_array_t :=
	(
		(	pixel_clock_Hz	=>	25000000,	-- actually 25175000, but 25Mhz is more common with FPGAs (and works on virtually all monitors)
			visible_width	=>	640,
			visible_height	=>	480,
			h_front_porch	=>	16,
			h_sync_pulse	=>	96,
			h_back_porch	=>	48,
			v_front_porch	=>	10,
			v_sync_pulse	=>	2,
			v_back_porch	=>	33,
			h_sync_polarity	=>	'0',
			v_sync_polarity	=>	'0'
		),
		(	pixel_clock_Hz	=>	40000000,
			visible_width	=>	800,
			visible_height	=>	600,
			h_front_porch	=>	40,
			h_sync_pulse	=>	128,
			h_back_porch	=>	88,
			v_front_porch	=>	1,
			v_sync_pulse	=>	4,
			v_back_porch	=>	23,
			h_sync_polarity	=>	'1',
			v_sync_polarity	=>	'1'
		)
	);

	constant C_total_width:		integer			:= (vmode(C_vgatext_mode).h_front_porch+vmode(C_vgatext_mode).h_sync_pulse+vmode(C_vgatext_mode).h_back_porch+vmode(C_vgatext_mode).visible_width);
	constant C_total_height:	integer			:= (vmode(C_vgatext_mode).v_front_porch+vmode(C_vgatext_mode).v_sync_pulse+vmode(C_vgatext_mode).v_back_porch+vmode(C_vgatext_mode).visible_height);
	constant C_char_width:		integer			:= 8;

	-- constants for the VGA textmode registers
	constant C_cntrl:		std_logic_vector		:= "000";	-- 0 [rw 8-bit]	 (31) enable, (30) text enable, (29)=bitmap enable, (28)=cursor enable, (20-16)=frame count, (15-8)=cursory, (7-0)=cursorx
	constant C_bmap_addr:	std_logic_vector		:= "001";	-- 1 [rw 32-bit] address in SRAM/SDRAM for bitmap start
	constant C_bmap_color:	std_logic_vector		:= "010";	-- 2 [-w 32-bit] (23 downto 0)=0xRRGGBB 24-bit color for bitmap
	constant C_palette_reg:	std_logic_vector		:= "011";	-- 3 [-w 32-bit] (27 down 24)=palette reg, (23 downto 0)=0xRRGGBB 24-bit color
	constant C_text_addr:	std_logic_vector		:= "100";	-- 4 [rw 32-bit] address in SRAM/SDRAM for text+color start
	constant C_mem_addr:	std_logic_vector		:= "101";	-- 5 [-w 32-bit] (23 downto 0)=0xRRGGBB 24-bit color for bitmap
	constant C_mem_data:	std_logic_vector		:= "110";	-- 6 [-w 32-bit] (27 down 24)=palette reg, (23 downto 0)=0xRRGGBB 24-bit color

	signal	hcount	:	signed(11 downto 0);			-- horizontal pixel counter (negative is off visible area)
	signal	vcount	:	signed(11 downto 0);			-- vertical pixel counter (negative is off visible area)
	signal	fcount	:	unsigned(3 downto 0);			-- frame counter (incremented once per frame)

	signal	cntrl_r	:	std_logic_vector(3 downto 0) := "1000";	-- (3)=enable, (2)=text enable, (1)=bitmap enable, (0)=cursor enable
	signal	curx_r	:	unsigned(7 downto 0) := (others => '0');	-- cursor X position
	signal	cury_r	:	unsigned(7 downto 0) := (others => '0');	-- cursor Y position
	signal	monoflag:	std_logic;
	signal	bitmapflag:	std_logic;
	signal	resolution:	std_logic_vector(1 downto 0);
	signal	colors:		std_logic_vector(2 downto 0);

	signal	r_r		:	std_logic_vector(7 downto 0);	-- registered outputs from clocked process
	signal	g_r		:	std_logic_vector(7 downto 0);	-- registered outputs from clocked process
	signal	b_r		:	std_logic_vector(7 downto 0);	-- registered outputs from clocked process
	signal	hsync_r	:	std_logic;
	signal	vsync_r	:	std_logic;
	signal	visible_r :	std_logic;						-- 1 if in visible area

	signal	text_addr_r: std_logic_vector(31 downto 0);	-- SRAM/SDRAM text start address
	signal	addr_r	:	unsigned(29 downto 0); -- address in BRAM to fetch character+color
	signal	cy		:	unsigned(7 downto 0);			-- current text line
	signal	bmap_addr_r: std_logic_vector(31 downto 0);	-- SRAM/SDRAM bitmap start address
	signal	bmap_color_r: std_logic_vector(23 downto 0);
	signal	baddr_r	:	unsigned(27 downto 0);			-- current SRAM bitmap address
	signal	req_bitmap_strobe	: std_logic;
	signal	bitmap_r: std_logic_vector(31 downto 0);
	signal	bitmap_n_r: std_logic_vector(31 downto 0);

	signal	fonty	:	unsigned(4 downto 0);
	signal	color_r	:	std_logic_vector(7 downto 0);
	signal	color_n_r:	std_logic_vector(7 downto 0) := x"1F";
	signal	fontdata_r	:	std_logic_vector(7 downto 0);
	signal	fontdata_n_r :	std_logic_vector(7 downto 0);

	signal	cursoron :	std_logic;

	type palette_t is array(0 to 15) of std_logic_vector(23 downto 0);	-- x"RRGGBB"
	signal palette: palette_t :=
	(
		x"000000",
		x"0000AA",
		x"00AA00",
		x"00AAAA",
		x"AA0000",
		x"AA00AA",
		x"AAAA00",
		x"AAAAAA",
		x"555555",
		x"5555FF",
		x"55FF55",
		x"55FFFF",
		x"FF5555",
		x"FF55FF",
		x"FFFF55",
		x"FFFFFF"
	);

begin
	reg_proc: process(clk, ce)
	begin
		if rising_edge(clk) then
			if ce = '1' and bus_write = '1' then
				case addr is
					when C_cntrl =>
						if byte_sel(0)='1' then
							if C_vgatext_text then
							if unsigned(bus_in(7 downto 0)) < (vmode(C_vgatext_mode).visible_width/8) then
								curx_r <= unsigned(bus_in(7 downto 0));
							else
								curx_r <= to_unsigned(vmode(C_vgatext_mode).visible_width/8, curx_r'length);	-- NOTE: this allows software to query text columns
							end if;
							end if;
						end if;
						if byte_sel(1)='1' then
							if C_vgatext_text then
							if unsigned(bus_in(15 downto 8)) < (vmode(C_vgatext_mode).visible_height/C_vgatext_char_height) then
								cury_r <= unsigned(bus_in(15 downto 8));
							else
								cury_r <= to_unsigned((vmode(C_vgatext_mode).visible_height/C_vgatext_char_height), cury_r'length);	-- NOTE: this allows software to query text lines
							end if;
							end if;
						end if;
						if byte_sel(2)='1' then
							if C_vgatext_monochrome then
							color_n_r <= bus_in(23 downto 16);
							end if;
						end if;
						if byte_sel(3)='1' then
							cntrl_r <= bus_in(31 downto 28);
						end if;
					when C_bmap_addr =>
						if C_vgatext_bitmap then
							bmap_addr_r <= bus_in;
						end if;
					when C_bmap_color =>
						if C_vgatext_bitmap then
							bmap_color_r <= bus_in(23 downto 0);
						end if;
					when C_palette_reg =>
						if C_vgatext_palette then
							palette(to_integer(unsigned(bus_in(27 downto 24)))) <= bus_in(23 downto 0);
						end if;
					when C_text_addr =>
						if C_vgatext_text then
							text_addr_r <= bus_in;
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	monoflag <= '1' when C_vgatext_monochrome else '0';
	bitmapflag <= '1' when C_vgatext_bitmap else '0';
	resolution <= "01" when C_vgatext_mode = 1 else
				  "10" when C_vgatext_mode = 2 else
				  "11" when C_vgatext_mode = 3 else
				  "00";
	colors	<= "001" when C_vgatext_bitmap_depth = 1 else
			   "010" when C_vgatext_bitmap_depth = 2 else
			   "011" when C_vgatext_bitmap_depth = 4 else
			   "100" when C_vgatext_bitmap_depth = 8 else
			   "000";

	bus_out <=	std_logic_vector(bmap_addr_r) when addr=C_bmap_addr else
				std_logic_vector(text_addr_r) when addr=C_text_addr else
				cntrl_r & monoflag & bitmapflag & resolution & colors & "0" & std_logic_vector(fcount) & std_logic_vector(cury_r) & std_logic_vector(curx_r);

	G_bitmap_sram:
	if C_vgatext_bitmap AND NOT C_vgatext_bitmap_fifo generate
	bitmap_proc: process(clk)
	begin
		if rising_edge(clk) then
			if (bitmap_ready = '1') then
				bitmap_n_r <= bitmap_data;
				bitmap_strobe <= '0';
			elsif (req_bitmap_strobe = '1') then
				bitmap_strobe <= '1';
			end if;
		end if;
	end process;
	end generate;

	G_bitmap_fifo: if C_vgatext_bitmap AND C_vgatext_bitmap_fifo generate
	bitmap_strobe <= req_bitmap_strobe;
	end generate;

	pixel_proc: process(clk_pixel)
		variable fontpix: std_logic;
		variable pixcolor: std_logic_vector(7 downto 0);
		variable bitmap_pix: std_logic_vector(C_vgatext_bitmap_depth-1 downto 0);
		variable char_data: std_logic_vector(7 downto 0);
		variable color_data: std_logic_vector(7 downto 0);
	begin
		if rising_edge(clk_pixel) then
			if cntrl_r(3)='1' then
				if hcount = (vmode(C_vgatext_mode).visible_width-1) then				-- are we at the end of a horizontal line?
					hcount <= to_signed((vmode(C_vgatext_mode).visible_width-C_total_width), 12);		-- yes, reset hcount
					if vcount = (vmode(C_vgatext_mode).visible_height-1) then			-- are we at the bottom of the frame also?
						vcount <= to_signed((vmode(C_vgatext_mode).visible_height-C_total_height), 12);	-- yes, reset vcount
						fcount <= fcount + 1;					-- increment fcount frame counter
					else
						vcount <= vcount + 1;					-- no, increment vcount line counter
					end if;
				else
					hcount <= hcount + 1;						-- no, increment hcount pixel counter
				end if;

				-- if hcount is in the proper range, generate hsync output
				if (hcount >= -(vmode(C_vgatext_mode).h_back_porch+vmode(C_vgatext_mode).h_sync_pulse) and hcount < -vmode(C_vgatext_mode).h_back_porch) then
					hsync_r <= vmode(C_vgatext_mode).h_sync_polarity;
				else
					hsync_r <= NOT vmode(C_vgatext_mode).h_sync_polarity;
				end if;

				-- if vcount is in the proper range, generate vsync output
				if (vcount >= -(vmode(C_vgatext_mode).v_back_porch+vmode(C_vgatext_mode).v_sync_pulse) and vcount < -vmode(C_vgatext_mode).v_back_porch) then
					vsync_r <= vmode(C_vgatext_mode).v_sync_polarity;
				else
					vsync_r <= NOT vmode(C_vgatext_mode).v_sync_polarity;
				end if;

				if (hcount >= 0 AND vcount >= 0) then
					visible_r	<= '1';
				else
					visible_r	<= '0';
				end if;

				r_r <= (others => '0');
				g_r <= (others => '0');
				b_r <= (others => '0');

				fontdata_r <= fontdata_r(6 downto 0) & "0";
				
				if C_vgatext_text_fifo then
					text_strobe <= '0';
					text_rewind <= '0';
				end if;
				if C_vgatext_bitmap then
					req_bitmap_strobe <= '0';
				end if;

				if (vcount >= 0) then
					if (C_vgatext_text AND cntrl_r(2)='1' AND hcount >= -8 AND vcount < ((vmode(C_vgatext_mode).visible_height/C_vgatext_char_height)*C_vgatext_char_height)) then
						case hcount(2 downto 0) is
							when "100" =>
								if NOT C_vgatext_text_fifo then
									bram_addr 	<= std_logic_vector(addr_r(12 downto 2));
								end if;
							when "101" =>
								char_data := (others => '0');
								if C_vgatext_text_fifo then
									if C_vgatext_monochrome then
									case addr_r(1 downto 0) is	-- extract proper byte for char (no color byte)
										when "00" =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data( 0+C_vgatext_font_depth-1 downto 0);
										when "01" =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data( 8+C_vgatext_font_depth-1 downto 8);
										when "10" =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data(16+C_vgatext_font_depth-1 downto 16);
										when "11" =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data(24+C_vgatext_font_depth-1 downto 24);
														text_strobe <= '1';
										when others => null;
									end case;
									else
									case addr_r(1) is			-- extract proper word and low byte for char, high byte for color
										when '0' =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data( 0+C_vgatext_font_depth-1 downto 0);
													color_n_r <= text_data(15 downto 8);
										when '1' =>	char_data(C_vgatext_font_depth-1 downto 0) := text_data(16+C_vgatext_font_depth-1 downto 16);
													color_n_r <= text_data(31 downto 24);
													text_strobe <= '1';
										when others => null;
									end case;
									end if;
								else
									if C_vgatext_monochrome then
									case addr_r(1 downto 0) is	-- extract proper byte for char (no color byte)
										when "00" =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data( 0+C_vgatext_font_depth-1 downto 0);
										when "01" =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data( 8+C_vgatext_font_depth-1 downto 8);
										when "10" =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data(16+C_vgatext_font_depth-1 downto 16);
										when "11" =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data(24+C_vgatext_font_depth-1 downto 24);
										when others => null;
									end case;
									else
									case addr_r(1) is			-- extract proper word and low byte for char, high byte for color
										when '0' =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data( 0+C_vgatext_font_depth-1 downto 0);
													color_n_r <= text_data(15 downto 8);
										when '1' =>	char_data(C_vgatext_font_depth-1 downto 0) := bram_data(16+C_vgatext_font_depth-1 downto 16);
													color_n_r <= text_data(31 downto 24);
										when others => null;
									end case;
									end if;
								end if;
								
								bram_addr <= (others => '1');	-- assume unset bits are 1 to place font at high end of vga_textmode memory
								if C_vgatext_font_height=8 then
								if (fonty < 16) then
									bram_addr(C_vgatext_font_depth+2 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & fonty(3);
								else
									bram_addr(C_vgatext_font_depth+2 downto 2) <= (others => '0');
								end if;
								else
								if (fonty < 16) then
									bram_addr(C_vgatext_font_depth+3 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & std_logic_vector(fonty(3 downto 2));
								else
									bram_addr(C_vgatext_font_depth+3 downto 2) <= char_data(C_vgatext_font_depth-1 downto 0) & "11";
								end if;
								end if;
							when "110" =>
								if (fonty < 16) then
									if C_vgatext_font_height=8 then
									case fonty(2 downto 1) is
										when "00" => fontdata_n_r <= bram_data( 7 downto  0);
										when "01" => fontdata_n_r <= bram_data(15 downto  8);
										when "10" => fontdata_n_r <= bram_data(23 downto 16);
										when "11" => fontdata_n_r <= bram_data(31 downto 24);
										when others => null;
									end case;
									else
									case fonty(1 downto 0) is
										when "00" => fontdata_n_r <= bram_data( 7 downto  0);
										when "01" => fontdata_n_r <= bram_data(15 downto  8);
										when "10" => fontdata_n_r <= bram_data(23 downto 16);
										when "11" => fontdata_n_r <= bram_data(31 downto 24);
										when others => null;
									end case;
									end if;
								else
									fontdata_n_r <= text_data(31 downto 24);
								end if;

								if (hcount = vmode(C_vgatext_mode).visible_width-2) then
									if (fonty /= C_vgatext_char_height-1) then
										if C_vgatext_text_fifo then
											text_rewind <= '1';
										end if;
										if C_vgatext_monochrome then
											addr_r <= addr_r - (vmode(C_vgatext_mode).visible_width/C_char_width);
										else
											addr_r <= addr_r - ((vmode(C_vgatext_mode).visible_width/C_char_width)*2);
										end if;
									end if;
								else
								if C_vgatext_monochrome then
										addr_r <= addr_r + 1;
									else
										addr_r <= addr_r + 2;
									end if;
								end if;
							when "111" =>
								if (hcount = vmode(C_vgatext_mode).visible_width-1) then
									if (fonty = C_vgatext_char_height-1) then
										fonty <= (others => '0');
										cy <= cy + 1;
									else
										fonty <= fonty + 1;
									end if;
								end if;
								fontdata_r <= fontdata_n_r;
								color_r <= color_n_r;
							when others =>
								null;
						end case;
					end if;

					bitmap_pix := (others => '0');
								if C_vgatext_bitmap_depth = 8 then
								bitmap_pix := bitmap_r(C_vgatext_bitmap_depth-1 downto 0);	-- little-endian byte order
								else
								bitmap_pix := bitmap_r(31 downto 32-C_vgatext_bitmap_depth);
								end if;
					if C_vgatext_bitmap AND cntrl_r(1)='1' then
						if C_vgatext_bitmap_depth = 8 then
						bitmap_pix := bitmap_r(C_vgatext_bitmap_depth-1 downto 0);	-- little-endian byte order
						else
						bitmap_pix := bitmap_r(31 downto 32-C_vgatext_bitmap_depth);
						end if;
						if C_vgatext_bitmap_fifo then						-- FIFO
							if (hcount >= -1 AND hcount < vmode(C_vgatext_mode).visible_width-1) then
								if C_vgatext_bitmap_depth = 8 then			-- 256 color
								if (hcount(1 downto 0) = "11") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_data;
								else
									bitmap_r <=  x"00" & bitmap_r(31 downto 8);	-- little-endian byte order
								end if;
								elsif C_vgatext_bitmap_depth = 4 then		-- 16 color
								if (hcount(2 downto 0) = "111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_data;
								else
									bitmap_r <= bitmap_r(27 downto 0) & "0000";
								end if;
								elsif C_vgatext_bitmap_depth = 2 then		-- 4 color
								if (hcount(3 downto 0) = "1111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_data;
								else
									bitmap_r <= bitmap_r(29 downto 0) & "00";
								end if;
								else										-- 2 color
								if (hcount(4 downto 0) = "11111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_data;
								else
									bitmap_r <= bitmap_r(30 downto 0) & "0";
								end if;
								end if;
							end if;
						else											-- SRAM port
							if (hcount = -33) then
								req_bitmap_strobe <= '1';
							end if;

							if C_vgatext_bitmap_depth = 8 then			-- 256 color
								if (hcount >= -1 AND hcount(1 downto 0) = "11") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_n_r;
									if (hcount /= vmode(C_vgatext_mode).visible_width-5) then
										baddr_r <= baddr_r + 1;
									end if;
								else
									bitmap_r <=  x"00" & bitmap_r(31 downto 8);	-- little-endian byte order
								end if;
							elsif C_vgatext_bitmap_depth = 4 then		-- 16 color
								if (hcount >= -1 AND hcount(2 downto 0) = "111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_n_r;
									if (hcount /= vmode(C_vgatext_mode).visible_width-9) then
										baddr_r <= baddr_r + 1;
									end if;
								else
									bitmap_r <= bitmap_r(27 downto 0) & x"0";
								end if;
							elsif C_vgatext_bitmap_depth = 2 then		-- 4 color
								if (hcount >= -1 AND hcount(3 downto 0) = "1111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_n_r;
									if (hcount /= vmode(C_vgatext_mode).visible_width-17) then
										baddr_r <= baddr_r + 1;
									end if;
								else
									bitmap_r <= bitmap_r(29 downto 0) & "00";
								end if;
							else										-- 2 color
								if (hcount >= -1 AND hcount(4 downto 0) = "11111") then
									req_bitmap_strobe <= '1';
									bitmap_r <= bitmap_n_r;
									if (hcount /= vmode(C_vgatext_mode).visible_width-33) then
										baddr_r <= baddr_r + 1;
									end if;
								else
									bitmap_r <= bitmap_r(30 downto 0) & "0";
								end if;
							end if;
						end if;
					end if;

					pixcolor := color_r;
					fontpix := fontdata_r(7);

					if (C_vgatext_text AND curx_r = unsigned(hcount(10 downto 3)) AND cury_r = cy AND cursoron = '1') then
						fontpix := NOT fontpix;
					end if;

					if (cntrl_r(2)='1' AND fontpix = '1') then
						if C_vgatext_palette then
						r_r <= palette(to_integer(unsigned(pixcolor(3 downto 0))))(23 downto 16);
						g_r <= palette(to_integer(unsigned(pixcolor(3 downto 0))))(15 downto 8);
						b_r <= palette(to_integer(unsigned(pixcolor(3 downto 0))))(7 downto 0);
						else
						r_r <= pixcolor(2) & pixcolor(3) & pixcolor(2) & pixcolor(3) & pixcolor(2) & pixcolor(3) & pixcolor(2) & pixcolor(3);
						g_r <= pixcolor(1) & pixcolor(3) & pixcolor(1) & pixcolor(3) & pixcolor(1) & pixcolor(3) & pixcolor(1) & pixcolor(3);
						b_r <= pixcolor(0) & pixcolor(3) & pixcolor(0) & pixcolor(3) & pixcolor(0) & pixcolor(3) & pixcolor(0) & pixcolor(3);
						end if;
					else
						if (C_vgatext_bitmap AND unsigned(bitmap_pix) /= 0) then
							if C_vgatext_bitmap_depth = 8 then			-- 8bpp RRR GGG BB
							r_r <= bitmap_pix(7 downto 5) & bitmap_pix(7 downto 5) & bitmap_pix(7 downto 6);
							g_r <= bitmap_pix(4 downto 2) & bitmap_pix(4 downto 2) & bitmap_pix(4 downto 3);
							b_r <= bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0) & bitmap_pix(1 downto 0);
							elsif C_vgatext_bitmap_depth = 4 then
							if C_vgatext_palette then						-- 4bpp palletized
							r_r <= palette(to_integer(unsigned(bitmap_pix)))(23 downto 16);
							g_r <= palette(to_integer(unsigned(bitmap_pix)))(15 downto 8);
							b_r <= palette(to_integer(unsigned(bitmap_pix)))(7 downto 0);
							else											-- 4bpp IRGB
							r_r <= bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3) & bitmap_pix(2) & bitmap_pix(3);
							g_r <= bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3) & bitmap_pix(1) & bitmap_pix(3);
							b_r <= bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3) & bitmap_pix(0) & bitmap_pix(3);
							end if;
							elsif C_vgatext_bitmap_depth = 2 then
							if C_vgatext_palette then						-- 2bpp palletized
							r_r <= palette(to_integer(unsigned(bitmap_pix)))(23 downto 16);
							g_r <= palette(to_integer(unsigned(bitmap_pix)))(15 downto 8);
							b_r <= palette(to_integer(unsigned(bitmap_pix)))(7 downto 0);
							else											-- 2bpp fixed black, blue, red, white
							if bitmap_pix(1)='1' then	r_r <= x"ff"; end if;
							if bitmap_pix = "11" then	g_r <= x"ff"; end if;
							if bitmap_pix(0)='1' then	b_r <= x"ff"; end if;
							end if;
							else
							r_r <= bmap_color_r(23 downto 16);				-- 1bpp bitmap color
							g_r <= bmap_color_r(15 downto 8);
							b_r <= bmap_color_r(7 downto 0);
							end if;
						else
							if C_vgatext_palette then
							r_r <= palette(to_integer(unsigned(pixcolor(7 downto 4))))(23 downto 16);
							g_r <= palette(to_integer(unsigned(pixcolor(7 downto 4))))(15 downto 8);
							b_r <= palette(to_integer(unsigned(pixcolor(7 downto 4))))(7 downto 0);
							else
							r_r <= pixcolor(6) & pixcolor(7) & pixcolor(6) & pixcolor(7) & pixcolor(6) & pixcolor(7) & pixcolor(6) & pixcolor(7);
							g_r <= pixcolor(5) & pixcolor(7) & pixcolor(5) & pixcolor(7) & pixcolor(5) & pixcolor(7) & pixcolor(5) & pixcolor(7);
							b_r <= pixcolor(4) & pixcolor(7) & pixcolor(4) & pixcolor(7) & pixcolor(4) & pixcolor(7) & pixcolor(4) & pixcolor(7);
							end if;
						end if;
					end if;
				else
					if C_vgatext_text then
 					addr_r <= unsigned(text_addr_r(29 downto 0));
					fonty <= (others => '0');
					cy <= (others => '0');
					end if;

					if C_vgatext_bitmap then
					baddr_r <= unsigned(bmap_addr_r(29 downto 2));
					req_bitmap_strobe <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	cursoron <= fcount(3) AND cntrl_r(0);
	bitmap_addr <= std_logic_vector(baddr_r(27 downto 0));
	text_addr <= text_addr_r(29 downto 2);
	
	hsync <= hsync_r;
	vsync <= vsync_r;
	nblank <= '0' when visible_r = '1' else '1';
	R <= std_logic_vector(r_r(7 downto 8-C_vgatext_bits)) when visible_r = '1' else (others => '0');
	G <= std_logic_vector(g_r(7 downto 8-C_vgatext_bits)) when visible_r = '1' else (others => '0');
	B <= std_logic_vector(b_r(7 downto 8-C_vgatext_bits)) when visible_r = '1' else (others => '0');

end Behavioral;
