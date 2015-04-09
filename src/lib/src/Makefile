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
# $Id$
#

ifeq ($(MAKECMDGOALS),crt0)
 LIB = crt0
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
$(error Must specify library target: crt0 c cint m ulx2s)
endif

ifeq ($(LIB),crt0)
 ASFILES = ${ARCH}/start.S
endif

ifeq ($(LIB),c)
 ifneq ($(ARCH),riscv)
  ASFILES = ${ARCH}/setjmp.S ${ARCH}/exception.S
 endif

 CFILES = assert.c atoi.c diskio.c div.c div64.c fatfs.c \
	file.c gets.c malloc.c memcmp.c memcpy.c memmove.c \
	memset.c mul.c printf.c qsort.c random.c sdcard.c sio_poll.c \
	spi.c sprintf.c strcasecmp.c strcpy.c strncpy.c \
	strstr.c strtol.c

 ifneq ($(ARCH),riscv)
  CFILES += sio.c sio_baud.c setjmperr.c isr.c
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
	float/subdf3.c float/subsf3.c float/truncdfsf2.c
 endif
endif

ifeq ($(LIB),m)
 CFILES = math/scalbn.c math/pow.c math/isnan.c math/fabs.c math/floor.c \
	math/log.c math/atan.c math/cos.c math/acos.c math/copysignf.c \
	math/fmod.c math/sinhf.c math/sin.c math/sqrt.c math/asin.c \
	math/exp.c math/cosf.c math/sinf.c math/acosf.c math/asinf.c \
	math/atanf.c math/expf.c math/fabsf.c math/fmodf.c math/floorf.c \
	math/logf.c math/powf.c math/sqrtf.c math/ceilf.c math/expm1.c \
	math/coshf.c math/modff.c math/atan2f.c math/log10f.c math/tanhf.c \
	math/log2f.c math/tanf.c math/erff.c math/atanhf.c math/acoshf.c \
	math/asinhf.c math/expm1f.c math/log1pf.c math/frexpf.c math/isinf.c \
	math/isfinite.c math/scalbnf.c math/log2.c math/log10.c math/cosh.c \
	math/sinh.c math/modf.c math/ceil.c math/erf.c math/frexp.c \
	math/atan2.c math/acosh.c math/log1p.c math/atanh.c math/asinh.c \
	math/tanh.c math/tan.c
endif

ifeq ($(LIB),ulx2s)
 CFILES = fb.c tjpgd.c sprite.c lcd.c
endif

include ${POST_MK}
