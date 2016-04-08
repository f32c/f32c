--
-- Copyright (c) 2016 Marko Zec, University of Zagreb
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

component SB_RAM256x16
    port(
	RDATA : out std_logic_vector( 15  downto 0) ;
	RCLK  : in  std_logic ;
	RCLKE : in  std_logic := 'H';
	RE    : in  std_logic := 'L';
	RADDR : in  std_logic_vector( 7  downto 0) ;
	WCLK  : in  std_logic ;
	WCLKE : in  std_logic := 'H';
	WE    : in  std_logic := 'L';
	WADDR : in  std_logic_vector( 7  downto 0) ;
	MASK  : in  std_logic_vector( 15  downto 0) ;
	WDATA : in  std_logic_vector( 15  downto 0)
    );
end component;

begin

    assert C_synchronous_read
      report "ice40 only supports register files with synchronous read ports";

    iter: for i in 0 to 1 generate
    begin
	reg_1 : SB_RAM256x16
	port map (
	RADDR(4 downto 0) => rd1_addr,
	RDATA => rd1_data(i * 16 + 15 downto i * 16),
	RCLK => rd_clk, RCLKE => '1', RE => '1',
	WADDR(4 downto 0) => wr_addr,
	WDATA => wr_data(i * 16 + 15 downto i * 16),
	WCLK=> wr_clk, WCLKE => '1', MASK => x"0000", WE => '1'
	);

	reg_2 : SB_RAM256x16
	port map (
	RADDR(4 downto 0) => rd2_addr,
	RDATA => rd2_data(i * 16 + 15 downto i * 16),
	RCLK => rd_clk, RCLKE => '1', RE => '1',
	WADDR(4 downto 0) => wr_addr,
	WDATA => wr_data(i * 16 + 15 downto i * 16),
	WCLK=> wr_clk, WCLKE => '1', MASK => x"0000", WE => '1'
	);

	reg_d : SB_RAM256x16
	port map (
	RADDR(4 downto 0) => rdd_addr,
	RDATA => rdd_data(i * 16 + 15 downto i * 16),
	RCLK => rd_clk, RCLKE => '1', RE => '1',
	WADDR(4 downto 0) => wr_addr,
	WDATA => wr_data(i * 16 + 15 downto i * 16),
	WCLK=> wr_clk, WCLKE => '1', MASK => x"0000", WE => '1'
	);
    end generate;
end Behavioral;
