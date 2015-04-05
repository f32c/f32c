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
use work.bootloader.all; -- ram initializaton constants boot_0..3 from bootloader.vhd

-- this bram module doesn't follow exactly the BRAM dmem control lines
-- but is seems to work with f32c

-- this bram outputs dmem_data_out always when not dmem_write

-- it should output dmem_data_out only when dmem_addr_strobe, and
-- this could be done by uncommenting if dmem_byte_sel_0 = '1'
-- but in this case it would require 2x more bram blocks
-- known to fix 2x bram waste on Altera Cyclone 4E, allowing bram size of 16K
-- this method doesn't fix 2x bram waste on Xilinx ZYBO

entity bram is
    generic(
	C_mem_size: integer
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
    type bram_type is array(0 to (C_mem_size * 256 - 1))
      of std_logic_vector(7 downto 0);

    signal bram_0: bram_type := ( 
	boot_0(  0),boot_0(  1),boot_0(  2),boot_0(  3),boot_0(  4),boot_0(  5),boot_0(  6),boot_0(  7),
	boot_0(  8),boot_0(  9),boot_0( 10),boot_0( 11),boot_0( 12),boot_0( 13),boot_0( 14),boot_0( 15),
	boot_0( 16),boot_0( 17),boot_0( 18),boot_0( 19),boot_0( 20),boot_0( 21),boot_0( 22),boot_0( 23),
	boot_0( 24),boot_0( 25),boot_0( 26),boot_0( 27),boot_0( 28),boot_0( 29),boot_0( 30),boot_0( 31),
	boot_0( 32),boot_0( 33),boot_0( 34),boot_0( 35),boot_0( 36),boot_0( 37),boot_0( 38),boot_0( 39),
	boot_0( 40),boot_0( 41),boot_0( 42),boot_0( 43),boot_0( 44),boot_0( 45),boot_0( 46),boot_0( 47),
	boot_0( 48),boot_0( 49),boot_0( 50),boot_0( 51),boot_0( 52),boot_0( 53),boot_0( 54),boot_0( 55),
	boot_0( 56),boot_0( 57),boot_0( 58),boot_0( 59),boot_0( 60),boot_0( 61),boot_0( 62),boot_0( 63),
	boot_0( 64),boot_0( 65),boot_0( 66),boot_0( 67),boot_0( 68),boot_0( 69),boot_0( 70),boot_0( 71),
	boot_0( 72),boot_0( 73),boot_0( 74),boot_0( 75),boot_0( 76),boot_0( 77),boot_0( 78),boot_0( 79),
	boot_0( 80),boot_0( 81),boot_0( 82),boot_0( 83),boot_0( 84),boot_0( 85),boot_0( 86),boot_0( 87),
	boot_0( 88),boot_0( 89),boot_0( 90),boot_0( 91),boot_0( 92),boot_0( 93),boot_0( 94),boot_0( 95),
	boot_0( 96),boot_0( 97),boot_0( 98),boot_0( 99),boot_0(100),boot_0(101),boot_0(102),boot_0(103),
	boot_0(104),boot_0(105),boot_0(106),boot_0(107),boot_0(108),boot_0(109),boot_0(110),boot_0(111),
	boot_0(112),boot_0(113),boot_0(114),boot_0(115),boot_0(116),boot_0(117),boot_0(118),boot_0(119),
	boot_0(120),boot_0(121),boot_0(122),boot_0(123),boot_0(124),boot_0(125),boot_0(126),boot_0(127),
        others => x"00"
    );

    signal bram_1: bram_type := (
	boot_1(  0),boot_1(  1),boot_1(  2),boot_1(  3),boot_1(  4),boot_1(  5),boot_1(  6),boot_1(  7),
	boot_1(  8),boot_1(  9),boot_1( 10),boot_1( 11),boot_1( 12),boot_1( 13),boot_1( 14),boot_1( 15),
	boot_1( 16),boot_1( 17),boot_1( 18),boot_1( 19),boot_1( 20),boot_1( 21),boot_1( 22),boot_1( 23),
	boot_1( 24),boot_1( 25),boot_1( 26),boot_1( 27),boot_1( 28),boot_1( 29),boot_1( 30),boot_1( 31),
	boot_1( 32),boot_1( 33),boot_1( 34),boot_1( 35),boot_1( 36),boot_1( 37),boot_1( 38),boot_1( 39),
	boot_1( 40),boot_1( 41),boot_1( 42),boot_1( 43),boot_1( 44),boot_1( 45),boot_1( 46),boot_1( 47),
	boot_1( 48),boot_1( 49),boot_1( 50),boot_1( 51),boot_1( 52),boot_1( 53),boot_1( 54),boot_1( 55),
	boot_1( 56),boot_1( 57),boot_1( 58),boot_1( 59),boot_1( 60),boot_1( 61),boot_1( 62),boot_1( 63),
	boot_1( 64),boot_1( 65),boot_1( 66),boot_1( 67),boot_1( 68),boot_1( 69),boot_1( 70),boot_1( 71),
	boot_1( 72),boot_1( 73),boot_1( 74),boot_1( 75),boot_1( 76),boot_1( 77),boot_1( 78),boot_1( 79),
	boot_1( 80),boot_1( 81),boot_1( 82),boot_1( 83),boot_1( 84),boot_1( 85),boot_1( 86),boot_1( 87),
	boot_1( 88),boot_1( 89),boot_1( 90),boot_1( 91),boot_1( 92),boot_1( 93),boot_1( 94),boot_1( 95),
	boot_1( 96),boot_1( 97),boot_1( 98),boot_1( 99),boot_1(100),boot_1(101),boot_1(102),boot_1(103),
	boot_1(104),boot_1(105),boot_1(106),boot_1(107),boot_1(108),boot_1(109),boot_1(110),boot_1(111),
	boot_1(112),boot_1(113),boot_1(114),boot_1(115),boot_1(116),boot_1(117),boot_1(118),boot_1(119),
	boot_1(120),boot_1(121),boot_1(122),boot_1(123),boot_1(124),boot_1(125),boot_1(126),boot_1(127),
	others => x"00"
    );

    signal bram_2: bram_type := (
	boot_2(  0),boot_2(  1),boot_2(  2),boot_2(  3),boot_2(  4),boot_2(  5),boot_2(  6),boot_2(  7),
	boot_2(  8),boot_2(  9),boot_2( 10),boot_2( 11),boot_2( 12),boot_2( 13),boot_2( 14),boot_2( 15),
	boot_2( 16),boot_2( 17),boot_2( 18),boot_2( 19),boot_2( 20),boot_2( 21),boot_2( 22),boot_2( 23),
	boot_2( 24),boot_2( 25),boot_2( 26),boot_2( 27),boot_2( 28),boot_2( 29),boot_2( 30),boot_2( 31),
	boot_2( 32),boot_2( 33),boot_2( 34),boot_2( 35),boot_2( 36),boot_2( 37),boot_2( 38),boot_2( 39),
	boot_2( 40),boot_2( 41),boot_2( 42),boot_2( 43),boot_2( 44),boot_2( 45),boot_2( 46),boot_2( 47),
	boot_2( 48),boot_2( 49),boot_2( 50),boot_2( 51),boot_2( 52),boot_2( 53),boot_2( 54),boot_2( 55),
	boot_2( 56),boot_2( 57),boot_2( 58),boot_2( 59),boot_2( 60),boot_2( 61),boot_2( 62),boot_2( 63),
	boot_2( 64),boot_2( 65),boot_2( 66),boot_2( 67),boot_2( 68),boot_2( 69),boot_2( 70),boot_2( 71),
	boot_2( 72),boot_2( 73),boot_2( 74),boot_2( 75),boot_2( 76),boot_2( 77),boot_2( 78),boot_2( 79),
	boot_2( 80),boot_2( 81),boot_2( 82),boot_2( 83),boot_2( 84),boot_2( 85),boot_2( 86),boot_2( 87),
	boot_2( 88),boot_2( 89),boot_2( 90),boot_2( 91),boot_2( 92),boot_2( 93),boot_2( 94),boot_2( 95),
	boot_2( 96),boot_2( 97),boot_2( 98),boot_2( 99),boot_2(100),boot_2(101),boot_2(102),boot_2(103),
	boot_2(104),boot_2(105),boot_2(106),boot_2(107),boot_2(108),boot_2(109),boot_2(110),boot_2(111),
	boot_2(112),boot_2(113),boot_2(114),boot_2(115),boot_2(116),boot_2(117),boot_2(118),boot_2(119),
	boot_2(120),boot_2(121),boot_2(122),boot_2(123),boot_2(124),boot_2(125),boot_2(126),boot_2(127),
	others => x"00"
    );
    signal bram_3: bram_type := (
	boot_3(  0),boot_3(  1),boot_3(  2),boot_3(  3),boot_3(  4),boot_3(  5),boot_3(  6),boot_3(  7),
	boot_3(  8),boot_3(  9),boot_3( 10),boot_3( 11),boot_3( 12),boot_3( 13),boot_3( 14),boot_3( 15),
	boot_3( 16),boot_3( 17),boot_3( 18),boot_3( 19),boot_3( 20),boot_3( 21),boot_3( 22),boot_3( 23),
	boot_3( 24),boot_3( 25),boot_3( 26),boot_3( 27),boot_3( 28),boot_3( 29),boot_3( 30),boot_3( 31),
	boot_3( 32),boot_3( 33),boot_3( 34),boot_3( 35),boot_3( 36),boot_3( 37),boot_3( 38),boot_3( 39),
	boot_3( 40),boot_3( 41),boot_3( 42),boot_3( 43),boot_3( 44),boot_3( 45),boot_3( 46),boot_3( 47),
	boot_3( 48),boot_3( 49),boot_3( 50),boot_3( 51),boot_3( 52),boot_3( 53),boot_3( 54),boot_3( 55),
	boot_3( 56),boot_3( 57),boot_3( 58),boot_3( 59),boot_3( 60),boot_3( 61),boot_3( 62),boot_3( 63),
	boot_3( 64),boot_3( 65),boot_3( 66),boot_3( 67),boot_3( 68),boot_3( 69),boot_3( 70),boot_3( 71),
	boot_3( 72),boot_3( 73),boot_3( 74),boot_3( 75),boot_3( 76),boot_3( 77),boot_3( 78),boot_3( 79),
	boot_3( 80),boot_3( 81),boot_3( 82),boot_3( 83),boot_3( 84),boot_3( 85),boot_3( 86),boot_3( 87),
	boot_3( 88),boot_3( 89),boot_3( 90),boot_3( 91),boot_3( 92),boot_3( 93),boot_3( 94),boot_3( 95),
	boot_3( 96),boot_3( 97),boot_3( 98),boot_3( 99),boot_3(100),boot_3(101),boot_3(102),boot_3(103),
	boot_3(104),boot_3(105),boot_3(106),boot_3(107),boot_3(108),boot_3(109),boot_3(110),boot_3(111),
	boot_3(112),boot_3(113),boot_3(114),boot_3(115),boot_3(116),boot_3(117),boot_3(118),boot_3(119),
	boot_3(120),boot_3(121),boot_3(122),boot_3(123),boot_3(124),boot_3(125),boot_3(126),boot_3(127),
	others => x"00"
    );

    -- Lattice Diamond attributes
    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bram_0: signal is "no_rw_check";
    attribute syn_ramstyle of bram_1: signal is "no_rw_check";
    attribute syn_ramstyle of bram_2: signal is "no_rw_check";
    attribute syn_ramstyle of bram_3: signal is "no_rw_check";

    -- Xilinx XST attributes
    attribute ram_style: string;
    attribute ram_style of bram_0: signal is "no_rw_check";
    attribute ram_style of bram_1: signal is "no_rw_check";
    attribute ram_style of bram_2: signal is "no_rw_check";
    attribute ram_style of bram_3: signal is "no_rw_check";

    -- Altera Quartus attributes
    attribute ramstyle: string;
    attribute ramstyle of bram_0: signal is "no_rw_check";
    attribute ramstyle of bram_1: signal is "no_rw_check";
    attribute ramstyle of bram_2: signal is "no_rw_check";
    attribute ramstyle of bram_3: signal is "no_rw_check";

    signal ibram_0, ibram_1, ibram_2, ibram_3: std_logic_vector(7 downto 0);
    signal dbram_0, dbram_1, dbram_2, dbram_3: std_logic_vector(7 downto 0);

    signal read_enable, write_enable: boolean;
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

    process(clk)
    begin
	if falling_edge(clk) then
	    if write_enable_0 = '1' then
                bram_0(conv_integer(dmem_addr)) <=
		      dmem_data_in(7 downto 0);
                dbram_0 <= dmem_data_in(7 downto 0);
            else
            -- end if;
            -- if dmem_byte_sel_0 = '1' then
                dbram_0 <= bram_0(conv_integer(dmem_addr));
            end if;
	    if imem_addr_strobe = '1' then
		ibram_0 <= bram_0(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
            if write_enable_1 = '1' then
                bram_1(conv_integer(dmem_addr)) <=
		      dmem_data_in(15 downto 8);
                dbram_1 <= dmem_data_in(15 downto 8);
            else
            -- end if;
            -- if dmem_byte_sel_1 = '1' then
	        dbram_1 <= bram_1(conv_integer(dmem_addr));
            end if;
	    if imem_addr_strobe = '1' then
		ibram_1 <= bram_1(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
            if write_enable_2 = '1' then
                bram_2(conv_integer(dmem_addr)) <=
		      dmem_data_in(23 downto 16);
                dbram_2 <= dmem_data_in(23 downto 16);
            else
            -- end if;
            -- if dmem_byte_sel_2 = '1' then
                dbram_2 <= bram_2(conv_integer(dmem_addr));
            end if;
	    if imem_addr_strobe = '1' then
		ibram_2 <= bram_2(conv_integer(imem_addr));
	    end if;
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
            if write_enable_3 = '1' then
                bram_3(conv_integer(dmem_addr)) <=
		      dmem_data_in(31 downto 24);
                dbram_3 <= dmem_data_in(31 downto 24);
            else
            -- end if;
            -- if dmem_byte_sel_3 = '1' then
                dbram_3 <= bram_3(conv_integer(dmem_addr));
            end if;
	    if imem_addr_strobe = '1' then
		ibram_3 <= bram_3(conv_integer(imem_addr));
	    end if;
	end if;
    end process;
end x;
