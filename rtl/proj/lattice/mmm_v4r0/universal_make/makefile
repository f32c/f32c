# ******* project, board and chip name *******
PROJECT = f32c
BOARD = mmm
FPGA_SIZE = 85
FPGA_PACKAGE = 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 4
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP = is25lp128f

# ******* design files *******
CONSTRAINTS = ../../constraints/DM1228-L5SD-V3r0.lpf

# usually all toplevels have the same top module name
TOP_MODULE = mmm_v4r0_xram_sdram_vector

# various toplevels for building different f32c soc's
TOP_MODULE_FILE = ../../../../lattice/mmm_v4r0/top/top_mmm_v4r0_xram_sdram_vector.vhd

BITSTREAM = \
 $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
 $(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf

include files.mk

SCRIPTS = ../../include/scripts
include $(SCRIPTS)/ulx3s_diamond.mk


