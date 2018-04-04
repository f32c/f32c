# MAX10 with geeneric boot preloader

Instead of bootloader stored into UFM, this project
implements bootloader stored into generic VHDL constant table,
at the expense of few extra LUT usage

From arduino, select BRAM memory (should load at address 0x200)
c2_pong example works and c2_sprites with 64 sprites

    #define SPRITE_MAX 64

