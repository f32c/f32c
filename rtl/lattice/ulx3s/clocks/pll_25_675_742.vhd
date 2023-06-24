library IEEE;
use IEEE.std_logic_1164.all;
library ECP5U;
use ECP5U.components.all;

entity pll_112m5 is
    port (
	clk_112m5: in std_logic; 
	clk_371m25: out std_logic; 
	clk_123m75: out std_logic; 
	clk_92m8125: out std_logic; 
	clk_74m25: out std_logic; 
	LOCK: out std_logic
    );
end pll_112m5;

architecture x of pll_112m5 is

    -- internal signal declarations
    signal REFCLK: std_logic;
    signal CLKOS3_t: std_logic;
    signal CLKOS2_t: std_logic;
    signal CLKOS_t: std_logic;
    signal CLKOP_t: std_logic;
    signal scuba_vhi: std_logic;
    signal scuba_vlo: std_logic;

    attribute FREQUENCY_PIN_CLKOS3: string; 
    attribute FREQUENCY_PIN_CLKOS2: string; 
    attribute FREQUENCY_PIN_CLKOS: string; 
    attribute FREQUENCY_PIN_CLKOP: string; 
    attribute FREQUENCY_PIN_CLKI: string; 
    attribute ICP_CURRENT: string; 
    attribute LPF_RESISTOR: string; 
    attribute FREQUENCY_PIN_CLKOS3 of PLL: label is "74.250000";
    attribute FREQUENCY_PIN_CLKOS2 of PLL: label is "92.812500";
    attribute FREQUENCY_PIN_CLKOS of PLL: label is "123.750000";
    attribute FREQUENCY_PIN_CLKOP of PLL: label is "371.250000";
    attribute FREQUENCY_PIN_CLKI of PLL: label is "112.500000";
    attribute ICP_CURRENT of PLL: label is "7";
    attribute LPF_RESISTOR of PLL: label is "16";
    attribute syn_keep: boolean;
    attribute NGD_DRC_MASK: integer;
    attribute NGD_DRC_MASK of x: architecture is 1;

begin
    -- component instantiation statements
    scuba_vhi_inst: VHI
    port map (Z=>scuba_vhi);

    scuba_vlo_inst: VLO
    port map (Z=>scuba_vlo);

    pll: EHXPLLL
    generic map (
	PLLRST_ENA=> "DISABLED", INTFB_WAKE=> "DISABLED", 
	STDBY_ENABLE=> "DISABLED", DPHASE_SOURCE=> "DISABLED", 
	CLKOS3_FPHASE=> 0, CLKOS3_CPHASE=> 9, CLKOS2_FPHASE=> 0, 
	CLKOS2_CPHASE=> 7, CLKOS_FPHASE=> 0, CLKOS_CPHASE=> 5, 
	CLKOP_FPHASE=> 0, CLKOP_CPHASE=> 1, PLL_LOCK_MODE=> 0, 
	CLKOS_TRIM_DELAY=> 0, CLKOS_TRIM_POL=> "FALLING", 
	CLKOP_TRIM_DELAY=> 0, CLKOP_TRIM_POL=> "FALLING", 
	OUTDIVIDER_MUXD=> "DIVD", CLKOS3_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXC=> "DIVC", CLKOS2_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXB=> "DIVB", CLKOS_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXA=> "DIVA", CLKOP_ENABLE=> "ENABLED", CLKOS3_DIV=> 10, 
	CLKOS2_DIV=> 8, CLKOS_DIV=> 6, CLKOP_DIV=> 2, CLKFB_DIV=> 33, 
	CLKI_DIV=> 10, FEEDBK_PATH=> "CLKOP"
    )
    port map (
	CLKI=> clk_112m5, CLKFB=>CLKOP_t, PHASESEL1=>scuba_vlo, 
	PHASESEL0=>scuba_vlo, PHASEDIR=>scuba_vlo, 
	PHASESTEP=>scuba_vlo, PHASELOADREG=>scuba_vlo, 
	STDBY=>scuba_vlo, PLLWAKESYNC=>scuba_vlo, RST=>scuba_vlo, 
	ENCLKOP=>scuba_vlo, ENCLKOS=>scuba_vlo, ENCLKOS2=>scuba_vlo, 
	ENCLKOS3=>scuba_vlo, CLKOP=>CLKOP_t, CLKOS=>CLKOS_t, 
	CLKOS2=>CLKOS2_t, CLKOS3=>CLKOS3_t, LOCK=>LOCK, 
	INTLOCK=>open, REFCLK=>REFCLK, CLKINTFB=>open
    );

    clk_371m25 <= CLKOP_t;
    clk_123m75 <= CLKOS_t;
    clk_92m8125 <= CLKOS2_t;
    clk_74m25 <= CLKOS3_t;
end x;


library IEEE;
use IEEE.std_logic_1164.all;
library ECP5U;
use ECP5U.components.all;

entity pll_25m is
    port (
	clk_25m: in std_logic; 
	clk_371m25: out std_logic; 
	clk_337m5: out std_logic; 
	clk_168m75: out std_logic; 
	clk_123m75: out std_logic; 
	clk_112m5: out std_logic; 
	clk_92m8125: out std_logic; 
	clk_84m375: out std_logic; 
	clk_74m25: out std_logic; 
	LOCK: out std_logic
    );
end pll_25m;

architecture x of pll_25m is

    -- internal signal declarations
    signal REFCLK: std_logic;
    signal CLKOS3_t: std_logic;
    signal CLKOS2_t: std_logic;
    signal CLKOS_t: std_logic;
    signal CLKOP_t: std_logic;
    signal scuba_vhi: std_logic;
    signal scuba_vlo: std_logic;
    signal lock_a, lock_b: std_logic;

    attribute FREQUENCY_PIN_CLKOS3: string; 
    attribute FREQUENCY_PIN_CLKOS2: string; 
    attribute FREQUENCY_PIN_CLKOS: string; 
    attribute FREQUENCY_PIN_CLKOP: string; 
    attribute FREQUENCY_PIN_CLKI: string; 
    attribute ICP_CURRENT: string; 
    attribute LPF_RESISTOR: string; 
    attribute FREQUENCY_PIN_CLKOS3 of PLL: label is "84.375000";
    attribute FREQUENCY_PIN_CLKOS2 of PLL: label is "112.500000";
    attribute FREQUENCY_PIN_CLKOS of PLL: label is "168.750000";
    attribute FREQUENCY_PIN_CLKOP of PLL: label is "337.500000";
    attribute FREQUENCY_PIN_CLKI of PLL: label is "25.000000";
    attribute ICP_CURRENT of PLL: label is "6";
    attribute LPF_RESISTOR of PLL: label is "16";
    attribute syn_keep: boolean;
    attribute NGD_DRC_MASK: integer;
    attribute NGD_DRC_MASK of x: architecture is 1;

begin
    -- component instantiation statements
    scuba_vhi_inst: VHI
    port map (Z=>scuba_vhi);

    scuba_vlo_inst: VLO
    port map (Z=>scuba_vlo);

    pll: EHXPLLL
    generic map (
	PLLRST_ENA=> "DISABLED", INTFB_WAKE=> "DISABLED", 
	STDBY_ENABLE=> "DISABLED", DPHASE_SOURCE=> "DISABLED", 
	CLKOS3_FPHASE=> 0, CLKOS3_CPHASE=> 7, CLKOS2_FPHASE=> 0, 
	CLKOS2_CPHASE=> 5, CLKOS_FPHASE=> 0, CLKOS_CPHASE=> 3, 
	CLKOP_FPHASE=> 0, CLKOP_CPHASE=> 1, PLL_LOCK_MODE=> 0, 
	CLKOS_TRIM_DELAY=> 0, CLKOS_TRIM_POL=> "FALLING", 
	CLKOP_TRIM_DELAY=> 0, CLKOP_TRIM_POL=> "FALLING", 
	OUTDIVIDER_MUXD=> "DIVD", CLKOS3_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXC=> "DIVC", CLKOS2_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXB=> "DIVB", CLKOS_ENABLE=> "ENABLED", 
	OUTDIVIDER_MUXA=> "DIVA", CLKOP_ENABLE=> "ENABLED", CLKOS3_DIV=> 8, 
	CLKOS2_DIV=> 6, CLKOS_DIV=> 4, CLKOP_DIV=> 2, CLKFB_DIV=> 27, 
	CLKI_DIV=> 2, FEEDBK_PATH=> "CLKOP"
    )
    port map (
	CLKI=>clk_25m, CLKFB=>CLKOP_t, PHASESEL1=>scuba_vlo, 
	PHASESEL0=>scuba_vlo, PHASEDIR=>scuba_vlo, 
	PHASESTEP=>scuba_vlo, PHASELOADREG=>scuba_vlo, 
	STDBY=>scuba_vlo, PLLWAKESYNC=>scuba_vlo, RST=>scuba_vlo, 
	ENCLKOP=>scuba_vlo, ENCLKOS=>scuba_vlo, ENCLKOS2=>scuba_vlo, 
	ENCLKOS3=>scuba_vlo, CLKOP=>CLKOP_t, CLKOS=>CLKOS_t, 
	CLKOS2=>CLKOS2_t, CLKOS3=>CLKOS3_t, LOCK=> lock_a, 
	INTLOCK=>open, REFCLK=>REFCLK, CLKINTFB=>open
    );

    pll_b: entity work.pll_112m5
    port map (
	clk_112m5 => CLKOS2_t,
	clk_371m25 => clk_371m25,
	clk_123m75 => clk_123m75,
	clk_92m8125 => clk_92m8125,
	clk_74m25 => clk_74m25,
	lock => lock_b
    );

    clk_337m5 <= CLKOP_t;
    clk_168m75 <= CLKOS_t;
    clk_112m5 <= CLKOS2_t;
    clk_84m375 <= CLKOS3_t;

    lock <= lock_a and lock_b;

end x;
