
PROG = test1

CFILES = test1.c \
	../lib/sio.c ../lib/div.c ../lib/gets.c ../lib/printf.c \
	../lib/random.c ../lib/fatfs.c ../lib/spi.c \
	../lib/diskio.c ../lib/sdcard.c ../lib/fb.c

#CFLAGS += -DOPTIMIZED_DIVSI3 -DFAST_STRCMP -DUNROLLED_STRCMP
CFLAGS += -Os

ASFILES = ../lib/start.S

include ../conf/f32c.mk

