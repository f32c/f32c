
# Default load offset - bootloader is at 0x00000000
ifndef LOADADDR
LOADADDR = 0x000001a0
#LOADADDR = 0x00000400
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
MK_INCLUDES = -nostdinc -I../include -I.

# MIPS-specific flags
MK_CFLAGS += -march=f32c
#MK_CFLAGS += -march=mips2 -mtune=f32c
MK_CFLAGS += ${ENDIANFLAGS}
#MK_CFLAGS += -mno-branch-likely
MK_CFLAGS += -G 32768

# f32c-specific flags
#MK_CFLAGS += -msoft-mul
MK_CFLAGS += -msoft-div

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

MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow -Wpadded -Winline
MK_CFLAGS += -ffreestanding

# Debugging options
MK_CFLAGS += -g

# Optimization options
MK_CFLAGS += -Os
MK_CFLAGS += -fselective-scheduling
MK_CFLAGS += -finline-limit=16 -fmerge-all-constants
MK_CFLAGS += -falign-functions=4 -falign-labels=4
MK_CFLAGS += -falign-jumps=4 -falign-loops=4
MK_CFLAGS += -fsched2-use-superblocks
MK_CFLAGS += -freorder-blocks -fpeel-loops
MK_CFLAGS += -fgcse-sm -fgcse-las
MK_CFLAGS += -fira-algorithm=priority
MK_CFLAGS += -mno-shared

# No zero-filled BSS
MK_CFLAGS += -fno-zero-initialized-in-bss

MK_LDFLAGS += -Ttext ${LOADADDR} -N ${ENDIANFLAGS}


CC = mips-elf-gcc ${MK_INCLUDES} ${MK_CFLAGS} ${ECFLAGS}
LD = mips-elf-ld ${MK_LDFLAGS} ${LDFLAGS}
OBJCOPY = mips-elf-objcopy -O ihex


#
# Autogenerate targets
#

OBJS = $(ASFILES:.S=.o) $(CFILES:.c=.o)

HEX = ${PROG}.hex
IHEX = ${PROG}.ihex

${HEX}: ${PROG} Makefile
	${OBJCOPY} ${PROG} ${HEX}

${PROG}: ${OBJS} Makefile
	${LD} -o ${PROG} ${OBJS}

depend:
	echo ${MK_INCLUDES} ${CFILES}
	mkdep ${MK_INCLUDES} ${CFILES}

clean:
	rm -f ${OBJS} ${PROG} ${HEX}

cleandepend:
	rm -f .depend

#
# Dependencies
#
#include .depend

