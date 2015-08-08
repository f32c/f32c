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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.message.all; -- RDS message in file message.vhd

entity bram_rds is
    generic(
        c_mem_bytes: integer range 2 to 2048 := 260; -- bytes
        c_addr_bits: integer range 1 to 11 := 9 -- address bits of BRAM
    );
    port(
	clk: in std_logic;
	imem_addr: in std_logic_vector(c_addr_bits-1 downto 0);
	imem_data_out: out std_logic_vector(7 downto 0);
	dmem_write: in std_logic;
	dmem_addr: in std_logic_vector(c_addr_bits-1 downto 0);
	dmem_data_in: in std_logic_vector(7 downto 0);
	dmem_data_out: out std_logic_vector(7 downto 0)
    );
end bram_rds;

architecture x of bram_rds is
    type bram_type is array(0 to (c_mem_bytes - 1))
      of std_logic_vector(7 downto 0);

    -- function to convert initial RDS message type to bram_type
    function init_bram(x: rds_msg_type; lmax: integer)
      return bram_type is
        variable i, n: integer;
        variable y: bram_type;
    begin
      n := x'length;
      if n > lmax then
        n := lmax;
      end if;
      for i in 0 to n - 1 loop
        y(i) := x(i);
      end loop;
      return y;
    end init_bram;

    signal bram_0: bram_type := init_bram(rds_msg_map, c_mem_bytes);

    -- Lattice Diamond attributes
    attribute syn_ramstyle: string;
    attribute syn_ramstyle of bram_0: signal is "no_rw_check";

    -- Xilinx XST attributes
    attribute ram_style: string;
    attribute ram_style of bram_0: signal is "no_rw_check";

    -- Altera Quartus attributes
    attribute ramstyle: string;
    attribute ramstyle of bram_0: signal is "no_rw_check";

    signal ibram_0: std_logic_vector(7 downto 0);
    signal dbram_0: std_logic_vector(7 downto 0);

begin

    dmem_data_out <= dbram_0;
    imem_data_out <= ibram_0;

    process(clk)
    begin
	if rising_edge(clk) then
	    if dmem_write = '1' then
		bram_0(conv_integer(dmem_addr)) <= dmem_data_in(7 downto 0);
	    end if;
	    dbram_0 <= bram_0(conv_integer(dmem_addr));
	    ibram_0 <= bram_0(conv_integer(imem_addr));
	end if;
    end process;
end x;
