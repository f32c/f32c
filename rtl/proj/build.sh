#!/usr/local/bin/bash

export TEMP=/tmp
export LSC_INI_PATH=""
export LSC_DIAMOND=true
export TCL_LIBRARY=/usr/local/diamond/3.1/tcltk/lib/tcl8.5
/usr/local/diamond/3.1/bin/lin/diamondc build.tcl
