
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c
CFLAGS += -mno-branch-likely -mno-mul
CFLAGS += -DROM_LOADER

PROG = loader

CFILES = loader.c ../sio/loader.c

F32C_LIBS = spi

include ${POST_MK}
