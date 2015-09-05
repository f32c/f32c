#!/bin/sh
# openocd --file=ftdi-zybo.ocd --file=zybo.ocd
xc3sprog -c jtaghs1_fast -p 1 zybo.bit
