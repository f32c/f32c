
library IEEE;
use IEEE.std_logic_1164.all;
library ECP5U;
use ECP5U.components.all;

entity pll_25m is
    port (
	clk_25m: in std_logic; 
	clk_168m75: out std_logic; 
	clk_112m5: out std_logic; 
	clk_96m43: out std_logic; 
	clk_84m34: out std_logic; 
	lock: out std_logic
    );
end pll_25m;

architecture Structure of pll_25m is
    signal CLKOP_t: std_logic;
    signal CLKOS_t: std_logic;
    signal CLKOS2_t: std_logic;
    signal CLKOS3_t: std_logic;

    attribute FREQUENCY_PIN_CLKI: string; 
    attribute FREQUENCY_PIN_CLKOP: string; 
    attribute FREQUENCY_PIN_CLKOS: string; 
    attribute FREQUENCY_PIN_CLKOS2: string; 
    attribute FREQUENCY_PIN_CLKOS3: string; 
    attribute ICP_CURRENT: string; 
    attribute LPF_RESISTOR: string; 
    attribute FREQUENCY_PIN_CLKI of PLLInst_0: label is "25.000000";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0: label is "112.500000";
    attribute FREQUENCY_PIN_CLKOS of PLLInst_0: label is "168.750000";
    attribute FREQUENCY_PIN_CLKOS2 of PLLInst_0: label is "96.428571";
    attribute FREQUENCY_PIN_CLKOS3 of PLLInst_0: label is "84.375000";
    attribute ICP_CURRENT of PLLInst_0: label is "6";
    attribute LPF_RESISTOR of PLLInst_0: label is "16";
    attribute NGD_DRC_MASK: integer;
    attribute NGD_DRC_MASK of Structure: architecture is 1;

begin
    PLLInst_0: EHXPLLL
    generic map (
	PLLRST_ENA => "DISABLED", INTFB_WAKE=> "DISABLED", 
	STDBY_ENABLE => "DISABLED", DPHASE_SOURCE=> "DISABLED", 
	CLKOS3_FPHASE => 0, CLKOS3_CPHASE=>  7, CLKOS2_FPHASE => 0, 
	CLKOS2_CPHASE => 6, CLKOS_FPHASE=>  0, CLKOS_CPHASE => 3, 
	CLKOP_FPHASE => 0, CLKOP_CPHASE=>  5, PLL_LOCK_MODE => 0, 
	CLKOP_TRIM_DELAY => 0, CLKOP_TRIM_POL => "FALLING", 
	CLKOS_TRIM_DELAY => 0, CLKOS_TRIM_POL => "FALLING", 
	OUTDIVIDER_MUXA => "DIVA", CLKOP_ENABLE => "ENABLED",
	OUTDIVIDER_MUXB => "DIVB", CLKOS_ENABLE => "ENABLED", 
	OUTDIVIDER_MUXC => "DIVC", CLKOS2_ENABLE => "ENABLED", 
	OUTDIVIDER_MUXD => "DIVD", CLKOS3_ENABLE => "ENABLED", 
	CLKOS3_DIV => 8, CLKOS2_DIV => 7, CLKOS_DIV => 4, CLKOP_DIV => 6,
	CLKFB_DIV => 9, CLKI_DIV => 2, FEEDBK_PATH => "CLKOP"
    )
    port map (
	CLKI => clk_25m, CLKFB => CLKOP_t,
	PHASESEL1 => '0', PHASESEL0 => '0', PHASEDIR => '0', 
	PHASESTEP => '0', PHASELOADREG => '0', 
	STDBY => '0', PLLWAKESYNC => '0', RST => '0', 
	ENCLKOP => '0', ENCLKOS => '0', ENCLKOS2 => '0', ENCLKOS3 => '0',
	CLKOP => CLKOP_t, CLKOS => CLKOS_t,
	CLKOS2 => CLKOS2_t, CLKOS3 => CLKOS3_t,
	LOCK => LOCK, INTLOCK => open, REFCLK => open, CLKINTFB => open
    );

    clk_168m75 <= CLKOS_t;
    clk_112m5 <= CLKOP_t;
    clk_96m43 <= CLKOS2_t;
    clk_84m34 <= CLKOS3_t;
end Structure;
