
PROG = fprog

CFILES = fprog.c

F32C_LIBS = printf fatfs

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code size
CFLAGS += -D_FS_MINIMIZE=0 -D_FS_READONLY=0 -D_FS_SHARE=0
CFLAGS += -D_FS_TINY=1 -D_FS_RPATH=0 -D_USE_LFN=0

include ${POST_MK}
