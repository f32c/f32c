module clk_25_125_89_89s_48_v
(
    input clkin, // 25 MHz, 0 deg
    output [3:0] clkout, // 0: 125 MHz, 0 deg; 1: 89.2857 MHz, 0 deg; 2: 89.2857 MHz, 180 deg; 3: 48.0769 MHz, 0 deg
    output locked
);
wire clkfb;
wire clkos;
wire clkop;
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .CLKOP_FPHASE(0),
        .CLKOP_CPHASE(2),
        .OUTDIVIDER_MUXA("DIVA"),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(5),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(7),
        .CLKOS_CPHASE(2),
        .CLKOS_FPHASE(0),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(7),
        .CLKOS2_CPHASE(5),
        .CLKOS2_FPHASE(4),
        .CLKOS3_ENABLE("ENABLED"),
        .CLKOS3_DIV(13),
        .CLKOS3_CPHASE(2),
        .CLKOS3_FPHASE(0),
        .CLKFB_DIV(5),
        .CLKI_DIV(1),
        .FEEDBK_PATH("INT_OP")
    ) pll_i (
        .CLKI(clkin),
        .CLKFB(clkfb),
        .CLKINTFB(clkfb),
        .CLKOP(clkop),
        .CLKOS(clkout[1]),
        .CLKOS2(clkout[2]),
        .CLKOS3(clkout[3]),
        .RST(1'b0),
        .STDBY(1'b0),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(locked)
	);
assign clkout[0] = clkop;
endmodule
