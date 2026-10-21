
#include <sys/syscall.h>

#include <mips/regdef.h>

	.section .sdata.__syscall_ptrs
	.align 4
	.globl __syscall_ptrs
__syscall_ptrs:	.space 4

	.text

	.macro	SYSCALL label displacement
	.section .text.\label
	.globl \label
	.type \label, @function
\label:
	j	__syscall_trampoline
	li	v1, \displacement * 4
	.endm

	.set noreorder

#include "../sys/syscalls.S"

	.section .text.__syscall_trampoline
__syscall_trampoline:
	lw	v0, %gprel(__syscall_ptrs)(gp)
	addiu	sp, sp, -24
	addu	v1, v1, v0
	lw	v1, 0(v1)
	sw	ra, 20(sp)
	jal	v1
	lw	gp, 0(v0)

	lw	ra, 20(sp)
	la	gp, _gp
	jr	ra
	addiu	sp, sp, 24

	.set reorder

