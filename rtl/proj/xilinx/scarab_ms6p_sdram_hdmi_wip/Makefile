project = miniSpartan6-plus
vendor = xilinx
family = spartan6
part = xc6slx25-ftg256-3 # last number -3 is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /opt/Xilinx/ISE/14.7/ISE_DS
xil_env = . $(isedir)/settings64.sh
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
# openocd_interface = ../include/ft2232-fpu1.ocd
openocd_interface = ../include/ft2232-generic.ocd
xc3sprog_interface = ftdi

vfiles = \
../../../soc/pid/ctrlpid_v.v \
../../../soc/pid/simotor_v.v \
../../../soc/pid/rotary_decoder_v.v \
../../../soc/vgahdmi/vgahdmif_v.v \

vhdfiles = \
../../../xilinx/scarab_ms6p_toplevel_sdram_wip.vhd \
../../../xilinx/pll_50M_112M5.vhd \
../../../xilinx/pll_50M_100M.vhd \
../../../xilinx/pll_50M_100M_25M_250M.vhd \
../../../xilinx/pll_50M_81M25.vhd \
../../../xilinx/pll_50M_25M_83M33_250M.vhd \
../../../xilinx/pll_50M_250M_125M_25M.vhd \
../../../xilinx/pll_50M_250M_111M11_25M.vhd \
../../../xilinx/hdmi_out.vhd \
../../../generic/glue_sdram_wip.vhd \
../../../generic/bram.vhd \
../../../generic/boot_block_pack.vhd \
../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../generic/bram_true2p_1clk.vhd \
../../../generic/bram_true2p_2clk.vhd \
../../../generic/bptrace.vhd \
../../../generic/reg1w2r.vhd \
../../../generic/bram_video.vhd \
../../../cpu/alu.vhd \
../../../cpu/loadalign.vhd \
../../../cpu/pipeline.vhd \
../../../cpu/shift.vhd \
../../../cpu/defs_f32c.vhd \
../../../cpu/defs_mi32.vhd \
../../../cpu/defs_rv32.vhd \
../../../cpu/idecode_mi32.vhd \
../../../cpu/idecode_rv32.vhd \
../../../cpu/cache_generic_param.vhd \
../../../cpu/debug.vhd \
../../../soc/sram_pack.vhd \
../../../soc/arbiter.vhd \
../../../soc/sdram_ctrl.vhd \
../../../soc/ram_emu.vhd \
../../../soc/sdram.vhd \
../../../soc/sio.vhd \
../../../soc/spi.vhd \
../../../soc/gpio.vhd \
../../../soc/timer.vhd \
../../../soc/pcm.vhd \
../../../soc/pid/pid.vhd \
../../../soc/pid/ctrlpid.vhd \
../../../soc/pid/simotor.vhd \
../../../soc/pid/rotary_decoder.vhd \
../../../soc/fm/fm.vhd \
../../../soc/fm/fmgen.vhd \
../../../soc/fm/rds.vhd \
../../../soc/fm/bram_rds.vhd \
../../../soc/fm/message.vhd \
../../../soc/vgahdmi/compositing_fifo.vhd \
../../../soc/vgahdmi/videofifo_bram.vhd \
../../../soc/vgahdmi/vgahdmif.vhd \
../../../soc/vgahdmi/VGA_textmode.vhd \
../../../soc/vgahdmi/font_block_pack.vhd \
../../../soc/vgahdmi/font8x8_xark.vhd \
../../../soc/vgahdmi/font8x16_xark.vhd \
../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../soc/vgahdmi/dvid_out.vhd \

include ../include/xilinx.mk
