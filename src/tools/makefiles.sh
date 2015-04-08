#!/bin/sh

echo "*** Setting environment for f32c make ***"
echo
echo "In order for make to work, this script must be run from" 
echo "directory where it is with dot before script name:"
echo ". ./envirnoment.sh"
echo "This is what it does:"
export MAKEFILES=$PWD/../conf/f32c.mk
echo "export MAKEFILES=$MAKEFILES"
