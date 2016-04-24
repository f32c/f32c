
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)


all:
	@rm -rf ${IMPL_DIR}
	@echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | ${DIAMONDC}
	ddtcmd -oft -fullvme -if project_sram.xcf -nocompress -noheader -of project/project_project_sram.vme
	# flash vme file needs jedec *.jed file as input which is not automatically
	# generated from commandline.
	# GUI runs it with this
	# bitgen -f "project_project.t2b" -w "project_project.ncd" -jedec "project_project.prf"
	# after jedec file is generated, we can generate vme file for flash programming:
	# ddtcmd -oft -fullvme -if project_flash.xcf -nocompress -noheader -of project/project_project_flash.vme

clean:
	rm -rf ${IMPL_DIR} .recovery *.sty *~

program:
	FleaFPGA-JTAG project/project_project_sram.vme
	# after this, to gain access to serial port on linux
	# rmmod ftdi_sio; modprobe ftdi_sio

flash:
	FleaFPGA-JTAG project/project_project_flash.vme
	# after this, to gain access to serial port on linux
	# rmmod ftdi_sio; modprobe ftdi_sio
