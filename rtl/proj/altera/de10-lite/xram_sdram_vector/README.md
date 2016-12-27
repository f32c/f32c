# xram_sdram_vector project

Everything works at 75 MHz (VGA, SDRAM, Vector) but it's kinda
"stretched".

75 MHz is both the upper limit for the f32c core and lower limit for SDRAM.
Luckily they both meet in the middle.

Bootloader had to be reduced to 1K because MAX 10
doesn't have capacity to preload 2K.

Compiling takes almost 1 hour.

Cache should be 2K or 4K with 8 vectors, 
for 8K cache only 4 vectors can be used.

If both 8K cache and 8 vectors are attempted to compile,
quartus 16.1 will abort with some internal error.
