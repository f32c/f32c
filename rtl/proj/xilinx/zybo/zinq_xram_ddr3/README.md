# ZYBO DDR3 attempt

Some writings one the net write about possibility
to access ZYBO DDR3 RAM from PL over AXI. 
Normally ZYBO RAM is used by PS .

    PL = f32c softcore in VHDL
    PS = ARM hardcore aka ZYNQ)

A minimum ZYNQ is instantiated with one general
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


Use zynq default DDR3 options (don't change anything
except zynq core clock to 525 MHz (default is 533.333 MHz)

Disable GP0 port.
Double click to ZYNQ shematic box and enable HP0 port 
(high performance port 0)

Make all needed ports externally accessible.

In address editor tab, select HP0 mapping range
0x0000_0000 size 32MB to 0x03FF_FFFF
Address editor tap *should* be on titlebar
of the window in which ZYNQ schematic box is shown.

Right click on zynq box and "Validate design".
Should pass with no errors.

On sources, navigate to zynq instance and 
click "make HDL wrapper" and "generate output products"

Recompile bitstream

# Bitstream works

Board must first boot to linux. Select jumper
SD/QSPI/JTAG to QSPI possition (jumper in the middle)

Power the board, yellow TX/RX should blink as linux
print boot messages and green MIO7 will light for several seconds 
and when it turns off, linux has mostly booted.

Then upload bitstream over JTAG.

It shows fading leds, and LED3 has to blink, indicating
that ZYNQ is clocked.

Bitstream also displays HDMI test picture,

# Problems

Some dirtyness fixes in address.
I have not exported hardware design to SDK and compiled
my own FSBL or linux, but used stock installation from
factory. 

Those steps may be needed to reconfigure ZYNQ into 
more suitable DDR3 behaviour and clocks
