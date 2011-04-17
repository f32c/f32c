
.include "../conf/f32c.mk"

build:
	$(CC) -o fprog.o fprog.c
	$(AS) -o start.o ../lib/start.S
	$(CC) -o sio.o ../lib/sio.c
	$(CC) -o spi.o ../lib/spi.c
	$(CC) -o div.o ../lib/div.c
	$(CC) -o mul.o ../lib/mul.c
	$(CC) -o printf.o ../lib/printf.c
	$(LD) -o img.elf \
	    start.o sio.o spi.o printf.o div.o mul.o fprog.o

clean:
	rm -f fprog.o start.o sio.o spi.o printf.o div.o mul.o img.elf
