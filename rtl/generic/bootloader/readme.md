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

# User defined bootloader

After f32c reset, at least first 5 instructions must be NOPs (0x00000000)
to initialize pipeline to its primary state.

Initial code must set correct stack pointers.
If user's code (Arduino-IDE compiled) code should be
replaced as the bootloader, leave parts of the original
bootloader that starts with NOPs and initializes the stack.

# Booting from SPI config flash

This is not yet properly implemented so here will be done
a proposal on how to properly make it.

Most FPGA devices use SPI config flash to load the initial
bitstream at power-on. Usually the flash content can be accessed
(read and written) from the running bitstream.
Usualy there is enough free space in the flash for user's code.

To boot f32c code from SPI config flash, initial flash-capable 
bootloader (which is normally pre-loaded from vhdl) should:

    1. look for first 32-bit signature "C0 DE F3 2C" every 64K
       (at address 0x10000, 0x20000, ... etc. bytes expect signature) 
    2. after signature read 32-bit RAM starting address
    3. after RAM starting address read 32-bit content length
    4. copy following content (length bytes) to RAM starting address
       calculating CRC
    5. after content read 32-bit CRC
    6. if CRC is correct, jump to RAM starting address,
    7. optionally look for another signature starting from
       next 64K until all flash is searched

