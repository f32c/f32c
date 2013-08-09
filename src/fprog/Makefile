
PROG = fprog

CFILES = fprog.c

F32C_LIBS = printf fatfs

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

ASFILES = ../lib/start.S

include ${POST_MK}
