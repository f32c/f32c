
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
    clk_div0          : integer := 10;      -- 100 MHz
    clk_phase0        : real    := 0.0;
    clk_div1          : integer := 10;      -- 100 MHz
    clk_phase1        : real    := 0.0;
    clk_div2          : integer := 10;      -- 100 MHz
    clk_phase2        : real    := 0.0;
    clk_div3          : integer := 10;      -- 100 MHz
    clk_phase3        : real    := 0.0;
    clk_div4          : integer := 10;      -- 100 MHz
    clk_phase4        : real    := 0.0;
    clk_div5          : integer := 10;      -- 100 MHz
    clk_phase5        : real    := 0.0
  );
  port(
    -- Clock in ports
    clk_in            : in     std_logic;   -- 100 MHz
    -- Clock out ports
    clk_out0          : out    std_logic;   -- 100 MHz
    clk_out1          : out    std_logic;   -- 100 MHz
    clk_out2          : out    std_logic;   -- 100 MHz
    clk_out3          : out    std_logic;   -- 100 MHz
    clk_out4          : out    std_logic;   -- 100 MHz
    clk_out5          : out    std_logic;   -- 100 MHz
    locked            : out    std_logic
  );
end xil_pll;

architecture RTL of xil_pll is

  signal clkin_buf  : std_logic;

  signal clkfb      : std_logic;
  signal clkfb_buf  : std_logic;

  signal clk_0      : std_logic;
  signal clk_1      : std_logic;
  signal clk_2      : std_logic;
  signal clk_3      : std_logic;
  signal clk_4      : std_logic;
  signal clk_5      : std_logic;

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
    CLKOUT0_DIVIDE       => clk_div0,
    CLKOUT0_PHASE        => clk_phase0,
    CLKOUT0_DUTY_CYCLE   => 0.500,
    CLKOUT1_DIVIDE       => clk_div1,
    CLKOUT1_PHASE        => clk_phase1,
    CLKOUT1_DUTY_CYCLE   => 0.500,
    CLKOUT2_DIVIDE       => clk_div2,
    CLKOUT2_PHASE        => clk_phase2,
    CLKOUT2_DUTY_CYCLE   => 0.500,
    CLKOUT3_DIVIDE       => clk_div3,
    CLKOUT3_PHASE        => clk_phase3,
    CLKOUT3_DUTY_CYCLE   => 0.500,
    CLKOUT4_DIVIDE       => clk_div4,
    CLKOUT4_PHASE        => clk_phase4,
    CLKOUT4_DUTY_CYCLE   => 0.500,
    CLKOUT5_DIVIDE       => clk_div5,
    CLKOUT5_PHASE        => clk_phase5,
    CLKOUT5_DUTY_CYCLE   => 0.500,
    CLKIN_PERIOD         => clk_in_period_ns,
    REF_JITTER           => 0.010
  )
  port map(
    CLKFBOUT            => clkfb,
    CLKOUT0             => clk_0,
    CLKOUT1             => clk_1,
    CLKOUT2             => clk_2,
    CLKOUT3             => clk_3,
    CLKOUT4             => clk_4,
    CLKOUT5             => clk_5,
    LOCKED              => locked,
    RST                 => '0',
    -- Input clock control
    CLKFBIN             => clkfb_buf,
    CLKIN               => clkin_buf);

  fb_bufg : BUFG
  port map(
    O => clkfb_buf,
    I => clkfb
  );

  clk0_bufg : BUFG
  port map(
    O   => clk_out0,
    I   => clk_0
  );

  clk1_bufg : BUFG
  port map(
    O   => clk_out1,
    I   => clk_1
  );

  clk2_bufg : BUFG
  port map(
    O   => clk_out2,
    I   => clk_2
  );

  clk3_bufg : BUFG
  port map(
    O   => clk_out3,
    I   => clk_3
  );

  clk4_bufg : BUFG
  port map(
    O   => clk_out4,
    I   => clk_4
  );

  clk5_bufg : BUFG
  port map(
    O   => clk_out5,
    I   => clk_5
  );

end RTL;
