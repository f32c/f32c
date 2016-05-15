# DDR3 support over MIG and AXI interconnect

ESA11 team created config scripts for MIX and AXI
interconnect and the RAM axi_cache.vhd interface for the
plasma CPU which has similar bus signaling to F32C.

F32C team created acram.vhd the minimalisted 
memory driver containg only a multiport arbiter
with minimal adaptation to connect to a single memory
port over axi_cache.vhd, using plasma-compatible bus 
signaling.

The MIG config files mig_7series_1.xci and mig_a.prj
are taken unmodified, from ESA11-7a35i and old versions of 
Vivado (pre 2015.4). However it seems that vivados older 
than 2016.1 didn't compile f32c bus arbitration struct 
correctly so this DDR3 had no chance to work 
(constant value passed to the memory bus).

New vivado 2016.1 seem to compile arbitration correctly 
but IDE MIG GUI interface scripts have changed. On vivado
2016.1 IDE it is no longer possible (at least we don't know how) 
to Re-customize MIG module from vivado and get the functional 
MIG DDR3 module after.

Old config files for the reference clock had option "Use System clock"
which was 200MHz on board 7a35i and it worked.
That option and frequency are no longer availabe on 2016.1 IDE MIG
customization window. However the internal scripts still seem to accept
old options if manually put in config file mig_a.prj

    <ReferenceClock>Use System Clock</ReferenceClock>
    <InputClkFreq>200</InputClkFreq>

see also generated verilog files how they internally connect mmcm_clk

    generate
    if (REFCLK_TYPE == "USE_SYSTEM_CLOCK")
      assign clk_ref_in = mmcm_clk;
    else
      assign clk_ref_in = clk_ref_i;
    endgenerate

Also note that DDR3 AXI support is only available when generated in
verilog format. f32c project must have global desgin language set to verilog
although f32c is 99% vhdl.
Modules in f32c which instantiate mig should have some component.* entries 
to wrap this up.

So the 7a35i mig config files are manually changed with text editor
replacing 7a35t -> 7a100t, new chip name but leaving all the rest
of options and pinout the same as on board ESA11-7a35i.

New chip 7a100t might be more happy with clock speed as prescribed
by the book, but at least it compiles and creates a nice bitstream which
runs compositing2 video examples :)
