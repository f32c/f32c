#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=esa11_f32c
xc3sprog_interface = jtaghs1_fast
xc3sprog_device = 1
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/zybo_xram_ddr3.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim
junk+=$(project).cache

# esa11_f32c.srcs/sources_1/ip -> esa11_f32c.srcs/sources_1/ip

junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.v
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.vhdl
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.dcp
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.xml
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.xdc
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.veo
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/*.vho
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/axi_interconnect_v1_7_10
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/blk_mem_gen_v8_3_3
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/fifo_generator_v13_1_1
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/synth
junk+=$(project).srcs/sources_1/ip/axi_interconnect_1m64_3s32/sim

junk+=$(project).srcs/sources_1/bd/zinq_ram/ip
junk+=$(project).srcs/sources_1/bd/zinq_ram/ipshared
junk+=$(project).srcs/sources_1/bd/zinq_ram/ui
junk+=$(project).srcs/sources_1/bd/zinq_ram/hw_handoff
junk+=$(project).srcs/sources_1/bd/zinq_ram/hdl

# clk_125_100_200_250_25MHz for 640x480 SDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_25MHz/clk_wiz_v5_3_1
# clk_125_100_200_125_25MHz for 640x480 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_125_25MHz/clk_wiz_v5_3_1
# clk_125_100_200_40MHz for 800x600 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_40MHz/clk_wiz_v5_3_1
# clk_125_100_200_150_30MHz for 800x480 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_150_30MHz/clk_wiz_v5_3_1
# clk_125_108_216_325_65MHz for 1024x768 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/.Xil
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_325_65MHz/clk_wiz_v5_3_1
# clk_125_100_112_225_45MHz for 1024x576 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/.Xil
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_112_225_45MHz/clk_wiz_v5_3_1
# clk_125_100_200_250_50MHz for 1024x576 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/.Xil
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_100_200_250_50MHz/clk_wiz_v5_3_1
# clk_125_108_216_541MHz for 1280x1024 DDR
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/.Xil
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_125_108_216_541MHz/clk_wiz_v5_3_1

include ../../include/vivado.mk
