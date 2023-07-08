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
CONFIG_DEVICE = EPCS16
SERIAL_FLASH_LOADER_DEVICE = EP4CE6
# OPENOCD_INTERFACE=interface/altera-usb-blaster.cfg
# OPENOCD_INTERFACE=ftdi-fpu1.ocd
OPENOCD_INTERFACE=remote.ocd

###################################################################
#
# Quartus shell environment vars
#
###################################################################

quartus_env ?= . ../../include/quartus_env.sh

# include makefile which does it all
include ../../include/altera.mk

###################################################################
# Setup your sources here
SRCS = \
../../../../altera/de0nano/top_sdram.vhd \
../../../../altera/de0nano/clocks/pll_50m.vhd \
../../../../altera/de0nano/clocks/pll_50m_81m25.vhd \
../../../../generic/hdmi_out.vhd \
../../../../generic/glue_sdram_fb.vhd \
../../../../generic/bram.vhd \
../../../../generic/bootloader/defs_bootblock.vhd \
../../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../../generic/bootloader/boot_rom_mi32el.vhd \
../../../../generic/bram_true2p_1clk.vhd \
../../../../generic/bram_true2p_2clk.vhd \
../../../../generic/bptrace.vhd \
../../../../generic/acram_emu.vhd \
../../../../generic/bram_video.vhd \
../../../../cpu/idecode_rv32.vhd \
../../../../cpu/idecode_mi32.vhd \
../../../../cpu/f32c_cache.vhd \
../../../../cpu/defs_rv32.vhd \
../../../../cpu/defs_mi32.vhd \
../../../../cpu/defs_f32c.vhd \
../../../../cpu/shift.vhd \
../../../../cpu/mul_iter.vhd \
../../../../cpu/f32c_core.vhd \
../../../../cpu/loadalign.vhd \
../../../../cpu/alu.vhd \
../../../../cpu/debug.vhd \
../../../../soc/sram_pack.vhd \
../../../../soc/sram.vhd \
../../../../soc/sram_refresh.vhd \
../../../../soc/sram8.vhd \
../../../../soc/acram.vhd \
../../../../soc/sdram.vhd \
../../../../soc/sdram_mz.vhd \
../../../../soc/sdram_pack.vhd \
../../../../soc/sio.vhd \
../../../../soc/spi.vhd \
../../../../soc/gpio.vhd \
../../../../soc/timer.vhd \
../../../../soc/pcm.vhd \
../../../../soc/pid/pid.vhd \
../../../../soc/pid/ctrlpid.vhd \
../../../../soc/pid/simotor.vhd \
../../../../soc/pid/rotary_decoder.vhd \
../../../../soc/fm/fm.vhd \
../../../../soc/fm/fmgen.vhd \
../../../../soc/fm/rds.vhd \
../../../../soc/fm/bram_rds.vhd \
../../../../soc/fm/message.vhd \
../../../../soc/fm/lowpass.vhd \
../../../../soc/ps2.vhd \
../../../../soc/pid/ctrlpid_v.v \
../../../../soc/pid/simotor_v.v \
../../../../soc/pid/rotary_decoder_v.v \
../../../../soc/vgahdmi/compositing_fifo.vhd \
../../../../soc/vgahdmi/compositing2_fifo.vhd \
../../../../soc/fb.vhd \
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/VGA_textmode.vhd \
../../../../soc/vgahdmi/font_block_pack.vhd \
../../../../soc/vgahdmi/font8x8_xark.vhd \
../../../../soc/vgahdmi/font8x16_xark.vhd \
../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/ledstrip.vhd \
../../../../soc/vgahdmi/ws2812b.vhd \
../../../../soc/vgahdmi/pulse_counter.vhd \
