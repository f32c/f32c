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

# $Id: elf2bram.tcl 126 2011-03-30 09:50:18Z marko $


if {$argc == 0} {
    puts "Usage: ./elf2bram.tcl ifile \[ofile\]"
    exit 1
} elseif {$argc == 1} {
    set ofile bram.vhd
} else {
    set ofile [lindex $argv 1]
}

set elffile [open "| mips-rtems-objdump -s [lindex $argv 0]"]
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
	    set addr $line_addr
	}
	if {$endian == "none"} {
	    puts "Undefined endianess at line $linenum"
	    exit 1
	}
	puts -nonewline "[format %08X $addr]: "
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
	puts ""
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
