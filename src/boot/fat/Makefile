
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

# SPI flash image name
SPI_IMG_NAME = ulx2s_4m.img

PROG = loader

LIBSRC = ../../lib/src

CFILES = loader.c ${LIBSRC}/sio_poll.c \
	${LIBSRC}/printf.c ${LIBSRC}/fatfs.c ${LIBSRC}/file.c \
	${LIBSRC}/malloc.c ${LIBSRC}/spi.c ${LIBSRC}/sdcard.c \
	${LIBSRC}/diskio.c ${LIBSRC}/mul.c ${LIBSRC}/div.c ${LIBSRC}/div64.c

ASFILES = ${LIBSRC}/${ARCH}/start.S

include ${POST_MK}

image:	loader.bin
	cat /dev/zero | tr "\000" "\377" | dd ibs=4k count=1k of=${SPI_IMG_NAME}
	echo "(`wc -c loader.bin | cut -c1-9` + 512 + 4095) / 4096" | bc > .rs
	echo "Reserved sectors:" `cat .rs`
	newfs_msdos -F 12 -S 4096 -s 1024 -r `cat .rs` -e 128 -n 1 \
	    ./${SPI_IMG_NAME}
	rm .rs
	dd bs=1 if=loader.bin of=${SPI_IMG_NAME} oseek=512 conv=notrunc
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
