#!/bin/sh

# XXX check for wget, make, bison...
# XXX Win32 -> use the MinGW-MSYS bundle
# XXX sudo for install?

# XXX impossible to build statically linked binutils?
# F32C_MAKEOPTIONS="LDFLAGS=-static"

SUDO=sudo
MAKE=make

MAKE_JOBS=2

BINUTILS_SRC_DIR=~/github/riscv-binutils-gdb
GCC_SRC_DIR=~/github/riscv-gcc
F32C_SRC_DIR=~/github/f32c
F32C_TOOLCHAIN_DST_DIR=/usr/local


#
# One-time job: fetch the sources, apply f32c patches
#

if [ ! -d ${BINUTILS_SRC_DIR} ]
then
    git clone https://github.com/riscv/riscv-binutils-gdb ${BINUTILS_SRC_DIR}
    cd ${BINUTILS_SRC_DIR}
    patch -p0 < ${F32C_SRC_DIR}/src/compiler/patches/binutils-2.26.diff
fi

if [ ! -d ${GCC_SRC_DIR} ]
then
    git clone https://github.com/riscv/riscv-gcc ${GCC_SRC_DIR}
    cd ${GCC_SRC_DIR}
    ./contrib/download_prerequisites 
    patch -p0 < ${F32C_SRC_DIR}/src/compiler/patches/gcc-6.1.0.diff
fi


#
# Build the toolchain(s)
#

${SUDO} mkdir -p ${F32C_TOOLCHAIN_DST_DIR}

for TARGET_ARCH in riscv32 mips
do
    for SRC_DIR in ${BINUTILS_SRC_DIR} ${GCC_SRC_DIR}
    do
	cd ${SRC_DIR}
	${MAKE} distclean
	find . -name config.cache -exec rm {} \;
	./configure --target=${TARGET_ARCH}-elf --enable-languages=c,c++ \
		--prefix=${F32C_TOOLCHAIN_DST_DIR} \
		--mandir=${F32C_TOOLCHAIN_DST_DIR}/man \
		--infodir=${F32C_TOOLCHAIN_DST_DIR}/info \
		--disable-nls --disable-shared \
		--disable-werror --with-gnu-as --with-gnu-ld
	${MAKE} -j ${MAKE_JOBS} ${F32C_MAKEOPTIONS}
	${SUDO} ${MAKE} ${F32C_MAKEOPTIONS} install
    done

    ${SUDO} strip ${F32C_TOOLCHAIN_DST_DIR}/bin/${TARGET_ARCH}-elf-*
    ${SUDO} find ${F32C_TOOLCHAIN_DST_DIR}/${TARGET_ARCH}-elf \
	-type f -exec strip {} \;
    ${SUDO} find ${F32C_TOOLCHAIN_DST_DIR}/libexec/gcc/${TARGET_ARCH}-elf \
	-type f -exec strip {} \;
done
