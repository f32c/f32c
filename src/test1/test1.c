
#include <sys/param.h>
#include <io.h>
#include <stdio.h>

#include <mips/asm.h>


int fib(int);


int
fib(int n)
{

	if (n < 2)
		return (n);
	else
		return (fib(n-1) + fib(n-2));
} 


int
main(void)
{
	uint32_t tmp, freq_khz;
	uint32_t start, end;

	printf("Hello, MIPS world!\n\n");

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

	printf("f32c @ %d.%03d MHz, code running from ",
	    freq_khz / 1000, freq_khz % 1000);
#ifdef BRAM
	printf("FPGA block RAM.\n\n");
#else
	printf("external static RAM.\n\n");
#endif

	RDTSC(start);
	for (tmp = 0; tmp <= 30; tmp++)
		printf("fib(%d) = %d\n", tmp, fib(tmp));
	RDTSC(end);
	printf("\nCompleted in %d ms\n", (end - start) / freq_khz);

	return (0);
}
