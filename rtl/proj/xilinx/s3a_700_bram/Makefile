project = s3a_700_bram
vendor = xilinx
family = spartan3
part = xc3s700an-fgg484-4 # last number -4 is speed grade
#part = xc3s700an-fgg484-5 # last number -5 is speed grade
flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
openocd_interface = interface/altera-usb-blaster.cfg
xc3sprog_interface = xpc
SHELL = /bin/bash

vhdfiles = \
../../../xilinx/s3_toplevel_bram.vhd \
../../../xilinx/dcm_s3_50m.vhd \
../../../generic/glue_bram.vhd \
../../../generic/bram.vhd \
../../../generic/boot_block_pack.vhd \
../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../generic/bootloader/boot_sio_rv32el.vhd \
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
