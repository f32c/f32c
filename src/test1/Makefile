
PROG = test1

CFILES = test1.c test_fn.c \
	../lib/sio.c ../lib/div.c ../lib/gets.c ../lib/printf.c \
	../lib/random.c

CFLAGS += -DOPTIMIZED_DIVSI3 -DFAST_STRCMP -DUNROLLED_STRCMP
CFLAGS += -Os

ASFILES = ../lib/start.S

include ../conf/f32c.mk

