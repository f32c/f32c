include ../py/mkenv.mk

# qstr definitions (must come before including py.mk)
QSTR_DEFS = qstrdefsport.h

# include py core make definitions
include ../py/py.mk

CROSS_COMPILE = mips-elf-

INC =  -I.
INC += -I$(PY_SRC)
INC += -I$(BUILD)

AS = mips-elf-gcc -G 32768 -EL -c -I../../../include -nostdinc -nostdlib -march=f32c

CFLAGS_MIPS = -I../../../include -include sys/param.h -nostdinc
CFLAGS_MIPS += -G 32768 -EL -march=f32c -ffunction-sections
CFLAGS = $(INC) -Wall -Werror -ansi -std=gnu99 -nostdlib $(CFLAGS_MIPS) $(COPT)

#Debugging/Optimization
ifeq ($(DEBUG), 1)
CFLAGS += -O0 -ggdb
else
CFLAGS += -Os -DNDEBUG
endif

CFLAGS += -DNO_PRINTF_FLOAT

LDFLAGS = -N -EL -nostdlib -gc-sections
LDFLAGS += --section-start=.init=0x80000000

LIBS =

SRC_C = \
	main.c \
	file.c \
	../../lib/setjmperr.c \
	../../lib/div.c \
	../../lib/printf.c \
	../../lib/sprintf.c \
	../../lib/sio_poll.c \
	../../lib/malloc.c \
	../../lib/memcmp.c \
	../../lib/memset.c \
	../../lib/memmove.c \
	../../lib/gets.c \
	../../lib/file.c \
	../../lib/fatfs.c \
	../../lib/diskio.c \
	../../lib/sdcard.c \
	../../lib/spi.c \


#	string0.c \
	malloc0.c \
	gccollect.c \

SRC_S = \
	setjmp.S \
	start.S \
#	startup_stm32f40xx.s \
	gchelper.s \

OBJ = $(PY_O) $(addprefix $(BUILD)/, $(SRC_S:.S=.o)) $(SRC_C:.c=.o)

all: py.bin

py.bin: py.elf
	../../../tools/isa_check.tcl mips py.elf
	mips-elf-objcopy -O binary py.elf py.bin
	mips-elf-objcopy -O srec py.elf py.hex

py.elf: $(OBJ)
	$(ECHO) "LINK $@"
	$(Q)$(LD) $(LDFLAGS) -o $@ $(OBJ) $(LIBS)
	$(Q)$(SIZE) $@

include ../py/mkrules.mk

$(BUILD)/setjmp.o: setjmp.S
	$(AS) setjmp.S -o $@

$(BUILD)/start.o: start.S
	$(AS) start.S -o $@

clean:
	rm -fr build
	rm -f *.o
	rm -f py.bin py.elf py.hex
