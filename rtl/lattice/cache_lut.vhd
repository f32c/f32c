--
-- Copyright 2013 University of Zagreb, Croatia.
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
-- THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
--

-- $Id: reg1w2r.vhd 821 2012-01-24 11:40:59Z marko $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library xp2;
use xp2.components.all;


entity cache_lut is
    port(
	clk: in std_logic;
	addr: in std_logic_vector(9 downto 0);
	rd_data: out std_logic_vector(31 downto 0);
	rd_tag: out std_logic_vector(11 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_tag: in std_logic_vector(11 downto 0);
	wr_enable: in std_logic
    );
end cache_lut;

architecture Behavioral of cache_lut is
    signal to_bram, from_bram: std_logic_vector(3 * 18 - 1 downto 0);
begin

    rd_data <= from_bram(31 downto 0);
    rd_tag <= from_bram(43 downto 32);
    to_bram(31 downto 0) <= wr_data;
    to_bram(43 downto 32) <= wr_tag;

    block_iter: for b in 0 to 2 generate
    begin
    bram_dp: entity work.bram_dp_x18
    port map (
	clk_a => clk, clk_b => clk,
	ce_a => '1', ce_b => '0',
	we_a => wr_enable, we_b => '0',
	res => '0',
	addr_a => addr, addr_b => (others => '0'),
	data_in_a => to_bram(b * 18 + 17 downto b * 18),
	data_in_b => (others => '0'),
	data_out_a => from_bram(b * 18 + 17 downto b * 18),
	data_out_b => open
    );
    end generate block_iter;
end Behavioral;
