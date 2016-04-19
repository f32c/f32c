--
-- Copyright (c) 2011-2013 Marko Zec, University of Zagreb
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

library IEEE;
use IEEE.std_logic_1164.all;

library xp2;
use xp2.components.all;

entity bptrace is
	generic (
		C_bptrace_ebram: boolean := true
	);
	port (
		din: in std_logic_vector(1 downto 0); 
		dout: out std_logic_vector(1 downto 0);
		rdaddr, wraddr: in std_logic_vector(12 downto 0); 
		re, we, clk: in std_logic
	);
end bptrace;

architecture Structure of bptrace is
	signal do_a, do_b, outreg: std_logic_vector(1 downto 0);
	signal wea, web: std_logic;

begin

	G_bptrace_dpr:
	if not C_bptrace_ebram generate
	begin
	bptrace_dpr_a: DPR16X4A
	port map (
		DI0 => din(0), DI1 => din(1), DI2 => '0', DI3 => '0',
		DO0 => do_a(0), DO1 => do_a(1), DO2 => open, DO3 => open,
		WAD0 => wraddr(0), WAD1 => wraddr(1), WAD2 => wraddr(2), WAD3 => wraddr(3),
		RAD0 => rdaddr(0), RAD1 => rdaddr(1), RAD2 => rdaddr(2), RAD3 => rdaddr(3),
		WCK => clk, WRE => wea
	);
	bptrace_dpr_b: DPR16X4B
	port map (
		DI0 => din(0), DI1 => din(1), DI2 => '0', DI3 => '0',
		DO0 => do_b(0), DO1 => do_b(1), DO2 => open, DO3 => open,
		WAD0 => wraddr(0), WAD1 => wraddr(1), WAD2 => wraddr(2), WAD3 => wraddr(3),
		RAD0 => rdaddr(0), RAD1 => rdaddr(1), RAD2 => rdaddr(2), RAD3 => rdaddr(3),
		WCK => clk, WRE => web
	);
	wea <= we and not wraddr(4);
	web <= we and wraddr(4);
	process(clk)
	begin
		if (rising_edge(clk) and re = '1') then
			if rdaddr(4) = '0' then
				outreg <= do_a;
			else
				outreg <= do_b;
			end if;
		end if;
	end process;
	dout <= outreg;
	end generate;

	G_bptrace_ebr:
	if C_bptrace_ebram generate
	begin
    	bptrace_ebram: DP16KB
	generic map (
		-- CSDECODE_B => "000", CSDECODE_A=> "000",
		WRITEMODE_B => "NORMAL", WRITEMODE_A => "NORMAL",
		GSR=> "DISABLED", RESETMODE => "SYNC", 
		REGMODE_B => "NOREG", REGMODE_A => "NOREG",
		DATA_WIDTH_B => 2, DATA_WIDTH_A => 2
	)
	port map (
		DIA0 => '0', DIA1 => '0', DIA2 => '0', DIA3 => '0',
		DIA4 => '0', DIA5 => '0', DIA6 => '0', DIA7 => '0',
		DIA8 => '0', DIA9 => '0', DIA10 => '0', DIA11 => '0', 
		DIA12 => '0', DIA13 => '0', DIA14 => '0', DIA15=> '0',
		DIA16 => '0', DIA17 => '0', 
		ADA0 => '0', ADA1 => rdaddr(0), ADA2 => rdaddr(1), ADA3 => rdaddr(2),
		ADA4 => rdaddr(3), ADA5 => rdaddr(4), ADA6 => rdaddr(5), ADA7 => rdaddr(6),
		ADA8 => rdaddr(7), ADA9 => rdaddr(8), ADA10 => rdaddr(9), ADA11 => rdaddr(10), 
		ADA12 => rdaddr(11), ADA13 => rdaddr(12),
		CEA => re, CLKA => clk, WEA => '0',
		CSA0 => '0', CSA1 => '0', CSA2 => '0', RSTA => '0',
		DIB0 => '0', DIB1 => din(1), DIB2 => '0', DIB3 => '0', 
		DIB4 => '0', DIB5 => '0', DIB6 => '0', DIB7 => '0',
		DIB8 => '0', DIB9 => '0', DIB10 => '0', DIB11 => din(0),
		DIB12 => '0', DIB13 => '0', DIB14 => '0', DIB15 => '0',
		DIB16 => '0', DIB17 => '0',
		ADB0 => '0', ADB1 => wraddr(0), ADB2 => wraddr(1), ADB3 => wraddr(2), 
		ADB4 => wraddr(3), ADB5 => wraddr(4), ADB6 => wraddr(5), ADB7 => wraddr(6),
		ADB8 => wraddr(7), ADB9 => wraddr(8), ADB10 => wraddr(9), ADB11 => wraddr(10),
		ADB12 => wraddr(11), ADB13 => wraddr(12),
		CEB => we, CLKB => clk, WEB => '1', 
		CSB0 => '0', CSB1 => '0', CSB2 => '0', RSTB => '0', 
		DOA0 => dout(0), DOA1 => dout(1), DOA2=> open, DOA3 => open,
		DOA4 => open, DOA5 => open, DOA6 => open, DOA7 => open, 
		DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open, 
		DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open, 
		DOA16 => open, DOA17 => open,
		DOB0 => open, DOB1 => open, DOB2 => open, DOB3 => open,
		DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
		DOB8 => open, DOB9 => open, DOB10 => open, DOB11 => open, 
		DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open, 
		DOB16 => open, DOB17 => open
	);
	end generate;

end Structure;
