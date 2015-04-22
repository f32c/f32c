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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity bptrace is
    port (
	din: in std_logic_vector(1 downto 0); 
	dout: out std_logic_vector(1 downto 0);
	rdaddr, wraddr: in std_logic_vector(12 downto 0); 
	re, we, clk: in std_logic
    );
end bptrace;

architecture Structure of bptrace is
    type bptrace_type is array(0 to 8191) of std_logic_vector(1 downto 0);
    signal bptrace: bptrace_type;

    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bptrace: signal is "no_rw_check";

begin
    process(clk)
    begin
	if rising_edge(clk) then
	    if we = '1' then
		bptrace(conv_integer(wraddr)) <= din;
	    end if;
	    if re = '1' then
		dout <= bptrace(conv_integer(rdaddr));
	    end if;
	end if;
    end process;
end Structure;
