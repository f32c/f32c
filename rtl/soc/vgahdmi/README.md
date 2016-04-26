# Video output directory

collection of files that create vga video output

vga.vhd does simple 640x480 60Hz 8bpp bitmap output

VGA_textmode.vhd can do mixed textmode and bitmap graphics

both may have sprites and compositing2 2D acceleration features
this is done in compositing2_fifo.vhd before the bitmap generation
process.

# obsolete files

soon to be deleted and not recommended for new projects:

compositing_fifo.vhd -> use either videofifo_bram.vhd or compositing2_fifo.vhd
vgahdmif.vhd -> use vga.vhd + vga2dvid.vhd
