--
-- Copyright 2013 Marko Zec, University of Zagreb
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

-- $Id: bram.vhd 2624 2015-03-24 21:24:02Z marko $


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bram is
    generic(
	C_mem_size: integer -- not used here, fixed 4x4 = 16K ram
    );
    port(
	clk: in std_logic;
	imem_addr_strobe: in std_logic;
	imem_data_ready: out std_logic;
	imem_addr: in std_logic_vector(31 downto 2);
	imem_data_out: out std_logic_vector(31 downto 0);
	dmem_addr_strobe: in std_logic;
	dmem_data_ready: out std_logic;
	dmem_write: in std_logic;
	dmem_byte_sel: in std_logic_vector(3 downto 0);
	dmem_addr: in std_logic_vector(31 downto 2);
	dmem_data_in: in std_logic_vector(31 downto 0);
	dmem_data_out: out std_logic_vector(31 downto 0)
    );
end bram;

architecture x of bram is
    signal ibram_0, ibram_1, ibram_2, ibram_3: std_logic_vector(7 downto 0);
    signal dbram_0, dbram_1, dbram_2, dbram_3: std_logic_vector(7 downto 0);
    signal write_enable: boolean;
    signal dmem_byte_sel_0, dmem_byte_sel_1, dmem_byte_sel_2, dmem_byte_sel_3 : std_logic;
    signal write_enable_0, write_enable_1, write_enable_2, write_enable_3: std_logic;
begin
    imem_data_ready <= '1';
    dmem_data_ready <= '1';

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    write_enable <=
      dmem_write = '1' and dmem_addr(19 downto 9) /= x"00" & "000";
    
    dmem_byte_sel_0 <= '1' when dmem_addr_strobe = '1' and dmem_byte_sel(0) = '1' else '0';
    dmem_byte_sel_1 <= '1' when dmem_addr_strobe = '1' and dmem_byte_sel(1) = '1' else '0';
    dmem_byte_sel_2 <= '1' when dmem_addr_strobe = '1' and dmem_byte_sel(2) = '1' else '0';
    dmem_byte_sel_3 <= '1' when dmem_addr_strobe = '1' and dmem_byte_sel(3) = '1' else '0';
    
    write_enable_0 <= '1' when write_enable and dmem_byte_sel_0 = '1'  else '0';
    write_enable_1 <= '1' when write_enable and dmem_byte_sel_1 = '1'  else '0';
    write_enable_2 <= '1' when write_enable and dmem_byte_sel_2 = '1'  else '0';
    write_enable_3 <= '1' when write_enable and dmem_byte_sel_3 = '1'  else '0';

    -- use Quartus II -> Tools -> Megafunction Wizard to
    -- create Registered Dual Port BRAM
    -- have ready intel hex files for bootloader initial content
    ram_16k: if C_mem_size = 16 generate
    altera_bram_0: entity work.bram_cyclone4e_4k
    port map (
      address_a => dmem_addr(13 downto 2),
         data_a => dmem_data_in(7 downto 0),
         wren_a => write_enable_0,
         rden_a => dmem_byte_sel_0,
            q_a => dbram_0,
      address_b => imem_addr(13 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_0,
      clock => clk
    );

    altera_bram_1: entity work.bram_cyclone4e_4k
    port map (
      address_a => dmem_addr(13 downto 2),
         data_a => dmem_data_in(15 downto 8),
         wren_a => write_enable_1,
         rden_a => dmem_byte_sel_1,
            q_a => dbram_1,
      address_b => imem_addr(13 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_1,
      clock => clk
    );

    altera_bram_2: entity work.bram_cyclone4e_4k
    port map (
      address_a => dmem_addr(13 downto 2),
         data_a => dmem_data_in(23 downto 16),
         wren_a => write_enable_2,
         rden_a => dmem_byte_sel_2,
            q_a => dbram_2,
      address_b => imem_addr(13 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_2,
      clock => clk
    );

    altera_bram_3: entity work.bram_cyclone4e_4k
    port map (
      address_a => dmem_addr(13 downto 2),
         data_a => dmem_data_in(31 downto 24),
         wren_a => write_enable_3,
         rden_a => dmem_byte_sel_3,
            q_a => dbram_3,
      address_b => imem_addr(13 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_3,
      clock => clk
    );
    end generate;

    ram_32k: if C_mem_size = 32 generate
    altera_bram_0: entity work.bram_cyclone4e_8k
    port map (
      address_a => dmem_addr(14 downto 2),
         data_a => dmem_data_in(7 downto 0),
         wren_a => write_enable_0,
         rden_a => dmem_byte_sel_0,
            q_a => dbram_0,
      address_b => imem_addr(14 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_0,
      clock => clk
    );

    altera_bram_1: entity work.bram_cyclone4e_8k
    port map (
      address_a => dmem_addr(14 downto 2),
         data_a => dmem_data_in(15 downto 8),
         wren_a => write_enable_1,
         rden_a => dmem_byte_sel_1,
            q_a => dbram_1,
      address_b => imem_addr(14 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_1,
      clock => clk
    );

    altera_bram_2: entity work.bram_cyclone4e_8k
    port map (
      address_a => dmem_addr(14 downto 2),
         data_a => dmem_data_in(23 downto 16),
         wren_a => write_enable_2,
         rden_a => dmem_byte_sel_2,
            q_a => dbram_2,
      address_b => imem_addr(14 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_2,
      clock => clk
    );

    altera_bram_3: entity work.bram_cyclone4e_8k
    port map (
      address_a => dmem_addr(14 downto 2),
         data_a => dmem_data_in(31 downto 24),
         wren_a => write_enable_3,
         rden_a => dmem_byte_sel_3,
            q_a => dbram_3,
      address_b => imem_addr(14 downto 2),
         data_b => (others => '-'),
         wren_b => '0',
         rden_b => imem_addr_strobe,
            q_b => ibram_3,
      clock => clk
    );
    end generate;

end x;
