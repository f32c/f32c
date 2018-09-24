
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)
DDTCMD := $(shell find ${DIAMOND_BIN}/ -name ddtcmd)

OPENOCD = openocd_ft232r
OPENOCD_BASE := ../../programmer/openocd/fleafpga_uno

# name of the project as defined in project file
PROJECT = project

all: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.vme $(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme
	#@rm -rf ${IMPL_DIR}
	#@echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | ${DIAMONDC}
	#ddtcmd -oft -fullvme -if project_sram.xcf -nocompress -noheader -of project/project_project_sram.vme
	# flash vme file needs jedec *.jed file as input which is not automatically
	# generated from commandline.
	# GUI runs it with this
	# bitgen -f "project_project.t2b" -w "project_project.ncd" -jedec "project_project.prf"
	# after jedec file is generated, we can generate vme file for flash programming:
	# ddtcmd -oft -fullvme -if project_flash.xcf -nocompress -noheader -of project/project_project_flash.vme


$(PROJECT)/$(PROJECT)_$(PROJECT).bit:
	echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | ${DIAMONDC}

$(PROJECT)/$(PROJECT)_$(PROJECT)_sram.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	LANG=C $(DDTCMD) -oft -fullvme -if project_sram.xcf -nocompress -noheader -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	LANG=C $(DDTCMD) -oft -svfsingle -revd -maxdata 8 -if project_sram.xcf -noheader -of $@

program: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.vme
	FleaFPGA-JTAG $<

$(PROJECT)/$(PROJECT)_$(PROJECT).jed:
	echo prj_project open ${PROJ_FILE} \; prj_run Export -task Jedecgen | ${DIAMONDC}

$(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	LANG=C $(DDTCMD) -oft -fullvme -if project_flash.xcf -nocompress -noheader -of $@

flash: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme
	FleaFPGA-JTAG $<

program_ft230x: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/ft230x.ocd --file=$(OPENOCD_BASE)/machxo2.ocd

clean:
	rm -rf ${IMPL_DIR} .recovery *.sty *~
