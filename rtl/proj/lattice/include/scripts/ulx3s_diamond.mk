# ******* project, board and chip name *******
PROJECT ?= project
BOARD ?= board
FPGA_SIZE ?= 12
FPGA_CHIP ?= lfe5u-$(FPGA_SIZE)f
FPGA_PACKAGE ?= 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI ?= 1
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP ?= is25lp032d

# ******* design files *******
CONSTRAINTS ?= board_constraints.lpf
TOP_MODULE ?= top
TOP_MODULE_FILE ?= $(TOP_MODULE).v
VERILOG_FILES ?= $(TOP_MODULE_FILE)
VHDL_FILES ?=

# ******* tools installation paths *******
# https://github.com/ldoolitt/vhd2vl
VHDL2VL ?= /mt/scratch/tmp/openfpga/vhd2vl/src/vhd2vl
# https://github.com/YosysHQ/yosys
YOSYS ?= /mt/scratch/tmp/openfpga/yosys/yosys
# https://github.com/YosysHQ/nextpnr
NEXTPNR-ECP5 ?= /mt/scratch/tmp/openfpga/nextpnr/nextpnr-ecp5
# https://github.com/SymbiFlow/prjtrellis
TRELLIS ?= /mt/scratch/tmp/openfpga/prjtrellis

ifeq ($(FPGA_CHIP), lfe5u-12f)
  CHIP_ID=0x21111043
  MASK_FILE=LFE5U-45F.msk
endif
ifeq ($(FPGA_CHIP), lfe5u-25f)
  CHIP_ID=0x41111043
  MASK_FILE=LFE5U-45F.msk
endif
ifeq ($(FPGA_CHIP), lfe5u-45f)
  CHIP_ID=0x41112043
  MASK_FILE=LFE5U-45F.msk
endif
ifeq ($(FPGA_CHIP), lfe5u-85f)
  CHIP_ID=0x41113043
  MASK_FILE=LFE5U-85F.msk
endif

ifeq ($(FPGA_SIZE), 12)
  FPGA_K=25
  IDCODE_CHIPID=--idcode $(CHIP_ID)
else
  FPGA_K=$(FPGA_SIZE)
  IDCODE_CHIPID=
endif

FPGA_CHIP_EQUIVALENT ?= lfe5u-$(FPGA_K)f

# open source synthesis tools
ECPPACK ?= $(TRELLIS)/libtrellis/ecppack
TRELLISDB ?= $(TRELLIS)/database
LIBTRELLIS ?= $(TRELLIS)/libtrellis
BIT2SVF ?= $(TRELLIS)/tools/bit_to_svf.py
BASECFG ?= $(TRELLIS)/misc/basecfgs/empty_$(FPGA_CHIP_EQUIVALENT).config
# ypsys options, sometimes those can be used: -noccu2 -nomux -nodram
YOSYS_OPTIONS ?= 

# closed source synthesis tools
DIAMOND_BASE := /usr/local/diamond
ifneq ($(wildcard $(DIAMOND_BASE)),)
  DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
  DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)
  DDTCMD := $(shell find ${DIAMOND_BIN}/ -name ddtcmd)
  MASK_PATH := $(shell find ${DIAMOND_BASE}/ -maxdepth 5 -name xpga -type d)/ecp5
endif

#PROJ_FILE := $(shell ls *.ldf | head -1)
#PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
#IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
#IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

# programming tools
TINYFPGASP ?= tinyfpgasp
FLEAFPGA_JTAG ?= FleaFPGA-JTAG 
OPENOCD ?= openocd_ft232r
UJPROG ?= ujprog

# helper scripts directory
SCRIPTS ?= scripts

# rest of the include makefile
FPGA_CHIP_UPPERCASE := $(shell echo $(FPGA_CHIP) | tr '[:lower:]' '[:upper:]')
FPGA_PACKAGE_UPPERCASE := $(shell echo $(FPGA_PACKAGE) | tr '[:lower:]' '[:upper:]')

#all: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf
# all: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf
#all: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
all: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit

# VHDL to VERILOG conversion
%.v: %.vhd
	$(VHDL2VL) $< $@

#*.v: *.vhdl
#	$(VHDL2VL) $< $@

#$(PROJECT).ys: makefile
#	$(SCRIPTS)/ysgen.sh $(VERILOG_FILES) $(VHDL_TO_VERILOG_FILES) > $@
#	echo "hierarchy -top ${TOP_MODULE}" >> $@
#	echo "synth_ecp5 -noccu2 -nomux -nodram -json ${PROJECT}.json" >> $@

#$(PROJECT).json: $(PROJECT).ys $(VERILOG_FILES) $(VHDL_TO_VERILOG_FILES)
#	$(YOSYS) $(PROJECT).ys

$(PROJECT).json: $(VERILOG_FILES) $(VHDL_TO_VERILOG_FILES)
	$(YOSYS) \
	-p "hierarchy -top ${TOP_MODULE}" \
	-p "synth_ecp5 ${YOSYS_OPTIONS} -json ${PROJECT}.json" \
	$(VERILOG_FILES) $(VHDL_TO_VERILOG_FILES)

$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).config: $(PROJECT).json $(BASECFG)
	$(NEXTPNR-ECP5) --$(FPGA_K)k --json $(PROJECT).json --lpf $(CONSTRAINTS) --basecfg $(BASECFG) --textcfg $@

#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).config
#	LANG=C LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) $(IDCODE_CHIPID) --db $(TRELLISDB) --input $< --bit $@

# generate LDF project file for diamond
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).ldf: $(SCRIPTS)/project.ldf $(SCRIPTS)/ldf.xsl
	xsltproc \
	  --stringparam FPGA_DEVICE $(FPGA_CHIP_UPPERCASE)-$(FPGA_PACKAGE_UPPERCASE) \
	  --stringparam CONSTRAINTS_FILE $(CONSTRAINTS) \
	  --stringparam TOP_MODULE $(TOP_MODULE) \
	  --stringparam TOP_MODULE_FILE $(TOP_MODULE_FILE) \
	  --stringparam VHDL_FILES "$(VHDL_FILES)" \
	  --stringparam VERILOG_FILES "$(VERILOG_FILES)" \
	  $(SCRIPTS)/ldf.xsl $(SCRIPTS)/project.ldf > $@

project/project_project.bit: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).ldf
	echo prj_project open $< \; prj_run Export -task Bitgen | ${DIAMONDC}

$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit: project/project_project.bit
	ln -sf project/project_project.bit $@

# generate sram programming XCF file for DDTCMD
$(BOARD)_$(FPGA_SIZE)f.xcf: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit $(SCRIPTS)/$(BOARD)_sram.xcf $(SCRIPTS)/xcf.xsl
	xsltproc \
	  --stringparam FPGA_CHIP $(FPGA_CHIP_UPPERCASE) \
	  --stringparam CHIP_ID $(CHIP_ID) \
	  --stringparam BITSTREAM_FILE $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
	  $(SCRIPTS)/xcf.xsl $(SCRIPTS)/$(BOARD)_sram.xcf > $@

# run DDTCMD to generate sram VME file
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme: $(BOARD)_$(FPGA_SIZE)f.xcf $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	LANG=C ${DDTCMD} -oft -fullvme -if $(BOARD)_$(FPGA_SIZE)f.xcf -nocompress -noheader -of $@

# run DDTCMD to generate SVF file
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf: $(BOARD)_$(FPGA_SIZE)f.xcf $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if $(BOARD)_$(FPGA_SIZE)f.xcf -of $@

# run DDTCMD to generate flash MCS file
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash.mcs: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	LANG=C ${DDTCMD} -dev $(FPGA_CHIP_UPPERCASE) \
	-if $< -oft -int -quad $(FPGA_SPI) -of $@

# generate flash programming XCF file for DDTCMD
$(BOARD)_$(FPGA_SIZE)f_flash_$(FLASH_CHIP).xcf: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit $(SCRIPTS)/$(BOARD)_flash_$(FLASH_CHIP).xcf $(SCRIPTS)/xcf.xsl
	xsltproc \
	  --stringparam FPGA_CHIP $(FPGA_CHIP_UPPERCASE) \
	  --stringparam CHIP_ID $(CHIP_ID) \
	  --stringparam MASK_FILE $(MASK_PATH)/$(MASK_FILE) \
	  --stringparam BITSTREAM_FILE $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash.mcs \
	  $(SCRIPTS)/xcf.xsl $(SCRIPTS)/$(BOARD)_flash_$(FLASH_CHIP).xcf > $@

# run DDTCMD to generate flash VME file
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme: ulx3s_25f_flash_$(FLASH_CHIP).xcf $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash.mcs
	LANG=C ${DDTCMD} -oft -fullvme -if $(BOARD)_$(FPGA_SIZE)f_flash_$(FLASH_CHIP).xcf -nocompress -noheader -of $@

# generate SVF file by prjtrellis python script
#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
#	$(BIT2SVF) $< $@

#$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).config
#	LD_LIBRARY_PATH=$(LIBTRELLIS) $(ECPPACK) $(IDCODE_CHIPID) --db $(TRELLISDB) $< --freq 62.0 --svf-rowsize 8000 --svf $@

# program SRAM  with ujrprog (temporary)
program: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	$(UJPROG) $<

# program SRAM with FleaFPGA-JTAG (temporary)
program_flea: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme
	$(FLEAFPGA_JTAG) $<

# program FLASH over US1 port with ujprog (permanently)
flash: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	$(UJPROG) -j flash $<

# program FLASH uver US1 with FleaFPGA-JTAG (permanent)
flash_flea: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme
	$(FLEAFPGA_JTAG) $<

# program FLASH over US2 port with tinyfpgasp bootloader (permanently)
flash_tiny: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
	$(TINYFPGASP) -w $<

# generate chip-specific openocd programming file
$(BOARD)_$(FPGA_SIZE)f.ocd: makefile $(SCRIPTS)/ecp5-ocd.sh
	$(SCRIPTS)/ecp5-ocd.sh $(CHIP_ID) $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf > $@

# program SRAM with OPENOCD using onboard ft231y (temporary)
program_ocd: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf $(BOARD)_$(FPGA_SIZE)f.ocd
	$(OPENOCD) --file=$(SCRIPTS)/ft231x.ocd --file=$(BOARD)_$(FPGA_SIZE)f.ocd

# program SRAM with OPENOCD with jtag pass-thru to another board
program_ocd_thru: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf $(BOARD)_$(FPGA_SIZE)f.ocd
	$(OPENOCD) --file=$(SCRIPTS)/ft231x2.ocd --file=$(BOARD)_$(FPGA_SIZE)f.ocd

# program SRAM with OPENOCD with external ft232r module
program_ft232r: $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf $(BOARD)_$(FPGA_SIZE)f.ocd
	$(OPENOCD) --file=$(SCRIPTS)/ft232r.ocd --file=$(BOARD)_$(FPGA_SIZE)f.ocd

JUNK = *~
#JUNK += $(PROJECT).ys
JUNK += $(PROJECT).json
JUNK += $(VHDL_TO_VERILOG_FILES)
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).config
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).ldf
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf
JUNK += $(BOARD)_$(FPGA_SIZE)f.xcf
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash.mcs
JUNK += $(BOARD)_$(FPGA_SIZE)f_flash_$(FLASH_CHIP).xcf
JUNK += $(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme
JUNK += $(BOARD)_$(FPGA_SIZE)f.ocd
# diamond junk
JUNK += ${IMPL_DIR} .recovery ._Real_._Math_.vhd *.sty reportview.xml
JUNK += dummy_sym.sort project_tcl.html promote.xml
JUNK += generate_core.tcl generate_ngd.tcl msg_file.log
JUNK += project_tcr.dir

JUNK_DIR = project

clean:
	rm -rf $(JUNK_DIR)
	rm -f $(JUNK)
