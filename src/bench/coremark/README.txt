The EEMBC license for coremark is vague and above all is not irrevocable,
hence the coremark sources are not included here, but have to be
downloaded separately.  The "build.sh" script provided here should do the
job: fetch the appropriate sources from github, and build both mips and
riscv versions of the benchmark.

Note that by default the binaries are linked at 0x00000400.  To build
coremark for execution at some other address, add LOADADDR=0x80000000
to "make" arguments.

Use "ujprog -ta coremark.riscv.srec" / "ujprog -ta coremark.mips.srec"
or some other ASCII terminal emulation program to send the .srec encoded
binaries from the cm_src directory to the FPGA.

