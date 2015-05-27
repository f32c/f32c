The EEMBC license only permits downloads of CoreMark software sources
directly from their web site on individual basis, hence you should
register at www.eembc.org and download CoreMark tarball from there.

Unpack the tarball so that all sources are moved in this directory:

tar xf coremark_v1.0.tgz
mv coremark_v1.0/* .

Then, patch the original Makefile:

patch -p 0 < Makefile.diff

The "make" command can then be used to build the benchmark.  Note
that the default load address is 0x400.
