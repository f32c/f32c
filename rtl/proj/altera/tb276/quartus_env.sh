ALTERAPATH=/usr/local/altera/13.0sp1

if [ -d ${ALTERAPATH}/quartus/bin/ ] ; then
  export PATH=${ALTERAPATH}/quartus/bin/:"${PATH}"
  export QSYS_ROOTDIR="${ALTERAPATH}/quartus/sopc_builder/bin"
fi
