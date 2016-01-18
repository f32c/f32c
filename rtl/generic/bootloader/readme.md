# Bootloaders

How to create bootloader from source and generate loader.bin

set makefile environment (unix)
cd f32c/src/tools
. ./makefiles.sh

Compile (assuming arduino json installed from boards manager)
this will generate MIPS little endian binary bootloader
TODO: how do we generate big endian -- see options in arduino platform.txt
cd f32c/src/boot/sio
PATH=$PATH:~/.arduino15/packages/FPGArduino/tools/f32c-compiler/1.0.0/bin make

convert binary loader.bin with
f32c/src/tools/bin2vhdl.sh loader.bin > loader.vhd.include

copy-paste loader.vhd.include into appropriate file here
using text editor, copy paste lines like this:
x"00", x"00", x"00", x"00", x"21", x"40", x"00", x"00",
into bootloader vhd file:
boot_sio_mi32el.vhd -- generic f32c bootloader
boot_rom_mi32el.vhd -- SPI flash rom f32c bootloader (for ULX2S boards)
