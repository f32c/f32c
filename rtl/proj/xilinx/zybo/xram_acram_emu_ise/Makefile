project = zybo
vendor = xilinx
family = zinq
part = xc7z010-clg400-1 # last number -1 is speed grade
flashsize = 8192 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
#isedir = /usr/local/xilinx/14.7/ISE_DS
isedir = /opt/Xilinx/ISE/14.7/ISE_DS
xil_env = . $(isedir)/settings64.sh
openocd_interface = ftdi-zybo.ocd
xc3sprog_interface = jtaghs1_fast
xc3sprog_device = 1
SHELL = /bin/bash

vfiles = \
../../../../soc/pid/ctrlpid_v.v \
../../../../soc/pid/simotor_v.v \
../../../../soc/pid/rotary_decoder_v.v \

vhdfiles = \
../../../../xilinx/zybo/top/top_xram_acram_emu.vhd \
../../../../xilinx/zybo/clocks/pll_125M_250M_100M_25M.vhd \
../../../../xilinx/zybo/clocks/mmcm_125M_81M25_250M521_25M052.vhd \
../../../../xilinx/zybo/clocks/clk_125M_100M_125M_25M.vhd \
../../../../xilinx/chip/xc7/hdmi_out_xc7.vhd \
../../../../generic/glue_xram.vhd \
../../../../generic/bram.vhd \
../../../../generic/bootloader/defs_bootblock.vhd \
../../../../generic/bootloader/boot_sio_mi32el.vhd \
../../../../generic/bootloader/boot_sio_mi32eb.vhd \
../../../../generic/bootloader/boot_sio_rv32el.vhd \
../../../../generic/bootloader/boot_rom_mi32el.vhd \
../../../../generic/bram_true2p_1clk.vhd \
../../../../generic/bram_true2p_2clk.vhd \
../../../../generic/bptrace.vhd \
../../../../generic/bram_video.vhd \
../../../../generic/acram_emu.vhd \
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
../../../../soc/sdram.vhd \
../../../../soc/sio.vhd \
../../../../soc/spi.vhd \
../../../../soc/gpio.vhd \
../../../../soc/timer.vhd \
../../../../soc/pcm.vhd \
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
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/vga2lcd.vhd \
../../../../soc/vgahdmi/video_cache_i.vhd \
../../../../soc/vgahdmi/video_cache_d.vhd \
../../../../soc/vgahdmi/compositing2_fifo.vhd \
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/VGA_textmode.vhd \
../../../../soc/vgahdmi/font_block_pack.vhd \
../../../../soc/vgahdmi/font8x8_xark.vhd \
../../../../soc/vgahdmi/font8x16_xark.vhd \
../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/ledstrip.vhd \
../../../../soc/vgahdmi/ws2812b.vhd \
../../../../soc/vgahdmi/pulse_counter.vhd \

include ../../include/xilinx.mk
