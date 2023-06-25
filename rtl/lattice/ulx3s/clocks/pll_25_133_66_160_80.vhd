library IEEE;
use IEEE.std_logic_1164.all;
library ECP5U;
use ECP5U.components.all;

entity pll_25m is
    port (
	clk_25m: in std_logic;
	clk_160m: out std_logic;
	clk_133m33: out std_logic;
	clk_66m66: out std_logic;
	clk_80m: out std_logic;
	lock: out std_logic
    );
end pll_25m;

architecture x of pll_25m is
    signal CLKOP_t: std_logic;
    signal CLKOS_t: std_logic;
    signal CLKOS2_t: std_logic;
    signal CLKOS3_t: std_logic;
    signal CLKFB_t: std_logic;

    attribute FREQUENCY_PIN_CLKI: string;
    attribute FREQUENCY_PIN_CLKOP: string;
    attribute FREQUENCY_PIN_CLKOS: string;
    attribute FREQUENCY_PIN_CLKOS2: string;
    attribute FREQUENCY_PIN_CLKOS3: string;
    attribute ICP_CURRENT: string;
    attribute LPF_RESISTOR: string;
    attribute NGD_DRC_MASK: integer;
    attribute FREQUENCY_PIN_CLKI of PLL: label is "25.000000";
    attribute FREQUENCY_PIN_CLKOP of PLL: label is "133.333333";
    attribute FREQUENCY_PIN_CLKOS of PLL: label is "66.666667";
    attribute FREQUENCY_PIN_CLKOS2 of PLL: label is "160.000000";
    attribute FREQUENCY_PIN_CLKOS3 of PLL: label is "80.000000";
    attribute ICP_CURRENT of PLL: label is "7";
    attribute LPF_RESISTOR of PLL: label is "16";
    attribute NGD_DRC_MASK of x: architecture is 1;

begin
    PLL: EHXPLLL
    generic map (
	PLLRST_ENA => "DISABLED", INTFB_WAKE => "DISABLED", 
	STDBY_ENABLE => "DISABLED", DPHASE_SOURCE => "DISABLED", 
	CLKOS3_FPHASE => 0, CLKOS3_CPHASE => 9, CLKOS2_FPHASE => 0, 
	CLKOS2_CPHASE => 4, CLKOS_FPHASE => 0, CLKOS_CPHASE => 11, 
	CLKOP_FPHASE => 0, CLKOP_CPHASE => 5, PLL_LOCK_MODE => 0, 
	CLKOS_TRIM_DELAY => 0, CLKOS_TRIM_POL => "FALLING", 
	CLKOP_TRIM_DELAY => 0, CLKOP_TRIM_POL => "FALLING", 
	OUTDIVIDER_MUXD => "DIVD", CLKOS3_ENABLE => "DISABLED", 
	OUTDIVIDER_MUXC => "DIVC", CLKOS2_ENABLE => "DISABLED", 
	OUTDIVIDER_MUXB => "DIVB", CLKOS_ENABLE => "DISABLED", 
	OUTDIVIDER_MUXA => "DIVA", CLKOP_ENABLE => "ENABLED",
	CLKOP_DIV => 6, CLKOS_DIV => 12, CLKOS2_DIV => 5, CLKOS3_DIV => 10, 
	CLKFB_DIV => 16, CLKI_DIV => 3, FEEDBK_PATH => "INT_OP"
    )
    port map (
	CLKI => clk_25m, CLKFB => CLKFB_t, PHASESEL1 => '0', 
	PHASESEL0 => '0', PHASEDIR => '0', 
	PHASESTEP => '0', PHASELOADREG => '0', STDBY => '0', 
	PLLWAKESYNC => '0', RST => '0',
	ENCLKOP => '1', ENCLKOS => '1', ENCLKOS2 => '1', ENCLKOS3 => '1', 
	CLKOP => CLKOP_t, CLKOS => CLKOS_t, CLKOS2 => CLKOS2_t, 
	CLKOS3 => CLKOS3_t, LOCK => LOCK, INTLOCK =>open, REFCLK => open, 
	CLKINTFB => CLKFB_t
    );

    clk_160m <= CLKOS2_t;
    clk_133m33 <= CLKOP_t;
    clk_66m66 <= CLKOS_t;
    clk_80m <= CLKOS3_t;
end x;
