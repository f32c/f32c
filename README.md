# f32c

F32C is an opensource MIPS and RISC-V compatible microcontroller implemented in VHDL.
Besides CPU core of course, it contains all basic hardware like RS232, GPIO, 
timer, interrupts and video framebuffer. It has low LUT footprint so 
all this can into low cost $25 development FPGA board and leave a fair amount
of LUT free..

Many FPGA boards with Altera, Lattice and Xilinx FPGA are already supported and
porting F32C to new boards should be easy.
