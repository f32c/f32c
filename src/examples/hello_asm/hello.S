/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id$
 */

#include <io.h>
#ifdef __mips__
#include <mips/asm.h>
#endif

	.data
#ifdef __mips__
msg:	.asciiz	"Hello, FPGA world!\nI'm running on a f32c/mips CPU core.\n"
#else /* riscv */
msg:	.ascii	"Hello, FPGA world!\nI'm running on a f32c/riscv CPU core.\n"
#endif

	.text
	.globl	main
	.type	main,@function
main:
	# store return addres in s0
	move	s0, ra

	# print a message
	la	a0, msg
	jal	printf

	move	t1, zero
1:
	lb	t2, IO_PUSHBTN(zero)
	srl	t0, t1, 20
#ifdef __mips__
	addiu	t1, t1, 1
#else /* riscv */
	addi	t1, t1, 1
#endif
	sb	t0, IO_LED(zero)
	beqz	t2, 1b
	
	# return
	jr	s0

