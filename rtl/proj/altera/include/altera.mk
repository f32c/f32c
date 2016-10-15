###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT ?= project
TOP_LEVEL_ENTITY ?= glue
ASSIGNMENT_FILES ?= $(PROJECT).qpf $(PROJECT).qsf

###################################################################
# Part, Family, Boardfile
FAMILY ?= "Cyclone IV E"
PART ?= EP4CE6E22C8
BOARDFILE ?= tb276.board
CONFIG_DEVICE ?= EPCS4
SERIAL_FLASH_LOADER_DEVICE ?= EP4CE6
OPENOCD_INTERFACE ?= =interface/altera-usb-blaster.cfg
OPENOCD_BOARD ?= tb276.ocd
###################################################################

###################################################################
# Setup your sources here
SRCS ?= glue.vhd

###################################################################
#
# Quartus shell environment vars
#
###################################################################

quartus_env ?= . ./quartus_env.sh

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all: $(PROJECT).sof $(PROJECT).svf $(PROJECT).jic

clean:
	rm -rf *~ $(PROJECT).jdi $(PROJECT).jic $(PROJECT).pin $(PROJECT).qws \
	       *.rpt *.chg smart.log *.htm *.eqn *.sof *.svf *.pof *.smsg *.summary \
	       PLL*INFO.txt \
	       db incremental_db output_files greybox_tmp \
	       $(ASSIGNMENT_FILES)

map: smart.log $(PROJECT).map.rpt
fit: smart.log $(PROJECT).fit.rpt
asm: smart.log $(PROJECT).asm.rpt
sta: smart.log $(PROJECT).sta.rpt
smart: smart.log

###################################################################
# Executable Configuration
###################################################################

MAP_ARGS = --read_settings_files=on --enable_register_retiming=on $(addprefix --source=,$(SRCS))
FIT_ARGS = --part=$(PART) --read_settings_files=on --effort=standard --optimize_io_register_for_timing=on --one_fit_attempt=off --pack_register=auto
ASM_ARGS = 
STA_ARGS = 

###################################################################
# Target implementations
###################################################################

STAMP = echo done >

$(PROJECT).map.rpt: map.chg $(SOURCE_FILES) 
	$(quartus_env); quartus_map $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

$(PROJECT).fit.rpt: fit.chg $(PROJECT).map.rpt
	$(quartus_env); quartus_fit $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).asm.rpt: asm.chg $(PROJECT).fit.rpt
	$(quartus_env); quartus_asm $(ASM_ARGS) $(PROJECT)

$(PROJECT).sta.rpt: sta.chg $(PROJECT).fit.rpt
	$(quartus_env); quartus_sta $(STA_ARGS) $(PROJECT) 

smart.log: $(ASSIGNMENT_FILES)
	$(quartus_env); quartus_sh --determine_smart_action $(PROJECT) > smart.log
	
$(PROJECT).sof: map fit asm sta smart

$(PROJECT).jic: $(PROJECT).sof
	$(quartus_env); quartus_cpf -c -d $(CONFIG_DEVICE) -s $(SERIAL_FLASH_LOADER_DEVICE) $(PROJECT).sof $(PROJECT).jic

$(PROJECT).svf: $(PROJECT).sof
	$(quartus_env); quartus_cpf -c -q 1MHz -g 3.3 -n p $(PROJECT).sof $(PROJECT).svf

# http://dangerousprototypes.com/docs/JTAG_SVF_to_XSVF_file_converter
# executable svf2xsvf502 is in zip file under old subdirectory:
# http://www.xilinx.com/support/documentation/application_notes/xapp058.zip
$(PROJECT).xsvf: $(PROJECT).svf
	svf2xsvf502 -i $(PROJECT).svf -o $(PROJECT).xsvf

###################################################################
# Project initialization
###################################################################

$(ASSIGNMENT_FILES):
	$(quartus_env); quartus_sh --prepare -f $(FAMILY) -t $(TOP_LEVEL_ENTITY) $(PROJECT)
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
	$(quartus_env); quartus_pgm --no_banner --mode=jtag -o "P;$(PROJECT).sof"

program_ocd: $(PROJECT).svf
	openocd --file=$(OPENOCD_INTERFACE) --file=$(OPENOCD_BOARD)

flash: $(PROJECT).jic
	$(quartus_env); quartus_pgm --no_banner --mode=jtag -o "IP;$(PROJECT).jic"
	echo "Power cycle or Reset device to run"

# bitstream normally works but verify dumps some error (CRC)
#	$(quartus_env); quartus_pgm --no_banner --mode=jtag -o "IPV;$(PROJECT).jic"
