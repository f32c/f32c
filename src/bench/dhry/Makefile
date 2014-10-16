
PROG = dhry

WARNS = 1

# Override -Os, and turn on extra optimization efforts
DHRY_CFLAGS += -Ofast
DHRY_CFLAGS += -fselective-scheduling

# Inlining functions is not permitted per Dhrystone rules!
DHRY_CFLAGS += -fno-inline-functions -fno-inline-small-functions
DHRY_CFLAGS += -finline-limit=0

# builtin_strcpy is faster than a handcrafted version
DHRY_CFLAGS += -DUSE_BUILTIN_STRCPY
DHRY_CFLAGS += -DFAST_STRCMP -DUNROLLED_STRCMP

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

CFILES = dhry_1.c dhry_2.c miscfn.c

F32C_LIBS = printf atoi gets

include ${POST_MK}

# Specialized build rules for dhry_*.c files

./obj/${ARCH}/dhry_1.o: dhry_1.c
	${CC} ${DHRY_CFLAGS} -o $@ dhry_1.c

./obj/${ARCH}/dhry_2.o: dhry_2.c
	${CC} ${DHRY_CFLAGS} -o $@ dhry_2.c
