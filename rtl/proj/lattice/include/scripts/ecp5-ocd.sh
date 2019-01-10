#!/bin/sh
# ecp5-ocd.sh

CHIP_ID=$1
FILE_SVF=$2

cat << EOF
# OpenOCD commands

telnet_port 4444
gdb_port 3333

# JTAG TAPs
jtag newtap lfe5 tap -expected-id ${CHIP_ID} -irlen 8 -irmask 0xFF -ircapture 0x5

init
scan_chain
svf -tap lfe5.tap -quiet -progress ${FILE_SVF}
shutdown
EOF
