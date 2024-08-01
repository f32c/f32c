#File : core_portme.mak

BASE_DIR = $(subst conf/f32c.mk,,${MAKEFILES})
ISA_CHECK = tclsh ${BASE_DIR}tools/isa_check.tcl

ifeq ($(findstring riscv, ${ARCH}),)
 TOOLPREFIX = mips
else
 TOOLPREFIX = riscv32
endif

# Flag : OUTFLAG
#	Use this flag to define how to to get an executable (e.g -o)
OUTFLAG= -o

CC = $(TOOLPREFIX)-elf-gcc
LD = $(TOOLPREFIX)-elf-ld
AS = $(TOOLPREFIX)-elf-as
OBJCOPY = ${TOOLPREFIX}-elf-objcopy

# Flag : CFLAGS
#	Use this flag to define compiler options. Note, you can add compiler options from the command line using XCFLAGS="other flags"

WITHOUT_FLOAT = true
ENDIANFLAGS = -EL
MK_CFLAGS = -ffunction-sections -fdata-sections

# Default load offset - bootloader is at 0x00000000
ifndef LOADADDR
 LOADADDR = 0x400
endif

ifeq ($(findstring 0x8, ${LOADADDR}),)
 MK_CFLAGS += -DBRAM
endif

# Includes
MK_INCLUDES += -I${BASE_DIR}include
MK_STDINC = -nostdinc -include sys/param.h

# Libs
ifeq ($(ARCH),mips)
 LIBDIR = ${BASE_DIR}lib/${ARCH}el
else
 LIBDIR = ${BASE_DIR}lib/${ARCH}
endif

ifndef WITHOUT_LIBS
 ifdef WITHOUT_FLOAT
  MK_LIBS = ${LIBS} -lcint
 else
  MK_LIBS = ${LIBS} -lc
 endif
endif

# MIPS-specific flags
ifeq ($(ARCH),mips)
 MK_CFLAGS += -march=f32c
 MK_CFLAGS += ${ENDIANFLAGS}
 MK_CFLAGS += -G 32768
 OBJFLAGS += -R .MIPS.abiflags -R .reginfo
endif

# MIPS-specific flags
ifeq ($(ARCH),riscv)
 MK_CFLAGS += -march=rv32i -mabi=ilp32
 OBJFLAGS += -R .riscv.attributes
endif

MK_CFLAGS += ${MK_STDINC} ${MK_INCLUDES}

#MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow -Wpadded -Winline
MK_CFLAGS += -ffreestanding

# Optimization options
# CoreMark/MHz: 3.129 @ 84.375 MHz 16I$/16D$ SDRAM
MK_CFLAGS += -Ofast -funroll-all-loops -finline-limit=192 -fipa-pta

# Linker flags
#MK_LDFLAHS += ${ENDIANFLAGS}
#MK_LDFLAGS += -N
MK_LDFLAGS += -Wl,--section-start=.init=${LOADADDR}
MK_LDFLAGS += -Wl,--library-path=${LIBDIR}
MK_LDFLAGS += -Wl,-gc-sections
MK_LDFLAGS += -nostartfiles -nostdlib
ifndef WITHOUT_LIBS
 MK_LDFLAGS += -lcrt0
endif
MK_LDFLAGS += ${MK_LIBS}

PORT_CFLAGS = ${MK_CFLAGS}

FLAGS_STR = "$(PORT_CFLAGS) $(XCFLAGS) $(XLFLAGS) $(LFLAGS_END)"
CFLAGS = $(PORT_CFLAGS) -I$(PORT_DIR) -I. -DFLAGS_STR=\"$(FLAGS_STR)\"

#Flag : LFLAGS_END
#	Define any libraries needed for linking or other flags that should come at the end of the link line (e.g. linker scripts). 
#	Note : On certain platforms, the default clock_gettime implementation is supported but requires linking of librt.
LFLAGS_END = ${MK_LDFLAGS}

# Flag : PORT_SRCS
# 	Port specific source files can be added here
PORT_SRCS = $(PORT_DIR)/core_portme.c

#../../lib/src/sio_poll.c

# Flag : LOAD
#	For a simple port, we assume self hosted compile and run, no load needed.

# Flag : RUN
#	For a simple port, we assume self hosted compile and run, simple invocation of the executable

#For native compilation and execution
LOAD = echo Loading done
RUN = 

OEXT = .o
EXE = .$(ARCH)

.PHONY: port_prebuild
port_prebuild:

# Target: port_postbuild
# Generate any files that are needed after actual build end.
# E.g. change format to srec, bin, zip in order to be able to load into flash
.PHONY: port_postbuild
port_postbuild:
	${ISA_CHECK} ${ARCH} ${OUTFILE}
	${OBJCOPY} ${OBJFLAGS} -O binary ${OUTFILE} ${OUTFILE}.bin
	${OBJCOPY} ${OBJFLAGS} -O srec ${OUTFILE} ${OUTFILE}.srec

PORT_CLEAN = ${OUTFILE}.bin ${OUTFILE}.srec

# FLAG : OPATH
# Path to the output folder. Default - current folder.
OPATH = ./
MKDIR = mkdir -p

