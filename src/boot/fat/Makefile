
# Bootloader uses a non-default loadaddr
LOADADDR = 0x800F0000

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

# Leaves free space for bitstream
# FAT starts at 1MB (0x100000) FLASH address (offset mount).
FLASH_FAT_OFFSET = 1048576
# bitstream should be written from flash address 0
# and should not be longer than FLASH_FAT_OFFSET bytes
BITSTREAM_IMG_NAME = /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-v20-12k/pix8bpp640x480oledspi/f32c_ulx3s_v20_12k_pix8bpp640x480oledspi_100mhz.bit
# BITSTREAM_IMG_NAME = ../../../rtl/proj/lattice/ulx3s/xram_sdram_12f_v2.0_c2_oledspi/project/f32c_ulx3s_v20_12k_pix8bpp640x480oledspi_100mhz.bit
# BITSTREAM_IMG_NAME = /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-v20-45k/pix8bpp640x480oledspi/f32c_ulx3s_v20_45k_pix8bpp640x480oledspi_100mhz.bit
# BITSTREAM_IMG_NAME = ../../../rtl/proj/lattice/ulx3s/xram_sdram_vector_45f_v1.7p_c2_oledspi/project/f32c_ulx3s_v17_45k_pix8bpp640x480oledspi_100mhz.bit
# BITSTREAM_IMG_NAME = /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-v17-45k/pix8bpp640x480oledspi/f32c_ulx3s_v17_45k_pix8bpp640x480oledspi_100mhz.bit
# BITSTREAM_IMG_NAME = /mt/scratch/tmp/xilinx/papilio-pro/f32c/papilio_pro.bin
# BITSTREAM_IMG_NAME = ../../../rtl/proj/xilinx/papilio-pro/papilio_pro_xram_sdram/papilio_pro.bin
# loader start address relative to start of the FAT image
LOADER_START = 512
# it should match the address relative to flash start in rom/loader.c
# #define LOADER_START 0x100200

# SPI flash complete image name
SPI_IMG_NAME = /tmp/flash.img

# temporary files
TMP_BITSTREAM_IMG_NAME = /tmp/bitstream.img
TMP_FAT_IMG_NAME = /tmp/fat.img

# FAT filesystem parameters
VOLUME_NAME=ULX3S
IMAGE_KB = 3072
LOGICAL_SECTOR_SIZE = 4096
SECTORS = $(shell echo $(IMAGE_KB) \* 1024 / $(LOGICAL_SECTOR_SIZE) | bc)
RESERVED_SECTORS = $(shell echo '(' $$(wc -c loader.bin | xargs echo | cut -d " " -f 1) + $(LOADER_START) + $(LOGICAL_SECTOR_SIZE) - 1 ')' / $(LOGICAL_SECTOR_SIZE) | bc)
BOOTSECTOR_SIZE = 512
ERASE_TO_LOADER = $(shell echo $(LOADER_START) - $(BOOTSECTOR_SIZE) | bc)
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
	# erase (write 0xFF) as the space for bitstream
	dd if=/dev/zero bs=$(FLASH_FAT_OFFSET) count=1 | tr "\0" "\377" > ${TMP_BITSTREAM_IMG_NAME}
	# write the bitstream
	dd if=${BITSTREAM_IMG_NAME} of=${TMP_BITSTREAM_IMG_NAME} conv=notrunc
	# FAT filesystem
	dd if=/dev/zero ibs=$(LOGICAL_SECTOR_SIZE) count=$(SECTORS) | tr "\0" "\377" > ${TMP_FAT_IMG_NAME}
	@echo "Reserved sectors:" $(RESERVED_SECTORS)
	mkfs.msdos \
	  -n $(VOLUME_NAME) \
	  -F $(FAT_TYPE) \
	  -S $(LOGICAL_SECTOR_SIZE) \
	  -R $(RESERVED_SECTORS) \
	  -r $(ROOT_DIR_ENTRIES) \
	  -f $(NUMBER_OF_FATS) \
	  ${TMP_FAT_IMG_NAME} $(IMAGE_KB)
	# erase (write 0xFF) after bootsector up to start of loader.bin (space for bitstream)
        # dd if=/dev/zero bs=$(ERASE_TO_LOADER) count=1 | tr "\0" "\377" | dd of=${TMP_FAT_IMG_NAME} bs=$(BOOTSECTOR_SIZE) seek=
	# write the FAT bootloader
	dd if=loader.bin of=${TMP_FAT_IMG_NAME} bs=1 seek=$(LOADER_START) conv=notrunc
	# copy files to FAT filesystem
	mmd -i ${TMP_FAT_IMG_NAME} ::boot
	mmd -i ${TMP_FAT_IMG_NAME} ::demo
	# mcopy -i ${TMP_FAT_IMG_NAME} ~/src/fpga/fpgarduino/basic-c2/basic.bin ::boot
	mcopy -i ${TMP_FAT_IMG_NAME} ../../lang/basic/basic.bin ::boot
	mcopy -i ${TMP_FAT_IMG_NAME} ~/src/fpga/fpgarduino/basic-c2/autoexec.bas ::
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/arcagol.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/galaga.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/blink.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/pong.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/oled.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/sprites.bin ::demo
	mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/vector_fractal_fast.bin ::demo/vector.bin
	# mcopy -i ${TMP_FAT_IMG_NAME} /mt/scratch/tmp/lattice/ulx3s/ulx3s-sdcard/ULX3S/f32c/f32c-bin/galaga.bin ::autoexec.bin
	mdir -i ${TMP_FAT_IMG_NAME} -/ ::
	# complete FLASH image
	cat ${TMP_BITSTREAM_IMG_NAME} ${TMP_FAT_IMG_NAME} > ${SPI_IMG_NAME}
	@rm ${TMP_BITSTREAM_IMG_NAME} ${TMP_FAT_IMG_NAME}

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

flash_ulx2s:
	ujprog -j flash /mt/scratch/tmp/lattice/ulx2s/8e/xram_synth/ulx2s_8e_xram_synth.jed
	# ujprog -j flash ../../../rtl/proj/lattice/ulx2s/xram_synth/project/project_project.jed

flash_ulx3s:
	ujprog /mt/scratch/tmp/lattice/ulx3s/ulx3s-bin/fpga/tinyfpgasp/tinyfpgasp-12k-v2.0/tinyfpga_12k.bit
	#ujprog /mt/scratch/tmp/lattice/ulx3s/ulx3s-bin/fpga/tinyfpgasp/tinyfpgasp-45k-v2.0/tinyfpga_45k.bit
	#ujprog /mt/scratch/tmp/lattice/ulx3s/ulx3s-bin/fpga/tinyfpgasp/tinyfpgasp-45k-v1.7patch/tinyfpga_45k.bit
	#ujprog /mt/scratch/tmp/lattice/ulx3s/ulx3s-bin/fpga/tinyfpgasp/tinyfpgasp-85k-v2.0/tinyfpga_85k.bit
	sleep 2
	# write whole image
	tinyfpgasp -a 0 -w /tmp/flash.img

flash_papilio:
	xz -cd ../../../rtl/proj/xilinx/include/bscan_xc6s_tqg144_papilio_pro.bit.xz > /tmp/jtag_spi_bridge.bit
	/mt/scratch/tmp/xc3sprog/xc3sprog_anybin -c ftdi -I/tmp/jtag_spi_bridge.bit /tmp/flash.img
	rm /tmp/jtag_spi_bridge.bit
	/mt/scratch/tmp/xc3sprog/xc3sprog_anybin -c ftdi -R
