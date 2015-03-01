#
# Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id$
#

# Default load offset - bootloader is at 0x00000000
ifndef LOADADDR
LOADADDR = 0x80000000
endif

ifeq ($(findstring 0x8, ${LOADADDR}),)
MK_CFLAGS += -DBRAM
endif

# Includes
MK_INCLUDES = -nostdinc
MK_INCLUDES += -I${BASE_DIR}include
MK_STDINC = -include sys/param.h

ifeq (${ARCH},riscv)
	# RISCV-specific flags

	# Generate rv32 code (default is rv64)
	MK_CFLAGS += -m32
	MK_LDFLAGS += -melf32lriscv

	# f32c has no FP hardware
	MK_CFLAGS += -msoft-float

	# f32c/riscv has no mul / div hardware (default is mrvm)
	MK_CFLAGS += -mno-rvm

else
	# MIPS-specific flags

	# -EB big-endian (mips-elf-gcc default); -EL little-endian
	ifndef ENDIANFLAGS
		ENDIANFLAGS = -EL
	endif

	ifeq ($(findstring -march=,$(CFLAGS)),)
		MK_CFLAGS += -march=f32c
	endif
	MK_CFLAGS += ${ENDIANFLAGS}

	# small data section tuning
	ifeq ($(findstring -G,$(CFLAGS)),)
		MK_CFLAGS += -G 32768
	endif

	# f32c-specific flags
	#MK_CFLAGS += -mno-mul
	#MK_CFLAGS += -mno-div
	#MK_CFLAGS += -mno-unaligned-load
	#MK_CFLAGS += -mno-unaligned-store
	#MK_CFLAGS += -mcondmove
endif

# Optimization options
ifeq ($(findstring -O,$(CFLAGS)),)
MK_CFLAGS += -Os -fpeel-loops
endif

# Do not try to link with libc and standard startup files
MK_CFLAGS += -ffreestanding

# Do not link; use a pipe to feed the as
MK_CFLAGS += -c -pipe

# Every function goes in a separate section, so that unused ones can be GC-ed
MK_CFLAGS += -ffunction-sections -fdata-sections

# Default is to warn and abort on all standard errors and warnings
ifndef WARNS
WARNS = 2
endif

# Warning flags
ifeq ($(findstring ${WARNS}, "01234"),)
$(error Unsupportde WARNS level ${WARNS})
endif
ifneq ($(findstring ${WARNS}, "1234"),)
MK_CFLAGS += -Wall
endif
ifneq ($(findstring ${WARNS}, "234"),)
MK_CFLAGS += -Werror
endif
ifneq ($(findstring ${WARNS}, "34"),)
MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow
endif
ifneq ($(findstring ${WARNS}, "4"),)
MK_CFLAGS += -Winline
endif

# Too strict to be practical:
#MK_CFLAGS += -Wpadded

# Include debugging info
#MK_CFLAGS += -g

# Pull in any module-specific compiler flags
MK_CFLAGS += ${CFLAGS}

# Linker flags
MK_LDFLAGS += -N ${ENDIANFLAGS}
MK_LDFLAGS += --section-start=.init=${LOADADDR}
MK_LDFLAGS += -nostdlib

# Garbage-collect unused section (unreferenced functions)
MK_LDFLAGS += -gc-sections

# Pull in any module-specific linker flags
MK_LDFLAGS += ${LDFLAGS}

CC = ${ARCH}-elf-gcc ${MK_CFLAGS} ${MK_STDINC} ${MK_INCLUDES}
CXX = ${ARCH}-elf-g++ ${MK_CFLAGS} ${MK_STDINC} ${MK_INCLUDES}
AS = ${ARCH}-elf-gcc ${MK_CFLAGS} ${MK_INCLUDES}
LD = ${ARCH}-elf-ld ${MK_LDFLAGS}
OBJCOPY = ${ARCH}-elf-objcopy
ifeq ($(shell uname -s), FreeBSD)
ISA_CHECK = ${BASE_DIR}tools/isa_check.tcl
else
ISA_CHECK = tclsh ${BASE_DIR}tools/isa_check.tcl
endif
MKDEP = ${CC} -MM

#
# Add libraries to the list of CFILES
#

include ${LIBS_MK}

#
# Automatically include start.S in list of ASFILES
#

ASFILES += ${BASE_DIR}lib/${ARCH}/start.S

#
# All object files go to OBJDIR
#

ifndef OBJDIR
OBJDIR=./obj/${ARCH}
endif

#
# Autogenerate targets
#

ASM_OBJS = $(addprefix ${OBJDIR}/,$(ASFILES:.S=.O))
CXX_OBJS = $(addprefix ${OBJDIR}/,$(CXXFILES:.cpp=.o))
C_OBJS = $(addprefix ${OBJDIR}/,$(CFILES:.c=.o))
OBJS = ${ASM_OBJS} ${C_OBJS} ${CXX_OBJS}

BIN = ${PROG}.bin
HEX = ${PROG}.hex

${HEX}: ${BIN} Makefile
	${OBJCOPY} -O srec ${PROG} ${HEX}

${BIN}: ${PROG} Makefile
	${ISA_CHECK} ${ARCH} ${PROG}
	${OBJCOPY} -O binary ${PROG} ${BIN}

${PROG}: ${OBJS} Makefile
	${LD} -o ${PROG} ${OBJS}

depend:
	${MKDEP} ${CFILES} > .depend

clean:
	rm -f ${OBJS} ${PROG} ${BIN} ${HEX}

cleandepend:
	rm -f .depend

#
# Rule for compiling C files
#
$(addprefix ${OBJDIR}/,%.o) : %.c
	@mkdir -p $(dir $@)
	$(CC) -o $@ $<

#
# Rule for compiling C++ files
# XXX fixme extensions: .cc, .cxx, .c++ etc.
#
$(addprefix ${OBJDIR}/,%.o) : %.cpp
	@mkdir -p $(dir $@)
	$(CXX) -o $@ $<

#
# Rule for compiling ASM files
#
$(addprefix ${OBJDIR}/,%.O) : %.S
	@mkdir -p $(dir $@)
	$(AS) -o $@ $<

-include .depend
