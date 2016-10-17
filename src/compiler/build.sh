#!/bin/bash

set -e

#MAKE=gmake -j4
MAKE="make -j 2"

# prefix to install tools in /usr/local/gnu_mips_f32c
PREFIX=/usr/local/gnu_mips_f32c

MPC_ARCHIVE=$(ls mpc-*.tar.*)
MPC_DIR=$(tar -tf $MPC_ARCHIVE | head -n 1)
MPFR_ARCHIVE=$(ls mpfr-*.tar.*)
MPFR_DIR=$(tar -tf $MPFR_ARCHIVE | head -n 1)
GMP_ARCHIVE=$(ls gmp-*.tar.*)
GMP_DIR=$(tar -tf $GMP_ARCHIVE | head -n 1)
BINUTILS_ARCHIVE=$(ls binutils-*.tar.*)
BINUTILS_DIR=$(tar -tf $BINUTILS_ARCHIVE | head -n 1 | cut -d/ -f 1)
GCC_ARCHIVE=$(ls gcc-*.tar.*)
GCC_DIR=$(tar -tf $GCC_ARCHIVE | head -n 1)
echo "${MPC_ARCHIVE} -> ${MPC_DIR}"
echo "${MPFR_ARCHIVE} -> ${MPFR_DIR}"
echo "${GMP_ARCHIVE} -> ${GMP_DIR}"
echo "${BINUTILS_ARCHIVE} -> ${BINUTILS_DIR}"
echo "${GCC_ARCHIVE} -> ${GCC_DIR}"

if true
then
 rm -rf $MPC_DIR
 tar -xf $MPC_ARCHIVE
 rm -rf $MPFR_DIR
 tar -xf $MPFR_ARCHIVE
 rm -rf $GMP_DIR
 tar -xf $GMP_ARCHIVE
 rm -rf $BINUTILS_DIR
 tar -xf $BINUTILS_ARCHIVE
 rm -rf $GCC_DIR
 tar -xf $GCC_ARCHIVE
fi

if true
then
 cd $GCC_DIR
 ln -sf ../$MPC_DIR   mpc
 ln -sf ../$MPFR_DIR  mpfr
 ln -sf ../$GMP_DIR   gmp
 cd ..
fi

if true
then
 cd $BINUTILS_DIR
 patch -p0 < ../patches/binutils-2.26.diff
 cd ..
fi

if true
then
 cd $GCC_DIR
 patch -p0 < ../patches/gcc-5.2.0.diff
 cd ..
fi

if true
then
 cd $BINUTILS_DIR
 ./configure --target=mips-elf --enable-languages=c,c++ \
            --prefix=$PREFIX --mandir=$PREFIX/man \
            --infodir=$PREFIX/info --disable-nls --disable-shared \
            --disable-werror
 $MAKE
 # sudo $MAKE install
 $MAKE install
 cd ..
fi

if true
then
 cd $GCC_DIR
 ./configure --target=mips-elf --enable-languages=c,c++ \
            --prefix=$PREFIX --mandir=$PREFIX/man \
            --infodir=$PREFIX/info --disable-nls --disable-shared \
	    --disable-werror

 $MAKE
 $MAKE install
 # sudo $MAKE install
 cd ..
fi
