#!/bin/bash -e

# convert to svf
# . /usr/local/xilinx/14.7/ISE_DS/settings32.sh
# impact -batch ../include/bit2svf.ut
# openocd -f ../include/ft2232-fpu1.ocd -f esa11.ocd
xc3sprog -c ft4232h -p 0 default.bit
