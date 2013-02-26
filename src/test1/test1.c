
#include <sys/param.h>
#include <io.h>
#include <stdio.h>

#include <mips/asm.h>

int
main(void)
{
	uint32_t tmp, freq_khz;

	printf("Hello, MIPS world!\n\n");

	mfc0_macro(tmp, MIPS_COP_0_CONFIG);
	freq_khz = ((tmp >> 16) & 0xfff) * 1000 / ((tmp >> 29) + 1);

	printf("f32c @ %d.%03d MHz, code running from ",
	    freq_khz / 1000, freq_khz % 1000);
#ifdef BRAM
	printf("FPGA block RAM.\n");
#else
	printf("external static RAM.\n");
#endif

	return (0);
}
