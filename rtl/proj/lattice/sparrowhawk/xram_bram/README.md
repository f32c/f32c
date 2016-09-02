# JTAG programming

connect any ft2232 cable to JTAG
run once this:

    make program_ft2232

it will try to upload generated *.svf file with openocd
but this will not work (a little help needed to get it working)
 
But it will change something with ft2232 settings
so from now on the cable will be recognized by diamond
internal programmer:

    make program

Or from GUI
diamond project.ldf
Tools->Programmer, detect cable, click on icon "program"...
