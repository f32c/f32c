--
-- Copyright (c) 2013 Marko Zec, University of Zagreb
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

entity cvbs is
    generic (
	C_interlaced: boolean;
	C_clk_freq: integer;
	C_dac_freq: integer
    );
    port (
	clk, clk_dac: in std_logic;
	luma: in std_logic_vector(6 downto 0);
	chroma_phase: in std_logic_vector(5 downto 0);
	chroma_sat: in std_logic_vector(3 downto 0);
	active_pixel: out std_logic;
	scan_line: out std_logic_vector(9 downto 0);
	dac_out: out std_logic_vector(3 downto 0)
    );
end cvbs;

--
-- PAL timing
--
-- Line numbering			  	1 .. 625
-- Line frequency 				15625 Hz
-- Line period 					64 us
--	Long sync pulse (0.0 V):		27.3 us
--	Short sync pulse (0.0 V):		2.35 us
--	Active line timing:
--	(1) H-Sync pulse (0.0 V)		4.7 us
--	(2) Back porch (0.3 V)			5.7 us
--	(3) Active video (0.3 .. 1.0 V)		51.95 us
-- 	(4) Front porch (0.3 V)			1.65 us
-- Active scan lines (field #1):		23 to 310
-- Active scan lines (field #2):		336 to 623
-- Pixel clock per ITU-R BT.601:		13.5 MHz
-- Chroma carrier frequency:			4.43361875 MHz
--	Chroma phase alternation:		+/- 90 deg each line
--	Chroma burst phase:			+ 135 deg
-- 	Chroma burst length:			2.26 us
--	Chroma burst start relative to H-Sync:	5.6 us
--	No chroma burst on active lines:	6, 310, 320, 622, 623
--

--
-- Per half-line states:
-- 	ena_chroma_burst (boolean)
--	visible_line (boolean)
--	out_type:
--	    "00"	long_sync
--	    "01"	short sync
--	    "10"	field #1
--	    "11"	field #2
--

architecture behavioral of cvbs is
    -- Clocked with clk
    signal R_hpos, hpos_next: std_logic_vector(13 downto 0);
    signal R_dline, dline_next: std_logic_vector(10 downto 0);
    signal R_out_type, out_type_next: std_logic_vector(1 downto 0);
    signal R_visible_line, visible_line_next: boolean;
    signal R_visible_pixel, visible_pixel_next: boolean;
    signal R_sync_pulse, sync_pulse_next: boolean;
    signal R_chroma_line, chroma_line_next: boolean;
    signal R_chroma_burst, chroma_burst_next: boolean;
    signal R_chroma_sat: std_logic_vector(3 downto 0);
    signal R_chroma_phase: std_logic_vector(5 downto 0);
    signal R_luma: std_logic_vector(7 downto 0);

    -- Clocked with clk_dac
    signal Rx_chroma_sat: std_logic_vector(3 downto 0);
    signal Rx_chroma_phase: std_logic_vector(5 downto 0);
    signal Rx_luma: std_logic_vector(7 downto 0);
    signal Rx_odd_line: std_logic;
    signal Rx_clk_142m: std_logic;
    signal Rx_dds_142m: std_logic_vector(29 downto 0);
    signal Rx_chroma_acc: std_logic_vector(5 downto 0);
    signal Rx_chroma_delta: std_logic_vector(3 downto 0);
    signal Rx_chroma_eff, chroma_eff_next: std_logic_vector(5 downto 0); 
    signal Rx_dac_acc: std_logic_vector(3 downto 0);
    signal Rx_vout: std_logic_vector(7 downto 0);
    signal Rx_vout_0, Rx_vout_1: std_logic_vector(3 downto 0);
    signal Rx_dac_out: std_logic_vector(3 downto 0);
    signal Rx_chroma_bit, chroma_bit_next: std_logic;

    -- Horizontal timing constants
    constant HPOS_WRAP: integer := C_clk_freq / 31250;		--  32.00 us
    constant HSYNC_END: integer := C_clk_freq / 212766;		--   4.70 us
    constant LONG_SYNC_END: integer := C_clk_freq / 36630;	--  27.30 us
    constant SHORT_SYNC_END: integer := C_clk_freq / 425532;	--   2.35 us
    constant CHROMA_BURST_START: integer := C_clk_freq / 178571; --  5.60 us
    constant CHROMA_BURST_END: integer := C_clk_freq / 127226;	--   7.86 us
    constant ACTIVE_START: integer := C_clk_freq / 89000;	--  10.40 us (?)
    constant ACTIVE_END: integer := C_clk_freq / 32948;		--  30.35 us

    -- Misc. constants
    constant LUMA_BLACK: std_logic_vector(7 downto 0) := "01000000";

begin

    --
    -- Combinatorial logic
    --
    process(R_hpos, R_dline, R_out_type, R_sync_pulse, R_visible_line,
	R_visible_pixel, R_chroma_line, R_chroma_burst,
	Rx_chroma_acc, R_chroma_phase, R_luma)
    begin
	-- Update horizontal "position" and line counters
	if (R_hpos = HPOS_WRAP) then
	    hpos_next <= "00000000000001";
	    if ((C_interlaced and R_dline = 625 * 2 + 1) or
		(not C_interlaced and R_dline = 312 * 2 + 1)) then
		dline_next <= "00000000010";
	    else
		dline_next <= R_dline + 1;
	    end if;
	else
	    hpos_next <= R_hpos + 1;
	    dline_next <= R_dline;
	end if;

	-- Update out_type (short sync, long sync, field #1, or field #2)
	if (R_hpos = HPOS_WRAP) then
	    if ((C_interlaced and R_dline = 625 * 2 + 1) or
		(not C_interlaced and R_dline = 312 * 2 + 1)) then
		out_type_next <= "00";		-- long sync
	    elsif (R_dline = 3 * 2) then	-- middle of line 3
		out_type_next <= "01";		-- short sync
	    elsif (R_dline = 5 * 2 + 1) then	-- end of line 5
		out_type_next <= "10";		-- field #1
	    elsif ((C_interlaced and R_dline = 310 * 2 + 1) or
		(not C_interlaced and R_dline = 309 * 2 + 1)) then
		out_type_next <= "01";		-- short sync
	    elsif (C_interlaced and R_dline = 313 * 2) then -- 1/2 of line 313
		out_type_next <= "00";		-- long sync
	    elsif (C_interlaced and R_dline = 315 * 2 + 1) then	-- eol 315
		out_type_next <= "01";		-- short sync
	    elsif (C_interlaced and R_dline = 318 * 2) then -- 1/2 of line 318
		out_type_next <= "11";		-- field #2
	    elsif (C_interlaced and R_dline = 623 * 2) then -- 1/2 of line 623
		out_type_next <= "01";		-- short sync
	    else
		out_type_next <= R_out_type;	-- no change
	    end if;
	else
	    out_type_next <= R_out_type;	-- no change
	end if;

	-- Update sync_pulse
	if (R_hpos = HPOS_WRAP and R_dline(0) = '1') then -- start of a line
	    sync_pulse_next <= true;	
	elsif (R_hpos = HPOS_WRAP and R_out_type(1) = '0') then -- sync start
	    sync_pulse_next <= true;	
	elsif (R_out_type(1) = '1' and R_hpos = HSYNC_END) then
	    sync_pulse_next <= false;	
	elsif (R_out_type = "00" and R_hpos = LONG_SYNC_END) then
	    sync_pulse_next <= false;	
	elsif (R_out_type = "01" and R_hpos = SHORT_SYNC_END) then
	    sync_pulse_next <= false;	
	else
	    sync_pulse_next <= R_sync_pulse;
	end if;

	-- Update visible_line
	if (R_hpos = HPOS_WRAP and R_dline(0) = '1') then -- start of a line
	    if (R_dline(10 downto 1) = 23 or
		(C_interlaced and R_dline(10 downto 1) = 335)) then
		visible_line_next <= true;
	    elsif (out_type_next(1) = '0') then
		visible_line_next <= false;
	    else
		visible_line_next <= R_visible_line;
	    end if;
	else
	    visible_line_next <= R_visible_line;
	end if;

	-- Update visible_pixel
	if (R_visible_line and R_dline(0) = '0' and R_hpos = ACTIVE_START) then
	    visible_pixel_next <= true;
	elsif (R_dline(0) = '1' and R_hpos = ACTIVE_END) then
	    visible_pixel_next <= false;
	else
	    visible_pixel_next <= R_visible_pixel;
	end if;

	-- Update chroma_line
	if (R_hpos = HPOS_WRAP and R_dline(0) = '1') then -- start of a line
	    if (R_dline(10 downto 1) = 6 or
		(C_interlaced and R_dline(10 downto 1) = 320)) then
		chroma_line_next <= true;
	    elsif (R_dline(10 downto 1) = 309 or
		(C_interlaced and R_dline(10 downto 1) = 621)) then
		chroma_line_next <= false;
	    else
		chroma_line_next <= R_chroma_line;
	    end if;
	else
	    chroma_line_next <= R_chroma_line;
	end if;

	-- Update chroma_burst
	if (R_chroma_line and R_dline(0) = '0' and
	    R_hpos = CHROMA_BURST_START) then
	    chroma_burst_next <= true;
	elsif (R_hpos = CHROMA_BURST_END) then
	    chroma_burst_next <= false;
	else
	    chroma_burst_next <= R_chroma_burst;
	end if;

	-- Update chroma_phase and chroma_eff
	if (Rx_odd_line = '0') then
	    chroma_eff_next <= Rx_chroma_phase + Rx_chroma_acc;
	else
	    chroma_eff_next <= Rx_chroma_phase - Rx_chroma_acc;
	end if;

	-- Compute chroma_bit
	if (Rx_chroma_eff(4) = '1') then
	    if (Rx_chroma_sat > Rx_chroma_eff(3 downto 0)) then
		chroma_bit_next <= '1';
	    else
		chroma_bit_next <= '0';
	    end if;
	else
	    if (Rx_chroma_sat > ("1111" - Rx_chroma_eff(3 downto 0))) then
		chroma_bit_next <= '1';
	    else
		chroma_bit_next <= '0';
	    end if;
	end if;

	-- Update output
	scan_line <= R_dline(10 downto 1);
	if (R_visible_pixel) then
	    active_pixel <= '1'; -- external output
	else
	    active_pixel <= '0'; -- external output
	end if;
    end process;

    --
    -- Registers
    --
    process(clk)
    begin
	if (rising_edge(clk)) then 
	    -- Hsync / Vsync timing state machine
	    R_hpos <= hpos_next;
	    R_dline <= dline_next;
	    R_out_type <= out_type_next;
	    R_sync_pulse <= sync_pulse_next;
	    R_visible_line <= visible_line_next;
	    R_visible_pixel <= visible_pixel_next;
	    R_chroma_line <= chroma_line_next;
	    R_chroma_burst <= chroma_burst_next;

	    -- Luma
	    if (R_sync_pulse) then
		R_luma <= "00000000";
	    elsif (R_visible_pixel) then
		R_luma <= LUMA_BLACK + ('0' & luma); -- external input
	    else
		R_luma <= LUMA_BLACK;
	    end if;

	    -- Chroma
	    if (R_chroma_burst) then
		R_chroma_sat <= "1111";
		R_chroma_phase <= "011000"; -- 135 deg -> 24/64
	    elsif (R_visible_pixel) then
		R_chroma_sat <= chroma_sat; -- external input
		R_chroma_phase <= "111100" - chroma_phase; -- external input
	    else
		R_chroma_sat <= "0000";
		R_chroma_phase <= "011000"; -- 135 deg -> 24/64
	    end if;
	end if;
    end process;

    --
    -- Chroma and DAC
    --
    process(clk_dac)
    begin
	if rising_edge(clk_dac) then
	    -- Cross clock domain boundary
	    Rx_luma <= R_luma;
	    Rx_chroma_sat <= R_chroma_sat;
	    Rx_chroma_phase <= R_chroma_phase;
	    Rx_odd_line <= R_dline(1);

	    -- Chroma
	    -- increment = 2 ^ (bitlen(Rx_dds_142m)) * Ftarget / Fdds
	    -- Rx_dds_142m <= Rx_dds_142m + (595070235 / (C_dac_freq / 1000000));
	    Rx_dds_142m <= Rx_dds_142m + 468732247; -- 30 bit, 325 MHz
	    Rx_clk_142m <= Rx_dds_142m(29);
	    if (Rx_clk_142m = '0' and Rx_dds_142m(29) = '1') then
		Rx_chroma_acc(5 downto 1) <= Rx_chroma_acc(5 downto 1) + 1;
		Rx_chroma_acc(0) <= '0';
	    else
		Rx_chroma_acc(0) <= '1';
	    end if;

	    Rx_chroma_eff <= chroma_eff_next;
	    Rx_chroma_bit <= chroma_bit_next;
	    case Rx_chroma_eff(5) is
		when '0' =>
		    Rx_chroma_delta <= "000" & Rx_chroma_bit;
		when others =>
		    Rx_chroma_delta <= Rx_chroma_bit & Rx_chroma_bit &
			Rx_chroma_bit & Rx_chroma_bit;
	    end case;

	    -- DAC
	    Rx_dac_acc <= Rx_dac_acc + 1;
	    Rx_vout <= Rx_luma + (Rx_chroma_delta & "0000");
	    if (Rx_dac_acc > Rx_vout(3 downto 0)) then
		Rx_dac_out <= Rx_vout(7 downto 4);
	    else
		Rx_dac_out <= Rx_vout(7 downto 4) + 1;
	    end if;
	end if;
    end process;

    dac_out <= Rx_dac_out;
end;
