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


if {$argc != 1} {
    puts "Usage: isa_check.tcl ifile"
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
	    # Reorder bytes - send MSB (byte 3) first, LSB (byte 0) last
	    set word "[string range $word 6 7][string range $word 4 5][string range $word 2 3][string range $word 0 1]"
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

array set instr_map ""
set elffile [open "| mips-elf-objdump -d [lindex $argv 0]"]
set tot 0
while {[eof $elffile] == 0} {
    gets $elffile line
    if {[string first ":	" $line] < 0} {
	continue
    }
    set instr [lindex [split [string trim $line]] 3]
    if {[array get instr_map $instr] != ""} {
	incr instr_map($instr)
    } else {
	set instr_map($instr) 1
    }
    incr tot
}
close $elffile

set instr_list ""
foreach instr [array names instr_map] {
    lappend instr_list "$instr $instr_map($instr)"
}

set tabcnt 0
set start [lindex [lsort -integer [array names mem]] 0]
set end [lindex [lsort -integer [array names mem]] end]
puts -nonewline "First word 0x[format %08x $start], "
puts -nonewline "last word 0x[format %08x $end], "
puts "$endian endian."
puts "Instruction frequencies (total $tot):"
foreach entry [lsort -integer -decreasing -index 1 $instr_list] {
    puts -nonewline "[format %6s [lindex $entry 0]]:[format %5d [lindex $entry 1]]"
    incr tabcnt
    if {$tabcnt == 5} {
	set tabcnt 0
	puts ""
    } else {
	puts -nonewline "    "
    }
}
if {$tabcnt != 0} {
    puts ""
}

set base_isa_set "sh lhu lh bgtz sllv srav beq sltu bgez srl xor xori lui sw lbu and slt lw andi slti blez nop bne li sra addu nor negu subu bnez jalr or sltiu ori j beqz sll bltz jr sb lb move addiu jal"
set branch_likely_set "bnezl bltzl bnel beql beqzl bgezl bgtzl blezl"
set mul_set "mult multu mflo mfhi"
set unaligned_store_set "swl swr"
set unaligned_load_set "lwl lwr"
set sign_extend_set "seb seh"
set cp0_set "mfc0"

puts -nonewline "Branch likely instructions: "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $branch_likely_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Multiplication instructions: "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $mul_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Sign extend instructions: "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $sign_extend_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "CP0 instructions: "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $cp0_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Unaligned store instructions (unsupported): "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $unaligned_store_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Unaligned load instructions (unsupported): "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch $unaligned_load_set $instr] >= 0} {
	puts -nonewline "$instr "
    }
}
puts ""

puts -nonewline "Other unsupported instructions: "
foreach instr [lsort [array names instr_map]] {
    if {[lsearch "$base_isa_set $mul_set $unaligned_load_set $unaligned_store_set $branch_likely_set $sign_extend_set $cp0_set" $instr] < 0} {
	puts -nonewline "$instr "
    }
}
puts ""
