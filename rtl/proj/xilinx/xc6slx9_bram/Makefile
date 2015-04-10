project = xc6slx9
vendor = xilinx
family = spartan6
part = xc6slx9-tqg144-2 # last number -2 is speed grade
flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
SHELL = /bin/bash

# ../../../xilinx/glue_xc6slx9.vhd \

vhdfiles = \
../../../xilinx/xc6slx9_toplevel_bram.vhd \
../../../generic/glue_bram_mi32.vhd \
../../../generic/bootloader_mi32.vhd \
../../../generic/bram.vhd \
../../../generic/bptrace.vhd \
../../../generic/reg1w2r.vhd \
../../../cpu/alu.vhd \
../../../cpu/loadalign.vhd \
../../../cpu/pipeline.vhd \
../../../cpu/shift.vhd \
../../../cpu/debug.vhd \
../../../soc/sio.vhd \
../../../cpu/defs_f32c.vhd \
../../../cpu/defs_mi32.vhd \
../../../cpu/defs_rv32.vhd \
../../../cpu/idecode_mi32.vhd \
../../../cpu/idecode_rv32.vhd \
../../../xilinx/pll_25M_112M5.vhd \
../../../soc/timer.vhd 

include ../include/xilinx.mk
