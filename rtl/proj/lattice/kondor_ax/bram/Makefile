
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)
DDTCMD := $(shell find ${DIAMOND_BIN}/ -name ddtcmd)
OPENOCD_BASE := ../../programmer/openocd/kondor_ax/

XCF_FILE := $(IMPL_DIR)/$(PROJ_NAME).xcf
OCD_FILE := $(IMPL_DIR)/$(PROJ_NAME).ocd

all:
	@rm -rf ${IMPL_DIR}
	@echo prj_project open ${PROJ_FILE} \; prj_run PAR -task PARTrace \; prj_run Export -task Bitgen | ${DIAMONDC}
	@fgrep Warning: ${IMPL_DIR}/*.twr

clean:
	rm -rf ${IMPL_DIR} *~

$(IMPL_DIR)/$(PROJ_NAME)_$(IMPL_NAME).svf:
	sed s/XXXFIXMEXXX/$(IMPL_DIR)\\/$(PROJ_NAME)_$(IMPL_NAME)/ $(PROJ_NAME).xcf > $(XCF_FILE)
	${DDTCMD} -oft -svfsingle -revd -if $(XCF_FILE) -of $@

prog: $(IMPL_DIR)/$(PROJ_NAME)_$(IMPL_NAME).svf
	sed s/XXXFIXMEXXX/$(IMPL_DIR)\\/$(PROJ_NAME)_$(IMPL_NAME)/ $(PROJ_NAME).ocd > $(OCD_FILE)
	sudo openocd --file=$(OPENOCD_BASE)/ft2232-kondor-ax.ocd --file=$(OCD_FILE)

