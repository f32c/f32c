#!/bin/csh

svn co svn+ssh://login.nxlab.fer.hr/fpgasvn/f32c/src src

rm -fr src/.svn
rm -fr src/coremark src/demo src/tools src/test1 src/boot

tar -czvf f32c_src.tgz src
