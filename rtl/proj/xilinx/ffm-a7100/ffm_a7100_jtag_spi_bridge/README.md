# using xc3sprog to flash FFM-A7100

with the 200 pin connector to the left, all four switches are pointing
away from the connector

(SW1 connects the SPI-FLASH to the FPGA
the lower M1/M2 are boot mode from spi-flash ...)

/mt/scratch/tmp/xc3sprog/xc3sprog_anybin -v -c ft4232h_fast \
-Ibscan_ffm_a7100_v3r0_ffc_ca7_v2r0.runs/impl_1/bscan_ffm_a7100.bit \
/mt/scratch/tmp/amiga/xilinx/amiga_ffm_a7100_lcdif.bit:w:0

------------------------------------ cut --------------------

root@hp8300:/AD1/SHARED/XC3SPROG/xc3sprog-code/build# ./xc3sprog -v -c
ft4232h -p 0 top-a7.bit
XC3SPROG (c) 2004-2011 xc3sprog project $Rev: 795 $ OS: Linux
Free software: If you contribute nothing, expect nothing!
Feedback on success/failure/enhancement requests:
        http://sourceforge.net/mail/?group_id=170565
Check Sourceforge for updates:
        http://sourceforge.net/projects/xc3sprog/develop

Using built-in device list
Using built-in cable list
Cable ft4232h type ftdi VID 0x0403 PID 0x6011 dbus data 00 enable 0b
cbus data 00 data 00
Using Libftdi, Using JTAG frequency   1.500 MHz from undivided clock
JTAG chainpos: 0 Device IDCODE = 0x13631093     Desc: XA7A100T
Created from NCD file: top;UserID=0XFFFFFFFF;Version=2018.2.2
Target device: 7a100tfgg484
Created: 2018/12/09 13:28:11
Bitstream length: 30606304 bits
done. Programming time 20504.6 ms
USB transactions: Write 1886 read 15 retries 13

------------------------------------ cut --------------------


root@hp8300:/AD1/SHARED/XC3SPROG/xc3sprog-code/build# ./xc3sprog -v -c
ft4232h -I amiga_ffm_a7100.bit:w:0
XC3SPROG (c) 2004-2011 xc3sprog project $Rev: 795 $ OS: Linux
Free software: If you contribute nothing, expect nothing!
Feedback on success/failure/enhancement requests:
        http://sourceforge.net/mail/?group_id=170565
Check Sourceforge for updates:
        http://sourceforge.net/projects/xc3sprog/develop

Using built-in device list
Using built-in cable list
Cable ft4232h type ftdi VID 0x0403 PID 0x6011 dbus data 00 enable 0b
cbus data 00 data 00
Using Libftdi, Using JTAG frequency   1.500 MHz from undivided clock
JTAG chainpos: 0 Device IDCODE = 0x13631093     Desc: XA7A100T
JEDEC: 01 60 0x19 0xff
Found Spansion Device, Device ID 60, memory type 19, capacity ff
256 bytes/page, 65535 pages = 16776960 bytes total
Created from NCD file: amiga_ffm_a7100;UserID=0XFFFFFFFF;Version=2018.1
Target device: 7a100tfgg484
Created: 2018/06/05 12:35:55
Bitstream length: 30606304 bits
Erasing sector 59/59..  Writing data page  14944/ 14945 at flash page
14944..
Maximum erase time 289.4 ms, Max PP time 28938 us
Verifying page  14945/ 14945 at flash page  14945
Verify: Success!
USB transactions: Write 58319 read 58316 retries 72179
