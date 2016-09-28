#!/bin/sh
cd /usr/local/diamond/3.8_x64/synpbase/bin
sudo perl -i -pe 's/#!\/bin\/sh/#!\/bin\/bash/g' `ls -p | grep -v /`
sudo perl -i -pe 's/3\.\* \| 2\.4\.\* \| 2\.6\.\*  \)/4\.\* \| 3\.\* \| 2\.4\.\* \| 2\.6\.\*  \)/g' config/platform_check
