/*
 * Print messages from all CPU cores on serial console and blink LEDs.
 */

#include <stdio.h>
#include <dev/io.h>

#include <mips/asm.h>

#ifdef __mips__
static const char *arch = "mips";
#elif defined(__riscv)
static const char *arch = "riscv";
#else
static const char *arch = "unknown";
#endif

#define	BTN_ANY	(BTN_CENTER | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)


void
hello_cpu(int cpuid)
{
	int cnt = 0;
	char c;

	printf("Hello f32c/%s world from CPU #%d!\n", arch, cpuid);

	/* Wake up the next CPU */
	OUTW(IO_CPU_RESET, -1 << (cpuid + 2));

	do {
		cnt += cpuid + 13;
		if (cnt < 0x10000000)
			continue;
		cnt = 0;
		INB(c, IO_PUSHBTN);
		if ((c & BTN_ANY) == 0) {
			INB(c, IO_LED);
			c ^= 1 << cpuid;
			OUTB(IO_LED, c);
		}
		printf(" %d", cpuid);
	} while (1);
}


void
main(void)
{
	uint32_t tmp, cpuid;

	mfc0_macro(cpuid, MIPS_COP_0_CONFIG);
	cpuid &= 0xfff;

	tmp = 0x80180000 + 0x1000 * cpuid;
	__asm __volatile__(
		"move $29, %0;"	/* set per-thread SP */
		:
		: "r" (tmp)
	);

	hello_cpu(cpuid);
}
