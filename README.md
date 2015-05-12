# f32c

f32c is a simple 32-bit retargetable scalar 5-stage integer processor
pipeline which can be configured to execute subsets of either RISC-V
or MIPS instruction sets.  The core is implemented in parametrised
VHDL which permits synthesis with different area / speed tradeoffs,
and includes a branch predictor, exception handling control block,
and optional direct-mapped caches.  There is no MMU.

In synthetic integer benchmarks the core yields 1.63 DMIPS/Mhz and 2.31
CoreMark/MHz.  In performance-tuned configuration an f32c Soc which
includes a timer and a UART occupies only 1048 6-input LUTs, while still
being able to execute gcc-generated code when synthesized in the most
compact configuration which consumes just 697 LUTs.

The RTL code also includes modules such as a simple multi-port SRAM
controller, video framebuffer with PAL modulator, SPI, UART, PCM audio,
GPIO and PWM outputs, as well as glue logic tailored for numerous popular
FPGA development boards from various manufacturers.

Pre-compiled gcc-based toolchains for Windows, OS-X and Linux can be
found at http://www.nxlab.fer.hr/fpgarduino , along with pre-built
demo bitstreams for a dozen of common FPGA boards, and further details
on how to coveniently generate executables using the Arduino IDE.

All VHDL modules are BSD licensed.  The majority of software libraries
are borrowed from FreeBSD, with some originate from other projects and
may bear a MIT-style license.
