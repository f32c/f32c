# Default load offset - bootloader is at 0x00000000
ifndef LOADADDR
LOADADDR = 0x80000000
endif

ifeq ($(findstring 0x8, ${LOADADDR}),)
MK_CFLAGS += -DBRAM
endif

# -EB big-endian (gcc default); -EL little-endian
ifndef ENDIANFLAGS
ENDIANFLAGS = -EL
endif

# C flavor: K&R or ANSI (C99)
ifndef CSTD
CSTD = ANSI
endif

# Default is to warn and abort on all errors
ifndef WARNS
WARNS = 2
endif

# Includes
MK_INCLUDES = -nostdinc -I${BASE_DIR}include -I.

# MIPS-specific flags
MK_CFLAGS += -march=f32c
#MK_CFLAGS += -march=mips2 -mtune=f32c
MK_CFLAGS += ${ENDIANFLAGS}
#MK_CFLAGS += -mno-branch-likely
MK_CFLAGS += -G 32768

# f32c-specific flags
#MK_CFLAGS += -msoft-mul
MK_CFLAGS += -msoft-div
MK_CFLAGS += -msoft-float

# Language flags
ifeq ($(CSTD), ANSI)
MK_CFLAGS += -std=c99
endif

# Warning flags
ifneq ($(WARNS), 0)
MK_CFLAGS += -Wall
endif
ifeq ($(WARNS), 2)
MK_CFLAGS += -Werror
endif

MK_CFLAGS += -ffreestanding
MK_CFLAGS += -mno-shared

MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow
# Too strict:
#MK_CFLAGS += -Wpadded
#MK_CFLAGS += -Winline

# Debugging options
MK_CFLAGS += -g

# Optimization options
MK_CFLAGS += -Os
MK_CFLAGS += -fselective-scheduling
MK_CFLAGS += -finline-limit=4 -fmerge-all-constants
MK_CFLAGS += -falign-functions=4 -falign-labels=4
MK_CFLAGS += -falign-jumps=4 -falign-loops=4
MK_CFLAGS += -fpeel-loops
MK_CFLAGS += -fgcse-sm

# Those flags improved performance with gcc-4.6, but not with gcc-4.7
#MK_CFLAGS += -fgcse-las
#MK_CFLAGS += -fsched2-use-superblocks
#MK_CFLAGS += -fira-algorithm=priority

# No zero-filled BSS
MK_CFLAGS += -fno-zero-initialized-in-bss

# Pull in any module-specific compiler flags
MK_CFLAGS += ${CFLAGS}

# Linker flags
MK_LDFLAGS += -N ${ENDIANFLAGS}
MK_LDFLAGS += -Ttext ${LOADADDR}
MK_LDFLAGS += -nostartfiles -nostdlib

# Pull in any module-specific linker flags
MK_LDFLAGS += ${LDFLAGS}

CC = mips-elf-gcc ${MK_INCLUDES} ${MK_CFLAGS}
LD = mips-elf-ld ${MK_LDFLAGS}
OBJCOPY = mips-elf-objcopy
ISA_CHECK = ${BASE_DIR}tools/isa_check.tcl
MKDEP = ${CC} -MM

#
# Add libraries to the list of CFILES
#

include ${LIBS_MK}


#
# Autogenerate targets
#

OBJS = $(ASFILES:.S=.o) $(CFILES:.c=.o)

BIN = ${PROG}.bin
HEX = ${PROG}.hex

${HEX}: ${BIN} Makefile
	${OBJCOPY} -O srec ${PROG} ${HEX}

${BIN}: ${PROG} Makefile
	${ISA_CHECK} ${PROG}
	${OBJCOPY} -O binary ${PROG} ${BIN}

${PROG}: ${OBJS} Makefile
	${LD} -o ${PROG} ${OBJS}

depend:
	${MKDEP} ${CFILES}

clean:
	rm -f ${OBJS} ${PROG} ${BIN} ${HEX}

cleandepend:
	rm -f .depend

#
# Rule for compiling C files
#
%.o : %.c
	$(CC) -c -pipe $< -o $@
