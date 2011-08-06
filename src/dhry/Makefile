
PROG = dhry

CSTD = KnR
WARNS = 1

DHRY_CFLAGS += -O3

CFILES = dhry_1.c dhry_2.c miscfn.c \
	../lib/div.c ../lib/printf.c ../lib/sio.c

ASFILES = ../lib/start.S

include ../conf/f32c.mk

# gcc 4.6.1 produces fastest __divsi3() implementation using -O2, not -O3!

../lib/div.o:	Makefile ../lib/div.c
	${CC} -DOPTIMIZED_DIVSI3 -O2 -c -o ../lib/div.o ../lib/div.c

# Specialized build options for dhry_*.c files

dhry_1.o:	Makefile dhry.h ../include/string.h dhry_1.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_1.o dhry_1.c

dhry_2.o:	Makefile dhry.h ../include/string.h dhry_2.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_2.o dhry_2.c
