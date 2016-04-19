#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=zybo_xram_acram_emu
xc3sprog_interface = jtaghs1_fast
xc3sprog_device = 1
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/glue.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).sim

include ../../include/vivado.mk
