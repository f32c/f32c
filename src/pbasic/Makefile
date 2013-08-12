
PROG = basic

CFILES = bas1.c bas2.c bas3.c bas4.c bas5.c \
	 bas6.c nbas7.c bas8.c bas9.c assist.c alloc.c \
	 f32c_glue.c \
	 ${BASE_DIR}lib/atoi.c ${BASE_DIR}lib/random.c

F32C_LIBS = printf math fatfs setjmp

CFLAGS += -DOPTIMIZED_DIVSI3

CFLAGS += -Wno-unused-parameter
CFLAGS += -Wno-missing-braces -Wno-sign-compare

ASFILES += ${BASE_DIR}lib/start.S

include ${POST_MK}

