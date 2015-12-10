project = xc6slx9
vendor = xilinx
family = spartan6
part = xc6slx9-csg324-2 # last number -2 is speed grade
flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /opt/Xilinx/ISE/14.7/ISE_DS
# xil_env = . $(isedir)/settings64.sh
SHELL = /bin/bash
bitstream_bin = $(project).bin
# openocd_interface = interface/altera-usb-blaster.cfg
openocd_interface = ../include/ft2232-fpu1.ocd
xc3sprog_interface = ftdi

# ../../../xilinx/glue_xc6slx9.vhd \

vfiles = \
../../../soc/pid/ctrlpid_v.v \
../../../soc/pid/simotor_v.v \
../../../soc/pid/rotary_decoder_v.v \
../../../soc/vgahdmi/vgahdmif_v.v \

vhdfiles = \
../../../xilinx/s6_numato_mimas_v2_toplevel_bram.vhd \
../../../xilinx/pll_25M_112M5.vhd \
../../../xilinx/pll_25M_81M25.vhd \
../../../xilinx/clk_100MHz_25MHz_250MHz.vhd \
../../../generic/glue_bram_vgaf.vhd \
../../../generic/bram.vhd \
../../../generic/boot_block_pack.vhd \
../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../generic/bootloader/boot_sio_rv32el.vhd \
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
../../../soc/fm/fm.vhd \
../../../soc/fm/fmgen.vhd \
../../../soc/fm/rds.vhd \
../../../soc/fm/bram_rds.vhd \
../../../soc/fm/message.vhd \
../../../soc/ps2.vhd \
../../../soc/vgahdmi/vgahdmif.vhd \
../../../soc/vgahdmi/videofifo.vhd \
../../../soc/vgahdmi/VGA_textmode.vhd \
../../../soc/vgahdmi/font_block_pack.vhd \
../../../soc/vgahdmi/font8x8_xark.vhd \
../../../soc/vgahdmi/font8x16_xark.vhd \
../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../soc/vgahdmi/dvid_out.vhd \
../../../generic/bram_video.vhd \
../../../xilinx/hdmi_out.vhd \


include ../include/xilinx.mk
