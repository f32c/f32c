# How to compile FLASH FAT bootloader

    export PATH=$PATH:~davor/.arduino15/packages/FPGArduino/tools/f32c-compiler/1.0.0/bin/

    cd f32c/src/tools/
    . ,/makefiles.sh

    cd f32c/src/lib/src
    make

    cd f32c/src/boot/fat
    make
    make image_linux
    make flash_ulx3s
    