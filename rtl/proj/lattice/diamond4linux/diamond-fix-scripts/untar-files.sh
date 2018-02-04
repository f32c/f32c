#!/bin/sh -e

cd /mt/lattice/diamond/3.8_x64

#./tcltk/tcltk.tar.gz
cd tcltk
tar xf tcltk.tar.gz
rm tcltk.tar.gz
cd ..

#./examples/examples.tar.gz
cd examples
tar xf examples.tar.gz
rm examples.tar.gz
cd ..

#./cae_library/cae_library.tar.gz
cd cae_library
tar xf cae_library.tar.gz
rm cae_library.tar.gz
cd ..

#./embedded_source/embedded_source.tar.gz
cd embedded_source
tar xf embedded_source.tar.gz
rm embedded_source.tar.gz
cd ..

#./bin/bin.tar.gz
cd bin
tar xf bin.tar.gz
rm bin.tar.gz
cd ..

#./synpbase/synpbase.tar.gz
cd synpbase
tar xf synpbase.tar.gz
rm synpbase.tar.gz
cd ..

#./ispfpga/ispfpga.tar.gz
cd ispfpga
tar xf ispfpga.tar.gz
rm ispfpga.tar.gz
cd ..

#./data/data.tar.gz
cd data
tar xf data.tar.gz
rm data.tar.gz
cd ..
