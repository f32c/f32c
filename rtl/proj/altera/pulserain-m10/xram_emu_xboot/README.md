# MAX10 with geeneric boot preloader

Instead of bootloader stored into UFM, this project
implements bootloader stored into generic VHDL constant table,
at the expense of 10-15% extra LUT usage on MAX10-08

Purpose of this is the imlpementation of alternative
way to preload the bootloader code in order to search
for bugs observed with UFM preloading when CPU
didn't work except for some special latecy values.


