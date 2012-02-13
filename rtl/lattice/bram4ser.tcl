#!/usr/local/bin/tclsh8.6
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

# $Id: bram4ser.tcl 82 2010-03-17 17:25:23Z marko $

# Move cursor to home position (0,0)
set prog "\033\[H"

set prog "[set prog]                                General registers\033\[K\r\n"
set prog "[set prog] \$0 (zr): ______00   \$8 (t0): ______08  \$16 (s0): ______16  \$24 (t8): ______24\033\[K\r\n"
set prog "[set prog] \$1 (at): ______01   \$9 (t1): ______09  \$17 (s1): ______17  \$25 (t9): ______25\033\[K\r\n"
set prog "[set prog] \$2 (v0): ______02  \$10 (t2): ______10  \$18 (s2): ______18  \$26 (k0): ______26\033\[K\r\n"
set prog "[set prog] \$3 (v1): ______03  \$11 (t3): ______11  \$19 (s3): ______19  \$27 (k1): ______27\033\[K\r\n"
set prog "[set prog] \$4 (a0): ______04  \$12 (t4): ______12  \$20 (s4): ______20  \$28 (gp): ______28\033\[K\r\n"
set prog "[set prog] \$5 (a1): ______05  \$13 (t5): ______13  \$21 (s5): ______21  \$29 (sp): ______29\033\[K\r\n"
set prog "[set prog] \$6 (a2): ______06  \$14 (t6): ______14  \$22 (s6): ______22  \$30 (s8): ______30\033\[K\r\n"
set prog "[set prog] \$7 (a3): ______07  \$15 (t7): ______15  \$23 (s7): ______23  \$31 (ra): ______31\033\[K\r\n"


set prog "[set prog]\033\[K\r\n"
set prog "[set prog]   Cause: ______63    Status: ______62       EPC: ______61  BadVAddr: ______60\033\[K\r\n"
set prog "[set prog]      HI: ______59        LO: ______58\033\[K\r\n"

set prog "[set prog]\033\[K\r\n"
set prog "[set prog]                                    Pipeline\033\[K\r\n"
set prog "[set prog]       FETCH               DECODE              EXECUTE         MEMORY ACCESS\033\[K\r\n"
set prog "[set prog]      PC: ______32        PC: ______33        PC: ______34        PC: ______35\033\[K\r\n"
set prog "[set prog]instruct: ______36  instruct: ______37  instruct: ______38  instruct: ______39\033\[K\r\n"
set prog "[set prog]                    eff_reg1: ______40  eff_reg1: ______42   addsubx: ______45\033\[K\r\n"
set prog "[set prog]                    eff_reg2: ______41  eff_reg2: ______43     logic: ______46\033\[K\r\n"
set prog "[set prog]                                        eff_alu2: ______44  dmem_out: ______47\033\[K\r\n"
set prog "[set prog]                                        op_major: ______49   dmem_in: ______48\033\[K\r\n"
set prog "[set prog]  XXX: ______57\033\[K\r\n"
set prog "[set prog]\033\[K\r\n"
set prog "[set prog]  Cycles: ______52  Instruct: ______53  Branches: ______54     Taken: ______55\033\[K"

# Invisible cursor, clear to end of screen
set prog "[set prog]\033\[?25l\033\[J"

# Mark end of data, which sets bram_addr back to 0
set prog "[set prog]\377"

if { 0 } {
    puts $prog
    exit 0
}

# Substitute ______XX placeholders with appropriate control sequences
for { set i 0 } { $i < [string length $prog] } { incr i } {
    if { [string range $prog $i [expr $i + 5]] == "______" } {
	set addr [string range $prog [expr $i + 6] [expr $i + 7]]
	if { [string index $addr 0] == "0" } {
	    set addr [string range $addr 1 end]
	}
	set subst [binary format cc [expr 128 + $addr] 192]
	set prog [string replace $prog $i [expr $i + 7] $subst]
    }
}

# Convert to INITVAL_XX hex strings for Lattice EBR DP16KB primitive
for {set i 0} { $i < [string length $prog]} {incr i 32} {
    set str_in [string range $prog $i [expr $i + 31]]
    set str_out ""
    set overflow 0
    set bitpos 0
    for {set j 0} {$j < 32} {incr j} {
	binary scan "[string index $str_in $j]" c value
	if { $value < 0 } {
	    incr value 256
	}
	set value [expr ($value << $bitpos) + $overflow]
	set overflow [expr $value >> 8]
	set value [expr $value % 256]
	set str_out "[format %02X $value]$str_out"
	incr bitpos
	if {$bitpos == 2} {
	    set bitpos 0
	    set str_out "[format %01X $overflow]$str_out"
	    set overflow 0
	}
    }

    set str_out "		INITVAL_[format %02X [expr $i / 32]] => \"0x[set str_out]\","
    puts $str_out
}
