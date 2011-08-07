#!/usr/local/bin/tclsh8.6
#
# Copyright 2010,2011 University of Zagreb.
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


if {$argc != 2} {
    puts "Usage: elf2hex.tcl ifile ofile"
    exit 1
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
	    set addr $line_addr
	}
	if {$endian == "none"} {
	    puts "Undefined endianess at line $linenum"
	    exit 1
	}
	set l1 [string range $line 0 40]
	for {set i 1} {$i <= 4} {incr i} {
	    set word [lindex $l1 $i]
	    if {$word == ""} {
		set word 00000000
	    }
	    if {$section == ".text" || $endian == "little"} {
		# Switch endianess
		set word "[string range $word 6 7][string range $word 4 5][string range $word 2 3][string range $word 0 1]"
	    }
	    set mem($addr) $word
	    incr addr 4
	}
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

set hexfile [open [lindex $argv 1] w]
foreach addr [lsort -integer [array names mem]] {
    if {$addr % 16 == 0} {
	puts -nonewline $hexfile "[format %08x $addr]: "
    }
    if {$addr % 16 == 12} {
	puts $hexfile "$mem($addr)"
    } else {
	puts -nonewline $hexfile "$mem($addr) "
    }
}
if {$addr % 16 != 12} {
    puts $hexfile ""
}
puts $hexfile ""
close $hexfile

array set instr_map ""
set elffile [open "| mips-elf-objdump -d [lindex $argv 0]"]
while {[eof $elffile] == 0} {
    gets $elffile line
    if {[string first ":	" $line] < 0} {
	continue
    }
    set instr [lindex [split [string trim $line]] 3]
    if {[array get instr_map $instr] != ""} {
	incr instr_map($instr) 1
    } else {
	set instr_map($instr) 1
    }
}
close $elffile

set instr_list ""
foreach instr [array names instr_map] {
    lappend instr_list "$instr $instr_map($instr)"
}

set tabcnt 0
puts "Instruction frequencies:"
foreach entry [lsort -integer -decreasing -index 1 $instr_list] {
    puts -nonewline "[format %8s [lindex $entry 0]]: [lindex $entry 1]	"
    incr tabcnt 1
    if {$tabcnt == 4} {
	set tabcnt 0
	puts ""
    }
}
if {$tabcnt != 0} {
    puts ""
}

set base_isa_set "beq sltu bgez srl xor xori lui sw lbu and slt lw andi slti blez nop bne li sra addu nor negu subu bnez jalr or sltiu ori j beqz sll bltz jr sb lb move addiu jal"
set mul1_isa_set "$base_isa_set mult multu mflo mfhi"
set m32r1_isa_set "$mul1_isa_set movn movz mul"
set m32r2_isa_set "$m32r1_isa_set seb seh"

puts -nonewline "Not in base ISA: "
foreach instr [array names instr_map] {
    if {[lsearch $base_isa_set $instr] < 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Not in mul1 ISA: "
foreach instr [array names instr_map] {
    if {[lsearch $mul1_isa_set $instr] < 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Not in 32r1 ISA: "
foreach instr [array names instr_map] {
    if {[lsearch $m32r1_isa_set $instr] < 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Not in 32r2 ISA: "
foreach instr [array names instr_map] {
    if {[lsearch $m32r2_isa_set $instr] < 0} {
	puts -nonewline "$instr "
    }
}
puts ""
