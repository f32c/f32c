# Project with full featured use of glue_xram

Use of glue_xram which contains external SRAM driver
and all features we were able to pack together.

On ULX2S it is recommended to enable all medium size
features like timer, gpio,  but only one big size
feature like VGA or PID but not both at the same time.

For VGA textmode use cache_generic_param.vhd instead 
of cache.vhd
Currently (2016-08-14) when cache.vhd is used then
arcagol example shows VGA textmode corruption in
visual form of colorful junk leftovers.

vgahdmi 8bpp 640x480 max clock 81 MHz
vgatext 8bpp 640x480 max clock 50 MHz
