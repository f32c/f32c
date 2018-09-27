
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)
DDTCMD := $(shell find ${DIAMOND_BIN}/ -name ddtcmd)

OPENOCD = openocd_ft232r
OPENOCD_BASE := ../../programmer/openocd/ulx2s/

# name of the project as defined in project file
PROJECT = project

JUNK = ${IMPL_DIR} .recovery ._Real_._Math_.vhd *.sty reportview.xml
JUNK += dummy_sym.sort project_tcl.html promote.xml
JUNK += generate_core.tcl generate_ngd.tcl msg_file.log
JUNK += project_tcr.dir .run_manager.ini
JUNK += hdmi_pcs.jhd hdmi_pcs.naf hdmi_pcs.pp hdmi_pcs.readme hdmi_pcs.sort hdmi_pcs.sym hdmi_pcs.tft hdmi_pcstx_reset_sm.naf hdmi_pcs_generate.log

all: $(PROJECT)/$(PROJECT)_$(PROJECT).jed $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf

program: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	ujprog ${IMPL_DIR}/${PROJ_NAME}_${IMPL_NAME}.jed

flash: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	ujprog -j flash ${IMPL_DIR}/${PROJ_NAME}_${IMPL_NAME}.jed

#program_wifi: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
#	openocd --file=$(OPENOCD_BASE)/remote.ocd --file=$(OPENOCD_BASE)/ecp3.ocd

#program_ft2232: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
#	openocd --file=$(OPENOCD_BASE)/ft2232-fpu1.ocd --file=$(OPENOCD_BASE)/ecp3.ocd

program_ft232r: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/ft232r.ocd --file=$(OPENOCD_BASE)/fx2.ocd

$(PROJECT)/$(PROJECT)_$(PROJECT).bit:
	@echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | ${DIAMONDC}

$(PROJECT)/$(PROJECT)_$(PROJECT).jed:
	@echo prj_project open ${PROJ_FILE} \; prj_run PAR -task PARTrace \; prj_run Export -task Bitgen | ${DIAMONDC}
#	@fgrep Warning: ${IMPL_DIR}/*.twr

$(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	ujprog $< -s $@

#	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if ulx2s_sram.xcf -noheader -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT)_sram.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
	LANG=C ${DDTCMD} -oft -fullvme -if ulx2s_sram.xcf -noheader -of $@

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
#	LANG=C ddtcmd -oft -fullvme -if ulx2s_flash.xcf -nocompress -noheader -of $@

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash.svf: $(PROJECT)/$(PROJECT)_$(PROJECT).jed
#	LANG=C ddtcmd -oft -svfsingle -op "FLASH Erase,Program,Verify" -if $< -of $@

#flash: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash.vme
#	${PROGRAMMERC} $<

# example another project
#%.svf : %.jed
#	LANG=C ddtcmd -oft -svfsingle -op "FLASH Erase,Program,Verify" -if $< -of $@
#	mv -f $@ $@.flash
#	LANG=C ddtcmd -oft -svfsingle -revd -op "SRAM Fast Program" -if $< -of $@
#	mv -f $@ $@.sram
#	./svf_to_urjtag.pl <$@.flash | sed 's/,/./g' > $@

clean:
	rm -rf $(JUNK) *~
