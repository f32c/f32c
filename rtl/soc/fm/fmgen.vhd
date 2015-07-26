-- FM transmitter
-- (c) Marko Zec
-- LICENSE=BSD

-- This module can be used for any FM range

-- when used with FM RADIO 87-108 kHz
-- maximum frequency deviation is 75 kHz
-- input pcm value has range -32767..+32767
-- and corresponds to frequency deviation
-- of 2x pcm value -65536 .. +65536 Hz

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity fmgen is
generic (
	C_use_pcm_in: boolean := true;
	C_fm_acclen: integer := 28;
	C_fdds: real := 250000000.0 -- input clock frequency
);
port (
        clk_pcm: in std_logic; -- PCM processing clock, any (e.g. 25 MHz)
	clk_dds: in std_logic; -- DDS clock must be >2*cw_freq (e.g. 250 MHz)
	cw_freq: in std_logic_vector(31 downto 0);
	pcm_in: in signed(15 downto 0); -- FM swing +-2x this amplitude in Hz
	fm_out: out std_logic
);
end fmgen;

architecture x of fmgen is
	signal fm_acc, fm_inc: std_logic_vector((C_fm_acclen - 1) downto 0);

	signal R_pcm, R_pcm_avg: signed(15 downto 0);
	signal R_cnt: integer;
	signal R_dds_mul_x1, R_dds_mul_x2: std_logic_vector(31 downto 0);
	constant C_dds_mul_y: std_logic_vector(31 downto 0) :=
	    std_logic_vector(conv_signed(integer(2.0**30 / C_fdds * 2.0**28), 32));
	signal R_dds_mul_res: std_logic_vector(63 downto 0);

begin
    R_pcm <= pcm_in;

    -- Calculate signal average to remove DC offset
    process(clk_pcm)
    variable delta: std_logic_vector(15 downto 0);
    variable R_clk_div: std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk_pcm) then
	    R_clk_div := R_clk_div + 1;
	    if R_clk_div = x"0" then
		if (R_pcm - R_pcm_avg) > 0 then
		    R_pcm_avg <= R_pcm_avg + 1;
		-- elsif R_pcm < R_pcm_avg then
		else
		    R_pcm_avg <= R_pcm_avg - 1;
		end if;
	    end if;
        end if;
    end process;

    --
    -- Calculate current frequency of carrier wave (Frequency modulation)
    -- Removing DC offset
    --
    process (clk_pcm)
    begin
	if (rising_edge(clk_pcm)) then
	    R_dds_mul_x1 <= cw_freq + std_logic_vector(resize((R_pcm-R_pcm_avg) & "0", 32)); -- "0" multiply by 2
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

    fm_out <= fm_acc((C_fm_acclen - 1));
end;
