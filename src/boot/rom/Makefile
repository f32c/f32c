
# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not link standard libs
WITHOUT_LIBS = true

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c -mno-div -mno-mul
CFLAGS += -mno-branch-likely

# Appropriately configure ../sio/loader.c build
CFLAGS += -DROM_LOADER

# Appropriately configure lib/start.S build
CFLAGS += -DONLY_I_ROM

PROG = loader

CFILES = loader.c ../sio/loader.c \
	../../lib/spi.c ../../lib/sio_baud.c \
	../../lib/mul.c ../../lib/div.c

ASFILES = ../../lib/${ARCH}/start.S

F32C_LIBS = spi sio_baud

include ${POST_MK}
