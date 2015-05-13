# f32c

f32c is a retargetable 32-bit scalar 5-stage integer processor
pipeline which can be configured to execute subsets of either RISC-V
or MIPS instruction sets.  The core is implemented in parametrized
VHDL which permits synthesis with different area / speed tradeoffs,
and includes a branch predictor, exception handling control block,
and optional direct-mapped caches.  There is no MMU.
Configurable options include:

'''
C_arch               RISC-V or MIPS ISA
C_big_endian         bus endianess
C_mult_enable        synthesize multipler unit
C_branch_likely      support branch delay slot annulling
C_sign_extend        support sign extension instructions
C_movn_movz          support conditional move instructions
C_ll_sc              support atomic read-modify-write constructs
C_branch_prediction  synthesize branch predictor
C_bp_global_depth    global branch history trace size
C_result_forwarding  synthesize result bypasses
C_load_aligner 	     synthesize load aligner
C_full_shifter 	     pipelined instead of iterative shifer
C_debug              synthesize single-stepping debug module
'''

In synthetic integer benchmarks the core yields 1.63 DMIPS/Mhz and 2.31
CoreMark/MHz.  A performance-tuned f32c SoC which includes a timer
and a UART occupies only 1048 6-input LUTs, while still being able
to execute gcc-generated code when synthesized in the most compact
configuration which consumes just 697 LUTs.

The RTL code also includes modules such as a multi-port SRAM
controller, video framebuffer with PAL modulator, SPI, UART, PCM audio,
GPIO, PWM outputs and a timer, as well as glue logic tailored for
numerous popular FPGA development boards from various manufacturers.

Pre-compiled gcc-based toolchains for Windows, OS-X and Linux can be
found at http://www.nxlab.fer.hr/fpgarduino, together with pre-built
demo FPGA bitstreams and further instructions on how to compile
RISC-V / MIPS executables using the Arduino IDE.

All VHDL modules are BSD licensed.  The majority of software libraries
are borrowed from FreeBSD, while some originate from other projects and
may bear an MIT-style license.
