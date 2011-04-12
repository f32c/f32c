
#LOADADDR = 0x80100100
LOADADDR = 0x00000000

# -EB big-endian (default); -EL little-endian

ENDIANFLAGS = -EL

# Includes
CFLAGS = -I../include
# MIPS-specific flags
CFLAGS += -march=mips3 ${ENDIANFLAGS}
CFLAGS += -mno-branch-likely
CFLAGS += -mno-mips16 -mno-dsp -mno-mips3d -mno-mdmx -msoft-float
CFLAGS += -c -s -n -nostdlib -fno-builtin
CFLAGS += -std=c99 -Wall -Werror
CFLAGS += -G 32768
# f32c-specific flags
CFLAGS += -msoft-mul -msoft-div
# Debugging options
CFLAGS += -g
# Optimization options
CFLAGS += -Os
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
	$(CC) -o loader.o loader.c
	$(CC) -o sio.o ../lib/sio.c
	$(LD) -o img.elf \
	    boot.o sio.o loader.o

clean:
	rm -f boot.o loader.o sio.o img.elf
