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

LDFLAGS = -N -EL -nostdlib -gc-sections
LDFLAGS += --section-start=.init=0x80000000

LIBS =

SRC_C = \
	main.c \
	file.c \
	edit.c \
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
	../../lib/strcpy.c \

SRC_C += ../../lib/float/adddf3.c
SRC_C += ../../lib/float/addsf3.c
SRC_C += ../../lib/float/ashldi3.c
SRC_C += ../../lib/float/clzsi2.c
SRC_C += ../../lib/float/comparedf2.c
SRC_C += ../../lib/float/comparesf2.c
SRC_C += ../../lib/float/divdf3.c
SRC_C += ../../lib/float/divsf3.c
SRC_C += ../../lib/float/extendsfdf2.c
SRC_C += ../../lib/float/fixdfsi.c
SRC_C += ../../lib/float/fixsfsi.c
SRC_C += ../../lib/float/fixunsdfsi.c
SRC_C += ../../lib/float/fixunsdfdi.c
SRC_C += ../../lib/float/fixunssfsi.c
SRC_C += ../../lib/float/floatsidf.c
SRC_C += ../../lib/float/floatsisf.c
SRC_C += ../../lib/float/floatundidf.c
SRC_C += ../../lib/float/floatunsidf.c
SRC_C += ../../lib/float/floatunsisf.c
SRC_C += ../../lib/float/lshrdi3.c
SRC_C += ../../lib/float/muldf3.c
SRC_C += ../../lib/float/mulsf3.c
SRC_C += ../../lib/float/negdf2.c
SRC_C += ../../lib/float/negsf2.c
SRC_C += ../../lib/float/subdf3.c
SRC_C += ../../lib/float/subsf3.c
SRC_C += ../../lib/float/truncdfsf2.c

SRC_C += ../../lib/math/exp.c
SRC_C += ../../lib/math/sqrt.c
SRC_C += ../../lib/math/scalbn.c
SRC_C += ../../lib/math/isnan.c

# single precision math functions
SRC_C += ../../lib/math/fmodf.c
SRC_C += ../../lib/math/floorf.c
SRC_C += ../../lib/math/powf.c
SRC_C += ../../lib/math/modff.c
SRC_C += ../../lib/math/logf.c
SRC_C += ../../lib/math/expf.c
SRC_C += ../../lib/math/acosf.c
SRC_C += ../../lib/math/asinf.c
SRC_C += ../../lib/math/atanf.c
SRC_C += ../../lib/math/cosf.c
SRC_C += ../../lib/math/fabsf.c
SRC_C += ../../lib/math/sinf.c
SRC_C += ../../lib/math/sqrtf.c
SRC_C += ../../lib/math/ceilf.c
SRC_C += ../../lib/math/sinhf.c
SRC_C += ../../lib/math/coshf.c
SRC_C += ../../lib/math/atan2f.c
SRC_C += ../../lib/math/tanhf.c
SRC_C += ../../lib/math/tanf.c
SRC_C += ../../lib/math/log10f.c
SRC_C += ../../lib/math/log2f.c
SRC_C += ../../lib/math/erff.c
SRC_C += ../../lib/math/atanhf.c
SRC_C += ../../lib/math/acoshf.c
SRC_C += ../../lib/math/asinhf.c
SRC_C += ../../lib/math/expm1f.c
SRC_C += ../../lib/math/log1pf.c
SRC_C += ../../lib/math/frexpf.c
SRC_C += ../../lib/math/scalbnf.c
SRC_C += ../../lib/math/isinf.c
SRC_C += ../../lib/math/isfinite.c

# double precision math functions - unneeded ATM
ifeq (0, 1)
SRC_C += ../../lib/math/pow.c
SRC_C += ../../lib/math/fmod.c
SRC_C += ../../lib/math/floor.c
SRC_C += ../../lib/math/acos.c
SRC_C += ../../lib/math/asin.c
SRC_C += ../../lib/math/atan.c
SRC_C += ../../lib/math/cos.c
SRC_C += ../../lib/math/fabs.c
SRC_C += ../../lib/math/log.c
SRC_C += ../../lib/math/sin.c
endif


#	string0.c \
	malloc0.c \
	gccollect.c \

SRC_S = \
	setjmp.S \
	start.S \

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

$(BUILD)/setjmp.o: setjmp.S
	$(AS) setjmp.S -o $@

$(BUILD)/start.o: start.S
	$(AS) start.S -o $@

clean:
	rm -fr build
	rm -f *.o
	rm -f $(PROG).bin $(PROG).elf $(PROG).hex
