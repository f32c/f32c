# Building on iCEcube2

USE Synplify PRO

    Synthesis tool (right click) -> Select Synthesis Tools -> Synplify PRO

add constraints file to (icecube2 might forget this file if restarted)

    P&R Flow -> P&R files -> Constraint Files (right click) -> add file icoboard_beta.pcf

compile icoprog on raspberry pi2:

    cd $HOME
    sudo apt-get install subversion
    svn co http://svn.clifford.at/handicraft/2015/icoprog
    cd icoprog && make install

icoboard plugged into raspberry pi2, raspberry reachable with ssh
to program bitstream:

    ssh pi@raspberrypi.lan 'icoprog -p' < blink_Implmnt/sbt/outputs/bitmap/top_bitmap.bin
