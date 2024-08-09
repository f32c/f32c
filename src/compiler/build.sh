#!/bin/sh

# main targets
TARGET_ARCH="mips riscv32"

# optional extras
#TARGET_ARCH=${TARGET_ARCH}" microblaze nios2 arm"

GNU_MIRROR=https://ftp.gnu.org/gnu

BINUTILS_URL=${GNU_MIRROR}/binutils/binutils-2.42.tar.xz
GCC_URL=${GNU_MIRROR}/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz

BINUTILS_SRC_DIR=~/github/gnu/binutils
GCC_SRC_DIR=~/github/gnu/gcc

F32C_SRC_DIR=~/github/f32c
#F32C_TOOLCHAIN_DST_DIR=/usr/local
F32C_TOOLCHAIN_DST_DIR=/tmp/f32c

# XXX impossible to build statically linked binutils?
# F32C_MAKEOPTIONS="LDFLAGS=-static"

# XXX Win32 -> use the MinGW-MSYS bundle

# Uncomment SUDO if you want the binaries directly installed into /usr/...
#SUDO=su

MAKE=make
MAKE_JOBS=4

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
    mkdir -p ${GCC_SRC_DIR}
    cd ${GCC_SRC_DIR}
    wget ${GCC_URL}
    tar -xf *
    rm *.tar*
    mv */* .
    ./contrib/download_prerequisites 
    patch -p0 < ${F32C_SRC_DIR}/src/compiler/patches/gcc-14.2.0.diff
fi


#
# Build the toolchain(s)
#

${SUDO} mkdir -p ${F32C_TOOLCHAIN_DST_DIR}

for TARGET in $TARGET_ARCH
do
    TARGET_PREF=${TARGET}-elf
    if [ "$TARGET" == "arm" ]; then
	TARGET_PREF=${TARGET_PREF}-eabi
    fi
    for SRC_DIR in ${BINUTILS_SRC_DIR} ${GCC_SRC_DIR}
    do
	cd ${SRC_DIR}
	${MAKE} distclean
	find . -name config.cache -exec rm {} \;
	./configure --target=${TARGET_PREF} --enable-languages=c,c++ \
		--prefix=${F32C_TOOLCHAIN_DST_DIR} \
		--mandir=${F32C_TOOLCHAIN_DST_DIR}/man \
		--infodir=${F32C_TOOLCHAIN_DST_DIR}/info \
		--disable-nls --disable-shared \
		--disable-werror --with-gnu-as --with-gnu-ld
	${MAKE} -j ${MAKE_JOBS} ${F32C_MAKEOPTIONS}
	${SUDO} ${MAKE} ${F32C_MAKEOPTIONS} install
    done

    ${SUDO} strip ${F32C_TOOLCHAIN_DST_DIR}/bin/${TARGET_PREF}-*
    ${SUDO} find ${F32C_TOOLCHAIN_DST_DIR}/${TARGET_PREF} \
	-type f -exec strip {} \;
    ${SUDO} find ${F32C_TOOLCHAIN_DST_DIR}/libexec/gcc/${TARGET_PREF} \
	-type f -exec strip {} \;
done
