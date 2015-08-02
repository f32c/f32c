#/!bin/sh
grep "version" options.ggo | sed -e 's/.*"\(.*\)".*/\1/'
