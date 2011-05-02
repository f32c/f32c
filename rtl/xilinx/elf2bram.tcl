#!/usr/local/bin/tclsh8.4
#
# Copyright 2010 University of Zagreb, Croatia.
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

# $Id$


if {$argc == 0} {
    puts "Usage: ./elf2bram.tcl ifile \[ofile\]"
    exit 1
} elseif {$argc == 1} {
    set ofile bram.vhd
} else {
    set ofile [lindex $argv 1]
}

set elffile [open "| mips-elf-objdump -s [lindex $argv 0]"]
set linenum 0
set section undefined
set endian none
set addr 0

while {[eof $elffile] == 0} {
    gets $elffile line
    incr linenum
    if {[string range $line 0 18] == "Contents of section"} {
	set section [string trim [lindex $line 3] :]
    } elseif {[string index $line 0] == " " &&
	[lsearch ".text .rodata .data .sdata" $section] != -1} {
	set line_addr [expr 0x[lindex [string range $line 0 10] 0]]
	if {$addr != $line_addr} {
	    puts "Bad address $line_addr (expected $addr) at line $linenum"
	    exit 1
	}
	if {$endian == "none"} {
	    puts "Undefined endianess at line $linenum"
	    exit 1
	}
	puts -nonewline "$addr:	"
	set l1 [string range $line 0 40]
	for { set i 1 } { $i <= 4} { incr i } {
	    set word [lindex $l1 $i]
	    if {$word == ""} {
		set word 00000000
	    }
	    if {$section == ".text" || $endian == "little"} {
		# Switch endianess
		set word "[string range $word 6 7][string range $word 4 5][string range $word 2 3][string range $word 0 1]"
	    }
	    set mem($addr) $word
	    puts -nonewline "$word "
	    incr addr 4
	}
	puts [string range $line 42 end]
    } elseif {$endian == "none" &&
	[lrange $line 1 2] == "file format"} {
	if {[lindex $line 3] == "elf32-littlemips"} {
	    set endian little
	} elseif {[lindex $line 3] == "elf32-bigmips"} {
	    set endian big
        }
    }
}
close $elffile

# Pad mem to 256 byte-block boundary
while { [expr $addr % 256] != 0 } {
    set mem($addr) 00000000
    incr addr 4
}

set bramfile [open $ofile]
set linenum 0
set section undefined
set generic 0
set buf ""
set filebuf ""

set seqn(RAMB16_S36_S36) 0
set seqn(RAMB16_S9_S9) 0
set width(RAMB16_S36_S36) 32
set width(RAMB16_S9_S9) 8

while {[eof $bramfile] == 0} {
    gets $bramfile line
    incr linenum
    if {$section == "undefined"} {
	if {[string first ": RAMB16_" $line] != -1} {
	    set section [lindex [string trim $line] end]
	}
    } else {
	set key [string trim $line]
	if {[string first "generic map(" $key] == 0} {
	    set generic 1
	} elseif {$generic == 1 && [string first INIT_ $key] == 0} {
	    continue
	} elseif {$key == ")"} {
	    # Construct and dump INIT_xx lines!
	    set eseqn [expr $seqn($section) / (32 / $width($section))]
	    set startaddr [expr $eseqn * 65536 / $width($section)]
	    set endaddr [expr ($eseqn + 1) * 65536 / $width($section)]
	    if {$endaddr > $addr} {
		set endaddr $addr
	    }
	    set mod [expr 1024 / $width($section)]
	    set eindex [expr $seqn($section) % (32 / $width($section))]
	    set cwidth [expr $width($section) / 4]
	    set cfrom [expr 8 - $cwidth * ($eindex + 1)]
	    set cto [expr 7 - $cwidth * $eindex]
	    #
	    set tmp_seqn 0
	    for {set i $startaddr} {$i < $endaddr} {incr i 4} {
		set t [expr ($i / $mod) * $mod + ($mod - 4 - $i) % $mod] 
		set buf "[set buf][string range $mem($t) $cfrom $cto]"
		if {[expr ($mod - 4 - $i) % $mod] == 0} {
		    set entry "			INIT_"
		    set entry "$entry[format %02X $tmp_seqn] => x\"$buf\""
		    if {[expr $i + 4] < $endaddr} {
			lappend filebuf "[set entry],"
		    } else {
			lappend filebuf $entry
		    }
		    set buf ""
		    incr tmp_seqn
		}
	    }
	    #
	    incr seqn($section)
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
