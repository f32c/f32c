--
-- Copyright (c) 2025 Marko Zec
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity dv_syncgen is
    port (
	pixclk: in std_logic;
	-- inputs: video mode configuration
	hdisp: in std_logic_vector(11 downto 0);
	hsyncstart: in std_logic_vector(11 downto 0);
	hsyncend: in std_logic_vector(11 downto 0);
	htotal: in std_logic_vector(11 downto 0);
	vdisp: in std_logic_vector(10 downto 0);
	vsyncstart: in std_logic_vector(10 downto 0);
	vsyncend: in std_logic_vector(10 downto 0);
	vtotal: in std_logic_vector(10 downto 0);
	hsyncn: in std_logic;
	vsyncn: in std_logic;
	interlace: in std_logic;
	-- outputs: sync signals
	hsync: out std_logic;
	vsync: out std_logic;
	active: out std_logic;
	field: out std_logic;
	frame_gap: out std_logic
    );
end dv_syncgen;

architecture x of dv_syncgen is
    -- configuration registers, synchronized to pixclk
    signal Rp_hdisp: std_logic_vector(11 downto 0);
    signal Rp_hsyncstart: std_logic_vector(11 downto 0);
    signal Rp_hsyncend: std_logic_vector(11 downto 0);
    signal Rp_htotal: std_logic_vector(11 downto 0);
    signal Rp_vdisp: std_logic_vector(10 downto 0);
    signal Rp_vsyncstart: std_logic_vector(10 downto 0);
    signal Rp_vsyncend: std_logic_vector(10 downto 0);
    signal Rp_vtotal: std_logic_vector(10 downto 0);
    signal Rp_hsyncn: std_logic;
    signal Rp_vsyncn: std_logic;
    signal Rp_interlace: std_logic;

    signal Rp_hstate: std_logic_vector(1 downto 0);
    signal Rp_vstate: std_logic_vector(1 downto 0);
    signal Rp_hpos: std_logic_vector(11 downto 0);
    signal Rp_vpos: std_logic_vector(10 downto 0);
    signal Rp_hbound: std_logic_vector(47 downto 0);
    signal Rp_vbound: std_logic_vector(43 downto 0);
    signal Rp_vsync_delay: std_logic_vector(11 downto 0);
    signal Rp_skip_line: boolean;
    signal Rp_hsync: std_logic;
    signal Rp_vsync: std_logic;
    signal Rp_active: std_logic;
    signal Rp_field: std_logic;
    signal Rp_frame_gap: std_logic;

begin
    process(pixclk)
	variable hsync: boolean;
    begin
	if rising_edge(pixclk) then
	    -- configuration registers, synchronizing to pixclk
	    Rp_hdisp <= hdisp;
	    Rp_hsyncstart <= hsyncstart;
	    Rp_hsyncend <= hsyncend;
	    Rp_htotal <= htotal;
	    Rp_vdisp <= vdisp;
	    Rp_vsyncstart <= vsyncstart;
	    Rp_vsyncend <= vsyncend;
	    Rp_vtotal <= vtotal;
	    Rp_hsyncn <= hsyncn;
	    Rp_vsyncn <= vsyncn;
	    Rp_interlace <= interlace;

	    Rp_hpos <= Rp_hpos + 1;
	    hsync := false;
	    if Rp_hpos = Rp_hbound(11 downto 0) then
		Rp_hstate <= Rp_hstate + 1;
		if Rp_hstate = "11" then
		    Rp_hbound <= Rp_htotal & Rp_hsyncend
		      & Rp_hsyncstart & Rp_hdisp;
		    Rp_hpos <= conv_std_logic_vector(1, 12);
		else
		    Rp_hbound(35 downto 0) <= Rp_hbound(47 downto 12);
		end if;
		case Rp_hstate is
		when "00" =>
		    Rp_active <= '0';
		when "01" =>
		    Rp_hsync <= not Rp_hsyncn;
		    hsync := true;
		when "10" =>
		    Rp_hsync <= Rp_hsyncn;
		when others => -- "11"
		    if Rp_vstate = "00" and not Rp_skip_line then
			Rp_active <= '1';
		    end if;
		    Rp_skip_line <= false;
		end case;
	    end if;
	    if hsync then
		Rp_vpos <= Rp_vpos + 1;
		if Rp_interlace = '1' then
		    Rp_vpos <= Rp_vpos + 2;
		end if;
		if Rp_vpos(10 downto 1) = Rp_vbound(10 downto 1) and
		  (Rp_interlace = '1' or (Rp_vpos(0) = Rp_vbound(0))) then
		    Rp_vstate <= Rp_vstate + 1;
		    Rp_vbound(32 downto 0) <= Rp_vbound(43 downto 11);
		    case Rp_vstate is
		    when "00" =>
			Rp_field <= Rp_interlace and not Rp_field;
			Rp_frame_gap <= not Rp_interlace or Rp_field;
		    when "01" =>
			if Rp_field = '0' then
			    Rp_vsync <= not Rp_vsyncn;
			else
			    Rp_vsync_delay <= '0' & Rp_htotal(11 downto 1);
			end if;
		    when "10" =>
			if Rp_field = '0' then
			    Rp_vsync <= Rp_vsyncn;
			else
			    Rp_vsync_delay <= '0' & Rp_htotal(11 downto 1);
			end if;
		    when "11" =>
			Rp_vbound <= Rp_vtotal & Rp_vsyncend
			  & Rp_vsyncstart & Rp_vdisp;
			Rp_vpos <= conv_std_logic_vector(1, 11);
			if Rp_interlace = '1' then
			    if Rp_field = '0' then
				Rp_vpos <= conv_std_logic_vector(2, 11);
			    elsif Rp_vtotal(0) = '1' then
				Rp_skip_line <= true;
			    end if;
			end if;
			if Rp_interlace = '0' or Rp_field = '0' then
			    Rp_frame_gap <= '0';
			end if;
		    when others =>
			-- nothing to do, appease the tools
		    end case;
		end if;
	    end if;
	    if Rp_vsync_delay(11) = '0' then
		Rp_vsync_delay <= Rp_vsync_delay - 1;
		if Rp_vsync_delay = 0 then
		    Rp_vsync <= not Rp_vsync;
		end if;
	    end if;
	end if;
    end process;

    hsync <= Rp_hsync;
    vsync <= Rp_vsync;
    active <= Rp_active;
    field <= Rp_field;
    frame_gap <= Rp_frame_gap;
end x;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.sdram_pack.all;

entity dvi_fb is
    port (
	clk: in std_logic;
	-- I/O bus slave
	ce: std_logic;
	bus_write: in std_logic;
	byte_sel: in std_logic_vector(3 downto 0);
	bus_addr: in std_logic_vector(5 downto 2);
	bus_in: in std_logic_vector(31 downto 0);
	bus_out: out std_logic_vector(31 downto 0);
	-- DMA master: todo
	dma_req: out sdram_req_type;
	dma_resp: in sdram_resp_type;
	-- Digital video
	pixclk, pixclk_x5: in std_logic;
	dv_clk, dv_r, dv_g, dv_b: out std_logic_vector(1 downto 0)
    );
end dvi_fb;

architecture x of dvi_fb is
    -- pixel fifo: fills in clk domain, drains in pixclk domain
    type T_pixel_fifo is array (0 to 511) of std_logic_vector(23 downto 0);
    signal M_pixel_fifo: T_pixel_fifo;
    attribute syn_ramstyle: string; -- Lattice Diamond
    attribute syn_ramstyle of M_pixel_fifo: signal is "no_rw_check";

    -- pixclk domain, registers
    signal Rp_fifo_tail: std_logic_vector(8 downto 0);
    signal Rp_from_fifo: std_logic_vector(23 downto 0);
    signal Rp_r, Rp_g, Rp_b: std_logic_vector(7 downto 0);
    signal Rp_hsync_dly, Rp_vsync_dly, Rp_blank_dly: std_logic;

    -- pixclk domain, wires
    signal dv_vsync, dv_hsync, dv_active, dv_field, dv_frame_gap: std_logic;

    -- pixclk -> clk clock domain crossing synchronizers
    signal R_pixel_fifo_sync: std_logic_vector(2 downto 0);
    signal R_frame_gap_sync: std_logic_vector(2 downto 0);

    -- main clk domain, fifo clk -> pixclk clock domain
    signal R_pixel_fifo_tail_cdc: std_logic_vector(8 downto 4);
    signal R_pixel_fifo_head: std_logic_vector(8 downto 0);

    -- main clk domain, framebuffer, registers
    type T_dma_fifo is array (0 to 15) of std_logic_vector(31 downto 0);
    signal M_dma_fifo: T_dma_fifo;
    signal R_dma_base: std_logic_vector(31 downto 2);
    signal R_dma_end: std_logic_vector(31 downto 2);
    signal R_dma_cur: std_logic_vector(31 downto 2);
    signal R_dma_fifo_head, R_dma_fifo_tail: std_logic_vector(3 downto 0);
    attribute syn_ramstyle of M_dma_fifo: signal is "no_rw_check";
    signal R_pixel_index: std_logic_vector(1 downto 0);
    signal R_hcnt: std_logic_vector(8 downto 0);

    -- main clk domain, framebuffer, wires
    signal frame_gap: boolean;
    signal pixel_fifo_needs_more_pixels: boolean;
    signal dma_fifo_may_fetch, dma_fifo_has_data: boolean;
    signal dma_fifo_head_next, dma_fifo_tail_next: std_logic_vector(3 downto 0);

    -- main clk domain, (mostly) static linemode configuration data
    signal R_hdisp: std_logic_vector(11 downto 0);
    signal R_hsyncstart: std_logic_vector(11 downto 0);
    signal R_hsyncend: std_logic_vector(11 downto 0);
    signal R_htotal: std_logic_vector(11 downto 0);
    signal R_vdisp: std_logic_vector(10 downto 0);
    signal R_vsyncstart: std_logic_vector(10 downto 0);
    signal R_vsyncend: std_logic_vector(10 downto 0);
    signal R_vtotal: std_logic_vector(10 downto 0);
    signal R_hsyncn: std_logic;
    signal R_vsyncn: std_logic;
    signal R_interlace: std_logic;

begin
    frame_gap <= R_frame_gap_sync(0) = '1';
    pixel_fifo_needs_more_pixels <=
      R_pixel_fifo_tail_cdc /= R_pixel_fifo_head(8 downto 4) + 1;
    dma_fifo_may_fetch <=
      R_dma_fifo_head(3 downto 2) + 1 /= R_dma_fifo_tail(3 downto 2);
    dma_fifo_has_data <= R_dma_fifo_head /= R_dma_fifo_tail;

    dma_req.addr <= R_dma_cur;
    dma_req.strobe <= '1' when dma_fifo_may_fetch else '0';
    dma_req.burst_len <= x"03";
    dma_req.write <= '0';

    process(clk)
	variable pixel_ready: boolean;
	variable from_dma_fifo: std_logic_vector(31 downto 0);
	variable pixel: std_logic_vector(7 downto 0);
	variable r, g, b: std_logic_vector(7 downto 0);
    begin
	if rising_edge(clk) then
	    pixel_ready := false;

	    if frame_gap then
		-- Pixel output has stopped, prepare for a new frame
		R_dma_cur <= R_dma_base;
		R_pixel_fifo_head <= (others => '0');
		R_dma_fifo_head <= (others => '0');
		R_dma_fifo_tail <= (others => '0');
		R_pixel_index <= (others => '0');
		R_hcnt <= (others => '0');
	    else
		if dma_resp.data_ready = '1' then
		    M_dma_fifo(conv_integer(R_dma_fifo_head)) <=
		      dma_resp.data_out;
		    R_dma_cur <= R_dma_cur + 1;
		    R_dma_fifo_head <= R_dma_fifo_head + 1;
		    R_hcnt <= R_hcnt + 1;
		    if R_interlace = '1'
		      and  R_hcnt = R_hdisp(10 downto 2) - 1 then
			R_hcnt <= (others => '0');
			R_dma_cur <= R_dma_cur + R_hdisp(10 downto 2) + 1;
		    end if;
		    if R_dma_cur = R_dma_end then
			R_dma_cur <= R_dma_base + R_hdisp(10 downto 2);
		    end if;
		end if;

		if pixel_fifo_needs_more_pixels and dma_fifo_has_data then
		    from_dma_fifo := M_dma_fifo(conv_integer(R_dma_fifo_tail));
		    case R_pixel_index is
		    when "00" => pixel := from_dma_fifo(7 downto 0);
		    when "01" => pixel := from_dma_fifo(15 downto 8);
		    when "10" => pixel := from_dma_fifo(23 downto 16);
		    when others => pixel := from_dma_fifo(31 downto 24);
		    end case;
		    r :=  pixel(7 downto 5) & pixel(7 downto 5)
		      & pixel(7 downto 6);
		    g :=  pixel(4 downto 2) & pixel(4 downto 2)
		      & pixel(4 downto 3);
		    b := pixel(1 downto 0) & pixel(1 downto 0)
		      & pixel(1 downto 0) & pixel(1 downto 0);
		    pixel_ready := true;
		    R_pixel_index <= R_pixel_index + 1;
		    if R_pixel_index = "11" then
			R_dma_fifo_tail <= R_dma_fifo_tail + 1;
		    end if;
		end if;
	    end if;

	    if pixel_fifo_needs_more_pixels and pixel_ready then
		M_pixel_fifo(conv_integer(R_pixel_fifo_head)) <= r & g & b;
		R_pixel_fifo_head <= R_pixel_fifo_head + 1;
	    end if;

	    -- pixclk -> clk clock-domain crossing synchronizers
	    R_pixel_fifo_sync <=
	      Rp_fifo_tail(4) & R_pixel_fifo_sync(2 downto 1);
	    R_frame_gap_sync <= dv_frame_gap & R_frame_gap_sync(2 downto 1);
	    if R_pixel_fifo_sync(1) /= R_pixel_fifo_sync(0)
	      or R_frame_gap_sync(0) = '1' then
		R_pixel_fifo_tail_cdc <= Rp_fifo_tail(8 downto 4);
	    end if;

	    -- CPU interface: configuration registers
	    if ce = '1' and bus_write = '1' then
		case bus_addr is
		when x"0" =>
		    if byte_sel(1 downto 0) = "11" then
			R_hdisp <= bus_in(11 downto 0);
		    end if;
		    if byte_sel(3 downto 2) = "11" then
			R_hsyncstart <= bus_in(27 downto 16);
		    end if;
		when x"1" =>
		    if byte_sel(1 downto 0) = "11" then
			R_hsyncend <= bus_in(11 downto 0);
		    end if;
		    if byte_sel(3 downto 2) = "11" then
			R_htotal <= bus_in(27 downto 16);
		    end if;
		when x"2" =>
		    if byte_sel(1 downto 0) = "11" then
			R_vdisp <= bus_in(10 downto 0);
		    end if;
		    if byte_sel(3 downto 2) = "11" then
			R_vsyncstart <= bus_in(26 downto 16);
		    end if;
		when x"3" =>
		    if byte_sel(1 downto 0) = "11" then
			R_vsyncend <= bus_in(10 downto 0);
		    end if;
		    if byte_sel(3 downto 2) = "11" then
			R_vtotal <= bus_in(26 downto 16);
			R_hsyncn <= bus_in(29);
			R_vsyncn <= bus_in(30);
			R_interlace <= bus_in(31);
		    end if;
		when x"4" =>
		    R_dma_base <= bus_in(31 downto 2);
		when x"5" =>
		    R_dma_end <= bus_in(31 downto 2);
		when others =>
		end case;
	    end if;
	end if;
    end process;

    -- CPU read mux
    with bus_addr select bus_out <=
	--x"0" & R_hsyncstart & x"0" & R_hdisp when x"0",
	--x"0" & R_htotal & x"0" & R_hsyncend when x"1",
	--x"0" & '0' & R_vsyncstart & x"0" & '0' & R_vdisp when x"2",
	--R_interlace & R_vsyncn & R_hsyncn & "00"
	--  & R_vtotal & x"0" & '0' & R_vsyncend when x"3",
	R_dma_base & "00" when x"4",
	R_dma_end & "00" when x"5",
	R_dma_cur & "00" when x"6",
	(others => '0') when others;

    I_syncgen: entity work.dv_syncgen
    port map (
	pixclk => pixclk,
	-- mode config
	hdisp => R_hdisp,
	hsyncstart => R_hsyncstart,
	hsyncend => R_hsyncend,
	htotal => R_htotal,
	vdisp => R_vdisp,
	vsyncstart => R_vsyncstart,
	vsyncend => R_vsyncend,
	vtotal => R_vtotal,
	hsyncn => R_hsyncn,
	vsyncn => R_vsyncn,
	interlace => R_interlace,
	-- outputs
	hsync => dv_hsync,
	vsync => dv_vsync,
	active => dv_active,
	field => dv_field,
	frame_gap => dv_frame_gap
    );

    process(pixclk)
    begin
	if rising_edge(pixclk) then
	    -- from line buffer and dv_syncgen to vga2dvid
	    Rp_blank_dly <= not dv_active;
	    Rp_hsync_dly <= dv_hsync;
	    Rp_vsync_dly <= dv_vsync;
	    if dv_frame_gap = '1' then
		Rp_fifo_tail <= (others => '0');
	    elsif dv_active = '1' then
		Rp_fifo_tail <= Rp_fifo_tail + 1;
	    end if;
	    Rp_from_fifo <= M_pixel_fifo(conv_integer(Rp_fifo_tail));
	    Rp_r <= Rp_from_fifo(23 downto 16);
	    Rp_g <= Rp_from_fifo(15 downto 8);
	    Rp_b <= Rp_from_fifo(7 downto 0);
	end if;
    end process;

    I_dvid: entity work.vga2dvid
    generic map (
	C_parallel => false,
	C_ddr => true
    )
    port map (
	clk_pixel => pixclk,
	clk_shift => pixclk_x5,
	in_red => Rp_r,
	in_green => Rp_g,
	in_blue => Rp_b,
	in_hsync => Rp_hsync_dly,
	in_vsync => Rp_vsync_dly,
	in_blank => Rp_blank_dly,
	out_clock => dv_clk,
	out_red => dv_r,
	out_green => dv_g,
	out_blue=> dv_b
    );
end x;
