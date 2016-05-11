--
-- Copyright (c) 2013 - 2015 Marko Zec, University of Zagreb
-- Copyright (c) 2015 Davor Jadrijevic
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

-- BRAM block from address 0
-- contains f32c bootloader, either 512 (SIO) or 1024 (SIO + SPI) bytes long
-- BRAM is initialized with bootloader content at loading of FPGA bitstream

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.f32c_pack.all;
use work.boot_block_pack.all;
use work.boot_sio_mi32el.all;
use work.boot_sio_mi32eb.all;
use work.boot_sio_rv32el.all;
use work.boot_rom_mi32el.all;


entity bram is
    generic(
	C_bram_size: integer; -- in KBytes
	C_arch: integer; -- ARCH_MI32 or ARCH_RV32
	C_big_endian: boolean;
	C_boot_spi: boolean;
	C_write_protect_bootloader: boolean := true
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
    type T_sel_endian is array(boolean) of integer;
    constant sel_endian: T_sel_endian := (false => 0, true => 2);

    type T_sel_spi is array(boolean) of integer;
    constant sel_spi: T_sel_spi := (false => 0, true => 4);

    type T_boot_block_select is array(0 to 7) of boot_block_type;
    constant boot_block_select: T_boot_block_select := (
	 --  (arch, big endian, spi)
	(ARCH_MI32 + sel_endian(false)) + sel_spi(false) => boot_sio_mi32el,
	(ARCH_MI32 + sel_endian(true)) + sel_spi(false) => boot_sio_mi32eb,
	(ARCH_RV32 + sel_endian(false)) + sel_spi(false) => boot_sio_rv32el,
	(ARCH_RV32 + sel_endian(true)) + sel_spi(false) => (others => (others => '0')), -- RISC-V currently has no big endian support
	(ARCH_MI32 + sel_endian(false)) + sel_spi(true) => boot_rom_mi32el,
	(ARCH_MI32 + sel_endian(true)) + sel_spi(true) => (others => (others => '0')),
	(ARCH_RV32 + sel_endian(false)) + sel_spi(true) => (others => (others => '0')),
	(ARCH_RV32 + sel_endian(true)) + sel_spi(true) => (others => (others => '0')) -- RISC-V currently has no big endian support
    );

    constant boot_block: boot_block_type := boot_block_select(C_arch + sel_endian(C_big_endian) + sel_spi(C_boot_spi));

    type bram_type is array(0 to (C_bram_size * 256 - 1))
      of std_logic_vector(7 downto 0);

    --
    -- Xilinx ISE 14.7 for Spartan-3 will abort with error about loop 
    -- iteration limit >64 exceeded.  We need 128 iterations here.
    -- If buiding with makefile, edit file xilinx.opt file and
    -- append this line (give sufficiently large limit):
    -- -loop_iteration_limit 2048
    -- In ISE GUI, open the Design tab, right click on Synthesize - XST,
    -- choose Process Properties, choose Property display level: Advanced,
    -- scroll down to the "Other XST Command Line Options" field and
    -- enter: -loop_iteration_limit 2048
    --

    function boot_block_to_bram(x: boot_block_type; n: integer)
      return bram_type is
	variable y: bram_type;
	variable i,l: integer;
    begin
	y := (others => x"00");
	i := n;
	l := x'length;
	while(i < l) loop
	    y(i/4) := x(i);
	    i := i + 4;
	end loop;
	return y;
    end boot_block_to_bram;

    signal bram_0: bram_type := boot_block_to_bram(boot_block, 0);
    signal bram_1: bram_type := boot_block_to_bram(boot_block, 1);
    signal bram_2: bram_type := boot_block_to_bram(boot_block, 2);
    signal bram_3: bram_type := boot_block_to_bram(boot_block, 3);

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

    signal write_enable, write_strobe: boolean;

begin

    dmem_data_out <= dbram_3 & dbram_2 & dbram_1 & dbram_0;
    imem_data_out <= ibram_3 & ibram_2 & ibram_1 & ibram_0;

    write_strobe <= dmem_addr_strobe = '1' and dmem_write = '1';

    G_rom_protection:
    if C_write_protect_bootloader generate
    with C_bram_size select write_enable <=
	dmem_addr(10 downto 10) /= 0 and write_strobe when 2,
	dmem_addr(11 downto 10) /= 0 and write_strobe when 4,
	dmem_addr(12 downto 10) /= 0 and write_strobe when 8,
	dmem_addr(13 downto 10) /= 0 and write_strobe when 16,
	dmem_addr(14 downto 10) /= 0 and write_strobe when 32,
	dmem_addr(15 downto 10) /= 0 and write_strobe when 64,
	dmem_addr(16 downto 10) /= 0 and write_strobe when 128,
	dmem_addr(17 downto 10) /= 0 and write_strobe when 256,
	dmem_addr(18 downto 10) /= 0 and write_strobe when 512,
	dmem_addr(19 downto 10) /= 0 and write_strobe when 1024,
	dmem_write = '1' when others;
    end generate;
    G_flat_ram:
    if not C_write_protect_bootloader generate
	write_enable <= write_strobe;
    end generate;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(0) = '1' and write_enable then
		bram_0(conv_integer(dmem_addr)) <= dmem_data_in(7 downto 0);
	    end if;
	    dbram_0 <= bram_0(conv_integer(dmem_addr));
	    ibram_0 <= bram_0(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(1) = '1' and write_enable then
		bram_1(conv_integer(dmem_addr)) <= dmem_data_in(15 downto 8);
	    end if;
	    dbram_1 <= bram_1(conv_integer(dmem_addr));
	    ibram_1 <= bram_1(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(2) = '1' and write_enable then
		bram_2(conv_integer(dmem_addr)) <= dmem_data_in(23 downto 16);
	    end if;
	    dbram_2 <= bram_2(conv_integer(dmem_addr));
	    ibram_2 <= bram_2(conv_integer(imem_addr));
	end if;
    end process;

    process(clk)
    begin
	if falling_edge(clk) then
	    if dmem_byte_sel(3) = '1' and write_enable then
		bram_3(conv_integer(dmem_addr)) <= dmem_data_in(31 downto 24);
	    end if;
	    dbram_3 <= bram_3(conv_integer(dmem_addr));
	    ibram_3 <= bram_3(conv_integer(imem_addr));
	end if;
    end process;

    imem_data_ready <= '1';
    dmem_data_ready <= '1';
end x;
