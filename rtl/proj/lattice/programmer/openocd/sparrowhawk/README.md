# JTAG programming on linux

Connect any ft2232 cable to JTAG
run this (it may even work).

    make program_ft2232

Even if it doesn't work, it will alter some
ft2232 status so from then on, this may work:

    make program

Or programming from diamond GUI may work:
Tools->Programmer, detect cable, click on icon "program"...

# JTAG pinout

Connect JTAG programmer to 1x10-pin male header J15:

    J15: JTAG Header    wire    ESP-12 WIFI_JTAG
    ----------------    ----    ----------------
    Pin  1 VCC 3.3V     red     VCC
    Pin  2 TDO          green   GPIO12
    Pin  3 TDI          blue    GPIO13
    Pin  4 PROGRAMN
    Pin  5 NC
    Pin  6 TMS          violet  GPIO16
    Pin  7 GND          black   GND
    Pin  8 TCK          yellow  GPIO14
    Pin  9 DONE
    Pin 10 INITN

Note: wifi_jtag doesn't work. It will display chip ID
run upload, and report failure status and bitstream will not work.
Probably it uploads too slow.

# ft2232 and openocd

The make command will generate and patch *.svf bitstream file 
for programming with external tools like openocd.

"make program_ft2232" will attempt to upload generated *.svf 
file to FPGA with openocd. This upload is temporary (to SRAM of FPGA)
and is active as long as FPGA board power is ON.

However, openocd will change something to ft2232 cable and/or linux kernel 
so from then on (while ft2232 USB cable is plugged in PC), the cable will be 
recognized by diamond internal programmer.
