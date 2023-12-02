
This project is a custom one built to get FM RDS working on the DE10-Nano.

It brings locally any files requiring modification so as not to
provide merge conflicts with the original project source files.

They can be merged back for a pull request once everything is
working.

Currently there does not appear to be BRAM based versions of
modules supporting FM RDS with just basic SoC components, so
they are created here. The more complex ones on the DE0-Nano
for example would not run, but just have a halted processsor.
To many links, AXI buses, dual port cache BRAM timing, etc. to
debug to get a basic project going.

02/17/2019

Development Notes:

These are development notes. They may be obsolete by the time
you read them.

Changed Files:

Try to keep locally.

All local files in this project directory of
DE10-Nano\bram_fmrds.

  top_fmrds_bram_mips_64k.vhd - From original DE0-Nano top_bram.vhd
   - modified to increase memory
   - modified to pass in C_fmrds => true

  fmrds_glue_bram_vgaf.vhd - originally from f32c\rtl\generic\glue_bram_vgaf.vhd
   - modified to disable VGA, enable fmrds.

  Project is organized such that most settings and shared files
  are in glue_de10_nano.qsf. This file is included from a project
  variation .qsf file making multiple project variations more manageable.






