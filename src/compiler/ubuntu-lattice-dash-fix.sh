#!/bin/sh
cd /usr/local/diamond/3.7_x64/synpbase/bin
sudo perl -i -pe 's/#!\/bin\/sh/#!\/bin\/bash/g' `ls -p | grep -v /`
