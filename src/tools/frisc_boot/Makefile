
PROG = frisc_ld

WITHOUT_LIBS = true

CFILES = frisc_boot.c ../../lib/sio_poll.c ../../lib/sprintf.c \
	../../lib/printf.c ../../lib/fatfs.c ../../lib/file.c \
	../../lib/malloc.c ../../lib/spi.c ../../lib/sdcard.c \
	../../lib/diskio.c ../../lib/mul.c ../../lib/div.c

ASFILES = ../../lib/${ARCH}/start.S

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
