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

    function boot_block_to_bram(x: boot_block_type) return bram_type is
      variable y: bram_type;
      variable i: integer;
    begin
        y := (others => x"00");
        for i in x'range loop
          y(i) := x(i);
        end loop;
        return y;
    end boot_block_to_bram;
      
    signal bram_0: bram_type := boot_block_to_bram(boot_0);
    signal bram_1: bram_type := boot_block_to_bram(boot_1);
    signal bram_2: bram_type := boot_block_to_bram(boot_2);
    signal bram_3: bram_type := boot_block_to_bram(boot_3);

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
