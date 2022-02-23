--
-- Copyright (c) 2013 - 2022 Marko Zec
-- Copyright (c) 2015 Davor Jadrijevic
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


entity rom is
    generic(
	C_rom_size: natural := 2; -- in KBytes
	C_arch: natural; -- ARCH_MI32 or ARCH_RV32 selects image to preload
	C_big_endian: boolean; -- selects image to preload
	C_boot_spi: boolean -- selects image to preload
    );
    port(
	clk: in std_logic;
	strobe: in std_logic;
	addr: in std_logic_vector(31 downto 2);
	data_ready: out std_logic;
	data_out: out std_logic_vector(31 downto 0)
    );
end rom;

architecture x of rom is
    type T_boot_block_map is array(0 to 7) of boot_block_type;
    constant boot_block_map: T_boot_block_map := (
	boot_sio_mi32el,
	boot_sio_mi32eb,
	boot_rom_mi32el,
	(others => (others => '-')),
	boot_sio_rv32el,
	(others => (others => '-')),
	(others => (others => '-')),
	(others => (others => '-'))
    );

    type T_sel is array(boolean) of natural;
    constant sel: T_sel := (false => 0, true => 1);

    constant boot_block: boot_block_type :=
      boot_block_map(C_arch * 4 + sel(C_boot_spi) * 2 + sel(C_big_endian));

    type rom_type is array(0 to (C_rom_size * 256 - 1))
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
    function boot_block_to_rom(x: boot_block_type; n: natural)
      return rom_type is
	variable y: rom_type;
	variable i,l: natural;
    begin
	y := (others => (others => '0')); -- if '0' is '-' then Xilinx ISE error
	i := n;
	l := x'length;
	while i < l loop
	    y(i / 4) := x(i);
	    i := i + 4;
	end loop;
	return y;
    end boot_block_to_rom;

    signal rom_0: rom_type := boot_block_to_rom(boot_block, 0);
    signal rom_1: rom_type := boot_block_to_rom(boot_block, 1);
    signal rom_2: rom_type := boot_block_to_rom(boot_block, 2);
    signal rom_3: rom_type := boot_block_to_rom(boot_block, 3);

    signal R_ack: std_logic;

begin

    process(clk)
    begin
	if rising_edge(clk) then
	    data_out <= rom_3(conv_integer(addr)) & rom_2(conv_integer(addr))
	      & rom_1(conv_integer(addr)) & rom_0(conv_integer(addr));

	    if strobe = '1' and R_ack = '0' then
		R_ack <= '1';
	    else
		R_ack <= '0';
	    end if;
	end if;
    end process;

    data_ready <= R_ack;
end x;
