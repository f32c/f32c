f32cup.py can upload
usb-serial break is not currently implemented in usb, press btn(0) to get bootloader prompt
if it gets stuck, sometimes you can unstuck it by
screen /dev/ttyACM0
and press btn0 until prompt
sometimes it gets stuck hard, pressing btn(0) won't get prompt or gets incomplete prompt
then bitstream must be reloaded