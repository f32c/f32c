
PROG = dhry

CSTD = KnR
WARNS = 1

DHRY_CFLAGS += -O3 -fpeel-loops

CFILES = dhry_1.c dhry_2.c miscfn.c \
	../lib/div.c ../lib/printf.c ../lib/sio.c

ASFILES = ../lib/start.S

include ../conf/f32c.mk

# Specialized build options for dhry_*.c files

dhry_1.o:	Makefile dhry.h dhry_1.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_1.o dhry_1.c

dhry_2.o:	Makefile dhry.h dhry_2.c
	${CC} ${DHRY_CFLAGS} -c -o dhry_2.o dhry_2.c
