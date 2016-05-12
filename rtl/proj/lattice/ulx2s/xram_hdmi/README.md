# Project with full featured use of glue_xram

Use of glue_xram which contains external SRAM driver
and all features we were able to pack together.

On ULX2S it is recommended to enable all medium size
features like timer, gpio,  but only one big size 
feature like VGA or PID but not both at the same time.

Although XP2 chip as enough true differential outputs
for HDMI, they are not routed on the board in a practical
way. e.g. all pairs in a row so differential output is done
single sided outputs, which have fair chance to work on
common monitors.
