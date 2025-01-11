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

CROSS_COMPILE = $(ARCH)-elf-

INC =  -I.
INC += -I$(PY_SRC)
INC += -I$(BUILD)

ifeq ($(ARCH),mips)
 AS = mips-elf-gcc -G 32768 -EL -c -I../../../include -nostdinc -nostdlib -march=f32c
else
 AS = riscv-elf-gcc -c -I../../../include -nostdinc -nostdlib
endif

CFLAGS_F32C = -I../../../include -include sys/param.h -nostdinc -ffunction-sections
ifeq ($(ARCH),mips)
 CFLAGS_F32C += -G 32768 -EL -march=f32c
endif
CFLAGS = $(INC) -Wall -Werror -ansi -std=gnu99 -nostdlib $(CFLAGS_F32C) $(COPT)

#Debugging/Optimization
ifeq ($(DEBUG), 1)
CFLAGS += -O0 -ggdb
else
CFLAGS += -Os -DNDEBUG
endif

LDFLAGS = -N -EL -nostdlib
LDFLAGS += -gc-sections
LDFLAGS += --section-start=.init=0x80000000
LDFLAGS += --library-path=../../../lib/${ARCH}el

ifeq (${ARCH},mips)
        OBJFLAGS = -R .rel.dyn -R .MIPS.abiflags
endif

LIBS = -lcrt0 -lc -lm

SRC_C = main.c file.c edit.c

OBJ = $(PY_O) $(addprefix $(BUILD)/, $(SRC_S:.S=.o)) $(SRC_C:.c=.o)

all: $(PROG).bin

$(PROG).bin: $(PROG).elf
	$(ISA_CHECK) $(ARCH) $(PROG).elf
	$(ARCH)-elf-objcopy ${OBJFLAGS} -O binary $(PROG).elf $(PROG).bin
	$(ARCH)-elf-objcopy ${OBJFLAGS} -O srec $(PROG).elf $(PROG).srec

$(PROG).elf: $(OBJ)
	$(ECHO) "LINK $@"
	$(Q)$(LD) $(LDFLAGS) -o $@ $(OBJ) $(LIBS)
	$(Q)$(SIZE) $@

include ../py/mkrules.mk

clean:
	rm -fr build
	rm -f *.o
	rm -f $(PROG).bin $(PROG).elf $(PROG).hex
