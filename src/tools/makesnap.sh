#!/bin/csh

svn co svn+ssh://login.nxlab.fer.hr/fpgasvn/f32c f32c
svn co svn+ssh://login.nxlab.fer.hr/fpgasvn/demo/chess f32c/src/examples/chess

rm -fr f32c/.svn f32c/src/examples/chess/.svn f32c/rtl
rm -fr f32c/src/tools f32c/src/misc

# Pipelinanje naredbi ne radi bas pouzdano pod cygwinom,
# pa za sad kompletno eliminiramo skriptu isa_check.tcl
mv f32c/src/conf/post.mk f32c/src/conf/post.mk.org
fgrep -v ISA_CHECK f32c/src/conf/post.mk.org > f32c/src/conf/post.mk
rm f32c/src/conf/post.mk.org

tar -czvf f32c_src.tgz f32c
