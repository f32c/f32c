#!/bin/sh

if [ -d  /usr/local/diamond/3.3_x64/bin/lin64 ] ; then
   export PATH=/usr/local/diamond/3.3_x64/bin/lin64:"${PATH}"
fi
      
if [ -d  /usr/local/diamond/3.4_x64/bin/lin64 ] ; then
   export PATH=/usr/local/diamond/3.4_x64/bin/lin64:"${PATH}"
fi
          

THISDIR=$(dirname ${0})
DIAMOND_BINDIR=$(dirname $(which diamond))
DIAMOND_ROOT=$(dirname $(dirname ${DIAMOND_BINDIR}))
DIAMOND_TCLTK=$(find ${DIAMOND_ROOT} -type d -name tcltk)
DIAMOND_TCL_LIBRARY=$(dirname $(find ${DIAMOND_TCLTK} -type f -name package.tcl))
echo "DIAMOND_BINDIR=${DIAMOND_BINDIR}"
echo "DIAMOND_TCL_LIBRARY=${DIAMOND_TCL_LIBRARY}"
#DIAMOND_BINDIR=/usr/local/diamond/3.2/bin/lin
#DIAMOND_TCL_LIBRARY=/usr/local/diamond/3.2/tcltk/lib/tcl8.5
export TEMP=/tmp
export LSC_INI_PATH=""
export LSC_DIAMOND=true
export TCL_LIBRARY=${DIAMOND_TCL_LIBRARY}
PROJECT=project
DIR=${PROJECT}
rm -rf ${DIR}
mkdir -p ${DIR}
# make a bugfix symlink
BUGGYNAME=$(echo "${PROJECT}" | sed -e "s/\(.*\)\(...\)/\1_\1\2\2/g")
cd ${DIR}
ln -s "${PROJECT}_${PROJECT}.p2t" "${BUGGYNAME}.p2t"
cd ..
# end bugfix
diamondc ${THISDIR}/build.tcl $*
