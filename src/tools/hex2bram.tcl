#!/usr/local/bin/tclsh8.4
#
# Copyright 2011 University of Zagreb
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
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# $Id: $


if {$argc == 0} {
    puts "Usage: ./hex2bram.tcl ifile \[ofile\]"
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
    set line [string trim $line]
    # Does the line begin with a valid label?
    if {[string index [lindex $line 0] end] != ":"} {
	continue;
    }
    set line_addr [expr 0x[string trim [lindex $line 0] :]]
    if {$addr != $line_addr} {
	puts "WARNING: bad address $line_addr (expected $addr) at line $linenum"
	while {$addr < $line_addr} {
	    set mem($addr) 00000000
	    incr addr 4
	}
    }
    foreach entry [lrange $line 1 end] {
	set mem($addr) $entry
	incr addr 4
    }
}
close $hexfile

# Pad mem to 512 byte-block boundary
while {[expr $addr % 512] != 0} {
    set mem($addr) 00000000
    incr addr 4
}

set bramfile [open $ofile]
set linenum 0
set section undefined
set generic 0
set buf ""
set filebuf ""

set width(8) 8
set width(16) 4

while {[eof $bramfile] == 0} {
    gets $bramfile line
    incr linenum
    if {$section == "undefined"} {
	if {[string first ": DP16KB" $line] != -1} {
	    # set section [lindex [string trim $line] end]
	    set section [lindex [split [string trim $line] _:] 1]
	    set seqn [lindex [split [string trim $line] _:] 2]
	}
    } else {
	set key [string trim $line]
	if {$section != "undefined" &&
	  [string first "generic map" $key] == 0} {
	    set generic 1
	} elseif {$generic == 1 && [string first INITVAL_ $key] == 0} {
	    continue
	} elseif {$key == ")"} {
	    # Construct and dump INITVAL_xx lines!
	    set eseqn [expr $seqn / (32 / $width($section))]
	    set startaddr [expr $eseqn * 65536 / $width($section)]
	    set endaddr [expr ($eseqn + 1) * 65536 / $width($section)]
	    if {$endaddr > $addr} {
		set endaddr $addr
	    }
	    set mod [expr 1024 / $width($section)]
	    set eindex [expr $seqn % (32 / $width($section))]
	    set cwidth [expr $width($section) / 4]
	    set cfrom [expr 8 - $cwidth * ($eindex + 1)]
	    set cto [expr 7 - $cwidth * $eindex]
	    #
	    set tmp_seqn 0
	    set bitpos 0
	    for {set i $startaddr} {$i < $endaddr} {incr i 4} {
		set t [expr ($i / $mod) * $mod + ($mod - 4 - $i) % $mod] 
		set hex [string range $mem($t) $cfrom $cto]
		if {$bitpos == 0} {
		    scan $hex "%02x" val
		    set hex "[format %01X [expr $val / 128]][format %02X [expr ($val * 2) % 256]]"
		    set bitpos 1
		} else {
		    set bitpos 0
		}
		set buf "[set buf]$hex"
		if {[expr ($mod - 4 - $i) % $mod] == 0} {
		    set entry "		INITVAL_"
		    set entry "$entry[format %02X $tmp_seqn] => \"0x$buf\""
		    if {[expr $i + 4] < $endaddr} {
			lappend filebuf "[set entry],"
		    } else {
			lappend filebuf $entry
			set section undefined
		    }
		    set buf ""
		    incr tmp_seqn
		    set bitpos 0
		}
	    }
	    #
	    set section undefined
	    set generic 0
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
