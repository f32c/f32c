# The top level module should define the variables below then include
# this file.  The files listed should be in the same directory as the
# Makefile.  
#
#   variable	description
#   ----------  -------------
#   project	project name (top level module should match this name)
#   top_module  top level module of the project
#   libdir	path to library directory
#   libs	library modules used
#   vfiles	all local .v files
#   xilinx_cores  all local .xco files
#   vendor      vendor of FPGA (xilinx, altera, etc.)
#   family      FPGA device family (spartan3e) 
#   part        FPGA part name (xc4vfx12-10-sf363)
#   flashsize   size of flash for mcs file (16384) in kilobytes
#   optfile     (optional) xst extra opttions file to put in .scr
#   map_opts    (optional) options to give to map
#   par_opts    (optional) options to give to par
#   intstyle    (optional) intstyle option to all tools
#
#   files 		description
#   ----------  	------------
#   $(project).ucf	ucf file
#
# Library modules should have a modules.mk in their root directory,
# namely $(libdir)/<libname>/module.mk, that simply adds to the vfiles
# and xilinx_cores variable.
#
# all the .xco files listed in xilinx_cores will be generated with core, with
# the resulting .v and .ngc files placed back in the same directory as
# the .xco file.
#
# TODO: .xco files are device dependant, should use a template based system

coregen_work_dir ?= ./coregen-tmp
map_opts ?= -timing -ol high -detail -pr b -register_duplication -w
par_opts ?= -ol high
isedir ?= /opt/Xilinx/11.1/ISE
xil_env ?= . $(isedir)/settings32.sh
flashsize ?= 8192

libmks = $(patsubst %,$(libdir)/%/module.mk,$(libs)) 
mkfiles = Makefile $(libmks) xilinx.mk
include $(libmks)

corengcs = $(foreach core,$(xilinx_cores),$(core:.xco=.ngc))
local_corengcs = $(foreach ngc,$(corengcs),$(notdir $(ngc)))
vfiles += $(foreach core,$(xilinx_cores),$(core:.xco=.v))
junk += $(local_corengcs)

.PHONY: default xilinx_cores clean twr etwr
default: $(project).bit $(project).mcs $(project).svf $(project).xsvf
xilinx_cores: $(corengcs)
twr: $(project).twr
etwr: $(project)_err.twr

define cp_template
$(2): $(1)
	cp $(1) $(2)
endef
$(foreach ngc,$(corengcs),$(eval $(call cp_template,$(ngc),$(notdir $(ngc)))))

%.ngc %.v: %.xco
	@echo "=== rebuilding $@"
	if [ -d $(coregen_work_dir) ]; then \
		rm -rf $(coregen_work_dir)/*; \
	else \
		mkdir -p $(coregen_work_dir); \
	fi
	cd $(coregen_work_dir); \
	$(xil_env); \
	coregen -b $$OLDPWD/$<; \
	cd -
	xcodir=`dirname $<`; \
	basename=`basename $< .xco`; \
	if [ ! -r $(coregen_work_dir/$$basename.ngc) ]; then \
		echo "'$@' wasn't created."; \
		exit 1; \
	else \
		cp $(coregen_work_dir)/$$basename.v $(coregen_work_dir)/$$basename.ngc $$xcodir; \
	fi
junk += $(coregen_work_dir)

date = $(shell date +%F-%H-%M)

# some common junk
junk += *.xrpt

$(project).svf: $(project).bit
	cp $< default.bit
	$(xil_env); impact -batch bit2svf.ut
	mv default.svf $@
	rm default.bit

$(project)_flash.svf: $(project).mcs
	cp $< default.mcs
	cp $(project).cfi default.cfi
	$(xil_env); impact -batch mcs2svf.ut
	mv default.svf $@
	rm default.mcs default.cfi
junk += $(project)_flash.svf

$(project).xsvf: $(project).bit
	cp $< default.bit
	$(xil_env); impact -batch bit2xsvf.ut
	mv default.xsvf $@
	rm default.bit

programming_files: $(project).bit $(project).mcs $(project).svf $(project).xsvf
	mkdir -p $@/$(date)
	mkdir -p $@/latest
	for x in .svf .bit .mcs; do cp $(project)$$x $@/$(date)/$(project)$$x; cp $(project)$$x $@/latest/$(project)$$x; done
	$(xil_env); xst -help | head -1 | sed 's/^/#/' | cat - $(project).scr > $@/$(date)/$(project).scr

program: $(project).svf
	openocd --file=interface/altera-usb-blaster.cfg --file=$(project).ocd

flash: $(project)_flash.svf
	openocd --file=interface/altera-usb-blaster.cfg --file=$(project)_flash.ocd

$(project).mcs: $(project).bit
	$(xil_env); \
	promgen -spi -w -s $(flashsize) -p mcs -o $@ -u 0 $^
junk += $(project).mcs $(project).cfi $(project).prm

$(project).bit: $(project)_par.ncd
	$(xil_env); \
	bitgen $(intstyle) -g DriveDone:yes -g StartupClk:Cclk -w $(project)_par.ncd $(project).bit
junk += $(project).bgn $(project).bit $(project).drc $(project)_bd.bmm


$(project)_par.ncd: $(project).ncd
	$(xil_env); \
	if par $(intstyle) $(par_opts) -w $(project).ncd $(project)_par.ncd; then \
		:; \
	else \
		$(MAKE) etwr; \
	fi 
junk += $(project)_par.ncd $(project)_par.par $(project)_par.pad 
junk += $(project)_par_pad.csv $(project)_par_pad.txt 
junk += $(project)_par.grf $(project)_par.ptwx
junk += $(project)_par.unroutes $(project)_par.xpi

$(project).ncd: $(project).ngd
	if [ -r $(project)_par.ncd ]; then \
		cp $(project)_par.ncd smartguide.ncd; \
		smartguide="-smartguide smartguide.ncd"; \
	else \
		smartguide=""; \
	fi; \
	$(xil_env); \
	map $(intstyle) $(map_opts) $$smartguide $<
junk += $(project).ncd $(project).pcf $(project).ngm $(project).mrp $(project).map
junk += smartguide.ncd $(project).psr 
junk += $(project)_summary.xml $(project)_usage.xml

$(project).ngd: $(project).ngc $(project).ucf $(project).bmm
	$(xil_env); ngdbuild $(intstyle) $(project).ngc -bm $(project).bmm
junk += $(project).ngd $(project).bld

$(project).ngc: $(vfiles) $(vhdfiles) $(local_corengcs) $(project).scr $(project).prj
	$(xil_env); xst $(intstyle) -ifn $(project).scr
junk += xlnx_auto* $(top_module).lso $(project).srp 
junk += netlist.lst xst $(project).ngc

$(project).prj: $(vfiles) $(vhdfiles) $(mkfiles)
	for src in $(vfiles); do echo "verilog work $$src" >> $(project).tmpprj; done
	for src in $(vhdfiles); do echo "vhdl work $$src" >> $(project).tmpprj; done
	sort -u $(project).tmpprj > $(project).prj
	rm -f $(project).tmpprj
junk += $(project).prj

optfile += $(wildcard $(project).opt)
top_module ?= $(project)
$(project).scr: $(optfile) $(mkfiles) ./xilinx.opt
	echo "run" > $@
	echo "-p $(part)" >> $@
	echo "-top $(top_module)" >> $@
	echo "-ifn $(project).prj" >> $@
	echo "-ofn $(project).ngc" >> $@
	cat ./xilinx.opt $(optfile) >> $@
junk += $(project).scr

$(project).post_map.twr: $(project).ncd
	$(xil_env); trce -e 10 $< $(project).pcf -o $@
junk += $(project).post_map.twr $(project).post_map.twx smartpreview.twr

$(project).twr: $(project)_par.ncd
	$(xil_env); trce $< $(project).pcf -o $(project).twr
junk += $(project).twr $(project).twx smartpreview.twr

$(project)_err.twr: $(project)_par.ncd
	$(xil_env); trce -e 10 $< $(project).pcf -o $(project)_err.twr
junk += $(project)_err.twr $(project)_err.twx

.gitignore: $(mkfiles)
	echo programming_files $(junk) | sed 's, ,\n,g' > .gitignore

clean::
	rm -rf $(junk)
