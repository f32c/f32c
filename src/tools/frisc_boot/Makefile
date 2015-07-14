
PROG = frisc_ld

WITHOUT_LIBS = true

CFILES = frisc_boot.c ../../lib/src/sio_poll.c ../../lib/src/sprintf.c \
	../../lib/src/printf.c ../../lib/src/fatfs.c ../../lib/src/file.c \
	../../lib/src/malloc.c ../../lib/src/spi.c ../../lib/src/sdcard.c \
	../../lib/src/diskio.c ../../lib/src/mul.c ../../lib/src/div.c

ASFILES = ../../lib/src/${ARCH}/start.S

# Use a non-default loadaddr
LOADADDR = 0x800f0000

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c
CFLAGS += -mno-branch-likely -mno-mul -mno-div

# Omit floating point libs and corresponding printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code and data footprint
CFLAGS += -D_FS_TINY=1 -D_FS_RPATH=0 -D_FS_MINIMIZE=1 -D_FS_READONLY=1

include ${POST_MK}
