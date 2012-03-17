
PROG = dhry

CSTD = KnR
WARNS = 1

# Override -Os
DHRY_CFLAGS += -Ofast

# Inlining functions is not permitted per Dhrystone rules!
DHRY_CFLAGS += -fno-inline-functions -fno-inline-small-functions
#DHRY_CFLAGS += -finline-limit=32

# builtin_strcpy is faster than a handcrafted version but requires swr/swl
DHRY_CFLAGS += -DUSE_BUILTIN_STRCPY -DFASTER_STRCMP

# Build a faster __divsi3()
CFLAGS += -DOPTIMIZED_DIVSI3

CFILES = dhry_1.c dhry_2.c miscfn.c \
	../lib/div.c ../lib/printf.c ../lib/sio.c

ASFILES = ../lib/start.S


include ../conf/f32c.mk


# Specialized build rules for dhry_*.c files

dhry_1.o:	Makefile dhry.h ../include/string.h dhry_1.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_1.o dhry_1.c

dhry_2.o:	Makefile dhry.h ../include/string.h dhry_2.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_2.o dhry_2.c
