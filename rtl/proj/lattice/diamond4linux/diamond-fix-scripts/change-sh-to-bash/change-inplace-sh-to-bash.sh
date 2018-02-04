#!/bin/sh
SEDSCRIPT="s#/bin/sh#/bin/bash#1"
exec sed --in-place=".bak" -e $SEDSCRIPT $1
