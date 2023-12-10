# f32c

[f32c](/rtl/cpu/README.md) is a retargetable, scalar, pipelined, 32-bit processor core which
can execute subsets of either RISC-V or MIPS instruction sets.
It is implemented in parametrized VHDL which permits synthesis with
different area / speed tradeoffs, and includes a branch predictor,
exception handling control block, and optional direct-mapped caches.
The RTL code also includes [SoC](/rtl/soc/README.md) modules such as a 
multi-port SDRAM and SRAM controllers, video framebuffers with composite (PAL),
HDMI, DVI and VGA outputs with simple 2D acceleration for sprites and windows,
floating point vector processor, SPI, UART, PCM audio, GPIO, PWM outputs and a 
timer, as well as glue logic tailored for numerous popular FPGA development boards 
from various manufacturers.

In synthetic integer benchmarks the core yields 2.96 CoreMark/MHz
and 1.55 DMIPS/MHz with code and data stored in on-chip block RAMs.
When configured with 16 KB of instruction and 8 KB of data cache,
and with code and data stored in external SDRAM, the core yields
2.85 CoreMark/MHz and 1.36 DMIPS/MHz.

A performance-tuned f32c SoC which includes a timer
and an UART occupies only 1048 6-input LUTs, while still being able to
execute gcc-generated code when synthesized in the most compact
configuration which consumes just 697 (649 logic plus 48 memory) LUTs.

Floating point vector processor can be optionally synthesized.
Tested on Xilinx Spartan-6 (xc6slx25) and 7-series (xc7a35i, xc7a102t, xc7z010),
Altera Cyclone-4 (EP4CE22) and MAX-10 (10M50DAF), Lattice ECP3 (LFE3-150EA) 
and ECP5 (LFE5UM-85F). On Artix-7 it uses 3148 LUTs, 64K BRAM,
38 DSP multipliers (36 for divider unit) and can provide up to 3 MFLOPs/MHz.

The Fmax depends on core configuration and FPGA silicon, and tops at
around 115 MHz for 90 nm FPGAs (such as Xilinx S3E / S3A or Lattice XP2)
up to 185 MHz for latest generations of 6-input LUT FPGAs such as
Artix-7.

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
C_icache_size        instruction cache size (0 to 64 KB)
C_dcache_size        data cache size (0 to 64 KB)
C_debug              synthesize single-stepping debug module
```

Pre-compiled gcc-based toolchains for Windows, OS-X and Linux can be
found at the [FPGArduino page](http://www.nxlab.fer.hr/fpgarduino),
together with pre-built demo bitstreams for various Xilinx, Altera
and Lattice FPGAs, and with further instructions on how to compile
RISC-V / MIPS executables using the Arduino IDE.

All VHDL modules are [BSD licensed](LICENSE).  The majority of software
libraries are borrowed from FreeBSD, while some originate from other
projects and may be subject to an MIT-style license.
