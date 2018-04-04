# MAX10 with geeneric boot preloader

Instead of bootloader stored into UFM, this project
implements bootloader stored into generic VHDL constant table,
at the expense of few extra LUT usage

From arduino, select BRAM memory (should load at address 0x200)
exaplles "c2_pong" and "c2_sprites" work

