# ZYBO DDR3 attempt

Some writings one the net write about possibility
to access ZYBO DDR3 RAM from PL over AXI. 
Normally ZYBO RAM is used by PS .

    PL = f32c softcore in VHDL
    PS = ARM hardcore aka ZYNQ)

This is an attempt, it compiles but does not work.

A minimum ZINQ is instantiated with one general
purpose slave AXI port. This port should be accessed
by axi_cache.

# Compiling

From GUI, Generate block design for zinq_ram
Sources (middle top window) -> 
IP Sources (on bottom of this window to change tab) -> 
right click zinq_ram -> 
pulldown "Create HDL Wrapper".

then click generate bitstream on bottom of left window

To reconfigure ZYNQ, click on left window Open Block Design

# Bitstream works

It shows fading leds, it displays HDMI test picture,
a blink led can be uploaded to BRAM and it works

# Problems

No RAM ready signal, first write to ram will stop f32c CPU.

In toplevel module, some vector sizes between axi_cache and the ZINQ
are different so ti is just crudely adapted just for compil to pass
without much in-depth thinking of any meaning of them.

I'm not sure is axi and zynq clocked correctly either.

