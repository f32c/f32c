
#include <sys/syscall.h>

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
	li	t1, \displacement * 4
	j	__syscall_trampoline
	.endm

#include "../sys/syscalls.S"

	.section .text.__syscall_trampoline
__syscall_trampoline:
	la	t0, __syscall_ptrs
	addi	sp, sp, -24
	add	t1, t1, t0
	lw	gp, 0(t0)
	lw	t1, 0(t1)
	sw	ra, 20(sp)
	jalr	t1

	lw	ra, 20(sp)
	la	gp, __global_pointer$
	addi	sp, sp, 24
	jr	ra

