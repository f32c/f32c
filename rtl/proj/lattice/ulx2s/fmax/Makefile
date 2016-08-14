
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)


all:
	@rm -rf ${IMPL_DIR}
	@echo prj_project open ${PROJ_FILE} \; prj_run PAR -task PARTrace \; prj_run Export -task Bitgen | ${DIAMONDC}
	@fgrep Warning: ${IMPL_DIR}/*.twr

clean:
	rm -rf ${IMPL_DIR} *~

program:
	ujprog ${IMPL_DIR}/${PROJ_NAME}_${IMPL_NAME}.jed

flash:
	ujprog -j flash ${IMPL_DIR}/${PROJ_NAME}_${IMPL_NAME}.jed
