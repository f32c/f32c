
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not link standard libs
WITHOUT_LIBS = true

# No optional instructions in the loader
MIN = true

# Appropriately configure ../sio/loader.c build
CFLAGS += -DROM_LOADER -DONLY_I_ROM

PROG = loader

LIBSRC = ../../lib/src

CFILES = loader.c ../sio/loader.c ${LIBSRC}/dev/spi.c

ASFILES = start.S

include ${POST_MK}
