
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000400

LDFLAGS = -Ttext=${LOADADDR}

# Do not link standard libs
WITHOUT_LIBS = true

ifeq (${ARCH},mips)
	# Do not use GP-relative addressing
	CFLAGS += -G 0

	# No branch likely instructions in the loader
	CFLAGS += -mno-branch-likely
endif

PROG = memtest

CFLAGS += -DBIN_LOADER

CFILES = memtest.c

include ${POST_MK}
