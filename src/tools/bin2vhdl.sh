#!/bin/sh
dd bs=512 if=${1} conv=sync \
| hexdump -v -e '8/1 "x_%02X_, ""\n"' \
| sed -e 's/_/"/g'
 
