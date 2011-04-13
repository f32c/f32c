
.include "../conf/f32c.mk"

build:
	$(CC) -o test1.o test1.c
	$(AS) -o start.o ../lib/start.S
	$(CC) -o sio.o ../lib/sio.c
	$(LD) -o img.elf \
	    start.o sio.o test1.o

clean:
	rm -f test1.o start.o sio.o img.elf
