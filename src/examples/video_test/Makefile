
PROG = vidtest

CFILES = video_test.c

F32C_LIBS = printf sprintf framebuffer random div64 isr

# Omit floating point libs and corresponding printf parts
CFLAGS += -DNO_PRINTF_FLOAT

include ${POST_MK}
