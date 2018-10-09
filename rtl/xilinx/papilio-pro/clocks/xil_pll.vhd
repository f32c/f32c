--
-- Copyright (c) 2018 Felix Vietmeyer
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity xil_pll is
  generic(
    clk_in_period_ns  : real    := 10.0;    -- default input 100 MHz
    clk_mult          : integer := 10;      -- default fVCO = 1000 MHz
    clk_diva          : integer := 10;      -- 100 MHz
    clk_phasea        : real    := 0.0;
    clk_divb          : integer := 8;       -- 125 MHz
    clk_phaseb        : real    := 0.0;
    clk_divc          : integer := 40;      -- 25 MHz
    clk_phasec        : real    := 0.0;
    clk_divd          : integer := 10;      -- 100 MHz
    clk_phased        : real    := 0.0;
    clk_dive          : integer := 10;      -- 100 MHz
    clk_phasee        : real    := 0.0;
    clk_divf          : integer := 10;      -- 100 MHz
    clk_phasef        : real    := 0.0
  );
  port(
    -- Clock in ports
    clk_in            : in     std_logic;   -- 100 MHz
    -- Clock out ports
    clk_outa          : out    std_logic;   -- 100 MHz
    clk_outb          : out    std_logic;   -- 125 MHz
    clk_outc          : out    std_logic;   --  25 MHz
    clk_outd          : out    std_logic;   -- 100 MHz
    clk_oute          : out    std_logic;   -- 100 MHz
    clk_outf          : out    std_logic    -- 100 MHz
  );
end xil_pll;

architecture RTL of xil_pll is

  signal clkin_buf  : std_logic;

  signal clkfb      : std_logic;
  signal clkfb_buf  : std_logic;

  signal clk_a      : std_logic;
  signal clk_b      : std_logic;
  signal clk_c      : std_logic;
  signal clk_d      : std_logic;
  signal clk_e      : std_logic;
  signal clk_f      : std_logic;

begin

  clkin_bufg : IBUFG
  port map(
    O => clkin_buf,
    I => clk_in
  );

  inst_pll_base : PLL_BASE
  generic map(
    BANDWIDTH            => "OPTIMIZED",
    CLK_FEEDBACK         => "CLKFBOUT",
    COMPENSATION         => "SYSTEM_SYNCHRONOUS",
    DIVCLK_DIVIDE        => 1,
    CLKFBOUT_MULT        => clk_mult,
    CLKFBOUT_PHASE       => 0.000,
    CLKOUT0_DIVIDE       => clk_diva,
    CLKOUT0_PHASE        => clk_phasea,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => clk_diva,
    CLKOUT1_PHASE        => clk_phasea,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => clk_diva,
    CLKOUT2_PHASE        => clk_phasea,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => clk_diva,
    CLKOUT3_PHASE        => clk_phasea,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => clk_diva,
    CLKOUT4_PHASE        => clk_phasea,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => clk_diva,
    CLKOUT5_PHASE        => clk_phasea,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => clk_in_period_ns,
    REF_JITTER           => 0.010
  )
  port map(
    CLKFBOUT            => clkfb,
    CLKOUT0             => clk_a,
    CLKOUT1             => clk_b,
    CLKOUT2             => clk_c,
    CLKOUT3             => clk_d,
    CLKOUT4             => clk_e,
    CLKOUT5             => clk_f,
    LOCKED              => open,
    RST                 => '0',
    -- Input clock control
    CLKFBIN             => clkfb_buf,
    CLKIN               => clkin_buf);

  fb_bufg : BUFG
  port map(
    O => clkfb_buf,
    I => clkfb
  );

  clka_bufg : BUFG
  port map(
    O   => clk_outa,
    I   => clk_a
  );

  clkb_bufg : BUFG
  port map(
    O   => clk_outb,
    I   => clk_b
  );

  clkc_bufg : BUFG
  port map(
    O   => clk_outc,
    I   => clk_c
  );

  clkd_bufg : BUFG
  port map(
    O   => clk_outd,
    I   => clk_d
  );

  clke_bufg : BUFG
  port map(
    O   => clk_oute,
    I   => clk_e
  );

  clkf_bufg : BUFG
  port map(
    O   => clk_outf,
    I   => clk_f
  );

end RTL;
