--
-- Copyright (c) 2011, 2016 Marko Zec, University of Zagreb 
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


entity reg1w2r is
    generic(
	C_synchronous_read: boolean := false;
	C_debug: boolean := false
    );
    port(
	rd1_addr, rd2_addr, rdd_addr, wr_addr: in std_logic_vector(4 downto 0);
	rd1_data, rd2_data, rdd_data: out std_logic_vector(31 downto 0);
	wr_data: in std_logic_vector(31 downto 0);
	wr_enable: in std_logic;
	rd_clk, wr_clk: in std_logic
    );
end reg1w2r;

architecture Behavioral of reg1w2r is
    type reg_type is array(0 to 31) of std_logic_vector(31 downto 0);
    signal R1, R2, RD: reg_type;

    -- Prevent XST from inferring block RAMs
    attribute ram_style: string;
    attribute ram_style of R1: signal is "distributed";
    attribute ram_style of R2: signal is "distributed";
    attribute ram_style of RD: signal is "distributed";

begin
    process(wr_clk)
    begin
	if rising_edge(wr_clk) then
	    if wr_enable = '1' then
		R1(conv_integer(wr_addr)) <= wr_data;
		R2(conv_integer(wr_addr)) <= wr_data;
	    end if;
	    if C_debug and wr_enable = '1' then
		RD(conv_integer(wr_addr)) <= wr_data;
	    end if;
	end if;
    end process;

    process(rd_clk, rd1_addr, rd2_addr, rdd_addr)
    begin
	if falling_edge(rd_clk) or not C_synchronous_read then
	    rd1_data <= R1(conv_integer(rd1_addr));
	    rd2_data <= R2(conv_integer(rd2_addr));
	    rdd_data <= RD(conv_integer(rdd_addr));
	end if;
    end process;
end Behavioral;
