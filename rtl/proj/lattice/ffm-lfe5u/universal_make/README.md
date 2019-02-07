# Universal make

This makefile is recommended as template for all builds from linux.
It uses the same source base for building all bitstream formats for all
boards, all FPGA sizes, all SOCs etc., just by editing simple makefile
which does the magic.

All project files should be listed in "files.mk" and this file should
be maintained on one place, other derived makefiles should include
"files.mk" from here.

This makes build workflow significantly faster than maintaining
numerous similar but different projects using diamond GUI alone.
