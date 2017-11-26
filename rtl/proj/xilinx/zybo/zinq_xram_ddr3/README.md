# ZYBO DDR3 attempt

Some writings one the net write about possibility
to access ZYBO DDR3 RAM from PL over AXI. 
Normally ZYBO RAM is used by PS .

    PL = f32c softcore in VHDL
    PS = ARM hardcore aka ZYNQ)

A minimum ZYNQ is instantiated with one general
purpose slave AXI port. This port should be accessed
by axi_cache.

# Configuring and Compiling

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

untested: ACP port might be more suitable as it
uses hardcore cache from ZYNQ

Checking the "Use slave driven AxUSER values"  
box does in fact work.  Checking the box sets the 
parameter C_USE_DEFAULT_ACP_USER_VAL to 1, which I 
assume sets the peripheral to use the default values 
and always enforce coherency.

ACP has bits to cache enable, they all must be set:
S_ACP_AXI_ARCACHE => (others => '1')
S_ACP_AXI_AWCACHE => (others => '1')

Make all needed ports externally accessible.
Right click on zynq box and choose "Make extenal"

In address editor tab, select HP0 (or ACP)
and auto-assign address, view if it is correct or
manually set mapping range
0x0000_0000 size 32MB to 0x03FF_FFFF
Address editor tap *should* be on titlebar
of the window in which ZYNQ schematic box is shown.
Window menu entry may bring it up, if not delete
whole zynq box and start new block design.

Right click on zynq box and "Validate design".
Should pass with no errors.

On sources, navigate to zynq instance and 
click "make HDL wrapper" and "generate output products"

In sources, right clicking of zynq instace can view
HDL wrapper source, that is important to see right names
and bit widths of the signals

Recompile bitstream (click Generate Bitstream and wait 10 minutes)

# Bitstream works

Board must first boot to linux. Select jumper
SD/QSPI/JTAG to QSPI possition (jumper in the middle)

Power the board, yellow LEDs near TX/RX should blink as linux
prints boot messages and green LED MIO7 will turn on and be lit for
some time (less than 1 minute). When MIO7 LED turns off, linux has 
mostly booted to the point when we can upload f32c DDR3 bitstream.

So upload bitstream over JTAG (xc3sprog works)

f32c shows fading on LED0-2, and LED3 should be blinking at cca 1Hz rate, 
indicating that ZYNQ is outputing some clock, what means that it should
have some input clock too. Without LED3 blinking it not expected that DDR3
will work.

Bitstream will display HDMI and VGA test picture, but that is no
indication that DDR3 works. Try to upload blink to SDRAM, note that
LED0-2 correspond to arduino pins 8-10, while examples use pin 13 for
LED so edit it first to 8 and if that blinks, DDR3 is working

# After Vivado Upgrade

Module "zinq_ram" will have yellow triangle.
Right-click on "zinq_ram" module -> Reset output products.
Right-click on "zinq_ram" module -> Generate output products.
Right-click on "zinq_ram" module -> Generate HDL wrapper.
Yelow triangle will still be there.

Clock will have some red markings,
Right-click on clock module -> Ugrade IP -> continue with IP container
disabled -> OK

# Problems

Some dirty fixes in address relocation and handling
probably 64-bit memory as 32-bit access

I have not exported hardware design to SDK and compiled
my own FSBL or linux, but used stock installation from
factory.

Those steps may be needed to reconfigure ZYNQ into 
more suitable and cleaner DDR3 behaviour and clocks.

