project = zybo
vendor = xilinx
family = zinq
part = xc7z010-clg400-1 # last number -1 is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
openocd_interface = ftdi-zybo.ocd
SHELL = /bin/bash

vfiles = \
../../../soc/pid/ctrlpid_v.v \
../../../soc/pid/simotor_v.v \
../../../soc/pid/rotary_decoder_v.v \

vhdfiles = \
../../../xilinx/zybo_toplevel_bram.vhd \
../../../generic/glue_bram.vhd \
../../../generic/bram_mi32_eb.vhd \
../../../generic/bram_mi32_el.vhd \
../../../generic/bram_rv32.vhd \
../../../generic/bptrace.vhd \
../../../generic/reg1w2r.vhd \
../../../cpu/alu.vhd \
../../../cpu/loadalign.vhd \
../../../cpu/pipeline.vhd \
../../../cpu/shift.vhd \
../../../cpu/defs_f32c.vhd \
../../../cpu/defs_mi32.vhd \
../../../cpu/defs_rv32.vhd \
../../../cpu/idecode_mi32.vhd \
../../../cpu/idecode_rv32.vhd \
../../../cpu/debug.vhd \
../../../soc/sio.vhd \
../../../soc/spi.vhd \
../../../soc/gpio.vhd \
../../../soc/timer.vhd \
../../../soc/pid/pid.vhd \
../../../soc/pid/ctrlpid.vhd \
../../../soc/pid/simotor.vhd \
../../../soc/pid/rotary_decoder.vhd \

include ../include/xilinx.mk
