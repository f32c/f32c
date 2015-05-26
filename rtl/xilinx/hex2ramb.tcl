#!/usr/local/bin/tclsh8.6
#
# Copyright (c) 2010 Marko Zec, University of Zagreb
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# $Id$


if {$argc == 0} {
    puts "Usage: ./hex2ramb.tcl ifile \[ofile\]"
    exit 1
} elseif {$argc == 1} {
    set ofile bram.vhd
} else {
    set ofile [lindex $argv 1]
}

set hexfile [open "[lindex $argv 0]"]
set linenum 0
set addr 0

while {[eof $hexfile] == 0} {
    gets $hexfile line
    incr linenum
    set line [string trim $line]
    # Does the line begin with a valid label?
    if {[string index $line 0] != "S"} {
	if {$line == ""} {
	    continue;
	}
	puts "Invalid input file format at line $linenum"
	exit 1
    }
    set rtype [string index $line 1]
    set len [scan [string range $line 2 3] %02x]
    switch $rtype {
	0 {
	    set hex [string range $line 8 [expr $len * 2 + 1]]
	    while {$hex != ""} {
		set ascii [scan [string range $hex 0 1] %02x]
#		puts -nonewline [format %c $ascii]
		set hex [string range $hex 2 end]
	    }
#	    puts -nonewline ": "
	    continue
	}
	1 {
	    set addr_last 7
	}
	2 {
	    set addr_last 9
	}
	3 {
	    set addr_last 11
	}
	9 {
	    continue
	}
	default {
	    puts "XXX $rtype"
	    continue
	}
    }
    set block_addr [scan [string range $line 4 $addr_last] %x]
    while {$addr < $block_addr} {
	set mem($addr) 0
	incr addr
    }
    for {set i [expr $addr_last + 1]} {$i < [expr $len * 2 + 2]} {incr i 2} {
	set val [scan [string range $line $i [expr $i + 1]] %x]
	set mem($addr) $val
	incr addr
    }
}
close $hexfile

# Pad mem to 256 byte-block boundary
while { [expr $addr % 256] != 0 } {
    set mem($addr) 0
    incr addr
}

set bramfile [open $ofile]
set linenum 0
set section undefined
set generic 0
set done 0
set buf ""
set filebuf ""


proc peek {byte_addr} {
    global mem

    return $mem($byte_addr)
}


while {[eof $bramfile] == 0} {
    gets $bramfile line
    incr linenum
    if {$section == "undefined" && $done == 0} {
	if {[string first ": RAMB16_" $line] != -1 ||
	    [string first ": RAMB16BWE_S36_S36" $line] != -1} {
	    set section [lindex [string trim $line] end]
	}
    } else {
	set key [string trim $line]
	if {[string first "generic map" $key] == 0} {
	    set generic 1
	} elseif {$generic == 1 && [string first INIT_ $key] == 0} {
	    continue
	} elseif {$key == ")"} {
	    # Construct and dump INIT_xx lines!
	    set endaddr $addr
	    set line ""
	    for {set i 0} {$i < $endaddr} {incr i} {
		set buf "[format %02X [peek $i]]$buf"
		if {[expr ($i + 1) % 32] == 0} {
		    set line "[set line]	INIT_[format %02X [expr $i / 32]] => "
		    set line "[set line]x\"$buf\""
		    if {[expr $i + 1] < $endaddr} {
			set line "[set line],\n"
		    } else {
			set line "[set line]\n    )"
		    }
		    set buf ""
		}
	    }
	    set section undefined
	    set generic 0
	    set done 1
	}
    }
    lappend filebuf $line
}
close $bramfile

# Trim blank lines from the end of file
while {[lindex $filebuf end] == ""} {
    set filebuf [lreplace $filebuf end end]
}

set bramfile [open $ofile w]
foreach line $filebuf {
    puts $bramfile $line
}
close $bramfile
