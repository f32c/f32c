# f32c

F32C is an opensource MIPS and RISC-V compatible microcontroller implemented in VHDL.
Besides 32-bit CPU core of course, it contains all basic hardware like RS232, GPIO, 
timer, interrupts and video framebuffer. It implements only a subset for MIPS and
RISC-V instruction set enough for GCC to work and have instruction per clock ratio
good enough to outperform most ARM microcontrollers running at the same clock.
It has low LUT footprint so all this can into low cost $25 development FPGA board
and leave a fair amount of LUT free..

Many FPGA boards with Altera, Lattice and Xilinx FPGA are already supported.
Porting F32C to new boards should be easy.
