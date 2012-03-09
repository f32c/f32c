
#include <sys/param.h>
#include <stdio.h>
#include <string.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>

int
cpufreq(void)
{
	int config, freq;

	mfc0_macro(config, MIPS_COP_0_CONFIG);

	freq = ((config >> 16) & 0xfff) * 1000000 / ((config >> 29) + 1);
	printf("mfc0 MIPS_COP_0_CONFIG returned %08x\n", config);
	printf("freq = %d\n", freq);

	return (config);
}

int
main(void)
{

	cpufreq();

	return (0);
}
