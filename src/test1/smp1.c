
#include <sys/param.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>

#include <mips/asm.h>


static __inline void
atomic_set_32(__volatile uint32_t *p, uint32_t v)
{
	uint32_t temp;

	__asm __volatile (
		"1:\n"
		"	ll %0, %3\n"		/* load old value */
		"	or %0, %2, %0\n"	/* calculate new value */
		"	sc %0, %1\n"		/* attempt to store */
		"	beqz %0, 1b\n"		/* spin if failed */
		: "=&r" (temp), "=m" (*p)
		: "r" (v), "m" (*p)
		: "memory"
	);
}


int
main(void)
{
	int i, cpuid;
	volatile uint32_t *p = (void *) 0x80080000;

	mfc0_macro(cpuid, MIPS_COP_0_CONFIG);
	cpuid &= 0xf;

	printf("Hello, world from CPU #%d\n", cpuid);

	if (cpuid > 0) {
		/* This will execute only on CPU #1 */
		do {
			*p = *p + 1;
		} while (1);
	}

	printf("Starting CPU #1...\n");
	*p = 0;
	OUTB(IO_CPU_RESET, ~3);

	/* Wait for CPU #1 to become active */
	do {} while (*p == 0);

	printf("Loop starting on CPU #0...\n");
	for (i = 0; i < 100; i++) {
		printf("%d ", *p);
//		atomic_set_32(p, 0);
	}
	printf("\n");

	printf("Stopping CPU #1...\n");
	OUTB(IO_CPU_RESET, ~1);

	return (0);
}
