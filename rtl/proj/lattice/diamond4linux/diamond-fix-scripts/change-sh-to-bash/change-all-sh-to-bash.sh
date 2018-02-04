#!/bin/sh
SCRIPTDIR=/mt/lattice/diamond/3.8_x64/synpbase/bin
REPLACER=/mt/scratch/tmp/lattice/change-sh-to-bash/change-inplace-sh-to-bash.sh
#REPLACER=ls
find $SCRIPTDIR -type f -exec $REPLACER {} \;
