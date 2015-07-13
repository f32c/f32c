# HINTS
# cd ../../tools
# . ./makefiles.sh
# for BRAM
# make LOADADDR=0x400

# Do not link standard libs
WITHOUT_LIBS = true

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code size
CFLAGS += -D_FS_MINIMIZE=0 -D_FS_READONLY=1 -D_USE_ERASE=0
CFLAGS += -D_FS_TINY=0 -D_FS_RPATH=0 -D_USE_LFN=0 -D_MAX_SS=512

PROG = sdtest

LIBSRC = ../../lib/src

CFILES = sdcard_test.c ${LIBSRC}/sio_poll.c \
	${LIBSRC}/printf.c ${LIBSRC}/fatfs.c ${LIBSRC}/file.c \
	${LIBSRC}/malloc.c ${LIBSRC}/spi.c ${LIBSRC}/sdcard.c \
	${LIBSRC}/diskio.c ${LIBSRC}/mul.c ${LIBSRC}/div.c

ASFILES = ${LIBSRC}/${ARCH}/start.S

include ${POST_MK}

