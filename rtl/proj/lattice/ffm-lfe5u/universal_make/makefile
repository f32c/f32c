# ******* project, board and chip name *******
PROJECT = f32c
BOARD = ffm
FPGA_SIZE = 85
FPGA_PACKAGE = 6bg554c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 4
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP = is25lp128f

# ******* design files *******
# first ULX3S prototypes v1.7 boards with patched ESP32 connection
#CONSTRAINTS = ../../constraints/ulx3s_v17patch.lpf
# special for self-test
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v17patch_selftest.lpf
# current boards like v2.1.2 and v3.0.3
# default constraints, should be good for all
CONSTRAINTS = ../../constraints/FFM-LFE5U-V0r0_mit_FFC-CA7-V2r0.lpf
# special for self-test
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_selftest.lpf
# special for single-ended single-data-rate digital video
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_segpdi.lpf

# usually all toplevels have the same top module name
TOP_MODULE = ffm_lfe5u_xram_sdram_vector

# various toplevels for building different f32c soc's
TOP_MODULE_FILE = ../../../../lattice/ffm_lfe5u/top/top_ffm_lfe5u_xram_sdram_vector.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_85f_xram_acram_emu_vector.vhd

BITSTREAM = \
 $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
 $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf

include files.mk

SCRIPTS = ../../include/scripts
include $(SCRIPTS)/ulx3s_diamond.mk


