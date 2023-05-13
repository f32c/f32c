#!/bin/sh

# XXX Win32 -> use the MinGW-MSYS bundle


GNU_MIRROR=ftp://ftp.gnu.org/gnu

BINUTILS_URL=${GNU_MIRROR}/binutils/binutils-2.40.tar.xz
GCC_URL=${GNU_MIRROR}/gcc/gcc-13.1.0/gcc-13.1.0.tar.xz

BINUTILS_SRC_DIR=~/github/gnu/binutils
GCC_SRC_DIR=~/github/gnu/gcc

F32C_SRC_DIR=~/github/f32c
#F32C_TOOLCHAIN_DST_DIR=/usr/local
F32C_TOOLCHAIN_DST_DIR=/tmp/f32c


# XXX impossible to build statically linked binutils?
# F32C_MAKEOPTIONS="LDFLAGS=-static"

SUDO=sudo
MAKE=make
MAKE_JOBS=2

CC=gcc
CXX=g++

if [ "$OSTYPE" == "" ]; then
	OSTYPE=`uname`
fi

if [ "$OSTYPE" == "cygwin" ]; then
	SUDO=
fi

if [ "$OSTYPE" == "msys" ]; then
	F32C_MAKEOPTIONS="LDFLAGS=-static"
	SUDO=
fi

if [ "$OSTYPE" == "FreeBSD" ]; then
	MAKE=gmake
fi


#
# Check for prerequisites
#
for PROG in git wget tar patch $MAKE bison diff cmp makeinfo gcc g++ install
do
    if [ "`command -v $PROG`" == "" ]; then
	echo $PROG required but not installed, aborting!
	exit 1
    fi
done


#
# One-time job: fetch the sources, apply f32c patches
#

if [ ! -d ${BINUTILS_SRC_DIR} ]
then
#    git clone https://github.com/riscv/riscv-binutils-gdb ${BINUTILS_SRC_DIR}
    mkdir -p ${BINUTILS_SRC_DIR}
    cd ${BINUTILS_SRC_DIR}
    wget ${BINUTILS_URL}
    tar -xf *
    rm *.tar*
    mv */* .
    patch -p0 < ${F32C_SRC_DIR}/src/compiler/patches/binutils-2.40.diff
fi

if [ ! -d ${GCC_SRC_DIR} ]
then
#    git clone https://github.com/riscv/riscv-gcc ${GCC_SRC_DIR}
    mkdir -p ${GCC_SRC_DIR}
    cd ${GCC_SRC_DIR}
    cd ${GCC_SRC_DIR}
    wget ${GCC_URL}
    tar -xf *
    rm *.tar*
    mv */* .
    ./contrib/download_prerequisites 
    patch -p0 < ${F32C_SRC_DIR}/src/compiler/patches/gcc-13.1.0.diff
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
