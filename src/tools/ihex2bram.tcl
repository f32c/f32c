#!/usr/local/bin/tclsh8.6
#

# $Id: $


if {$argc == 0} {
    puts "Usage: ./ihex2bram.tcl ifile \[ofile\]"
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
    if {[string index $line 0] != ":"} {
	if {$line == ""} {
	    continue;
	}
	puts "Invalid input file format at line $linenum"
	exit 1
    }
    set len [scan [string range $line 1 2] %02x]
    set block_addr [scan [string range $line 3 6] %04x]
    set type [scan [string range $line 7 8] %02x]
    if {$type != 0} {
	continue
    }
    while {$addr < $block_addr} {
	set mem($addr) 0
	incr addr
    }
    for {set i 0} {$i < [expr $len * 2]} {incr i 2} {
	set val [scan [string range $line [expr 9 + $i] [expr 10 + $i]] %x]
	set mem($addr) $val
	incr addr
    }
}
close $hexfile

# Pad mem to 512 byte-block boundary
while {[expr $addr % 512] != 0} {
    set mem($addr) 0
    incr addr
}
set endaddr $addr

set bramfile [open $ofile]
set linenum 0
set section undefined
set generic 0
set buf ""
set filebuf ""


proc peek {byte_addr} {
    global mem

    return $mem($byte_addr)
}


while {[eof $bramfile] == 0} {
    gets $bramfile line
    incr linenum
    if {$section == "undefined"} {
	if {[string first ": DP16KB" $line] != -1} {
	    set section [lindex [split [string trim $line] _:] 1]
	    set seqn [lindex [split [string trim $line] _:] 2]
	    set width [expr 64 / $section]
	}
    } else {
	set key [string trim $line]
	if {$section != "undefined" &&
	  [string first "generic map" $key] == 0} {
	    # Beginning of generic section detected
	    set generic 1
	} elseif {$generic == 1 && [string first INITVAL_ $key] == 0} {
	    # Prune old INITVAL_ lines
	    continue
	} elseif {$key == ")"} {
	    # Construct and dump INITVAL_xx lines!
	    set addrstep [expr $section * 16]
	    for {set addr 0} {$addr < $endaddr} {incr addr $addrstep} {
		for {set i 0} {$i < 32} {incr i} {
		    switch $section {
		    8 {
			set byte_addr [expr $addr + $seqn + $i * 4]
			set ivbuf($i) [peek $byte_addr]
		    }
		    16 {
			set byte_addr [expr $addr + $seqn / 2 + $i * 8]
			if {[expr $seqn % 2] == 0} {
			    set ivbuf($i) [expr [peek $byte_addr] % 16]
			} else {
			    set ivbuf($i) [expr [peek $byte_addr] / 16]
			}
			set byte_addr [expr $addr + $seqn / 2 + $i * 8 + 4]
			if {[expr $seqn % 2] == 0} {
			    incr ivbuf($i) [expr ([peek $byte_addr] % 16) * 16]
			} else {
			    incr ivbuf($i) [expr ([peek $byte_addr] / 16) * 16]
			}
		    }
		    default {
			puts "Unsuported memory configuration: $section"
			exit 1
		    }
		    }
		}
		set hex ""
		for {set i 0} {$i < 32} {incr i} {
		    if {[expr $i % 2] == 0} {
			set hex "[format %02X $ivbuf($i)][set hex]"
		    } else {
			set hex "[format %03X [expr $ivbuf($i) * 2]][set hex]"
		    }
		}
		set prefix "INITVAL_[format %02x [expr $addr / $addrstep]] =>"
		if {$addr < [expr $endaddr - $addrstep]} {
		    lappend filebuf "		$prefix \"0x[set hex]\","
		} else {
		    lappend filebuf "		$prefix \"0x[set hex]\""
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
