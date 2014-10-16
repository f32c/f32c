
PROG = demo

CFILES = demo.c ../lib/pcmplay.c

F32C_LIBS = printf gets atoi fatfs sio_baud

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

include ${POST_MK}
