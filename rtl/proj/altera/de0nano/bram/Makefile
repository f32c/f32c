###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = project
TOP_LEVEL_ENTITY = glue
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf

###################################################################
# Part, Family, Boardfile
FAMILY = "Cyclone IV E"
PART = EP4CE22F17C6
BOARDFILE = de0.board
CONFIG_DEVICE = EPCS64
SERIAL_FLASH_LOADER_DEVICE = EP4CE6

###################################################################
#
# Quartus shell environment vars
#
###################################################################

quartus_env ?= . ../include/quartus_env.sh

# include makefile which does it all
include ../include/altera.mk

###################################################################
# Setup your sources here
SRCS = \
../../../altera/de0_toplevel_bram.vhd \
../../../altera/pll_50m.vhd \
../../../generic/glue_bram.vhd \
../../../generic/bram_mi32.vhd \
../../../generic/bram_rv32.vhd \
../../../generic/bptrace.vhd \
../../../cpu/idecode_rv32.vhd \
../../../cpu/idecode_mi32.vhd \
../../../cpu/defs_rv32.vhd \
../../../cpu/defs_mi32.vhd \
../../../cpu/defs_f32c.vhd \
../../../cpu/shift.vhd \
../../../cpu/mul_iter.vhd \
../../../cpu/f32c_core.vhd \
../../../cpu/loadalign.vhd \
../../../cpu/idecode.vhd \
../../../cpu/alu.vhd \
../../../cpu/debug.vhd \
../../../soc/sio.vhd \
../../../soc/gpio.vhd \
../../../soc/timer.vhd \
