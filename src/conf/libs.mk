
ifneq (,$(findstring div,$(F32C_LIBS)))
	_NEED_DIV = YES
endif

ifneq (,$(findstring random,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_RANDOM = YES
endif

ifneq (,$(findstring float,$(F32C_LIBS)))
	_NEED_FLOAT = YES
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
endif

ifneq (,$(findstring gets,$(F32C_LIBS)))
	_NEED_SIO = YES
	_NEED_GETS = YES
endif

ifneq (,$(findstring atoi,$(F32C_LIBS)))
	_NEED_ATOI = YES
endif

ifneq (,$(findstring spi,$(F32C_LIBS)))
	_NEED_SPI = YES
endif

ifneq (,$(findstring fatfs,$(F32C_LIBS)))
	_NEED_DIV = YES
	_NEED_SPI = YES
	_NEED_SDCARD = YES
	_NEED_DISKIO = YES
	_NEED_FATFS = YES
endif

ifneq (,$(findstring framebuffer,$(F32C_LIBS)))
	_NEED_FB = YES
endif




ifdef _NEED_SIO
	CFILES += ${BASE_DIR}lib/sio.c
endif

ifdef _NEED_SIO_BAUD
	CFILES += ${BASE_DIR}lib/sio_baud.c
endif

ifdef _NEED_PRINTF
	CFILES += ${BASE_DIR}lib/printf.c
endif

ifdef _NEED_GETS
	CFILES += ${BASE_DIR}lib/gets.c
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
endif

ifdef _NEED_RANDOM
	CFILES += ${BASE_DIR}lib/random.c
endif

ifdef _NEED_DIV
	CFILES += ${BASE_DIR}lib/div.c
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

ifdef _NEED_ATOI
	CFILES += ${BASE_DIR}lib/atoi.c
endif

ifdef _NEED_FB
	CFILES += ${BASE_DIR}lib/fb.c
endif

