
# Bootloader uses a non-default loadaddr
LOADADDR = 0x800f8000

# No optional instructions in the loader
CFLAGS += -march=mips3 -mtune=f32c
CFLAGS += -mno-branch-likely -mno-mul -mno-div

# Omit floating point libs and printf parts
CFLAGS += -DNO_PRINTF_FLOAT

# Reduce FATFS code size
CFLAGS += -D_FS_MINIMIZE=1 -D_FS_READONLY=1 -D_FS_SHARE=0
CFLAGS += -D_FS_TINY=1 -D_FS_RPATH=0 -D_USE_LFN=0

# SPI flash image name
SPI_IMG_NAME = ulx2s_4m.img

PROG = loader

CFILES = loader.c

F32C_LIBS = printf fatfs

include ${POST_MK}

image:	loader.bin
	cat /dev/zero | tr "\000" "\377" | dd ibs=4k count=1k of=${SPI_IMG_NAME}
	echo "(`wc -c loader.bin | cut -c1-9` + 512 + 4095) / 4096" | bc > .rs
	echo "Reserved sectors:" `cat .rs`
	newfs_msdos -F 12 -S 4096 -s 1024 -r `cat .rs` -n 1 ./${SPI_IMG_NAME}
	rm .rs
	dd bs=1 if=loader.bin of=${SPI_IMG_NAME} oseek=512 conv=notrunc
	mmd -i ${SPI_IMG_NAME} ::boot
	mmd -i ${SPI_IMG_NAME} ::pics
	mcopy -i ${SPI_IMG_NAME} ../../pbasic/basic.bin ::boot
	mattrib -i ${SPI_IMG_NAME} +r ::boot/basic.bin
	mcopy -i ${SPI_IMG_NAME} ../../wavplay/wavplay.bin ::
	mattrib -i ${SPI_IMG_NAME} +r ::wavplay.bin
	mcopy -i ${SPI_IMG_NAME} ../../dhry/dhry.bin ::dhry.bin
	mattrib -i ${SPI_IMG_NAME} +r ::dhry.bin
	mcopy -i ${SPI_IMG_NAME} ../../coremark/v1.0/coremark.bin ::coremark.bin
	mattrib -i ${SPI_IMG_NAME} +r ::coremark.bin
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/jpegs/pictures.txt ::pics
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/jpegs/*.jpg ::pics
	mcopy -i ${SPI_IMG_NAME} ../../pbasic/COPYRIGHT ::copyright.txt
	groff -mandoc -Tascii ../../pbasic/docs/basic.1 > .bas.man
	mcopy -i ${SPI_IMG_NAME} .bas.man ::readme.txt
	mcopy -i ${SPI_IMG_NAME} ../../../../demo/basic/demo1.bas ::autoexec.bas
