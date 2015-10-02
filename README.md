# f32c

f32c is a retargetable 32-bit scalar pipelined processor core which
can execute subsets of either RISC-V or MIPS instruction sets.
It is implemented in parametrized VHDL which permits synthesis with
different area / speed tradeoffs, and includes a branch predictor,
exception handling control block, and optional direct-mapped caches.
The RTL code also includes modules such as a multi-port SDRAM and SRAM
controllers, video framebuffers with composite (PAL), HDMI and VGA
outputs, SPI, UART, PCM audio, GPIO, PWM outputs and a timer, as well
as glue logic tailored for numerous popular FPGA development boards
from various manufacturers.

In synthetic integer benchmarks the core yields 3.06 CoreMark/MHz
and 1.63 DMIPS/MHz (1.81 DMIPS/MHz with function inlining).
A performance-tuned f32c SoC which includes a timer
and a UART occupies only 1048 6-input LUTs, while still being able to
execute gcc-generated code when synthesized in the most compact
configuration which consumes just 697 (649 logic plus 48 memory) LUTs.
From old to new FPGAs that we have tested, max stable clock ranges
from 70 MHz (Spartan 3E-500) to 125 MHz (Zynq Z-7010).

Configurable options include:

```
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
```

Pre-compiled gcc-based toolchains for Windows, OS-X and Linux can be
found at the [FPGArduino page](http://www.nxlab.fer.hr/fpgarduino),
together with pre-built demo bitstreams for various Xilinx, Altera
and Lattice FPGAs, and with further instructions on how to compile
RISC-V / MIPS executables using the Arduino IDE.

All VHDL modules are BSD licensed.  The majority of software libraries
are borrowed from FreeBSD, while some originate from other projects and
may bear an MIT-style license.
