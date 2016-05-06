--
-- Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
-- All rights reserved.
--
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
--
-- $Id$
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity tv is
    generic (
	C_big_endian: boolean := false;
	C_clk_freq: integer := 81250000;
	C_pixclk_div: std_logic_vector := "00111"; -- 512 h @ 81.25 MHz
	C_hpos_first: std_logic_vector := x"000"; -- first visible hpix
	C_hpos_last: std_logic_vector := x"200" -- last visible hpix + 1
    );
    port (
	clk, clk_dac: in std_logic;
	fetch_next: out std_logic;
	pixel_data: in std_logic_vector(15 downto 0); -- color input data, not simple RGB
	mode: in std_logic_vector(1 downto 0) := "10"; -- default display test picture
	dac_out: out std_logic_vector(3 downto 0);
	-- vsync: out std_logic;
	vblank, vsync: out std_logic -- fifo active = not vsync
    );
end tv;


architecture behavioral of tv is
    -- Types
    type pixbuf_dpram_type is array(0 to 15) of std_logic_vector(31 downto 0);

    -- Wiring to CVBS module
    signal active_pixel: std_logic;
    signal R_luma: std_logic_vector(6 downto 0);
    signal R_chroma_sat: std_logic_vector(3 downto 0);
    signal R_chroma_phase: std_logic_vector(5 downto 0);
    signal scan_line: std_logic_vector(9 downto 0);

    -- Internal state
    signal R_pixclk: std_logic_vector(4 downto 0);
    signal R_hpos: std_logic_vector(11 downto 0);
    --signal R_pixbuf: pixbuf_dpram_type;
    signal R_sram_addr: std_logic_vector(29 downto 2);
    --signal R_pixbuf_rd_addr, R_pixbuf_wr_addr: std_logic_vector(3 downto 0);
    --signal R_pixbuf_rd_byte: std_logic_vector(1 downto 0);
    signal R_scan_line_high: std_logic_vector(1 downto 0);
    signal R_vsync: std_logic;
    signal R_fetch_next: std_logic;
    signal R_vblank: std_logic;

begin
    -- Vertical SYNC generation
    -- takes scan_line input, generated from output module
    process(clk)
    begin
	if rising_edge(clk) then
	    R_scan_line_high <= scan_line(9 downto 8);
	    if R_scan_line_high /= "00" and scan_line = "00" & x"01" then
		R_vsync <= '1';
	    else
		R_vsync <= '0';
	    end if;
	    if conv_integer(scan_line) = 1 then
	      R_vblank <= '1';
	    end if;
	    if conv_integer(scan_line) = 40 then
	      R_vblank <= '0';
	    end if;
	end if;
    end process;
    vblank <= R_vblank;

    -- FIFO signaling: when to fetch new pixel_data
    process(clk)
    begin
	if rising_edge(clk) then
	    -- when to fetch new pixel
	    R_fetch_next <= '0'; -- default
	    if active_pixel = '0' then
		R_pixclk <= (others => '0');
		R_hpos <= (others => '0');
	        --if scan_line = "0000000001" then
		    --R_pixbuf_rd_addr <= x"0";
		    --R_pixbuf_rd_byte <= "00";
		--end if;
		--R_fetch_next <= '0';
	    elsif R_pixclk /= C_pixclk_div then
		R_pixclk <= R_pixclk + 1;
		--R_fetch_next <= '0';
	    else
		R_pixclk <= (others => '0');
                -- XXX: symplify R_hpos arithmetic comapre < >
                -- rather use = and register change
		if R_hpos /= C_hpos_last then
		    R_hpos <= R_hpos + 1;
		    if R_hpos < C_hpos_first then
		        --R_fetch_next <= '0';
		    else
			-- get new pixel
			R_fetch_next <= '1';
		    end if;
		--else
		--  R_fetch_next <= '0';
		end if;
	    end if;
	end if;
    end process;
    fetch_next <= R_fetch_next; -- signal for upstream FIFO to fetch next pixel data
    vsync <= R_vsync; -- before start of new frame: short 1, otherwise: long 0

    -- conversion pixel_data -> luma/chroma
    process(clk)
	variable vpos: std_logic_vector(9 downto 0) := scan_line - 40;
    begin
	if rising_edge(clk) then
	    if mode = "10" then
		-- test pattern
		R_luma <= vpos(5 downto 0) & '0';
		R_chroma_phase <= vpos(7 downto 6) & R_hpos(8 downto 6) & '0';
		R_chroma_sat <= R_hpos(5 downto 2);
	    elsif mode = "00" then
		-- 8-bit color pallete
		if pixel_data(7 downto 4) = "0000" then
		    R_luma <= pixel_data(3 downto 0) & "000";
		    R_chroma_sat <= "0000";
		    -- Don't change chroma phase for grayscale pixels.
		else
		    if pixel_data(7 downto 6) = "10" then
			R_luma <= pixel_data(5 downto 4) & "10000";
			R_chroma_sat <= "0101";
		    elsif pixel_data(7 downto 6) = "11" then
			R_luma <= pixel_data(5 downto 4) & "10000";
			R_chroma_sat <= "1111";
		    else
			R_luma <= pixel_data(6 downto 4) & "0000";
			R_chroma_sat <= "0010";
		    end if;
		    R_chroma_phase <= (pixel_data(3 downto 0) & "01");
		end if;
	    elsif mode = "01" then
		-- 16-bit color pallete
		-- Don't change chroma phase for grayscale pixels.
		if C_big_endian then
		    if pixel_data(7 downto 4) /= "0000" then
			if pixel_data(7 downto 6) = "00" then
			    R_chroma_phase <= pixel_data(3 downto 0) &
			      pixel_data(15) & '0';
			else
			    R_chroma_phase <= pixel_data(3 downto 0) &
			      pixel_data(15 downto 14);
			end if;
		    end if;
		    R_chroma_sat <= pixel_data(7 downto 4);
		    if pixel_data(15 downto 14) = "00" then
			R_luma <= pixel_data(14 downto 8);
		    else
			R_luma <= pixel_data(13 downto 8) & '0';
		    end if;
		else
		    if pixel_data(15 downto 12) /= "0000" then
			if pixel_data(15 downto 14) = "00" then
			    R_chroma_phase <= pixel_data(11 downto 7) & '0';
			else
			    R_chroma_phase <= pixel_data(11 downto 6);
			end if;
		    end if;
		    R_chroma_sat <= pixel_data(15 downto 12);
		    if pixel_data(15 downto 14) = "00" then
			R_luma <= pixel_data(6 downto 0);
		    else
			R_luma <= pixel_data(5 downto 0) & '0';
		    end if;
		end if;
	    end if;
	    -- Suppress displaying anything past the last horizontal pixel
	    -- XXX: simplify this by replacing arithmetic compare < with = and register
	    if R_hpos < C_hpos_first or R_hpos = C_hpos_last then
		R_luma <= (others => '0');
		R_chroma_sat <= (others => '0');
		R_chroma_phase <= (others => '0');
	    end if;
	end if;
    end process;

    -- Composite Signal Output Module
    -- this module takes luma/chroma as input
    -- and outputs dac_out for composite out hardware.
    -- It also outputs local incrementing scan_line, to
    -- which rest of the logic here need to synchronize
    PAL: entity work.cvbs
    generic map (
	C_interlaced => false,
	C_clk_freq => C_clk_freq,
	C_dac_freq => 325000000
    )
    port map (
	clk => clk, clk_dac => clk_dac,
	luma => R_luma, chroma_phase => R_chroma_phase,
	chroma_sat => R_chroma_sat, active_pixel => active_pixel,
	scan_line => scan_line, dac_out => dac_out
    );
end;
