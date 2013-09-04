
# Bootloader uses a non-default loadaddr
LOADADDR = 0x800f8000

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c
CFLAGS += -mno-branch-likely -msoft-mul

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code size
CFLAGS += -D_FS_MINIMIZE=1 -D_FS_READONLY=1 -D_FS_SHARE=0
CFLAGS += -D_FS_TINY=1 -D_FS_RPATH=0 -D_USE_LFN=0


PROG = loader

CFILES = loader.c

F32C_LIBS = printf fatfs

ASFILES = ${BASE_DIR}lib/start.S

include ${POST_MK}
