
.include "../conf/f32c.mk"

build:
	$(CC) demo.c
	$(AS) ../lib/start.S
	$(CC) ../lib/sio.c
	$(CC) ../lib/spi.c
	$(CC) ../lib/div.c
	$(CC) ../lib/mul.c
	$(CC) ../lib/printf.c
	$(CC) ../lib/pcmplay.c
	$(LD) -o img.elf \
	    start.o sio.o spi.o printf.o div.o mul.o pcmplay.o demo.o

clean:
	rm -f demo.o start.o sio.o spi.o printf.o div.o mul.o \
	    pcmplay.o img.elf
