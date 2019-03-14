# ******* project, board and chip name *******
PROJECT = f32c_pix8bpp640x480_100mhz
#PROJECT = f32c_pix8bpp640x480ws2_100mhz
#PROJECT = f32c_pix16bpp640x480ws2uc_100mhz
BOARD = fleafpga_ohm
# 12/25/45/85
FPGA_SIZE = 25
FPGA_PACKAGE = 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 1
# chip: w25q80 is25lp032d is25lp128f s25fl164k
FLASH_CHIP = w25q80

# ******* design files *******
# default constraints, should be good for all
CONSTRAINTS = ../../constraints/FleaFPGA_Ohm_A5.lpf

# usually all toplevels have the same top module name
TOP_MODULE = fleafpga_ohm_xram_sdram_vector

# various toplevels for building different f32c soc's
TOP_MODULE_FILE = ../../../../lattice/fleafpga_ohm_a5/top/top_fleafpga_ohm_a5_25f_xram_sdram_vector.vhd

include ../universal_make/files.mk

BITSTREAM = \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme

SCRIPTS = ../../include/scripts
include $(SCRIPTS)/ulx3s_diamond.mk
