# f32c C sources - how to compile:

MIPS compiler should be patched becuse f32c uses subset of
MIPS ISA (patches are here).
RISC-V compiler probably any (even the latest) will do but
you need to know latest set of required compiler and linker
options and this is often subject of change during development :)

Although you can download compilers, patch and compile from source,
fastest way is to tnstall arduino and from board manager
pull fpgarduino support - compiler binaries will be here:

    ~username/.arduino15/packages/FPGArduino/tools/f32c-compiler/1.0.0/bin

Then get back here and (replace "username.." with your login name)

    $ cd f32c/src/tools
    $ . ./makefiles.sh 
    *** Setting environment for f32c make ***

    In order for make to work, this script must be run from
    directory where it is with dot before script name:
    . ./makefiles.sh
    This is what it does:
    export MAKEFILES=/home/username/src/fpga/fpgarduino/f32c/src/tools/../conf/f32c.mk

    $ PATH=$PATH:~username/.arduino15/packages/FPGArduino/tools/f32c-compiler/1.0.0/bin/

    $ cd f32c/src/lib/src
    $ make
