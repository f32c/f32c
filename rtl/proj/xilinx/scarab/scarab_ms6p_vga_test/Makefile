project = miniSpartan6-plus
vendor = xilinx
family = spartan6
# for different FPGA chip, parameter override:
# MODEL=xc6slx9 make
MODEL ?= xc6slx25
part = ${MODEL}-ftg256-3 # last number -3 is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = scarab_vga_test
isedir = /opt/Xilinx/ISE/14.7/ISE_DS
xil_env = . $(isedir)/settings64.sh
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
# openocd_interface = ../include/ft2232-fpu1.ocd
openocd_interface = ../../include/ft2232-generic.ocd
xc3sprog_interface = ftdi

vhdfiles = \
../../../../xilinx/scarab_ms6p/top/top_scarab_vga_test.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_100M_25M_250M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_100M_125Mp_125Mn_25M.vhd \
../../../../xilinx/chip/xc6/hdmi_out_xc6.vhd \
../../../../xilinx/chip/xc6/ddr_out.vhd \
../../../../soc/vgahdmi/glue_vga_test.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/vgahdmi/video_mode_pack.vhd \
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/ddr_dvid_out_se.vhd \
../../../../soc/vgahdmi/vga2lcd.vhd \

include ../../include/xilinx.mk
