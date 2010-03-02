
#LOADADDR = 0x80100100
LOADADDR = 0x00000000

# -EB big-endian (default); -EL little-endian

ENDIANFLAGS = -EL

CFLAGS = -mips3 ${ENDIANFLAGS}
CFLAGS += -mno-mips16 -mno-branch-likely -mno-dsp -mno-mips3d
CFLAGS += -mno-mdmx -mlong-calls -msoft-float
CFLAGS += -c -s -n -nostdlib -fno-builtin
CFLAGS += -O -std=c99 -Wall -Werror -g
CFLAGS += -G 32768
# Other interesting options:
# -no-shared
# -fPIC -fpic
# -membedded-data

LDFLAGS += -Ttext ${LOADADDR} -N ${ENDIANFLAGS}

AS = mips-rtems-gcc ${CFLAGS} ${ASFLAGS}
CC = mips-rtems-gcc ${CFLAGS}
LD = mips-rtems-ld ${LDFLAGS}

build:
	$(AS) -o boot.o boot.S
	$(CC) -o libc.o libc.c
	$(CC) -o lcdfunc.o lcdfunc.c
	$(CC) -o demo_semafor.o demo_semafor.c
	$(CC) -o prog.o prog.c
	$(LD) -o img.elf \
	    boot.o libc.o lcdfunc.o demo_semafor.o prog.o

clean:
	rm boot.o libc.o lcdfunc.o demo_semafor.o prog.o img.elf
