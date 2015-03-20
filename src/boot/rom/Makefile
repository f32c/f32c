
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not link standard libs
WITHOUT_LIBS = true

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c -mno-div -mno-mul
CFLAGS += -mno-branch-likely

# Omit useless initializers to fit into 2 K of ROM
CFLAGS += -Wno-error=maybe-uninitialized

# Appropriately configure ../sio/loader.c build
CFLAGS += -DROM_LOADER

# Appropriately configure lib/start.S build
CFLAGS += -DONLY_I_ROM

PROG = loader

LIBSRC = ../../lib/src

CFILES = loader.c ../sio/loader.c \
	${LIBSRC}/spi.c ${LIBSRC}/sio_baud.c \
	${LIBSRC}/mul.c ${LIBSRC}/div.c

ASFILES = ${LIBSRC}/${ARCH}/start.S

include ${POST_MK}
