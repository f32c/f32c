
PROG = frisc_ld

CFILES = frisc_boot.c

F32C_LIBS = sprintf fatfs

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
