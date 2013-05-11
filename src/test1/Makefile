
PROG = test1

CFILES = test1.c \
	../lib/sio.c ../lib/div.c ../lib/gets.c ../lib/printf.c \
	../lib/random.c ../lib/fb.c \
	../lib/spi.c ../lib/diskio.c ../lib/sdcard.c ../lib/fatfs.c

CFLAGS += -DOPTIMIZED_DIVSI3
CFLAGS += -Os

ASFILES = ../lib/start.S

include ../conf/f32c.mk

