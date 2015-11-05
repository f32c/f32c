#!/bin/sh
# openocd --file=interface/altera-usb-blaster.cfg --file=xc6slx9.ocd
openocd --file=remote.ocd --file=xc6slx9.ocd
