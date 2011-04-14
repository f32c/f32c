
.include "../conf/f32c.mk"

# Bootloader uses a non-default loadaddr
LOADADDR = 0x00000000

# Do not use GP-relative addressing
CFLAGS += -G 0

build:
	$(CC) -o loader.o loader.c
	$(LD) -o img.elf loader.o

clean:
	rm -f loader.o img.elf
