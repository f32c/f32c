#!/bin/sh

COREMARK_SRC_DIR=./cm_src

#
# One-time job: fetch the coremark sources, apply f32c patches
#

if [ ! -d ${COREMARK_SRC_DIR} ]
then
	git clone https://github.com/eembc/coremark ${COREMARK_SRC_DIR}
	cp -R f32c ${COREMARK_SRC_DIR}
fi

cd ${COREMARK_SRC_DIR}

make PORT_DIR=f32c ARCH=mips
make PORT_DIR=f32c ARCH=riscv
