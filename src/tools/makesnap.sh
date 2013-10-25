#!/bin/csh

svn co svn+ssh://login.nxlab.fer.hr/fpgasvn/f32c/src src

rm -fr src/.svn
rm -fr src/coremark src/demo src/tools src/test1 src/boot

# Pipelinanje naredbi ne radi bas pouzdano pod cygwinom,
# pa za sad kompletno eliminiramo skriptu isa_check.tcl
mv src/conf/post.mk src/conf/post.mk.org
fgrep -v ISA_CHECK src/conf/post.mk.org > src/conf/post.mk
rm src/conf/post.mk.org

tar -czvf f32c_src.tgz src
