vivado=/opt/Xilinx/Vivado/2015.2/bin/vivado

build: clean
	$(vivado) -mode tcl -source run_vivado.tcl -tclargs build

clean:
	$(vivado) -mode tcl -source run_vivado.tcl -tclargs clean
