--
-- Copyright (c) 2016 Emard
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

-- emulation of the 16-bit SRAM chip using BRAM
-- it is useful for d/i cache coherence test.
-- it is not timing exact as real chip:
-- it uses system clock (sampled on falling edge)
-- real chip doesn't use system clock but has timing on its own.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity sram_emu is
    generic (
	C_addr_width: integer := 11 -- address width defines RAM size 11 bits -> 2^11 * 2 byte = 2048*2 = 4K
    );
    port (
	clk: in std_logic;
	-- To physical SRAM signals
	sram_a: in std_logic_vector(C_addr_width-1 downto 0);
	sram_d: inout std_logic_vector(15 downto 0);
	sram_wel, sram_lbl, sram_ubl: in std_logic
    );
end sram_emu;

architecture Structure of sram_emu is
    -- SRAM emulation signals for internal BRAM
    signal sram_we_lower, sram_we_upper: std_logic;
    signal from_sram_lower, from_sram_upper: std_logic_vector(7 downto 0);
    signal clk_n : std_logic;
begin

    clk_n <= not clk;
  
    sram_emul_lower: entity work.bram_true2p_1clk
    generic map (
        dual_port => false,
        data_width => 8,
        addr_width => C_addr_width
    )
    port map (
        clk => clk_n,
        we_a => sram_we_lower,
        addr_a => sram_a(C_addr_width-1 downto 0),
        data_in_a => sram_d(7 downto 0), data_out_a => from_sram_lower,
	we_b => '0', addr_b => (others => '0'),
        data_in_b => (others => '0'), data_out_b => open
    );

    sram_emul_upper: entity work.bram_true2p_1clk
    generic map (
        dual_port => false,
        data_width => 8,
        addr_width => C_addr_width
    )
    port map (
        clk => clk_n,
        we_a => sram_we_upper,
        addr_a => sram_a(C_addr_width-1 downto 0),
        data_in_a => sram_d(15 downto 8), data_out_a => from_sram_upper,
	we_b => '0', addr_b => (others => '0'),
        data_in_b => (others => '0'), data_out_b => open
    );

    sram_d(7 downto 0) <= from_sram_lower when sram_wel = '1'
      else (others => 'Z');
    sram_d(15 downto 8) <= from_sram_upper when sram_wel = '1'
      else (others => 'Z');
    sram_we_lower <= not (sram_wel or sram_lbl);
    sram_we_upper <= not (sram_wel or sram_ubl);

end Structure;
