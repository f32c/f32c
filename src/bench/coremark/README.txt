The EEMBC license only permits downloads of CoreMark software sources
directly from their web site on individual basis, hence you should
register at www.eembc.org and download CoreMark tarball from there.

Unpack the tarball so that all sources are moved in this directory:

tar xf coremark_v1.0.tgz
mv coremark_v1.0/* .

Then, patch the original Makefile:

patch -p 0 < Makefile.diff

The "make" command can then be used to build the benchmark.  Note
that if compiling for the MIPS ISA the default load address is 0x80000000,
which is the beginning of SRAM area, currently available only on FER
ULX2S boards.  For linking the benchmark to run on BRAM-based f32c
MIPS configurations add LOADADDR=0x200 when invoking make.  For RISCV
builds the default load address is already 0x200, so only supplying
ARCH=riscv as the only argument when invoking make should suffice.
