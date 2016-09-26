-- VHDL netlist generated by SCUBA Diamond (64-bit) 3.7.0.96.1
-- Module  Version: 5.7
--/mt/lattice/diamond/3.7_x64/ispfpga/bin/lin64/scuba -w -n pll_25m_112m5_56m25 -lang vhdl -synth synplify -arch mg5a00 -type pll -fin 25 -phase_cntl STATIC -fclkop 112.5 -fclkop_tol 0.0 -fb_mode CLOCKTREE -noclkos -fclkok 56.25 -fclkok_tol 0.0 -norst -noclkok2 

-- Mon Sep 26 01:21:47 2016

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library xp2;
use xp2.components.all;
-- synopsys translate_on

entity pll_25m_112m5_56m25 is
    port (
        CLK: in std_logic; 
        CLKOP: out std_logic; 
        CLKOK: out std_logic; 
        LOCK: out std_logic);
end pll_25m_112m5_56m25;

architecture Structure of pll_25m_112m5_56m25 is

    -- internal signal declarations
    signal CLKOP_t: std_logic;
    signal scuba_vlo: std_logic;

    -- local component declarations
    component VLO
        port (Z: out std_logic);
    end component;
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
    attribute CLKOK_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute CLKOS_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "112.500000";
    attribute CLKOP_BYPASS of PLLInst_0 : label is "DISABLED";
    attribute PHASE_CNTL of PLLInst_0 : label is "STATIC";
    attribute DUTY of PLLInst_0 : label is "8";
    attribute PHASEADJ of PLLInst_0 : label is "0.0";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "25.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "56.250000";
    attribute CLKOK_DIV of PLLInst_0 : label is "2";
    attribute CLKOP_DIV of PLLInst_0 : label is "4";
    attribute CLKFB_DIV of PLLInst_0 : label is "9";
    attribute CLKI_DIV of PLLInst_0 : label is "2";
    attribute FIN of PLLInst_0 : label is "25.000000";
    attribute syn_keep : boolean;
    attribute NGD_DRC_MASK : integer;
    attribute NGD_DRC_MASK of Structure : architecture is 1;

begin
    -- component instantiation statements
    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    PLLInst_0: EPLLD1
        -- synopsys translate_off
        generic map (CLKOK_BYPASS=> "DISABLED", CLKOS_BYPASS=> "DISABLED", 
        CLKOP_BYPASS=> "DISABLED", PHASE_CNTL=> "STATIC", DUTY=>  8, 
        PHASEADJ=> "0.0", CLKOK_DIV=>  2, CLKOP_DIV=>  4, CLKFB_DIV=>  9, 
        CLKI_DIV=>  2)
        -- synopsys translate_on
        port map (CLKI=>CLK, CLKFB=>CLKOP_t, RST=>scuba_vlo, 
            RSTK=>scuba_vlo, DPAMODE=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, PWD=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, LOCK=>LOCK, CLKINTFB=>open);

    CLKOP <= CLKOP_t;
end Structure;

-- synopsys translate_off
library xp2;
configuration Structure_CON of pll_25m_112m5_56m25 is
    for Structure
        for all:VLO use entity xp2.VLO(V); end for;
        for all:EPLLD1 use entity xp2.EPLLD1(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
