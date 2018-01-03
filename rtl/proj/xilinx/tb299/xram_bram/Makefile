project = xc6slx9
vendor = xilinx
family = spartan6
part = xc6slx9-tqg144-2 # last number -2 is speed grade
flashsize = 512 # KB (kilobytes) - SPI flash device is M25P40
top_module = glue
isedir = /usr/local/xilinx/14.7/ISE_DS
SHELL = /bin/bash
# openocd_interface = interface/altera-usb-blaster.cfg
# openocd_interface = ../../include/ft2232-fpu1.ocd
openocd_interface = remote.ocd
# xc3sprog ftdi won't work at full speed
# it must be lowered below 100kHz for bitstream to
# to start reliable
xc3sprog_interface = ftdi

vfiles = \
../../../../soc/pid/ctrlpid_v.v \
../../../../soc/pid/simotor_v.v \
../../../../soc/pid/rotary_decoder_v.v \
../../../../soc/vgahdmi/vgahdmif_v.v \

vhdfiles = \
../../../../xilinx/tb299/top/top_xc6slx9_xram_bram.vhd \
../../../../xilinx/tb299/clocks/pll_25M_112M5.vhd \
../../../../xilinx/tb299/clocks/clk_25_100_125_25.vhd \
../../../../xilinx/tb299/clocks/pll_25M_81M25.vhd \
../../../../xilinx/chip/xc6/hdmi_out_xc6.vhd \
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
../../../../generic/reg1w2r.vhd \
../../../../cpu/alu.vhd \
../../../../cpu/loadalign.vhd \
../../../../cpu/pipeline.vhd \
../../../../cpu/shift.vhd \
../../../../cpu/mul_iter.vhd \
../../../../cpu/defs_f32c.vhd \
../../../../cpu/defs_mi32.vhd \
../../../../cpu/defs_rv32.vhd \
../../../../cpu/idecode_mi32.vhd \
../../../../cpu/idecode_rv32.vhd \
../../../../cpu/cache_generic_param.vhd \
../../../../cpu/debug.vhd \
../../../../soc/sram_pack.vhd \
../../../../soc/sram.vhd \
../../../../soc/sram_refresh.vhd \
../../../../soc/sram8.vhd \
../../../../soc/acram.vhd \
../../../../soc/axiram.vhd \
../../../../soc/axi_read.vhd \
../../../../soc/axi_pack.vhd \
../../../../soc/sdram.vhd \
../../../../soc/ps2.vhd \
../../../../soc/sio.vhd \
../../../../soc/spi.vhd \
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
../../../../soc/fm/bram_rds.vhd \
../../../../soc/fm/message.vhd \
../../../../soc/fm/lowpass.vhd \
../../../../soc/vgahdmi/vga.vhd \
../../../../soc/vgahdmi/tv.vhd \
../../../../soc/vgahdmi/video_mode_pack.vhd \
../../../../soc/cvbs.vhd \
../../../../soc/vgahdmi/compositing2_fifo.vhd \
../../../../soc/vgahdmi/videofifo.vhd \
../../../../soc/vgahdmi/video_cache_i.vhd \
../../../../soc/vgahdmi/video_cache_d.vhd \
../../../../soc/vgahdmi/VGA_textmode.vhd \
../../../../soc/vgahdmi/font_block_pack.vhd \
../../../../soc/vgahdmi/font8x8_xark.vhd \
../../../../soc/vgahdmi/font8x16_xark.vhd \
../../../../soc/vgahdmi/VGA_textmode_bram.vhd \
../../../../soc/vgahdmi/VGA_textmode_font_bram8.vhd \
../../../../soc/vgahdmi/TMDS_encoder.vhd \
../../../../soc/vgahdmi/vga2dvid.vhd \
../../../../soc/vgahdmi/vga2lcd.vhd \
../../../../soc/vgahdmi/ledstrip.vhd \
../../../../soc/vgahdmi/ws2812b.vhd \
../../../../soc/vgahdmi/pulse_counter.vhd \

include ../../include/xilinx.mk
