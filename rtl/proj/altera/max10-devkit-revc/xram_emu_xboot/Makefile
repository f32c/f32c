###################################################################
# Project Configuration:
#
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = project
TOP_LEVEL_ENTITY = max10_devkit_revc_xram
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf

###################################################################
# Part, Family, Boardfile
FAMILY = "MAX 10 FPGA"
PART = 10M50DAF484C6GES
BOARDFILE = max10-devkit-revc.board
CONFIG_DEVICE = EPCS64
SERIAL_FLASH_LOADER_DEVICE = EP4CE6
OPENOCD_INTERFACE=altera-usb-blaster2.ocd
# OPENOCD_INTERFACE=altera-usb-blaster2.cfg
# OPENOCD_INTERFACE=ftdi-fpu1.ocd
# OPENOCD_INTERFACE=remote.ocd
OPENOCD_BOARD=max10-devkit-revc.ocd
OPENOCD_SVF_CLOCK=8MHz

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
../../../../altera/max10devkitrevc/top/max10_devkit_revc_xram_emu_xboot.vhd \
../../../../altera/max10devkitrevc/clocks/clk_25_25_125p_125n_75_100.vhd \
../../../../altera/max10devkitrevc/dual_config/dual_config.vhd \
../../../../altera/max10devkitrevc/dual_config/submodules/altera_dual_boot.v \
../../../../altera/max10devkitrevc/dual_config/submodules/rtl/alt_dual_boot.v \
../../../../altera/max10devkitrevc/dual_config/submodules/rtl/alt_dual_boot_avmm.v \
../../../../altera/max10devkitrevc/onchip_flash/onchip_flash.vhd \
../../../../altera/max10devkitrevc/onchip_flash/submodules/altera_onchip_flash_util.v \
../../../../altera/max10devkitrevc/onchip_flash/submodules/altera_onchip_flash_avmm_data_controller.v \
../../../../altera/max10devkitrevc/onchip_flash/submodules/altera_onchip_flash.v \
../../../../altera/max10devkitrevc/onchip_flash/submodules/altera_onchip_flash_avmm_csr_controller.v \
../../../../altera/max10devkitrevc/onchip_flash/submodules/rtl/altera_onchip_flash_block.v \
../../../../altera/max10devkitrevc/max10_boot_preloader/max10_boot_preloader.vhd \
../../../../altera/ffm/i2c_sender/i2c_sender.vhd \
../../../../generic/hdmi_out.vhd \
../../../../generic/glue_xram_vector.vhd \
../../../../generic/bram.vhd \
../../../../generic/bootloader/defs_bootblock1k.vhd \
../../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../../generic/bootloader/boot_rom_mi32el_empty.vhd \
../../../../generic/bootloader/boot_preloader.vhd \
../../../../generic/bootloader/bootrom_emu.vhd \
../../../../generic/bram_true2p_1clk.vhd \
../../../../generic/bram_true2p_2clk.vhd \
../../../../generic/bptrace.vhd \
../../../../generic/sram_emu.vhd \
../../../../generic/acram_emu.vhd \
../../../../cpu/idecode_rv32.vhd \
../../../../cpu/idecode_mi32.vhd \
../../../../cpu/cache_generic_param.vhd \
../../../../cpu/defs_rv32.vhd \
../../../../cpu/defs_mi32.vhd \
../../../../cpu/defs_f32c.vhd \
../../../../cpu/shift.vhd \
../../../../cpu/mul_iter.vhd \
../../../../cpu/pipeline.vhd \
../../../../cpu/loadalign.vhd \
../../../../cpu/alu.vhd \
../../../../cpu/debug.vhd \
../../../../soc/sram_pack.vhd \
../../../../soc/sram.vhd \
../../../../soc/sram_refresh.vhd \
../../../../soc/sram8.vhd \
../../../../soc/acram.vhd \
../../../../soc/axiram.vhd \
../../../../soc/axi_read.vhd \
../../../../soc/axi_pack.vhd \
../../../../soc/sdram.vhd \
../../../../soc/sio.vhd \
../../../../soc/spi.vhd \
../../../../soc/rtc.vhd \
../../../../soc/gpio.vhd \
../../../../soc/timer.vhd \
../../../../soc/pcm.vhd \
../../../../soc/synth.vhd \
../../../../soc/sigmadelta.vhd \
../../../../soc/spdif_tx.vhd \
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
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/video_cache_i.vhd \
../../../../soc/vgahdmi/video_cache_d.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/vgahdmi/video_mode_pack.vhd \
../../../../soc/cvbs.vhd \
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
../../../../soc/vector/fpu/add_sub_emiraga/add_sub_emiraga.vhd \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee_adder.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee.v \
../../../../soc/vector/fpu/mul/multiplier/fpmul_pipeline.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage1_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage2_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage3_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage4_struct.vhd \
../../../../soc/vector/fpu/mul/common/fpnormalize_fpnormalize.vhd \
../../../../soc/vector/fpu/mul/common/fpround_fpround.vhd \
../../../../soc/vector/fpu/mul/common/packfp_packfp.vhd \
../../../../soc/vector/fpu/mul/common/unpackfp_unpackfp.vhd \
../../../../soc/vector/fpu/float_divide_goldschmidt.vhd \

