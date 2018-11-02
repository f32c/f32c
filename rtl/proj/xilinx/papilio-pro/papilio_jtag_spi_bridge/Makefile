#project = bscan_xc6s_tqg144
project = bscan_xc6s_tqg144
vendor = xilinx
family = spartan6
part = xc6slx9-tqg144-2 # last number -2 is speed grade
#part = xc6slx25-ftg256-3
#flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
flashsize = 16384 # KB (kilobytes) - SPI flash device is M25P40
top_module = top
isedir = /usr/local/xilinx/14.7/ISE_DS
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
#openocd_interface = ../include/ft2232-fpu1.ocd
openocd_interface = ../../include/ft2232-generic.ocd
xc3sprog_interface = ftdi

# ../../../xilinx/glue_xc6slx9.vhd \

vfiles = bscan_s6_spi_isf_ext.v

include ../../include/xilinx.mk
