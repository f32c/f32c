
#*******************************************************************************
# Simple script to control vivado project via command line
#
# It takes 2 arguments
#   arg 1 either.
#   clean   cleans project files
#   build   build all output files
#   arg 2 project_name.xpr

# usage
# #!/bin/sh
# vivado=/opt/Xilinx/Vivado/2015.2/bin/vivado
# $vivado -mode tcl -source run_vivado.tcl -tclargs clean
# $vivado -mode tcl -source run_vivado.tcl -tclargs build




#*******************************************************************************
# Open project
#open_project esa11_7a35i_bram.xpr
open_project [lindex $argv 1]


#*******************************************************************************
# Update sources
update_compile_order -fileset sources_1


##*******************************************************************************
## Clean project

if {[lindex $argv 0] == "clean"} {
   ## clean implementation
   reset_run impl_1

   ## clean synthesis
   reset_run synth_1

   ## clean PS project configuration
   # reset_target all [get_files  ./vivado/ps_scripts.srcs/sources_1/bd/system/system.bd]
}


##*******************************************************************************
## Make output files

if {[lindex $argv 0] == "build"} {

   ## export PS configuration
#   generate_target all [get_files  ./vivado/ps_scripts.srcs/sources_1/bd/system/system.bd]
#   open_bd_design ./vivado/ps_scripts.srcs/sources_1/bd/system/system.bd
#   export_hardware [get_files ./vivado/ps_scripts.srcs/sources_1/bd/system/system.bd]
#   close_bd_design system

   ## do synthesis
   launch_runs synth_1
   wait_on_run synth_1

   ## do implementation
   launch_runs impl_1
   wait_on_run impl_1

   ## make bit file
   launch_runs impl_1 -to_step write_bitstream
   wait_on_run impl_1
}

#*******************************************************************************
# Close opened project
close_project

exit
