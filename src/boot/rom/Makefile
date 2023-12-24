
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not link standard libs
WITHOUT_LIBS = true

# No optional instructions in the loader
MIN = true

# Omit useless initializers to fit into 2 K of ROM
ifeq ($(ARCH),mips)
 CFLAGS += -Wno-error=maybe-uninitialized
else
 CFLAGS += -Wno-error=uninitialized
endif

# Appropriately configure ../sio/loader.c build
CFLAGS += -DROM_LOADER

# Appropriately configure lib/start.S build
CFLAGS += -DONLY_I_ROM

PROG = loader

LIBSRC = ../../lib/src

CFILES = loader.c ../sio/loader.c ${LIBSRC}/dev/spi.c ${LIBSRC}/gen/mul.c

ASFILES = start.S

include ${POST_MK}
