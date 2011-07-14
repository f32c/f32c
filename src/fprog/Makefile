
.include "../conf/f32c.mk"

build:
	$(CC) fprog.c
	$(AS) ../lib/start.S
	$(CC) ../lib/sio.c
	$(CC) ../lib/spi.c
	$(CC) ../lib/div.c
	$(CC) ../lib/printf.c
	$(LD) -o img.elf \
	    start.o sio.o spi.o printf.o div.o mul.o fprog.o

clean:
	rm -f fprog.o start.o sio.o spi.o printf.o div.o mul.o img.elf
