# ******* project, board and chip name *******
PROJECT = f32c
BOARD = ulx3s
FPGA_SIZE = 12
FPGA_PACKAGE = 6bg381c
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
CONSTRAINTS = ../../constraints/ulx3s_v20.lpf
# special for self-test
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_selftest.lpf
# special for single-ended single-data-rate digital video
#CONSTRAINTS = ../../constraints/ulx3s_options/ulx3s_v20_segpdi.lpf

# usually all toplevels have the same top module name
TOP_MODULE = ulx3s_xram_sdram_vector

# various toplevels for building different f32c soc's
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_flash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_lcd35.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_noflash.vhd
TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_433.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_synth.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_tv.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_usbserial.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_axi.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_12f_xram_sdram_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector_flash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_25f_xram_sdram_vector_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_433.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_synth.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_text_flash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_text.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_tv.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector_flash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector_noflash.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_45f_xram_sdram_vector_selftest.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_85f_xram_acram_emu_vector_segpdi.vhd
#TOP_MODULE_FILE = ../../../../lattice/ulx3s/top/top_ulx3s_85f_xram_acram_emu_vector.vhd

VHDL_FILES = $(TOP_MODULE_FILE) \
  ../../../../lattice/ulx3s/clocks/clk_25_78_125_25.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_100_125_25.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_250_25_83.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_25_48_89.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_125_25_48_104.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25M_112M5_93M75.vhd \
  ../../../../lattice/ulx3s/clocks/clk_112M5_433M92.vhd \
  ../../../../lattice/ulx3s/clocks/clk_25_287M5_19M16_6M38_95M83.vhd \
  ../../../../lattice/chip/ecp5u/ecp5_flash_clk.vhd \
  ../../../../generic/glue_xram_vector.vhd \
  ../../../../generic/bootloader/defs_bootblock.vhd \
  ../../../../generic/bootloader/boot_sio_rv32el.vhd \
  ../../../../generic/bootloader/boot_sio_mi32el.vhd \
  ../../../../generic/bootloader/boot_sio_mi32eb.vhd \
  ../../../../generic/bootloader/boot_rom_mi32el.vhd \
  ../../../../generic/bootloader/boot_preloader.vhd \
  ../../../../generic/bootloader/bootrom_emu.vhd \
  ../../../../generic/bram.vhd \
  ../../../../generic/bram_true2p_1clk.vhd \
  ../../../../generic/bram_true2p_2clk.vhd \
  ../../../../generic/bptrace.vhd \
  ../../../../generic/reg1w2r.vhd \
  ../../../../cpu/alu.vhd \
  ../../../../cpu/debug.vhd \
  ../../../../cpu/defs_f32c.vhd \
  ../../../../cpu/defs_mi32.vhd \
  ../../../../cpu/defs_rv32.vhd \
  ../../../../cpu/idecode_mi32.vhd \
  ../../../../cpu/idecode_rv32.vhd \
  ../../../../cpu/loadalign.vhd \
  ../../../../cpu/cache.vhd \
  ../../../../cpu/pipeline.vhd \
  ../../../../cpu/shift.vhd \
  ../../../../cpu/mul_iter.vhd \
  ../../../../soc/synth.vhd \
  ../../../../soc/sigmadelta.vhd \
  ../../../../soc/spdif_tx.vhd \
  ../../../../soc/pcm.vhd \
  ../../../../soc/sio.vhd \
  ../../../../soc/usb_serial/usbsio.vhd \
  ../../../../soc/usb_serial/usb_serial.vhd \
  ../../../../soc/usb_serial/usb_init.vhd \
  ../../../../soc/usb_serial/usb_packet.vhd \
  ../../../../soc/usb_serial/usb_control.vhd \
  ../../../../soc/usb_serial/usb_transact.vhd \
  ../../../../soc/usb11_phy/usb_phy.vhd \
  ../../../../soc/usb11_phy/usb_tx_phy.vhd \
  ../../../../soc/usb11_phy/usb_rx_phy_48MHz.vhd \
  ../../../../soc/gpio.vhd \
  ../../../../soc/timer.vhd \
  ../../../../soc/spi.vhd \
  ../../../../soc/pid/ctrlpid.vhd \
  ../../../../soc/pid/pid.vhd  \
  ../../../../soc/pid/rotary_decoder.vhd \
  ../../../../soc/pid/simotor.vhd \
  ../../../../soc/sram_pack.vhd \
  ../../../../soc/sram.vhd \
  ../../../../soc/sram_refresh.vhd \
  ../../../../soc/sram8.vhd \
  ../../../../soc/sdram.vhd \
  ../../../../soc/sdram32.vhd \
  ../../../../soc/acram.vhd \
  ../../../../generic/acram_emu.vhd \
  ../../../../soc/axi_pack.vhd \
  ../../../../soc/axiram.vhd \
  ../../../../soc/axi_read.vhd \
  ../../../../soc/vgahdmi/vga.vhd \
  ../../../../soc/vgahdmi/tv.vhd \
  ../../../../soc/vgahdmi/video_mode_pack.vhd \
  ../../../../soc/cvbs.vhd \
  ../../../../soc/vgahdmi/VGA_textmode.vhd \
  ../../../../soc/vgahdmi/videofifo.vhd \
  ../../../../soc/vgahdmi/video_cache_i.vhd \
  ../../../../soc/vgahdmi/video_cache_d.vhd \
  ../../../../soc/vgahdmi/compositing2_fifo.vhd \
  ../../../../soc/vgahdmi/ws2812b.vhd \
  ../../../../soc/vgahdmi/pulse_counter.vhd \
  ../../../../soc/vgahdmi/ledstrip.vhd \
  ../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
  ../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
  ../../../../soc/vgahdmi/font_block_pack.vhd \
  ../../../../soc/vgahdmi/font8x8_xark.vhd \
  ../../../../soc/vgahdmi/font8x16_xark.vhd \
  ../../../../soc/vgahdmi/TMDS_encoder.vhd \
  ../../../../soc/vgahdmi/vga2dvid.vhd \
  ../../../../soc/vgahdmi/vga2lcd.vhd \
  ../../../../soc/vgahdmi/vga2lcd35.vhd \
  ../../../../soc/simple_ADC.vhd \
  ../../../../soc/fm/fm.vhd \
  ../../../../soc/fm/rds.vhd \
  ../../../../soc/fm/lowpass.vhd \
  ../../../../soc/fm/fmgen.vhd \
  ../../../../soc/fm/bram_rds.vhd \
  ../../../../soc/fm/message.vhd \
  ../../../../soc/vector/vector.vhd \
  ../../../../soc/vector/f32c_vector_dma.vhd \
  ../../../../soc/vector/axi_vector_dma.vhd \
  ../../../../soc/vector/fpu/add_sub_emiraga/add_sub_emiraga.vhd \
  ../../../../soc/vector/fpu/mul/multiplier/fpmul_pipeline.vhd \
  ../../../../soc/vector/fpu/mul/multiplier/fpmul_stage1_struct.vhd \
  ../../../../soc/vector/fpu/mul/multiplier/fpmul_stage2_struct.vhd \
  ../../../../soc/vector/fpu/mul/multiplier/fpmul_stage3_struct.vhd \
  ../../../../soc/vector/fpu/mul/multiplier/fpmul_stage4_struct.vhd \
  ../../../../soc/vector/fpu/mul/common/fpnormalize_fpnormalize.vhd \
  ../../../../soc/vector/fpu/mul/common/fpround_fpround.vhd \
  ../../../../soc/vector/fpu/mul/common/packfp_packfp.vhd \
  ../../../../soc/vector/fpu/mul/common/unpackfp_unpackfp.vhd \
  ../../../../soc/vector/fpu/float_divide_goldschmidt.vhd

#  ../../../../soc/ps2.vhd \
    
VERILOG_FILES = \
  ../../../../soc/pid/ctrlpid_v.v \
  ../../../../soc/pid/simotor_v.v \
  ../../../../soc/pid/rotary_decoder_v.v \
  ../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee_adder.v \
  ../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee.v \

SCRIPTS = ../../include/scripts
include $(SCRIPTS)/ulx3s_diamond.mk
