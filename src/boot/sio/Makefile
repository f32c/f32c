
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

LDFLAGS = -Ttext=${LOADADDR}

# Do not link standard libs
WITHOUT_LIBS = true

ifeq (${ARCH},mips)
	# Do not use GP-relative addressing
	CFLAGS += -G 0

	# No branch likely instructions in the loader
	CFLAGS += -mno-branch-likely
else
	CFLAGS += -march=rv32imzifencei
endif

PROG = loader

CFLAGS += -DBIN_LOADER

CFILES = loader.c binboot.c

include ${POST_MK}
