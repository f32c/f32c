
#include <sys/param.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>

#include <mips/asm.h>
#include <mips/atomic.h>


int
main(void)
{
	int i, r, cpuid;
	volatile uint32_t *p = (void *) 0x80080000;

	mfc0_macro(cpuid, MIPS_COP_0_CONFIG);
	cpuid &= 0xf;

	printf("Hello, world from CPU #%d\n", cpuid);

	if (cpuid > 0) {
		/* This will execute only on CPU #1 */
		do {
			atomic_add_32(p, 1);
		} while (1);
	}

	printf("Starting CPU #1...\n");
	*p = 0;
	OUTB(IO_CPU_RESET, ~3);

	/* Wait for CPU #1 to become active */
	do {} while (*p == 0);

	printf("Loop starting on CPU #0...\n");
	for (i = 0; i < 1000000; i++) {
		atomic_clear_32(p, 0xffffffff);
		r = *p;
		if (r > 0)
			printf("%d:%d ", i, r);
	}
	printf("\n");

	printf("Stopping CPU #1...\n");
	OUTB(IO_CPU_RESET, ~1);

	return (0);
}
