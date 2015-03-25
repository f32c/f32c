library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library xp2;
use xp2.components.all;
-- synopsys translate_on

entity pll is
    generic (
	C_pll_freq: integer
    );
    port (
        CLK: in std_logic; 
	reset: in std_logic;
        CLKOP: out std_logic; 
        CLKOK: out std_logic; 
        LOCK: out std_logic);
    attribute dont_touch : boolean;
    attribute dont_touch of pll : entity is true;
end pll;

architecture Structure of pll is

    -- internal signal declarations
    signal CLKOP_t: std_logic;
    signal CLKFB_t: std_logic;
    signal scuba_vlo: std_logic;

    -- local component declarations
    component EPLLD1
    -- synopsys translate_off
        generic (CLKOK_BYPASS : in String; CLKOS_BYPASS : in String; 
                CLKOP_BYPASS : in String; DUTY : in Integer; 
                PHASEADJ : in String; PHASE_CNTL : in String; 
                CLKOK_DIV : in Integer; CLKFB_DIV : in Integer; 
                CLKOP_DIV : in Integer; CLKI_DIV : in Integer);
    -- synopsys translate_on
        port (CLKI: in std_logic; CLKFB: in std_logic; RST: in std_logic; 
            RSTK: in std_logic; DPAMODE: in std_logic; DRPAI3: in std_logic; 
            DRPAI2: in std_logic; DRPAI1: in std_logic; DRPAI0: in std_logic; 
            DFPAI3: in std_logic; DFPAI2: in std_logic; DFPAI1: in std_logic; 
            DFPAI0: in std_logic; PWD: in std_logic; CLKOP: out std_logic; 
            CLKOS: out std_logic; CLKOK: out std_logic; LOCK: out std_logic; 
            CLKINTFB: out std_logic);
    end component;
    attribute CLKOK_BYPASS : string; 
    attribute CLKOS_BYPASS : string; 
    attribute FREQUENCY_PIN_CLKOP : string; 
    attribute CLKOP_BYPASS : string; 
    attribute PHASE_CNTL : string; 
    attribute DUTY : string; 
    attribute PHASEADJ : string; 
    attribute FREQUENCY_PIN_CLKI : string; 
    attribute FREQUENCY_PIN_CLKOK : string; 
    attribute CLKOK_DIV : string; 
    attribute CLKOP_DIV : string; 
    attribute CLKFB_DIV : string; 
    attribute CLKI_DIV : string; 
    attribute FIN : string; 
    attribute syn_keep : boolean;
    attribute syn_noprune : boolean;
    attribute syn_noprune of Structure : architecture is true;

begin
    scuba_vlo <= '0';

    PLL_325:
    if C_pll_freq = 325 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "325.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "81.250000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "2";
    attribute CLKFB_DIV of PLLInst_0 : label is "13";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  2, CLKFB_DIV=>  13, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_150:
    if C_pll_freq = 150 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "150.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "37.500000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "4";
    attribute CLKFB_DIV of PLLInst_0 : label is "6";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  4, CLKFB_DIV=>  6, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_137:
    if C_pll_freq = 137 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "137.500000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "34.375000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "4";
    attribute CLKFB_DIV of PLLInst_0 : label is "11";
    attribute CLKI_DIV of PLLInst_0 : label is "2";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  4, CLKFB_DIV=>  11, 
        CLKI_DIV=>  2)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_125:
    if C_pll_freq = 125 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "125.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "31.250000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "4";
    attribute CLKFB_DIV of PLLInst_0 : label is "5";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  4, CLKFB_DIV=>  5, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_112:
    if C_pll_freq = 112 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "112.500000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "28.125000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "4";
    attribute CLKFB_DIV of PLLInst_0 : label is "9";
    attribute CLKI_DIV of PLLInst_0 : label is "2";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  4, CLKFB_DIV=>  9, 
        CLKI_DIV=>  2)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_100:
    if C_pll_freq = 100 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "100.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "25.000000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "8";
    attribute CLKFB_DIV of PLLInst_0 : label is "4";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  8, CLKFB_DIV=>  4, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_87:
    if C_pll_freq = 87 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "87.500000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "21.875000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "8";
    attribute CLKFB_DIV of PLLInst_0 : label is "7";
    attribute CLKI_DIV of PLLInst_0 : label is "2";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  8, CLKFB_DIV=>  7, 
        CLKI_DIV=>  2)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_75:
    if C_pll_freq = 75 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "75.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "18.750000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "8";
    attribute CLKFB_DIV of PLLInst_0 : label is "3";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  8, CLKFB_DIV=>  3, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_62:
    if C_pll_freq = 62 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "62.500000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "15.625000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "8";
    attribute CLKFB_DIV of PLLInst_0 : label is "5";
    attribute CLKI_DIV of PLLInst_0 : label is "2";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  8, CLKFB_DIV=>  5, 
        CLKI_DIV=>  2)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    PLL_50:
    if C_pll_freq = 50 generate
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "50.000000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "12.500000";
    attribute CLKOK_DIV of PLLInst_0 : label is "4";
    attribute CLKOP_DIV of PLLInst_0 : label is "16";
    attribute CLKFB_DIV of PLLInst_0 : label is "2";
    attribute CLKI_DIV of PLLInst_0 : label is "1";
    attribute FIN of PLLInst_0 : label is "25.000000";
    begin
    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  4, CLKOP_DIV=>  16, CLKFB_DIV=>  2, 
        CLKI_DIV=>  1)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST => reset, 
            RSTK => reset, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>CLKFB_t);
    end generate;

    CLKOP <= CLKOP_t;
end Structure;

-- synopsys translate_off
library xp2;
configuration Structure_CON of pll is
    for Structure
        for all:EPLLD1 use entity xp2.EPLLD1(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
