
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not use GP-relative addressing
CFLAGS += -G 0

# No branch likely instructions in the loader
CFLAGS += -mno-branch-likely

PROG = loader

CFILES = loader.c

include ${POST_MK}

# Do not build lib/start.S !
ASFILES = 
