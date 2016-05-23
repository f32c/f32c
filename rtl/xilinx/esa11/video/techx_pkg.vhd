
--   Target Chip: Xilinx
-----------------------------------------------------------

-----------------------------------------------------------
-- Package technology
-----------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;


package techx_pkg is

   -- Components
   --------------------------------------------------------
   component global_buffer
   port(
      i_in     : in     std_logic;
      o_out    : out    std_logic
   );
   end component global_buffer;


   component clock_dll
   generic(
      CLKIN_PERIOD         : real;
      DLL_FREQUENCY_MODE   : string
   );
   port(
      i_reset              : in     std_logic;
      i_clk                : in     std_logic;
      i_clk2x_fb           : in     std_logic;
      o_clk                : out    std_logic;
      o_clk_n              : out    std_logic;
      o_clk2x              : out    std_logic;
      o_clkdv			      : out    std_logic;
      o_locked             : out    std_logic
   );
   end component clock_dll;


   component inout_tri_port
   port(
      i_out    : in     std_logic;
      i_oe     : in     std_logic;
      o_in     : out    std_logic;
      io_io    : inout  std_logic
   );
   end component inout_tri_port;

   component clk_port
   port(
      i_in     : in     std_logic;
      o_out    : out    std_logic
   );
   end component clk_port;


   component inp_ds_port is
   port(
      i_in_p    : in     std_logic;
      i_in_n    : in     std_logic;
      o_out     : out    std_logic
   );
   end component inp_ds_port;

end package techx_pkg;

-- Global_buffer
-----------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-- pragma translate_off
library unisim;
use unisim.vcomponents.all;
-- pragma translate_on
use work.techx_pkg.all;

entity global_buffer is
   port(
      i_in     : in     std_logic;
      o_out    : out    std_logic
   );
end entity global_buffer;


architecture synthesis of global_buffer is

   component bufg
   port(
      i     : in     std_logic;
      o     : out    std_logic
   );
   end component bufg;

begin

   global_inst: bufg
   port map(
      i     => i_in,
      o     => o_out
   );

end architecture synthesis;


-- Clock DLL
-----------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-- pragma translate_off
library unisim;
use unisim.vcomponents.all;
-- pragma translate_on

use work.techx_pkg.all;


entity clock_dll is
   generic(
      CLKIN_PERIOD         : real;
      DLL_FREQUENCY_MODE   : string
   );
   port(
      i_reset              : in     std_logic;
      i_clk                : in     std_logic;
      i_clk2x_fb           : in     std_logic;
      o_clk                : out    std_logic;
      o_clk_n              : out    std_logic;
      o_clk2x              : out    std_logic;
      o_clkdv			      : out    std_logic;
      o_locked             : out    std_logic
   );
end entity clock_dll;


architecture synthesis of clock_dll is

   component bufg
   port(
      i     : in     std_logic;
      o     : out    std_logic
   );
   end component bufg;


   component dcm_sp
   generic(
      CLK_FEEDBACK            : string;
      CLKDV_DIVIDE            : real;
      CLKFX_DIVIDE            : integer;
      CLKFX_MULTIPLY          : integer;
      CLKIN_DIVIDE_BY_2       : boolean;
      CLKIN_PERIOD            : real;
      CLKOUT_PHASE_SHIFT      : string;
      DESKEW_ADJUST           : string;
      DFS_FREQUENCY_MODE      : string;
      DLL_FREQUENCY_MODE      : string;
      DUTY_CYCLE_CORRECTION   : boolean;
      FACTORY_JF              : bit_vector;
      PHASE_SHIFT             : integer;
      STARTUP_WAIT            : boolean
   );
   port(
      clkfb                   : in     std_logic;
      clkin                   : in     std_logic;
      dssen                   : in     std_logic;
      psclk                   : in     std_logic;
      psen                    : in     std_logic;
      psincdec                : in     std_logic;
      rst                     : in     std_logic;
      clkdv                   : out    std_logic;
      clkfx                   : out    std_logic;
      clkfx180                : out    std_logic;
      clk0                    : out    std_logic;
      clk2x                   : out    std_logic;
      clk2x180                : out    std_logic;
      clk90                   : out    std_logic;
      clk180                  : out    std_logic;
      clk270                  : out    std_logic;
      locked                  : out    std_logic;
      psdone                  : out    std_logic;
      status                  : out    std_logic_vector(7 downto 0)
   );
   end component dcm_sp;


   signal      clk0           : std_logic;
   signal      clkfb          : std_logic;
   signal      clk2x          : std_logic;
   signal      clkdv          : std_logic;
   signal      clk180         : std_logic;

begin

   global_buffer_i0: bufg
   port map(
      i     => clk0,
      o     => clkfb
   );

   o_clk <= clkfb;


   global_buffer_i1: bufg
   port map(
      i     => clk2x,
      o     => o_clk2x
   );

   global_buffer_i2: bufg
   port map(
      i     => clkdv,
      o     => o_clkdv
   );

   global_buffer_i3: bufg
   port map(
      i     => clk180,
      o     => o_clk_n
   );

-- MMCME2_BASE: Base Mixed Mode Clock Manager
-- 7 Series
-- Xilinx HDL Libraries Guide, version 2014.4
--MMCME2_BASE_inst : MMCME2_BASE
--generic map (
--BANDWIDTH => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
--CLKFBOUT_MULT_F => 5.0, -- Multiply value for all CLKOUT (2.000-64.000).
--CLKFBOUT_PHASE => 0.0, -- Phase offset in degrees of CLKFB (-360.000-360.000).
--CLKIN1_PERIOD => 0.0, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
---- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
--CLKOUT1_DIVIDE => 1,
--CLKOUT2_DIVIDE => 1,
--CLKOUT3_DIVIDE => 1,
--CLKOUT4_DIVIDE => 1,
--CLKOUT5_DIVIDE => 1,
--CLKOUT6_DIVIDE => 1,
--CLKOUT0_DIVIDE_F => 1.0, -- Divide amount for CLKOUT0 (1.000-128.000).
---- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
--CLKOUT0_DUTY_CYCLE => 0.5,
--CLKOUT1_DUTY_CYCLE => 0.5,
--CLKOUT2_DUTY_CYCLE => 0.5,
--CLKOUT3_DUTY_CYCLE => 0.5,
--CLKOUT4_DUTY_CYCLE => 0.5,
--CLKOUT5_DUTY_CYCLE => 0.5,
--CLKOUT6_DUTY_CYCLE => 0.5,
---- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
--CLKOUT0_PHASE => 0.0,
--CLKOUT1_PHASE => 0.0,
--CLKOUT2_PHASE => 0.0,
--CLKOUT3_PHASE => 0.0,
--CLKOUT4_PHASE => 0.0,
--CLKOUT5_PHASE => 0.0,
--CLKOUT6_PHASE => 0.0,
--CLKOUT4_CASCADE => FALSE, -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
--DIVCLK_DIVIDE => 1, -- Master division value (1-106)
--REF_JITTER1 => 0.0, -- Reference input jitter in UI (0.000-0.999).
--STARTUP_WAIT => FALSE -- Delays DONE until MMCM is locked (FALSE, TRUE)
--)
--port map (
---- Clock Outputs: 1-bit (each) output: User configurable clock outputs
--CLKOUT0 => CLKOUT0, -- 1-bit output: CLKOUT0
--CLKOUT0B => open, -- 1-bit output: Inverted CLKOUT0
--CLKOUT1 => CLKOUT1, -- 1-bit output: CLKOUT1
--CLKOUT1B => open, -- 1-bit output: Inverted CLKOUT1
--CLKOUT2 => CLKOUT2, -- 1-bit output: CLKOUT2
--CLKOUT2B => open, -- 1-bit output: Inverted CLKOUT2
--CLKOUT3 => CLKOUT3, -- 1-bit output: CLKOUT3
--CLKOUT3B => open, -- 1-bit output: Inverted CLKOUT3
--CLKOUT4 => open, -- 1-bit output: CLKOUT4
--CLKOUT5 => open, -- 1-bit output: CLKOUT5
--CLKOUT6 => open, -- 1-bit output: CLKOUT6
---- Feedback Clocks: 1-bit (each) output: Clock feedback ports
--CLKFBOUT => clk0, -- 1-bit output: Feedback clock
--CLKFBOUTB => open, -- 1-bit output: Inverted CLKFBOUT
---- Status Ports: 1-bit (each) output: MMCM status ports
--LOCKED => o_locked, -- 1-bit output: LOCK
---- Clock Inputs: 1-bit (each) input: Clock input
--CLKIN1 => i_clk, -- 1-bit input: Clock
---- Control Ports: 1-bit (each) input: MMCM control ports
--PWRDWN => '0', -- 1-bit input: Power-down
--RST => i_reset, -- 1-bit input: Reset
---- Feedback Clocks: 1-bit (each) input: Clock feedback ports
--CLKFBIN => i_clk_fb -- 1-bit input: Feedback clock
--);
-- End of MMCME2_BASE_inst instantiation


   dcm_inst: dcm_sp
   generic map(
      CLK_FEEDBACK            => "2X",
      CLKDV_DIVIDE            => 2.0,
      CLKFX_DIVIDE            => 1,
      CLKFX_MULTIPLY          => 4,
      CLKIN_DIVIDE_BY_2       => FALSE,
      CLKIN_PERIOD            => CLKIN_PERIOD,
      CLKOUT_PHASE_SHIFT      => "NONE",
      DESKEW_ADJUST           => "SYSTEM_SYNCHRONOUS",
      DFS_FREQUENCY_MODE      => "LOW",
      DLL_FREQUENCY_MODE      => DLL_FREQUENCY_MODE,
      DUTY_CYCLE_CORRECTION   => TRUE,
      FACTORY_JF              => X"C080",
      PHASE_SHIFT             => 0,
      STARTUP_WAIT            => FALSE
   )
   port map(
      rst                     => i_reset,
      clkin                   => i_clk,
      clkfb                   => i_clk2x_fb,
      dssen                   => '0',
      psclk                   => '0',
      psen                    => '0',
      psincdec                => '0',
      clk0                    => clk0,
      clk90                   => open,
      clk180                  => clk180,
      clk270                  => open,
      clk2x                   => clk2x,
      clk2x180                => open,
      clkdv                   => clkdv,
      clkfx                   => open,
      clkfx180                => open,
      locked                  => o_locked,
      psdone                  => open,
      status                  => open
   );

end architecture synthesis;


-----------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-- pragma translate_off
library unisim;
use unisim.vcomponents.all;
-- pragma translate_on
use work.techx_pkg.all;


entity inout_tri_port is
   port(
      i_out    : in     std_logic;                       -- Data input
      i_oe     : in     std_logic;                       -- Output enable
      o_in     : out    std_logic;                       -- Data output
      io_io    : inout  std_logic                        -- IO port
   );
end entity inout_tri_port;


architecture synthesis of inout_tri_port is

begin

   o_in <= To_X01(io_io);
   io_io <= i_out when i_oe = '1' else 'Z';

end architecture synthesis;


--------------------------------------------------------------------------------
-- Module clk_port
--
-- Implements a clock input port
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-- pragma translate_off
library unisim;
use unisim.vcomponents.all;
-- pragma translate_on

use work.techx_pkg.all;


entity clk_port is
   port(
      i_in     : in     std_logic;
      o_out     : out    std_logic
   );
end entity clk_port;


architecture synthesis of clk_port is

--constant hi : std_logic := '1';
--constant lo : std_logic := '0';

signal in_n : std_ulogic;

begin

   o_out <= i_in;
   
--   clk_out: ODDR
--   port map(
--      Q  => o_out,
--      C => i_in,
-- --     C1 => in_n,
--      CE => hi,
--      D1 => hi,
--      D2 => lo,
--      R  => lo,
--      S  => lo
--   );
   
end architecture synthesis;

--------------------------------------------------------------------------------
-- Module ds_inp
--
-- Implements a differential input port
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.techx_pkg.all;


entity inp_ds_port is
   port(
      i_in_p    : in     std_logic;
      i_in_n    : in     std_logic;
      o_out     : out    std_logic
   );
end entity inp_ds_port;

architecture synthesis of inp_ds_port is
begin

-- IBUFDS: Differential Input Buffer
-- 7 Series
-- Xilinx HDL Libraries Guide, version 2014.4
IBUFDS_1 : IBUFDS
--generic map (
--   DIFF_TERM => FALSE, -- Differential Termination
--   IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--   IOSTANDARD => "DEFAULT")
port map (
   O 	=> o_out,  -- Buffer output
   I 	=> i_in_p, -- Diff_p buffer input (connect directly to top-level port)
   IB 	=> i_in_n  -- Diff_n buffer input (connect directly to top-level port)
);
-- End of IBUFDS_inst instantiation

end architecture synthesis;

-- eof

