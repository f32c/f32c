#
# Copyright (c) 2015 Marko Zec, University of Zagreb
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

.PHONY: riscv
.PHONY: mips

ifeq ($(MAKECMDGOALS),crt0)
 LIB = crt0
 .DEFAULT_GOAL = lib
endif

ifeq ($(MAKECMDGOALS),crt0rom)
 LIB = crt0rom
 CFLAGS += -DCRT0ROM
 .DEFAULT_GOAL = lib
endif

ifeq ($(MAKECMDGOALS),c)
 LIB = c
 .DEFAULT_GOAL = lib
endif

ifeq ($(MAKECMDGOALS),cint)
 LIB = c
 .DEFAULT_GOAL = lib
 # Omit floating point libs and corresponding printf parts
 CFLAGS += -DNO_PRINTF_FLOAT
 INT_LIBC = true
endif

ifeq ($(MAKECMDGOALS),m)
 LIB = m
 .DEFAULT_GOAL = lib
endif

ifeq ($(MAKECMDGOALS),ulx2s)
 LIB = ulx2s
 .DEFAULT_GOAL = lib
endif

ifeq ($(.DEFAULT_GOAL),)
 LIB = none
 .DEFAULT_GOAL = all_libs
endif

ifeq ($(LIB),crt0)
 ASFILES = ${ARCH}/start.S
endif

ifeq ($(LIB),crt0rom)
 ASFILES = ${ARCH}/start.S
endif

ifeq ($(LIB),c)
 ifneq ($(ARCH),riscv)
  ASFILES = ${ARCH}/setjmp.S ${ARCH}/exception.S
 endif

 CFILES += gen/assert.c gen/div.c gen/div64.c gen/mul.c gen/errno.c

 CFILES += dev/sdcard.c dev/sio_baud.c dev/sio_poll.c dev/spi.c

 CFILES += fs/fatfs.c fs/ffunicode.c fs/file.c fs/diskio.c
 CFILES += fs/diskio_flash.c fs/diskio_fram.c fs/diskio_ram.c

 CFILES += stdio/gets.c stdio/printf.c stdio/sprintf.c

 CFILES += stdlib/abs.c stdlib/atoi.c stdlib/labs.c stdlib/malloc.c \
	stdlib/qsort.c stdlib/random.c stdlib/strtol.c stdlib/strtoll.c \
	stdlib/strtoull.c

 CFILES += string/memcmp.c string/memcpy.c string/memmove.c string/memset.c \
	string/strcasecmp.c string/strcat.c string/strcmp.c string/strcpy.c \
	string/strncpy.c string/strstr.c string/strtok.c

 CFILES += stdtime/asctime.c stdtime/clock.c stdtime/time.c

 ifneq ($(ARCH),riscv)
  CFILES += dev/sio.c gen/setjmperr.c gen/isr.c
 endif

 ifeq ($(INT_LIBC),true)
  LIB = cint
 endif
 ifneq ($(INT_LIBC),true)
  CFILES += float/adddf3.c float/addsf3.c float/ashldi3.c float/clzsi2.c \
	float/comparedf2.c float/comparesf2.c float/divdf3.c float/divsf3.c \
	float/extendsfdf2.c float/fixdfsi.c float/fixsfsi.c float/fixunsdfdi.c \
	float/fixunsdfsi.c float/fixunssfsi.c float/floatsidf.c \
	float/floatsisf.c float/floatundidf.c float/floatundisf.c \
	float/floatunsidf.c float/floatunsisf.c float/lshrdi3.c \
	float/muldf3.c float/mulsf3.c float/negdf2.c float/negsf2.c \
	float/subdf3.c float/subsf3.c float/truncdfsf2.c float/fixdfdi.c \
	float/ashrdi3.c float/floatdidf.c \
	math/isnan.c math/isinf.c math/isfinite.c
 endif
endif

ifeq ($(LIB),m)
 CFILES = math/scalbn.c math/pow.c math/fabs.c math/floor.c \
	math/log.c math/atan.c math/cos.c math/acos.c math/copysignf.c \
	math/fmod.c math/sinhf.c math/sin.c math/sqrt.c math/asin.c \
	math/exp.c math/cosf.c math/sinf.c math/acosf.c math/asinf.c \
	math/atanf.c math/expf.c math/fabsf.c math/fmodf.c math/floorf.c \
	math/logf.c math/powf.c math/sqrtf.c math/ceilf.c math/expm1.c \
	math/coshf.c math/modff.c math/atan2f.c math/log10f.c math/tanhf.c \
	math/log2f.c math/tanf.c math/erff.c math/atanhf.c math/acoshf.c \
	math/asinhf.c math/expm1f.c math/log1pf.c math/frexpf.c \
	math/scalbnf.c math/log2.c math/log10.c math/cosh.c \
	math/sinh.c math/modf.c math/ceil.c math/erf.c math/frexp.c \
	math/atan2.c math/acosh.c math/log1p.c math/atanh.c math/asinh.c \
	math/tanh.c math/tan.c math/signbit.c math/nearbyint.c math/rintf.c \
	math/fenv.c math/truncf.c math/trunc.c math/rint.c math/ldexp.c \
	math/lgamma.c
 ifneq ($(ARCH),riscv)
#  CFLAGS += -G 0
 endif
endif

ifeq ($(LIB),ulx2s)
 CFILES = dev/fb.c dev/tjpgd.c dev/upng.c dev/sprite.c dev/lcd.c
endif

include ${POST_MK}

libs:
	rm -fr ${LIBDIR}
	mkdir -p ${LIBDIR}
	rm -fr ${OBJDIR}
	${MAKE} crt0
	rm -fr ${OBJDIR}
	${MAKE} c
	rm -fr ${OBJDIR}
	${MAKE} cint
	rm -fr ${OBJDIR}
	${MAKE} m
	rm -fr ${OBJDIR}
	${MAKE} ulx2s
	rm -fr ${OBJDIR}

clean: clean_lib_objs

clean_lib_objs:
	rm -fr ${OBJDIR}

riscv:
	${MAKE} ARCH=riscv libs
	${MAKE} ARCH=riscv MIN=true libs

mipsel:
	${MAKE} ARCH=mips ENDIANFLAGS=-EL libs
	${MAKE} ARCH=mips ENDIANFLAGS=-EL NOMUL=true libs
	${MAKE} ARCH=mips ENDIANFLAGS=-EL MIN=true libs

mipseb:
	${MAKE} ARCH=mips ENDIANFLAGS=-EB libs
	${MAKE} ARCH=mips ENDIANFLAGS=-EB NOMUL=true libs
	${MAKE} ARCH=mips ENDIANFLAGS=-EB MIN=true libs

mips:
	${MAKE} mipsel
	${MAKE} mipseb

all_libs:
	${MAKE} riscv
	${MAKE} mips
