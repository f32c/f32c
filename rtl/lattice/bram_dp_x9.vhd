--
-- Copyright (c) 2013 Marko Zec, University of Zagreb
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


entity bram_dp_x9 is
    port (
	clk_a, clk_b: in std_logic; 
	ce_a, ce_b: in std_logic;
	we_a, we_b: in std_logic; 
	addr_a, addr_b: in std_logic_vector(10 downto 0); 
	data_in_a, data_in_b: in std_logic_vector(8 downto 0); 
	data_out_a, data_out_b: out std_logic_vector(8 downto 0)
    );
end bram_dp_x9;

architecture Structure of bram_dp_x9 is
begin
    bram_16_0: DP16KB
	generic map (
	    -- CSDECODE_A => "000", CSDECODE_B =>"000",
	    WRITEMODE_A => "WRITETHROUGH", WRITEMODE_B => "WRITETHROUGH",
	    GSR => "DISABLED", RESETMODE => "SYNC", 
	    REGMODE_A => "NOREG", REGMODE_B=> "NOREG",
	    DATA_WIDTH_A => 9, DATA_WIDTH_B => 9
	)
	port map (
	    DIA0 => data_in_a(0), DIA1 => data_in_a(1),
	    DIA2 => data_in_a(2), DIA3 => data_in_a(3),
	    DIA4 => data_in_a(4), DIA5 => data_in_a(5),
	    DIA6 => data_in_a(6), DIA7 => data_in_a(7),
	    DIA8 => data_in_a(8), DIA9 => '0',
	    DIA10 => '0', DIA11 => '0',
	    DIA12 => '0', DIA13 => '0',
	    DIA14 => '0', DIA15 => '0',
	    DIA16 => '0', DIA17 => '0',
	    DIB0 => data_in_b(0), DIB1 => data_in_b(1),
	    DIB2 => data_in_b(2), DIB3 => data_in_b(3),
	    DIB4 => data_in_b(4), DIB5 => data_in_b(5),
	    DIB6 => data_in_b(6), DIB7 => data_in_b(7),
	    DIB8 => data_in_b(8), DIB9 => '0',
	    DIB10 => '0', DIB11 => '0',
	    DIB12 => '0', DIB13 => '0',
	    DIB14 => '0', DIB15 => '0',
	    DIB16 => '0', DIB17 => '0',

	    DOA0 => data_out_a(0), DOA1 => data_out_a(1), 
	    DOA2 => data_out_a(2), DOA3 => data_out_a(3), 
	    DOA4 => data_out_a(4), DOA5 => data_out_a(5), 
	    DOA6 => data_out_a(6), DOA7 => data_out_a(7), 
	    DOA8 => data_out_a(8), DOA9 => open, 
	    DOA10 => open, DOA11 => open, 
	    DOA12 => open, DOA13 => open, 
	    DOA14 => open, DOA15 => open, 
	    DOA16 => open, DOA17 => open, 
	    DOB0 => data_out_b(0), DOB1 => data_out_b(1), 
	    DOB2 => data_out_b(2), DOB3 => data_out_b(3), 
	    DOB4 => data_out_b(4), DOB5 => data_out_b(5), 
	    DOB6 => data_out_b(6), DOB7 => data_out_b(7), 
	    DOB8 => data_out_b(8), DOB9 => open, 
	    DOB10 => open, DOB11 => open, 
	    DOB12 => open, DOB13 => open, 
	    DOB14 => open, DOB15 => open, 
	    DOB16 => open, DOB17 => open, 

	    ADA0 => '0', ADA1 => '0', ADA2 => '0',
	    ADA3 => addr_a(0), ADA4 => addr_a(1),
	    ADA5 => addr_a(2), ADA6 => addr_a(3),
	    ADA7 => addr_a(4), ADA8 => addr_a(5),
	    ADA9 => addr_a(6), ADA10 => addr_a(7),
	    ADA11 => addr_a(8), ADA12 => addr_a(9),
	    ADA13 => addr_a(10),
	    ADB0 => '0', ADB1 => '0', ADB2 => '0',
	    ADB3 => addr_b(0), ADB4 => addr_b(1),
	    ADB5 => addr_b(2), ADB6 => addr_b(3),
	    ADB7 => addr_b(4), ADB8 => addr_b(5),
	    ADB9 => addr_b(6), ADB10 => addr_b(7),
	    ADB11 => addr_b(8), ADB12 => addr_b(9),
	    ADB13 => addr_b(10),

	    CEA => ce_a, CLKA => clk_a, WEA => we_a, RSTA => '0', 
	    CSA0 => '0', CSA1 => '0', CSA2 => '0',
	    CEB => ce_b, CLKB => clk_b, WEB => we_b, RSTB => '0', 
	    CSB0 => '0', CSB1 => '0', CSB2 => '0'
	);
end Structure;
