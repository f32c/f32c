
.include "../conf/f32c.mk"

build:
	$(CC) test1.c
	$(AS) ../lib/start.S
	$(CC) ../lib/sio.c
	$(CC) ../lib/spi.c
	$(CC) ../lib/div.c
	$(CC) ../lib/mul.c
	$(CC) ../lib/printf.c
	$(LD) -o img.elf \
	    start.o sio.o spi.o printf.o div.o mul.o test1.o

clean:
	rm -f test1.o start.o sio.o spi.o printf.o div.o mul.o img.elf
