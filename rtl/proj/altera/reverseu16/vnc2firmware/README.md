# VNC2 USB-SERIAL firmware for f32c

VNC2 is versatile USB glue chip from FTDI.
It can be flashed with custom compiled firmware
to act like USB host or slave, accept or provide
serial port, keyboard, mouse, joystick, ...

Here (in f32c) is the source and compiled ROM binary firmware
which creates 115200 baud usbserial port suitable for f32c.
It was kindly provided by the author of the ReVerSE-U16 project:

    ttps://github.com/mvvproject/ReVerSE-U16

To upload firmware into ReVerSE-U16 board, 1-wire
"debugger" programmer hardware is needed, but it can
can be do-it-yourself with minimal hardware and the 
help of onboard FPGA as described here:

    https://github.com/emard/mini-vnc2-prog

Or here as the standalone circuit, with few parts more:

    https://github.com/mvvproject/ReVerSE-U16/tree/master/u16_board/modules/v2debug    

Besides the hardware, some windows is needed
with installed FT_PROG, V2PROG and FT900 programmer.
(It can work on virtualbox).

# Issues

To upload another arduino sketch, re-plug reverse-u16 or reload 
the bitstream.

This is because f32c has a use for serial "BREAK" signal, which
is requsted by standard serial ioctl() from unix or windows 
ujprog tool, see

    https://github.com/f32c/tools/tree/master/ujprog

On "compatible" serial port it is able to to generate a pulse of
about 200ms on the TX line. This signal is recognized by f32c CPU
as RESET so it aborts any running code and re-enters bootloader and
shows prompt "f32l>"

Serial break seems not to work on USBSlaveFT232Emu but I guess
FTDI somehow should have provided some way to generate this.
