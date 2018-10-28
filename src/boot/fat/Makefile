
# Bootloader uses a non-default loadaddr
LOADADDR = 0x8fff8000

# Do not link standard libs
WITHOUT_LIBS = true

# No optional instructions in the loader
MIN = true

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code size
CFLAGS += -D_FS_MINIMIZE=1 -D_FS_READONLY=1 -D_USE_ERASE=0
CFLAGS += -D_FS_TINY=1 -D_FS_RPATH=0 -D_USE_LFN=0 -D_CODE_PAGE=1

PROG = loader

# loader start address in the image
LOADER_START = 512

# SPI flash image name
SPI_IMG_NAME = ulx2s_4m.img

# FAT filesystem parameters
VOLUME_NAME=ULX3S
IMAGE_KB = 640
LOGICAL_SECTOR_SIZE = 4096
SECTORS = $(shell echo $(IMAGE_KB) \* 1024 / $(LOGICAL_SECTOR_SIZE) | bc)
RESERVED_SECTORS = $(shell echo '(' $$(wc -c loader.bin | xargs echo | cut -d " " -f 1) + $(LOADER_START) + $(LOGICAL_SECTOR_SIZE) - 1 ')' / $(LOGICAL_SECTOR_SIZE) | bc)
FAT_TYPE = 12
NUMBER_OF_FATS = 1
ROOT_DIR_ENTRIES = 128

LIBSRC = ../../lib/src

CFILES = loader.c ${LIBSRC}/sio_poll.c \
	${LIBSRC}/printf.c ${LIBSRC}/fatfs.c ${LIBSRC}/file.c \
	${LIBSRC}/malloc.c ${LIBSRC}/spi.c ${LIBSRC}/sdcard.c \
	${LIBSRC}/diskio.c ${LIBSRC}/mul.c ${LIBSRC}/div.c ${LIBSRC}/div64.c

ASFILES = ${LIBSRC}/${ARCH}/start.S

include ${POST_MK}

image_linux: loader.bin
	@echo "sectors:" $(SECTORS)
	cat /dev/zero | tr "\000" "\377" | dd ibs=$(LOGICAL_SECTOR_SIZE) count=$(SECTORS) of=${SPI_IMG_NAME}
	@echo "Reserved sectors:" $(RESERVED_SECTORS)
	mkfs.msdos \
	  -n $(VOLUME_NAME) \
	  -F $(FAT_TYPE) \
	  -S $(LOGICAL_SECTOR_SIZE) \
	  -R $(RESERVED_SECTORS) \
	  -r $(ROOT_DIR_ENTRIES) \
	  -f $(NUMBER_OF_FATS) \
	  ./${SPI_IMG_NAME}
	# freshly compiled loader.bin doesn't work
	# dd bs=1 if=loader.bin of=${SPI_IMG_NAME} seek=$(LOADER_START) conv=notrunc
	# loader.bin from old image works
	dd bs=1 if=/tmp/ulx3s_4m.img of=${SPI_IMG_NAME} skip=$(LOADER_START) seek=$(LOADER_START) count=10440 conv=notrunc
	mmd -i ${SPI_IMG_NAME} ::boot
	mcopy -i ${SPI_IMG_NAME} ~/src/fpga/fpgarduino/basic-c2/basic.bin ::boot
	mcopy -i ${SPI_IMG_NAME} ~/src/fpga/fpgarduino/basic-c2/autoexec.bas ::
	mdir -i ${SPI_IMG_NAME} -/ ::

image:	loader.bin
	cat /dev/zero | tr "\000" "\377" | dd ibs=$(LOGICAL_SECTOR_SIZE) count=$(SECTORS) of=${SPI_IMG_NAME}
	@echo "Reserved sectors:" $(RESERVED_SECTORS)
	newfs_msdos \
	  -L $(VOLUME_NAME) \
	  -F $(FAT_TYPE) \
	  -S $(LOGICAL_SECTOR_SIZE) \
	  -r $(RESERVED_SECTORS) \
	  -e $(ROOT_DIR_ENTRIES) \
	  -n $(NUMBER_OF_FATS) \
	    ./${SPI_IMG_NAME}
	dd bs=1 if=loader.bin of=${SPI_IMG_NAME} oseek=$(LOADER_START) conv=notrunc
	mmd -i ${SPI_IMG_NAME} ::boot
	mmd -i ${SPI_IMG_NAME} ::demo
	mmd -i ${SPI_IMG_NAME} ::demo/pics
	mmd -i ${SPI_IMG_NAME} ::demo/logos
	mmd -i ${SPI_IMG_NAME} ::demo/chess
	mmd -i ${SPI_IMG_NAME} ::bench
	mcopy -i ${SPI_IMG_NAME} ../../lang/basic/basic.bin ::boot
	mcopy -i ${SPI_IMG_NAME} ../../lang/python/f32c/py.bin ::boot
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/jpegs/pictures.txt \
		::demo/pics
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/jpegs/*.jpg ::demo/pics
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/jpegs/logos/*.jpg \
		::demo/logos
	mcopy -i ${SPI_IMG_NAME} ../../lang/basic/COPYRIGHT ::copyright.txt
	groff -mandoc -Tascii ../../lang/basic/docs/basic.1 > .bas.man
	mcopy -i ${SPI_IMG_NAME} .bas.man ::readme.txt
	mcopy -i ${SPI_IMG_NAME} ../../examples/video_test/vidtest.bin ::demo
	mcopy -i ${SPI_IMG_NAME} ../../examples/wavplay/wavplay.bin ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/demo.bas ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/snake.bas ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/tetris.bas ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/pacman.bas ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/four.bas ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/chess.bin ::demo
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/board.jpg ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/white.jpg ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/black.jpg ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/book.txt ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/README ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/COPYING ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/chess/mscp.c ::demo/chess
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/autoexec.bas ::
	mcopy -i ${SPI_IMG_NAME} ../../bench/coremark/coremark.bin ::bench
	mcopy -i ${SPI_IMG_NAME} ../../bench/dhry/dhry.bin ::bench
