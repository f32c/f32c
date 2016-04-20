project = esa11
vendor = xilinx
family = artix7
part = xc7a100t-fgg484-1  # last number -N is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
openocd_interface = ../include/ft2232-fpu1.ocd
# openocd_interface = ../include/ft2232-generic.ocd
xc3sprog_interface = ftdi

# ../../../xilinx/glue_xc6slx9.vhd \

vfiles = \
../../../soc/pid/ctrlpid_v.v \
../../../soc/pid/simotor_v.v \
../../../soc/pid/rotary_decoder_v.v \


vhdfiles = \
../../../xilinx/esa11_7a35i_toplevel_bram.vhd \
../../../xilinx/pll_50M_112M5.vhd \
../../../xilinx/pll_50M_100M.vhd \
../../../xilinx/pll_50M_81M25.vhd \
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
