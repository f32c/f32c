
PROG = wavplay

CFILES = wavplay.c

F32C_LIBS = printf sprintf fatfs lcd

# Omit floating point libs and corresponding printf parts
CFLAGS += -DNO_PRINTF_FLOAT

include ${POST_MK}
