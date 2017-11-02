-- Author: EMARD
-- License: BSD
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sigmadelta is
    port (
	clk: in std_logic;
	in_pcm_l, in_pcm_r: in signed(15 downto 0);
	out_l, out_r: out std_logic
    );
end sigmadelta;

architecture Behavioral of sigmadelta is
--    signal R_dma_first_addr, R_dma_last_addr: std_logic_vector(29 downto 2);
--    signal R_dma_cur_addr: std_logic_vector(29 downto 2);
--    signal R_dma_trigger_acc, R_dma_trigger_incr: std_logic_vector(23 downto 0);
--    signal R_dma_needs_refill: boolean;
--    signal R_dma_data_l, R_dma_data_r: signed(15 downto 0);
--    signal R_vol_l, R_vol_r: signed(15 downto 0);
--    signal R_pcm_data_l, R_pcm_data_r: signed(15 downto 0);
    signal R_pcm_unsigned_data_l, R_pcm_unsigned_data_r: std_logic_vector(15 downto 0);
    signal R_dac_acc_l, R_dac_acc_r: std_logic_vector(16 downto 0);

begin
    process(clk)
    begin
	if rising_edge(clk) then
	    -- PCM data from RAM normally should have average 0 (removed DC offset)
            -- for purpose of PCM generation here is
            -- conversion to unsigned std_logic_vector
            -- by inverting MSB bit (effectively adding 0x8000)
            R_pcm_unsigned_data_l <= std_logic_vector( (not in_pcm_l(15)) & in_pcm_l(14 downto 0) );
            R_pcm_unsigned_data_r <= std_logic_vector( (not in_pcm_r(15)) & in_pcm_r(14 downto 0) );
	    -- Output 1-bit DAC
	    R_dac_acc_l <= (R_dac_acc_l(16) & R_pcm_unsigned_data_l) + R_dac_acc_l;
	    R_dac_acc_r <= (R_dac_acc_r(16) & R_pcm_unsigned_data_r) + R_dac_acc_r;
	end if;
    end process;

    -- PWM output to 3.5mm jack (earphones)
    out_l <= R_dac_acc_l(16);
    out_r <= R_dac_acc_r(16);
end Behavioral;
