#File : core_portme.mak

# Flag : OUTFLAG
#	Use this flag to define how to to get an executable (e.g -o)
OUTFLAG= -o

# Flag : CC
#	Use this flag to define compiler to use
CC = mips-elf-gcc

# Flag : CFLAGS
#	Use this flag to define compiler options. Note, you can add compiler options from the command line using XCFLAGS="other flags"

LOADADDR = 0x00000200
ENDIANFLAGS = -EL

# MIPS-specific flags
MK_CFLAGS += -march=f32c
#MK_CFLAGS += -march=mips2 -mtune=f32c
MK_CFLAGS += ${ENDIANFLAGS}
#MK_CFLAGS += -mno-branch-likely
MK_CFLAGS += -G 32768

# f32c-specific flags
#MK_CFLAGS += -msoft-mul
MK_CFLAGS += -msoft-div

MK_CFLAGS += -nostdinc -I../../include

#MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow -Wpadded -Winline
MK_CFLAGS += -ffreestanding
#MK_CFLAGS += -mno-shared

# Optimization options
MK_CFLAGS += -O2
MK_CFLAGS += -finline-functions
MK_CFLAGS += -fpeel-loops -funroll-loops
MK_CFLAGS += -fselective-scheduling -fsel-sched-pipelining

# Minor improvements
MK_CFLAGS += -fsched2-use-superblocks
MK_CFLAGS += -fipa-cp-clone -fipa-pta -fmodulo-sched
MK_CFLAGS += -fira-loop-pressure

# Useless
#MK_CFLAGS += -fpredictive-commoning
#MK_CFLAGS += -fgcse-after-reload
#MK_CFLAGS += -fmerge-all-constants
#MK_CFLAGS += -falign-functions=4 -falign-labels=4
#MK_CFLAGS += -falign-jumps=4 -falign-loops=4

# Negative impact on performance
#MK_CFLAGS += -ftracer
#MK_CFLAGS += -finline-limit=0
#MK_CFLAGS += -funswitch-loops -ftree-loop-im
#MK_CFLAGS += -fira-algorithm=priority
#MK_CFLAGS += -fmodulo-sched-allow-regmoves
#MK_CFLAGS += -fgcse-sm
#MK_CFLAGS += -fgcse-las
#MK_CFLAGS += -fira-region=one

# Linker flags
MK_LDFLAGS += -N
MK_LDFLAGS += -Ttext ${LOADADDR}
MK_LDFLAGS += -nostartfiles -nostdlib
#MK_LDFLAHS += ${ENDIANFLAGS}


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

# Flag : LOAD
#	For a simple port, we assume self hosted compile and run, no load needed.

# Flag : RUN
#	For a simple port, we assume self hosted compile and run, simple invocation of the executable

#For native compilation and execution
LOAD = echo Loading done
RUN = 

OEXT = .o
EXE = .mips

# Target : port_pre% and port_post%
# For the purpose of this simple port, no pre or post steps needed.

.PHONY : port_prebuild port_postbuild port_prerun port_postrun port_preload port_postload
port_pre% port_post% : 

# FLAG : OPATH
# Path to the output folder. Default - current folder.
OPATH = ./
MKDIR = mkdir -p

