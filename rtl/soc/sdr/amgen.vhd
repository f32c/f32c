
--
-- AM transmitter.
--
-- Menlo:
--
-- This generates the carrier wave from a 256Mhz clock and applies a
-- processed 16 bit PCM modulation to the signal.
--
-- It has a filter for the PCM input to perform DC bias removal.
--
-- It operates across two clock domains. The main CPU clock
-- of 50 - 100Mhz (typical), and the radio frequency synthesis
-- clock of 250Mhz.
--
-- Logic in the 250Mhz clock domain is kept as simple as possible
-- to ensure timing closure.
--
-- MenloParkInnovation LLC
-- 03/20/2019
--
-- Started from:

-- FM transmitter
-- (c) Marko Zec
-- LICENSE=BSD

library IEEE;
use IEEE.std_logic_1164.all;
-- use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity amgen is
generic (
	c_use_pcm_in: boolean := true;
	c_fm_acclen: integer := 28;
	c_hz_per_bit: integer := 2; -- Hz FM modulation strength (1, 2 or 4)
	c_remove_dc: boolean := true; -- remove DC offset
	c_fdds: real -- Direct Digitial Synthesis clock frequency.
);
port (
        clk_pcm: in std_logic; -- PCM processing clock from CPU (e.g. 50/100 MHz)
	clk_dds: in std_logic; -- DDS clock must be >2*cw_freq (e.g. 250 MHz)
	cw_freq: in std_logic_vector(31 downto 0);  -- Carrier Wave frequecy
	pcm_in_i: in signed(15 downto 0);  -- Instantaneous signed PCM modulation value I
	pcm_in_q: in signed(15 downto 0);  -- Instantaneous signed PCM modulation value Q
	am_out: out std_logic           -- Pulsed signal to antenna, external filters, FM amplifiers.
);
end amgen;

architecture x of amgen is
	signal fm_acc, fm_inc: signed((C_fm_acclen - 1) downto 0);
	signal R_pcm_avg, R_pcm_ac: signed(15 downto 0);
	signal R_cnt: integer;
	signal R_dds_mul_x1, R_dds_mul_x2: signed(31 downto 0);
	constant C_dds_mul_y: signed(31 downto 0) :=
	    to_signed(integer(2.0**30 / C_fdds * 2.0**28), 32);
	signal R_dds_mul_res: signed(63 downto 0);

begin
    R_pcm_ac <= pcm_in_i - R_pcm_avg; -- subtract average to remove DC offset

    -- Calculate signal average to remove DC offset
    remove_dc_offset: if C_remove_dc generate
    process(clk_pcm)
    variable delta: std_logic_vector(15 downto 0);
    variable R_clk_div: std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk_pcm) then
	    R_clk_div := R_clk_div + 1;
	    if R_clk_div = x"0" then
		if R_pcm_ac > 0 then
		    R_pcm_avg <= R_pcm_avg + 1;
		elsif R_pcm_ac < 0 then
		    R_pcm_avg <= R_pcm_avg - 1;
		end if;
	    end if;
        end if;
    end process;
    end generate;

    --
    -- Calculate current frequency of carrier wave (Frequency modulation)
    -- Removing DC offset
    --
    process (clk_pcm)
    begin
	if (rising_edge(clk_pcm)) then
	    R_dds_mul_x1 <= signed(cw_freq) + R_pcm_ac*c_hz_per_bit;
	end if;
    end process;
	
    --
    -- Generate carrier wave
    --
    process (clk_dds)
    begin
	if (rising_edge(clk_dds)) then
	    -- Cross clock domains
    	    R_dds_mul_x2 <= R_dds_mul_x1;
	    R_dds_mul_res <= R_dds_mul_x2 * C_dds_mul_y;
	    fm_inc <= R_dds_mul_res(57 downto (58 - C_fm_acclen));
	    fm_acc <= fm_acc + fm_inc;
	end if;
    end process;

    am_out <= fm_acc((C_fm_acclen - 1));
end;
