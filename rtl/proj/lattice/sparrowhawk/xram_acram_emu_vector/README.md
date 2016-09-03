# JTAG programming on linux

Connect any ft2232 cable to JTAG
run this once (will print errors, that's ok):

    make program_ft2232

Every other time it is enough to run just this:

    make program

To ptogram from diamond GUI:
Tools->Programmer, detect cable, click on icon "program"...

# JTAG pinout

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

# ft2232 and openocd

The make build process will generate *.svf bitstream file 
for programming with external tools like openocd. 
"make program_ft2232" will attempt to upload generated *.svf file 
with openocd. This upload currently doesn't work (exits with error).
A little help is needed here to get it working...

However, openocd will change something to ft2232 cable and/or linux kernel 
so from then on (while ft2232 usb cable is plugged), the cable will be 
recognized by diamond internal programmer.
