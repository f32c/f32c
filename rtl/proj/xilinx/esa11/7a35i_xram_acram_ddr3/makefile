#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=esa11_f32c
xc3sprog_interface = ft4232h_fast
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/esa11_acram_ddr3.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim
junk+=$(project).cache

# esa11_f32c.srcs/sources_1/ip -> esa11_f32c.srcs/sources_1/ip

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

junk+=../../../../xilinx/esa11/ram/cache_fifo/*.upgrade_log
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.v
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.vhdl
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.dcp
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.xml
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.xdc
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.veo
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.vho
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.tcl
junk+=../../../../xilinx/esa11/ram/cache_fifo/*.ncf
junk+=../../../../xilinx/esa11/ram/cache_fifo/cache_fifo
junk+=../../../../xilinx/esa11/ram/cache_fifo/blk_mem_gen_v8_3_1
junk+=../../../../xilinx/esa11/ram/cache_fifo/fifo_generator_v13_0_1
junk+=../../../../xilinx/esa11/ram/cache_fifo/doc
junk+=../../../../xilinx/esa11/ram/cache_fifo/sim
junk+=../../../../xilinx/esa11/ram/cache_fifo/synth
junk+=../../../../xilinx/esa11/ram/cache_fifo/_xmsgs

junk+=../../../../xilinx/esa11/ram/blk_ram/*.upgrade_log
junk+=../../../../xilinx/esa11/ram/blk_ram/*.v
junk+=../../../../xilinx/esa11/ram/blk_ram/*.vhdl
junk+=../../../../xilinx/esa11/ram/blk_ram/*.dcp
junk+=../../../../xilinx/esa11/ram/blk_ram/*.xml
junk+=../../../../xilinx/esa11/ram/blk_ram/*.xdc
junk+=../../../../xilinx/esa11/ram/blk_ram/*.veo
junk+=../../../../xilinx/esa11/ram/blk_ram/*.vho
junk+=../../../../xilinx/esa11/ram/blk_ram/*.tcl
junk+=../../../../xilinx/esa11/ram/blk_ram/*.ncf
junk+=../../../../xilinx/esa11/ram/blk_ram/*.log
junk+=../../../../xilinx/esa11/ram/blk_ram/blk_mem_gen_v8_3_2
junk+=../../../../xilinx/esa11/ram/blk_ram/doc
junk+=../../../../xilinx/esa11/ram/blk_ram/sim
junk+=../../../../xilinx/esa11/ram/blk_ram/synth

junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.upgrade_log
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.v
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.vhdl
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.dcp
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.xml
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.xdc
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.veo
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.vho
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.tcl
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.ncf
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/*.log
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/doc
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/sim
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/synth
junk+=../../../../xilinx/esa11/clocks/clk_d100_100_200_250_25MHz_vivado2016.1/clk_wiz_v5_3_0

include ../../include/vivado.mk
