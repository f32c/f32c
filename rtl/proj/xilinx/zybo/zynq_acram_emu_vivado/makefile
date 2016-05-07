#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=zybo_xram_acram_emu
xc3sprog_interface = jtaghs1_fast
xc3sprog_device = 1
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/$(project).bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim

junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.upgrade_log
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.v
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.vhdl
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.dcp
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.xml
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.xdc
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.veo
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.vho
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.tcl
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.ncf
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/*.log
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/doc
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/sim
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/synth
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_250_25MHz_vivado2016.1/clk_wiz_v5_3_0

junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.upgrade_log
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.v
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.vhdl
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.dcp
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.xml
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.xdc
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.veo
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.vho
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.tcl
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.ncf
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/*.log
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/doc
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/sim
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/synth
junk+=../../../../xilinx/zybo/clocks/clk_125_100_200_400_40MHz_vivado2016.1/clk_wiz_v5_3_0

include ../../include/vivado.mk
