project = miniSpartan6-plus
vendor = xilinx
family = spartan6
MODEL ?= xc6slx25
part = ${MODEL}-ftg256-3 # last number -3 is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = scarab_xram_sdram_vector
isedir = /opt/Xilinx/ISE/14.7/ISE_DS
xil_env = . $(isedir)/settings64.sh
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
# openocd_interface = ../include/ft2232-fpu1.ocd
openocd_interface = ../../include/ft2232-generic.ocd
xc3sprog_interface = ftdi

vfiles = \
../../../../soc/pid/ctrlpid_v.v \
../../../../soc/pid/simotor_v.v \
../../../../soc/pid/rotary_decoder_v.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee_adder.v \
../../../../soc/vector/fpu/add_sub_emiraga/ieee754-verilog/src/ieee.v \

vhdfiles = \
../../../../xilinx/scarab_ms6p/top/top_xram_sdram_vector.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_112M5.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_100M.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_100M_25M_250M.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_81M25.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_25M_83M33_250M.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_250M_125M_25M.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_250M_111M11_25M.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_50M_96M43.vhd \
../../../../xilinx/scarab_ms6p/clocks/pll_96M43_433M9_289M3_28M93.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_100M_125Mp_125Mn_25M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_100M_150Mp_150Mn_30M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_100M_200Mp_200Mn_40M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_100M_250Mp_250Mn_50M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_97M5_325Mp_325Mn_65M.vhd \
../../../../xilinx/scarab_ms6p/clocks/clk_50M_93M75_375Mp_375Mn_75M.vhd \
../../../../xilinx/chip/xc6/hdmi_out_xc6.vhd \
../../../../xilinx/chip/xc6/ddr_out.vhd \
../../../../generic/glue_xram_vector.vhd \
../../../../generic/bram.vhd \
../../../../generic/bootloader/defs_bootblock.vhd \
../../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../../generic/bootloader/boot_rom_mi32el.vhd \
../../../../generic/bram_true2p_1clk.vhd \
../../../../generic/bram_true2p_2clk.vhd \
../../../../generic/bptrace.vhd \
../../../../cpu/alu.vhd \
../../../../cpu/loadalign.vhd \
../../../../cpu/f32c_core.vhd \
../../../../cpu/shift.vhd \
../../../../cpu/mul_iter.vhd \
../../../../cpu/defs_f32c.vhd \
../../../../cpu/defs_mi32.vhd \
../../../../cpu/defs_rv32.vhd \
../../../../cpu/idecode_mi32.vhd \
../../../../cpu/idecode_rv32.vhd \
../../../../cpu/f32c_cache.vhd \
../../../../cpu/debug.vhd \
../../../../soc/sram_pack.vhd \
../../../../soc/sram.vhd \
../../../../soc/sram_refresh.vhd \
../../../../soc/sram8.vhd \
../../../../soc/acram.vhd \
../../../../soc/axiram.vhd \
../../../../soc/axi_pack.vhd \
../../../../soc/axi_read.vhd \
../../../../soc/sdram.vhd \
../../../../soc/sdram32.vhd \
../../../../soc/sdram_pack.vhd \
../../../../soc/sdram_mz.vhd \
../../../../soc/sdram_mz_wrap.vhd \
../../../../soc/sio.vhd \
../../../../soc/spi.vhd \
../../../../soc/rtc.vhd \
../../../../soc/gpio.vhd \
../../../../soc/timer.vhd \
../../../../soc/pcm.vhd \
../../../../soc/synth.vhd \
../../../../soc/sigmadelta.vhd \
../../../../soc/spdif_tx.vhd \
../../../../soc/pid/pid.vhd \
../../../../soc/pid/ctrlpid.vhd \
../../../../soc/pid/simotor.vhd \
../../../../soc/pid/rotary_decoder.vhd \
../../../../soc/fm/fm.vhd \
../../../../soc/fm/fmgen.vhd \
../../../../soc/fm/rds.vhd \
../../../../soc/fm/lowpass.vhd \
../../../../soc/fm/bram_rds.vhd \
../../../../soc/fm/message.vhd \
../../../../soc/vector/vector.vhd \
../../../../soc/vector/f32c_vector_dma.vhd \
../../../../soc/vector/axi_vector_dma.vhd \
../../../../soc/vector/fpu/add_sub_emiraga/add_sub_emiraga.vhd \
../../../../soc/vector/fpu/float_divide_goldschmidt.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_pipeline.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage1_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage2_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage3_struct.vhd \
../../../../soc/vector/fpu/mul/multiplier/fpmul_stage4_struct.vhd \
../../../../soc/vector/fpu/mul/common/fpnormalize_fpnormalize.vhd \
../../../../soc/vector/fpu/mul/common/fpround_fpround.vhd \
../../../../soc/vector/fpu/mul/common/packfp_packfp.vhd \
../../../../soc/vector/fpu/mul/common/unpackfp_unpackfp.vhd \
../../../../soc/vgahdmi/compositing2_fifo.vhd \
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/video_cache_i.vhd \
../../../../soc/vgahdmi/video_cache_d.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/video_mode_pack.vhd \
../../../../soc/vgahdmi/VGA_textmode.vhd \
../../../../soc/vgahdmi/font_block_pack.vhd \
../../../../soc/vgahdmi/font8x8_xark.vhd \
../../../../soc/vgahdmi/font8x16_xark.vhd \
../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/ddr_dvid_out_se.vhd \
../../../../soc/vgahdmi/vga2lcd.vhd \
../../../../soc/vgahdmi/ledstrip.vhd \
../../../../soc/vgahdmi/ws2812b.vhd \
../../../../soc/vgahdmi/pulse_counter.vhd \

include ../../include/xilinx.mk
