#
# Copyright (c) 2013, 2014 Marko Zec, University of Zagreb
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

ifneq (,$(findstring isr,$(F32C_LIBS)))
	_NEED_ISR = YES
endif

ifneq (,$(findstring malloc,$(F32C_LIBS)))
	_NEED_MALLOC = YES
endif

ifneq (,$(findstring setjmp,$(F32C_LIBS)))
	_NEED_SETJMP = YES
endif

ifneq (,$(findstring -mno-mul,$(MK_CFLAGS)))
	_NEED_MUL = YES
endif

ifneq (,$(findstring div,$(F32C_LIBS)))
	_NEED_DIV = YES
endif

ifneq (,$(findstring div64,$(F32C_LIBS)))
	_NEED_DIV64 = YES
endif

ifneq (,$(findstring random,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_RANDOM = YES
endif

ifneq (,$(findstring math,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_FLOAT = YES
	_NEED_MATH = YES
endif

ifneq (,$(findstring sio,$(F32C_LIBS)))
	_NEED_SIO = YES
endif

ifneq (,$(findstring sio_baud,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_SIO = YES
	_NEED_SIO_BAUD = YES
endif

ifneq (,$(findstring printf,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_SIO = YES
	_NEED_PRINTF = YES
ifeq (,$(findstring NO_PRINTF_FLOAT,$(CFLAGS)))
	_NEED_FLOAT = YES
endif
endif

ifneq (,$(findstring sprintf,$(F32C_LIBS)))
	_NEED_SPRINTF = YES
endif

ifneq (,$(findstring gets,$(F32C_LIBS)))
	_NEED_GETS = YES
	_NEED_SIO = YES
endif

ifneq (,$(findstring assert,$(F32C_LIBS)))
	_NEED_ASSERT = YES
	_NEED_DIV = YES
	_NEED_SIO = YES
	_NEED_PRINTF = YES
endif

ifneq (,$(findstring atoi,$(F32C_LIBS)))
	_NEED_ATOI = YES
endif

ifneq (,$(findstring spi,$(F32C_LIBS)))
	_NEED_SPI = YES
endif

ifneq (,$(findstring memset,$(F32C_LIBS)))
	_NEED_MEMSET = YES
endif

ifneq (,$(findstring qsort,$(F32C_LIBS)))
	_NEED_QSORT = YES
endif

ifneq (,$(findstring fatfs,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_SPI = YES
	_NEED_SDCARD = YES
	_NEED_DISKIO = YES
	_NEED_FATFS = YES
endif

ifneq (,$(findstring framebuffer,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_FB = YES
	_NEED_MALLOC = YES
endif

ifneq (,$(findstring jpeg,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_FB = YES
	_NEED_MALLOC = YES
	_NEED_JPEG = YES
endif

ifneq (,$(findstring sprite,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_FB = YES
	_NEED_JPEG = YES
	_NEED_SPRITE = YES
	_NEED_MALLOC = YES
	_NEED_SPI = YES
	_NEED_SDCARD = YES
	_NEED_DISKIO = YES
	_NEED_FATFS = YES
endif

ifneq (,$(findstring lcd,$(F32C_LIBS)))
	_NEED_LCD = YES
endif


ifdef _NEED_MUL
	CFILES += ${BASE_DIR}lib/mul.c
endif

ifdef _NEED_DIV
	CFILES += ${BASE_DIR}lib/div.c
endif

ifdef _NEED_DIV64
	CFILES += ${BASE_DIR}lib/div64.c
endif

ifdef _NEED_ISR
	ASFILES += ${BASE_DIR}lib/exception.S
	CFILES += ${BASE_DIR}lib/isr.c
endif

ifdef _NEED_MALLOC
	CFILES += ${BASE_DIR}lib/malloc.c
endif

ifdef _NEED_SETJMP
	CFILES += ${BASE_DIR}lib/setjmperr.c
	ASFILES += ${BASE_DIR}lib/setjmp.S
endif

ifdef _NEED_SIO
	ifdef _NEED_ISR
		CFILES += ${BASE_DIR}lib/sio.c
	else
		CFILES += ${BASE_DIR}lib/sio_poll.c
	endif
endif

ifdef _NEED_SIO_BAUD
	CFILES += ${BASE_DIR}lib/sio_baud.c
endif

ifdef _NEED_PRINTF
	CFILES += ${BASE_DIR}lib/printf.c
endif

ifdef _NEED_SPRINTF
	CFILES += ${BASE_DIR}lib/sprintf.c
endif

ifdef _NEED_GETS
	CFILES += ${BASE_DIR}lib/gets.c
endif

ifdef _NEED_ASSERT
	CFILES += ${BASE_DIR}lib/assert.c
endif

ifdef _NEED_MEMSET
	CFILES += ${BASE_DIR}lib/memset.c
endif

ifdef _NEED_SPI
	CFILES += ${BASE_DIR}lib/spi.c
endif

ifdef _NEED_SDCARD
	CFILES += ${BASE_DIR}lib/sdcard.c
endif

ifdef _NEED_DISKIO
	CFILES += ${BASE_DIR}lib/diskio.c
endif

ifdef _NEED_FATFS
	CFILES += ${BASE_DIR}lib/fatfs.c
	CFILES += ${BASE_DIR}lib/file.c
endif

ifdef _NEED_RANDOM
	CFILES += ${BASE_DIR}lib/random.c
endif

ifdef _NEED_FLOAT
	CFILES += ${BASE_DIR}lib/float/adddf3.c
	CFILES += ${BASE_DIR}lib/float/addsf3.c
	CFILES += ${BASE_DIR}lib/float/ashldi3.c
	CFILES += ${BASE_DIR}lib/float/clzsi2.c
	CFILES += ${BASE_DIR}lib/float/comparedf2.c
	CFILES += ${BASE_DIR}lib/float/comparesf2.c
	CFILES += ${BASE_DIR}lib/float/divdf3.c
	CFILES += ${BASE_DIR}lib/float/divsf3.c
	CFILES += ${BASE_DIR}lib/float/extendsfdf2.c
	CFILES += ${BASE_DIR}lib/float/fixdfsi.c
	CFILES += ${BASE_DIR}lib/float/fixsfsi.c
	CFILES += ${BASE_DIR}lib/float/fixunsdfsi.c
	CFILES += ${BASE_DIR}lib/float/fixunsdfdi.c
	CFILES += ${BASE_DIR}lib/float/fixunssfsi.c
	CFILES += ${BASE_DIR}lib/float/floatsidf.c
	CFILES += ${BASE_DIR}lib/float/floatsisf.c
	CFILES += ${BASE_DIR}lib/float/floatundidf.c
	CFILES += ${BASE_DIR}lib/float/floatunsidf.c
	CFILES += ${BASE_DIR}lib/float/floatunsisf.c
	CFILES += ${BASE_DIR}lib/float/lshrdi3.c
	CFILES += ${BASE_DIR}lib/float/muldf3.c
	CFILES += ${BASE_DIR}lib/float/mulsf3.c
	CFILES += ${BASE_DIR}lib/float/negdf2.c
	CFILES += ${BASE_DIR}lib/float/negsf2.c
	CFILES += ${BASE_DIR}lib/float/subdf3.c
	CFILES += ${BASE_DIR}lib/float/subsf3.c
	CFILES += ${BASE_DIR}lib/float/truncdfsf2.c
endif

ifdef _NEED_MATH
	CFILES += ${BASE_DIR}lib/math/acos.c
	CFILES += ${BASE_DIR}lib/math/asin.c
	CFILES += ${BASE_DIR}lib/math/atan.c
	CFILES += ${BASE_DIR}lib/math/cos.c
	CFILES += ${BASE_DIR}lib/math/exp.c
	CFILES += ${BASE_DIR}lib/math/fabs.c
	CFILES += ${BASE_DIR}lib/math/fmod.c
	CFILES += ${BASE_DIR}lib/math/floor.c
	CFILES += ${BASE_DIR}lib/math/isnan.c
	CFILES += ${BASE_DIR}lib/math/log.c
	CFILES += ${BASE_DIR}lib/math/pow.c
	CFILES += ${BASE_DIR}lib/math/sin.c
	CFILES += ${BASE_DIR}lib/math/sqrt.c
	CFILES += ${BASE_DIR}lib/math/scalbn.c
endif

ifdef _NEED_ATOI
	CFILES += ${BASE_DIR}lib/atoi.c
endif

ifdef _NEED_QSORT
	CFILES += ${BASE_DIR}lib/qsort.c
endif

ifdef _NEED_FB
	CFILES += ${BASE_DIR}lib/fb.c
endif

ifdef _NEED_JPEG
	CFILES += ${BASE_DIR}lib/tjpgd.c
endif

ifdef _NEED_SPRITE
	CFILES += ${BASE_DIR}lib/sprite.c
endif

ifdef _NEED_LCD
	CFILES += ${BASE_DIR}lib/lcd.c
endif

