#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=basys3_xram_acram_emu
xc3sprog_interface = jtaghs1_fast
xc3sprog_device = 1
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/basys3.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim

# 100_100_200_125_25MHz for 640x480
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/clk_wiz_v5_3_1
# clk_d100_100_200_40MHz for 800x600

include ../../include/vivado.mk
