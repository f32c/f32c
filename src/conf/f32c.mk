
# Default load offset - bootloader is at 0x00000000
.if !(defined(LOADADDR))
LOADADDR = 0x00000200
.endif

# -EB big-endian (default); -EL little-endian
.if !(defined(ENDIANFLAGS))
ENDIANFLAGS = -EL
.endif

# Includes
MK_CFLAGS = -nostdinc -I../include -I.

# MIPS-specific flags
MK_CFLAGS += -march=mips3 ${ENDIANFLAGS}
MK_CFLAGS += -mtune=mips32 -mno-branch-likely
MK_CFLAGS += -mno-mips16 -mno-dsp -mno-mips3d -mno-mdmx -msoft-float
MK_CFLAGS += -G 32768

# f32c-specific flags
MK_CFLAGS += -msoft-mul -msoft-div

# Language flags
MK_CFLAGS += -std=c99 -Wall -Werror
MK_CFLAGS += -Wextra -Wsystem-headers -Wshadow -Wpadded -Winline
MK_CFLAGS += -c
MK_CFLAGS += -ffreestanding
#MK_CFLAGS += -s -n -nostdlib -fno-builtin

# Debugging options
MK_CFLAGS += -g

# Optimization options
MK_CFLAGS += -Os
MK_CFLAGS += -finline-limit=16 -fmerge-all-constants
MK_CFLAGS += -falign-functions=4 -falign-labels=4
MK_CFLAGS += -falign-jumps=4 -falign-loops=4
MK_CFLAGS += -fweb -frename-registers
MK_CFLAGS += -freorder-blocks
#MK_CFLAGS += -funsafe-loop-optimizations -Wunsafe-loop-optimizations
#MK_CFLAGS += --param max-delay-slot-insn-search=16
#MK_CFLAGS += --param max-delay-slot-live-search=16

# No zero-filled BSS
MK_CFLAGS += -fno-zero-initialized-in-bss

# Other interesting options:
# MK_CFLAGS += -fPIC -fpic
# -membedded-data
# -no-shared

MK_LDFLAGS += -Ttext ${LOADADDR} -N ${ENDIANFLAGS}

# Sweep CFLAGS from leading "-O2 -pipe" noise, inserted by sys.mk
.if (defined(CFLAGS))
ECFLAGS = ${CFLAGS:S/^-O2//:S/^-pipe//}
.endif

AS = mips-elf-gcc ${MK_CFLAGS} ${ASFLAGS}
CC = mips-elf-gcc ${MK_CFLAGS} ${ECFLAGS}
LD = mips-elf-ld ${MK_LDFLAGS} ${LDFLAGS}
ELF2HEX = ../tools/elf2hex.tcl


#
# Autogenerate targets
#

OBJS += ${ASFILES:T:.S=.o}
OBJS += ${CFILES:T:.c=.o}

HEX = ${PROG}.hex

${HEX}: ${PROG}
	${ELF2HEX} ${PROG} > ${HEX}

${PROG}: ${OBJS}
	${LD} -o ${PROG} ${OBJS}

.for _src in ${CFILES}
${_src:T:.c=.o}: ${_src}
	${CC} ${.IMPSRC}
.endfor

.for _src in ${ASFILES}
${_src:T:.S=.o}: ${_src}
	${AS} ${.IMPSRC}
.endfor

clean:
	rm -f ${OBJS} ${PROG} ${HEX}

