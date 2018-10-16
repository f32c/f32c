#!/bin/sh
# openocd --file=interface/altera-usb-blaster.cfg --file=xc6slx9.ocd
openocd_ft232r --file=../../include/ft232r.ocd --file=xc6slx9.ocd
