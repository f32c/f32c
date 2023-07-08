###################################################################
# Project Configuration:
#
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = project
TOP_LEVEL_ENTITY = de10lite_xram_sdram
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf

###################################################################
# Part, Family, Boardfile
FAMILY = "MAX 10 FPGA"
PART = 10M50DAF484C7G
BOARDFILE = de10-lite.board
CONFIG_DEVICE = EPCS64
SERIAL_FLASH_LOADER_DEVICE = EP4CE6
OPENOCD_INTERFACE=altera-usb-blaster.ocd
# OPENOCD_INTERFACE=ftdi-fpu1.ocd
# OPENOCD_INTERFACE=remote.ocd
OPENOCD_BOARD=de10-lite.ocd

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
../../../../altera/de10lite/top/top_de10lite_xram_sdram_vector.vhd \
../../../../altera/de10lite/clocks/clk_50M_25M_125MP_125MN_100M_83M33.vhd \
../../../../altera/de10lite/clocks/clk_50M_25M_250M_75M.vhd \
../../../../generic/hdmi_out.vhd \
../../../../generic/glue_xram_vector.vhd \
../../../../generic/bram.vhd \
../../../../generic/bootloader/defs_bootblock1k.vhd \
../../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../../generic/bootloader/boot_rom_mi32el_empty.vhd \
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
../../../../soc/sdram32.vhd \
../../../../soc/sram8.vhd \
../../../../soc/acram.vhd \
../../../../soc/axiram.vhd \
../../../../soc/axi_pack.vhd \
../../../../soc/axi_read.vhd \
../../../../soc/dacpwm.vhd \
../../../../soc/i2s.vhd \
../../../../soc/rtc.vhd \
../../../../soc/spdif_tx.vhd \
../../../../soc/sigmadelta.vhd \
../../../../soc/synth.vhd \
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
../../../../soc/usb11_phy/usb_rx_phy_emard.vhd \
../../../../soc/usb11_phy/usb_rx_phy_48MHz.vhd \
../../../../soc/usb11_phy/usb_tx_phy.vhd \
../../../../soc/usb11_phy/usb_phy.vhd \
../../../../soc/usb_serial/usbsio.vhd \
../../../../soc/usb_serial/usb_serial.vhd \
../../../../soc/usb_serial/usb_packet.vhd \
../../../../soc/usb_serial/usb_init.vhd \
../../../../soc/usb_serial/usb_control.vhd \
../../../../soc/usb_serial/usb_transact.vhd \
../../../../soc/usb_serial/usbsio.vhd \
../../../../soc/vgahdmi/vga2lcd35.vhd \
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/compositing2_fifo.vhd \
../../../../soc/vgahdmi/video_cache_i.vhd \
../../../../soc/vgahdmi/video_cache_d.vhd \
../../../../soc/vgahdmi/video_mode_pack.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/VGA_textmode.vhd \
../../../../soc/vgahdmi/font_block_pack.vhd \
../../../../soc/vgahdmi/font8x8_xark.vhd \
../../../../soc/vgahdmi/font8x16_xark.vhd \
../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/vga2lcd.vhd \
../../../../soc/vgahdmi/ledstrip.vhd \
../../../../soc/vgahdmi/ws2812b.vhd \
../../../../soc/vgahdmi/pulse_counter.vhd \
../../../../soc/vector/vector.vhd \
../../../../soc/vector/f32c_vector_dma.vhd \
../../../../soc/vector/axi_vector_dma.vhd \
../../../../soc/vector/fpu/add_sub/fpu_arch.vhd \
../../../../soc/vector/fpu/add_sub/add_sub27_arch.vhd \
../../../../soc/vector/fpu/add_sub/except_arch.vhd \
../../../../soc/vector/fpu/add_sub/pre_norm_arch.vhd \
../../../../soc/vector/fpu/add_sub/post_norm_arch.vhd \
../../../../soc/vector/fpu/float_divide_goldschmidt.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_pipeline.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage1_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage2_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage3_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage4_struct.vhd \
../../../../soc/vector/fpu/mul/common/fpnormalize_fpnormalize.vhd \
../../../../soc/vector/fpu/mul/common/fpround_fpround.vhd \
../../../../soc/vector/fpu/mul/common/packfp_packfp.vhd \
../../../../soc/vector/fpu/mul/common/unpackfp_unpackfp.vhd \
../../../../soc/vector/fpu/add_sub_emiraga/add_sub_emiraga.vhd \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/parselib.py \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee_adder.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/generate.py \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/defines.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/config.py \
