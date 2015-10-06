vivado  ?= /opt/Xilinx/Vivado/2015.2/bin/vivado
# basename of the file some_project.xpr
project ?= project
# xc3sprog interface name
xc3sprog_interface ?= ftdi
xc3sprog_device ?= 0
# name of the resulting bitstream file (*.bit)
bitfile=$(project).runs/impl_1/glue.bit

build: $(bitfile)

$(bitfile): clean
	# $(vivado) -mode tcl -source run_vivado.tcl -tclargs build
	$(vivado) -mode tcl -source run_vivado.tcl -tclargs build -tclargs $(project).xpr

clean:
	# slow and it doesn't clean it all
	# $(vivado) -mode tcl -source run_vivado.tcl -tclargs clean
	# faster to remove project files
	rm -rf *~ vivado.jou vivado.log webtalk* vivado_*.backup.???
	rm -rf $(project).cache $(project).hw $(project).runs $(project).sim $(project).srcs

program: xc3sprog

xc3sprog:
	xc3sprog -c $(xc3sprog_interface) -p $(xc3sprog_device) $(bitfile)
