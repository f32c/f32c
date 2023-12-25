--
-- Copyright (c) 2023 Marko Zec
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

library ieee;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.std_logic_textio.all;


entity rom is
    generic(
	C_rom_size: natural := 2; -- in KBytes
	C_arch: natural;
	C_big_endian: boolean;
	C_boot_spi: boolean;
	C_srec_file: string := ""
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
    type T_rom is array(0 to (C_rom_size * 256 - 1))
      of std_logic_vector(31 downto 0);

    function F_srec_file return string is
    begin
	if C_srec_file /= "" then
	    return C_srec_file;
	elsif C_arch = 0 then -- MIPS
	    if C_big_endian then
		if C_boot_spi then
		    return "boot/mipseb_spi.srec";
		else
		    return "boot/mipseb_sio.srec";
		end if;
	    else
		if C_boot_spi then
		    return "boot/mipsel_spi.srec";
		else
		    return "boot/mipsel_sio.srec";
		end if;
	    end if;
	elsif C_arch = 1 then -- RISCV
	    return "boot/riscv_sio.srec";
	else
	    assert FALSE report "Unsuported architecture #"
	      & integer'image(C_arch) severity failure;
	end if;
    end F_srec_file;

    impure function F_rom_from_srec(constant fname: string) return T_rom is
	file srec_file: text open read_mode is fname;
	variable M_r: T_rom;
	variable lin: line;
	variable c: character;
	variable lno: integer := -1;
	variable srec_addr: std_logic_vector(15 downto 0);
	variable rom_addr: natural := 0;
	variable bcount: std_logic_vector(7 downto 0);
	variable data: std_logic_vector(7 downto 0);
	variable csum: std_logic_vector(7 downto 0);
    begin
	M_r := (others => (others => '0'));
	assert not endfile(srec_file) report fname & ": cannot open"
	  severity failure;
	read_line: while not endfile(srec_file) loop
	    lno := lno + 1;
	    readline(srec_file, lin);
	    exit when endfile(srec_file); -- appease XST
	    read(lin, c);
	    assert c = 'S' report fname & ": invalid SREC input at line "
	      & integer'image(lno) severity failure;

	    read(lin, c);
	    case c is
	    when '0' =>
		-- SREC header, ignore
		next read_line;
	    when '1' =>
		-- data at 16-bit address
	    when '9' =>
		-- 16-bit start address, ignore
		next read_line;
	    when others =>
		assert FALSE report fname & ": unrecognized SREC type S"
		  & c & " at line " & integer'image(lno) severity failure;
	    end case;

	    hread(lin, bcount);
	    hread(lin, srec_addr);
	    csum := bcount + srec_addr(15 downto 8) + srec_addr(7 downto 0);
	    assert conv_integer(srec_addr) >= rom_addr report
	      fname & ": decreasing address at line "
	      & integer'image(lno) severity failure;
	    rom_addr := conv_integer(srec_addr);
	    for i in 0 to conv_integer(bcount) - 4 loop
		assert rom_addr < C_rom_size * 1024 report
		  fname & ": address " & integer'image(rom_addr) &
		  " out of bounds at line " & integer'image(lno)
		  severity failure;
		hread(lin, data);
		M_r(rom_addr / 4)((rom_addr mod 4) * 8 + 7
		  downto (rom_addr mod 4) * 8) := data;
		rom_addr := rom_addr + 1;
		csum := csum + data;
	    end loop;
	    hread(lin, data);
	    assert x"ff" - csum - data = 0 report
	      fname & ": invalid checksum at line " & integer'image(lno)
	      severity failure;
	end loop;
	report fname & ": " & integer'image(rom_addr) & " bytes";
	return M_r;
    end F_rom_from_srec;

    signal M_rom: T_rom := F_rom_from_srec(F_srec_file);
    signal R_ack: std_logic;

begin
    data_out <= M_rom(conv_integer(addr)) when rising_edge(clk);
    R_ack <= strobe and not R_ack when rising_edge(clk);
    data_ready <= R_ack;
end x;
