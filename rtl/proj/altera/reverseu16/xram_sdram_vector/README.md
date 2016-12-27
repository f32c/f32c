# reverse-u16 xram_sdram_vector

Everything important works at 100 MHz. Needs some playing
with cables and programmers.

# USB-serial VNC2 firmware and JTAG

After uploading the bitstream, if usb-serial port will not
enumerate or erratically attaches and detaches, unplug 10-pin
JTAG cable. This is known issue with STM32 based USB Blaster clone.
Cypress CYC68013A based USB Blaster clone is OK, it doesn't affect
USB serial with JTAG cable.

USB serial firmware doesn't support serial break,
so to upload new arduino sketch, reverse-u16 needs to be
power cycled to reload bitstream from config FLASH or the 
bitstream needs to be uploaded again over JTAG cable.

# Programming

Openocd: must be using "ftdi" lowlevel driver for 
programming with Altera USB Blaster or clones.
Lowlevel driver "ublast2" does't work at all on linux.

Openocd using lowlevel driver "ftdi" is known to work
with uploading temporary bitstream to FPGA SRAM.
It can be used with USB Blaster or clones STM32 or Cypress.
Lowlevel driver "ublast2" doesn't work at all on debian linux.

To program to SRAM (temporary) with openocd:

    make program_ocd

Quartus: (older 13.0sp1) programmer from quartus is
known to work for Cypress based USB Blaster clones.
STM32 based USB Blaster clones don't work on quartus.
Quartus 16.1 programmer doesn't work on linux debian.

To program to SRAM (temporary) with quartus:

    make program

To program to FLASH (permanent), with Quartus programmer:

    make program_flash

