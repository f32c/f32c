
#LOADADDR = 0x80100100
LOADADDR = 0x00000000

# -EB big-endian (default); -EL little-endian

ENDIANFLAGS = -EL

CFLAGS = -march=mips3 ${ENDIANFLAGS}
CFLAGS += -mno-branch-likely
CFLAGS += -mno-mips16 -mno-dsp -mno-mips3d -mno-mdmx -msoft-float
CFLAGS += -c -s -n -nostdlib -fno-builtin
CFLAGS += -std=c99 -Wall -Werror
CFLAGS += -G 32768
# Debugging options
CFLAGS += -g
# Optimization options
CFLAGS += -O2
#CFLAGS += -freorder-blocks-and-partition
#CFLAGS += -web -frename-registers

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
	rm -f boot.o libc.o lcdfunc.o demo_semafor.o prog.o img.elf
