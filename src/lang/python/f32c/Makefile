include ../py/mkenv.mk

# define main target
PROG = py

# qstr definitions (must come before including py.mk)
QSTR_DEFS = qstrdefsport.h

# include py core make definitions
include ../py/py.mk

ifeq ($(shell uname -s), FreeBSD)
ISA_CHECK = ${BASE_DIR}tools/isa_check.tcl
else
ISA_CHECK = tclsh ${BASE_DIR}tools/isa_check.tcl
endif

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

LDFLAGS = -N -EL -nostdlib
LDFLAGS += -gc-sections
LDFLAGS += --section-start=.init=0x80000000
LDFLAGS += --library-path=../../../lib/${ARCH}

LIBS = -lc -lm

SRC_C = main.c file.c edit.c

OBJ = $(PY_O) $(addprefix $(BUILD)/, $(SRC_S:.S=.o)) $(SRC_C:.c=.o)

all: $(PROG).bin

$(PROG).bin: $(PROG).elf
	$(ISA_CHECK) mips $(PROG).elf
	mips-elf-objcopy -O binary $(PROG).elf $(PROG).bin
	mips-elf-objcopy -O srec $(PROG).elf $(PROG).hex

$(PROG).elf: $(OBJ)
	$(ECHO) "LINK $@"
	$(Q)$(LD) $(LDFLAGS) -o $@ $(OBJ) $(LIBS)
	$(Q)$(SIZE) $@

include ../py/mkrules.mk

clean:
	rm -fr build
	rm -f *.o
	rm -f $(PROG).bin $(PROG).elf $(PROG).hex
