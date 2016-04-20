#vivado=/opt/Xilinx/Vivado/2015.3/bin/vivado
project=esa11_7a35i_xram_bram
xc3sprog_interface = ft4232h_fast
# name of resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/glue.bit

junk=*~
junk+=.Xil vivado.log vivado.jou
junk+=$(project).ip_user_files
junk+=$(project).cache

include ../../include/vivado.mk
