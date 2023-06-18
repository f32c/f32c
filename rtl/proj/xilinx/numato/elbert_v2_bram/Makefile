project = numato_elbert_v2_bram
vendor = xilinx
family = spartan3
#Numato Elbert V2
#XC3S50A
#TQG144AGQ1421
#4C
part = xc3s50a-tq144-4 # last number -4 is speed grade
flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
openocd_interface = interface/altera-usb-blaster.cfg
xc3sprog_interface = xpc
SHELL = /bin/bash

vhdfiles = \
../../../xilinx/s3_numato_elbert_v2_toplevel_bram.vhd \
../../../xilinx/ramb16bwe_rv32.vhd \
../../../xilinx/dcm_s3_12m.vhd \
../../../generic/glue_bram.vhd \
../../../generic/bram_mi32_eb.vhd \
../../../generic/bram_mi32_el.vhd \
../../../generic/bptrace.vhd \
../../../cpu/alu.vhd \
../../../cpu/loadalign.vhd \
../../../cpu/pipeline.vhd \
../../../cpu/shift.vhd \
../../../cpu/mul_iter.vhd \
../../../cpu/defs_f32c.vhd \
../../../cpu/defs_mi32.vhd \
../../../cpu/defs_rv32.vhd \
../../../cpu/idecode_mi32.vhd \
../../../cpu/idecode_rv32.vhd \
../../../cpu/debug.vhd \
../../../soc/sio.vhd \
../../../soc/spi.vhd \
../../../soc/gpio.vhd \
../../../soc/timer.vhd 

include ../include/xilinx.mk
