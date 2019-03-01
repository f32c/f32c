
MenloParkInnovation LLC
02/27/2019

The intention of this project is to create an Arduino UNO compatible
environment using the Terasic DE10-Lite which comes with Arduino UNO
headers.

It's MAX10 FPGA is suited for low power embedeed projects similar to
Arduino, but with F32C offers the performance and memory expansion
of the 32 bit MIPS or RISC-V cores.

It's 204K bytes of block RAMS easily supports 128K of program and
data memory leaving sufficient block RAMS for hardware functions.

At the 75Mhz CPU rate running from block RAM you have better performance
than the typical 16Mhz AtMega328 which is an 8/16 bit microcontroller
with only 2K RAM, 32K program memory.

After compiling a basic F32 core which consumes ~4000 LE's, you have
45K LE's available for custom hardware logic. This is where the
performance of the MAX10 based softcore "Arduino" vastly outperforms
even a newer 32 ARM based "Arduino" in real time hardware compute
intensive tasks with sensors, signal following and processing, etc.

Since the goal is Arduino compatibility, the project is organized
for that.

The FPGAArduino add in for the DE10-Lite will be updated to use
standard Arduino pin assignment numbers with the F32C extended
pin numbers in the upper ranges.

Additional work over time will added to allow more Soc's to be
enabled, and allow the user a simple way to integrate a locally
defined "Soc" module for custom hardware logic.

The project will be validated by porting the GRBL machine tool
controller software to it. Initially a pure "software" port
will be done, but the plan is to incorporate low level signal
generation in hardware by creating a CNC signals "SoC' module.
