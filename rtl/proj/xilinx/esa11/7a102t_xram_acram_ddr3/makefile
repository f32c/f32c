#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=esa11_7a102t_xram_acram_ddr3
xc3sprog_interface = ft4232h_fast
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/esa11_xram_acram_ddr3.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim
junk+=$(project).cache

junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.v
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.vhdl
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.dcp
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.xml
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.xdc
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.veo
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/*.vho
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/axi_interconnect_v1_7_9
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/blk_mem_gen_v8_3_2
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/fifo_generator_v13_1_0
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/synth
junk+=$(project).srcs/sources_1/ip/axi_interconnect_0/sim

junk+=$(project).srcs/sources_1/ip/mig_7series_1/example_design/
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.v
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.vhdl
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.dcp
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.xml
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.xdc
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.veo
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.vho
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.tcl
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.log
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.in
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.out
junk+=$(project).srcs/sources_1/ip/mig_7series_1/*.txt
junk+=$(project).srcs/sources_1/ip/mig_7series_1/_tmp
junk+=$(project).srcs/sources_1/ip/mig_7series_1/mig_7series_1
junk+=$(project).srcs/sources_1/ip/mig_7series_1/doc

junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/example_design/
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.v
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.vhdl
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.dcp
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.xml
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.xdc
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.veo
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/*.tcl
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/axi_bram_ctrl_v4_0
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/blk_mem_gen_v8_2
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/sim
junk+=$(project).srcs/sources_1/ip/axi_bram_ctrl_0/synth

junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.v
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.vhdl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.dcp
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.xml
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.xdc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.veo
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.vho
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.tcl
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.ncf
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/*.log
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/doc
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/sim
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/synth
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_250_25MHz/clk_wiz_v5_3_0

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
junk+=$(project).srcs/sources_1/ip/clk_d100_100_200_125_25MHz/clk_wiz_v5_3_0

junk+=$(project).srcs/sources_1/ip/cache_fifo/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.v
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.vhdl
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.dcp
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.xml
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.xdc
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.veo
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.vho
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.tcl
junk+=$(project).srcs/sources_1/ip/cache_fifo/*.ncf
junk+=$(project).srcs/sources_1/ip/cache_fifo/cache_fifo
junk+=$(project).srcs/sources_1/ip/cache_fifo/blk_mem_gen_v8_3_2
junk+=$(project).srcs/sources_1/ip/cache_fifo/fifo_generator_v13_1_0
junk+=$(project).srcs/sources_1/ip/cache_fifo/doc
junk+=$(project).srcs/sources_1/ip/cache_fifo/sim
junk+=$(project).srcs/sources_1/ip/cache_fifo/synth
junk+=$(project).srcs/sources_1/ip/cache_fifo/_xmsgs

junk+=$(project).srcs/sources_1/ip/blk_ram/*.upgrade_log
junk+=$(project).srcs/sources_1/ip/blk_ram/*.v
junk+=$(project).srcs/sources_1/ip/blk_ram/*.vhdl
junk+=$(project).srcs/sources_1/ip/blk_ram/*.dcp
junk+=$(project).srcs/sources_1/ip/blk_ram/*.xml
junk+=$(project).srcs/sources_1/ip/blk_ram/*.xdc
junk+=$(project).srcs/sources_1/ip/blk_ram/*.veo
junk+=$(project).srcs/sources_1/ip/blk_ram/*.vho
junk+=$(project).srcs/sources_1/ip/blk_ram/*.tcl
junk+=$(project).srcs/sources_1/ip/blk_ram/*.ncf
junk+=$(project).srcs/sources_1/ip/blk_ram/*.log
junk+=$(project).srcs/sources_1/ip/blk_ram/blk_mem_gen_v8_3_2
junk+=$(project).srcs/sources_1/ip/blk_ram/doc
junk+=$(project).srcs/sources_1/ip/blk_ram/sim
junk+=$(project).srcs/sources_1/ip/blk_ram/synth


include ../../include/vivado.mk
