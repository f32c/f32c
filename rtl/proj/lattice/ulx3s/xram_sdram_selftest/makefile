# ******* project, board and chip name *******
PROJECT = f32c_selftest_2ws_89mhz
# board: ulx3s_v20 ulx3s_v17p
BOARD = ulx3s_v20
# fpga size: 12 25 45 85
FPGA_SIZE = 12
FPGA_PACKAGE = 6bg381c
# config flash: 1:SPI (standard), 4:QSPI (quad)
FLASH_SPI = 4
# chip: is25lp032d is25lp128f s25fl164k
FLASH_CHIP = is25lp128f

# ******* design files *******
# current boards like v2.1.2 and v3.0.3
# default constraints, should be good for all
#CONSTRAINTS = ../../constraints/ulx3s_v20.lpf
# special for self-test
CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_selftest.lpf
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_selftest_extgpdi.lpf
# special for single-ended single-data-rate digital video
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_segpdi.lpf
# first ULX3S prototypes v1.7 boards with patched ESP32 connection
#CONSTRAINTS = ../../constraints/ulx3s_v17patch.lpf
# special for self-test
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v17patch_selftest.lpf

# usually all toplevels have the same top module name
TOP_MODULE = ulx3s_xram_sdram_vector

# various toplevels for building different f32c soc's
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_lcd35.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_433.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_synth.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_tv.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_usbserial.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_axi.vhd
TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_selftest_extgpdi.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_433.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_synth.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_text.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_text_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_tv.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_85f_xram_acram_emu_vector_segpdi.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_85f_xram_acram_emu_vector.vhd

#CLK0_NAME = clk_25_100_100s_v
CLK0_NAME = clk_25_125_89_89s_48_v
CLK0_FILE_NAME = ../../../../lattice/ulx3s/clocks/$(CLK0_NAME).v
# for new ecppll: to override above, rename CLK0_OPTIONS_NEW -> CLK0_OPTIONS
CLK0_OPTIONS = \
  --module=$(CLK0_NAME) \
  --clkin=25 \
  --clkout0=125 \
  --clkout1=89 \
  --clkout2=89 \
  --phase2=180 \
  --clkout3=48

CLK1_NAME = clk_25_125_104_104s_48_v
CLK1_FILE_NAME = ../../../../lattice/ulx3s/clocks/$(CLK1_NAME).v
# for new ecppll: to override above, rename CLK0_OPTIONS_NEW -> CLK0_OPTIONS
CLK1_OPTIONS = \
  --module=$(CLK1_NAME) \
  --clkin=25 \
  --clkout0=125 \
  --clkout1=104 \
  --clkout2=104 \
  --phase2=180 \
  --clkout3=48

CLK2_NAME = clk_25_250_100_100s_v
CLK2_FILE_NAME = ../../../../lattice/ulx3s/clocks/$(CLK2_NAME).v
# for new ecppll: to override above, rename CLK0_OPTIONS_NEW -> CLK0_OPTIONS
CLK2_OPTIONS = \
  --module=$(CLK2_NAME) \
  --clkin=25 \
  --clkout0=250 \
  --clkout1=100 \
  --clkout2=100 \
  --phase2=180 \

include ../universal_make/files.mk

BITSTREAM_ = \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).bit \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).vme \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT).svf \
$(BOARD)_$(FPGA_SIZE)f_$(PROJECT)_flash_$(FLASH_CHIP).vme

# BITSTREAM = project/project_project.bit

SCRIPTS = ../../include/scripts
#include $(SCRIPTS)/ulx3s_diamond.mk
include $(SCRIPTS)/trellis_path.mk
# include $(SCRIPTS)/trellis_main.mk
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/diamond_main.mk
