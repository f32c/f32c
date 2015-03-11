###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = project
TOP_LEVEL_ENTITY = glue
ASSIGNMENT_FILES = $(PROJECT).qpf $(PROJECT).qsf

###################################################################
# Part, Family, Boardfile
FAMILY = "Cyclone IV E"
PART = EP4CE22F17C6
BOARDFILE = de0.board
CONFIG_DEVICE = EPCS64
SERIAL_FLASH_LOADER_DEVICE = EP4CE6
###################################################################

###################################################################
# Setup your sources here
SRCS = \
 ../../cpu/idecode_rv32.vhd \
 ../../cpu/idecode_mi32.vhd \
 ../../cpu/defs_rv32.vhd \
 ../../cpu/defs_mi32.vhd \
 ../../cpu/defs_f32c.vhd \
 ../../soc/sio.vhd \
 ../../altera/glue.vhd \
 ../../generic/reg1w2r.vhd \
 ../../generic/bram.vhd \
 ../../generic/bptrace.vhd \
 ../../cpu/shift.vhd \
 ../../cpu/pipeline.vhd \
 ../../cpu/loadalign.vhd \
 ../../cpu/idecode.vhd \
 ../../cpu/alu.vhd

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all: smart.log $(PROJECT).asm.rpt $(PROJECT).sta.rpt 

clean:
	rm -rf *~ *_assignment_defaults.qdf *.qws *.rpt *.chg smart.log *.htm *.eqn *.sof *.pof *.smsg *.summary db incremental_db output_files simulation $(ASSIGNMENT_FILES)

map: smart.log $(PROJECT).map.rpt
fit: smart.log $(PROJECT).fit.rpt
asm: smart.log $(PROJECT).asm.rpt
sta: smart.log $(PROJECT).sta.rpt
smart: smart.log

###################################################################
# Executable Configuration
###################################################################

MAP_ARGS = --read_settings_files=on $(addprefix --source=,$(SRCS))

FIT_ARGS = --part=$(PART) --read_settings_files=on
ASM_ARGS = 
STA_ARGS = 

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

$(PROJECT).map.rpt: map.chg $(SOURCE_FILES) 
	quartus_map $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

$(PROJECT).fit.rpt: fit.chg $(PROJECT).map.rpt
	quartus_fit $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).asm.rpt: asm.chg $(PROJECT).fit.rpt
	quartus_asm $(ASM_ARGS) $(PROJECT)

$(PROJECT).sta.rpt: sta.chg $(PROJECT).fit.rpt
	quartus_sta $(STA_ARGS) $(PROJECT) 

smart.log: $(ASSIGNMENT_FILES)
	quartus_sh --determine_smart_action $(PROJECT) > smart.log
	
$(PROJECT).sof: all

$(PROJECT).jic: $(PROJECT).sof
	quartus_cpf -c -d $(CONFIG_DEVICE) -s $(SERIAL_FLASH_LOADER_DEVICE) $(PROJECT).sof $(PROJECT).jic

###################################################################
# Project initialization
###################################################################

$(ASSIGNMENT_FILES):
	quartus_sh --prepare -f $(FAMILY) -t $(TOP_LEVEL_ENTITY) $(PROJECT)
	cat $(BOARDFILE) >> $(PROJECT).qsf
map.chg:
	$(STAMP) map.chg
fit.chg:
	$(STAMP) fit.chg
sta.chg:
	$(STAMP) sta.chg
asm.chg:
	$(STAMP) asm.chg

###################################################################
# Programming the device
###################################################################

upload: program

program: $(PROJECT).sof
	quartus_pgm --no_banner --mode=jtag -o "P;$(PROJECT).sof"

flash: $(PROJECT).jic
	quartus_pgm --no_banner --mode=jtag -o "IPV;$(PROJECT).jic"
	echo "Power cycle or Reset device to run"
