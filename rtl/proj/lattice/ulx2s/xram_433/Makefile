
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)

OPENOCD = openocd_ft232r
OPENOCD_BASE := ../../programmer/openocd/ulx2s

# name of the project as defined in project file
PROJECT = project

JUNK = ${IMPL_DIR} .recovery ._Real_._Math_.vhd *.sty reportview.xml
JUNK += dummy_sym.sort project_tcl.html promote.xml
JUNK += generate_core.tcl generate_ngd.tcl msg_file.log
JUNK += project_tcr.dir .run_manager.ini
JUNK += hdmi_pcs.jhd hdmi_pcs.naf hdmi_pcs.pp hdmi_pcs.readme hdmi_pcs.sort hdmi_pcs.sym hdmi_pcs.tft hdmi_pcstx_reset_sm.naf hdmi_pcs_generate.log

all: $(PROJECT)/$(PROJECT)_$(PROJECT).jed $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf

$(PROJECT)/$(PROJECT)_$(PROJECT).jed:
	@echo prj_project open ${PROJ_FILE} \; prj_run PAR -task PARTrace \; prj_run Export -task Bitgen | ${DIAMONDC}
#	@fgrep Warning: ${IMPL_DIR}/*.twr

program: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	ujprog ${IMPL_DIR}/${PROJ_NAME}_${IMPL_NAME}.jed

$(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	ujprog $< -s $@

program_ft232r: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/ft232r.ocd --file=$(OPENOCD_BASE)/fx2.ocd

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
#	LANG=C ddtcmd -oft -fullvme -if ulx2s_flash.xcf -nocompress -noheader -of $@

#flash: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme
#	${PROGRAMMERC} $<

clean:
	rm -rf $(JUNK) *~
