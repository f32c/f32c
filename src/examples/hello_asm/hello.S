/*
 * Print a message on serial console, and blink LEDs until a button
 * is pressed on the ULX2S FPGA board.
 *
 * $Id $
 */

#include <mips/asm.h>
#include <io.h>

	.data
msg:	.asciiz	"Hello, FPGA world!\n"

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
	addiu	t1, t1, 1
	sb	t0, IO_LED(zero)
	beqz	t2, 1b
	
	# return
	jr	s0

