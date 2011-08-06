
#include <io.h>
#include <types.h>
#include <stdio.h>


extern void pcm_play(void);


int
main(void)
{
	int a = 1;
	
	/* Register PCM output function as idle loop handler */
	sio_idle_fn = pcm_play;

#ifdef STANDARD_MIPS32_ISA
	printf("\n\nStart test - MIPS32 ISA movn / movz\n");

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n1 (30)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n2 (0)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movn $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n3 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z1 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z2 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movz $10, $8, $9\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z3 (30)	a = %d\n", a);

#else	/* F32C ISA */
	printf("\n\nStart test - F32C ISA movn / movz\n");

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n1 (30)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n2 (0)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movn $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("n3 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 50\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z1 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 0\n"
		"li $9, 50\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z2 (10)	a = %d\n", a);

	__asm(
		".set noreorder\n"
		"li $10, 10\n"
		"li $8, 30\n"
		"li $9, 0\n"
		"movz $10, $9, $8\n"
		"move %0, $10\n"
		".set reorder\n"
		: "=r" (a)
	);
	printf("z3 (30)	a = %d\n", a);
#endif

	return (0);
}
