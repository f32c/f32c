
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# No optional instructions in the loader
CFLAGS += -mno-branch-likely -msoft-mul

PROG = loader

CFILES = loader.c

F32C_LIBS = spi

ASFILES = ${BASE_DIR}lib/start.S

include ${POST_MK}
