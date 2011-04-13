
.include "../conf/f32c.mk"

# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

build:
	$(AS) -o boot.o boot.S
	$(CC) -o loader.o loader.c
	$(LD) -o img.elf \
	    boot.o loader.o

clean:
	rm -f boot.o loader.o img.elf
