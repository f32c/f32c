
#include <sys/param.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <mips/asm.h>
#include <mips/cpuregs.h>


uint32_t
ref_udivmod(uint32_t a, uint32_t b, uint32_t *mod)
{
	uint32_t t1 = b << 31;
	uint32_t t2 = b;
	uint32_t hi = a, lo = 0;
	int i;

	for (i = 0; i < 32; ++i) {
		lo = lo << 1;
		if (hi >= t1 && t1 && t2 < 2) {
			hi = hi - t1;
			lo |= 1;
		}
		t1 = ((t2 & 2) << 30) | (t1 >> 1);
		t2 = t2 >> 1;
	}
	if (mod)
		*mod = hi;
	return (lo);
}


int
ref_divsi3(int a, int b)
{
	int neg = 0;
	int res;

	if (a < 0) {
		a = -a;
		neg = !neg;
	}

	if (b < 0) {
		b = -b;
		neg = !neg;
	}

	res = ref_udivmod(a, b, 0);

	if (neg)
		res = -res;

	return (res);
}


int
main(void)
{
	int a, b, res;

	for (;;) {
		a = random() << 1;
		b = (int)((random() << 1) - random()) >> (a & 0x1f);
		res = ref_divsi3(a, b);
		if (res != a / b)
			printf("a = %d b = %d	a / b = %d\n", a, b, a / b);
	}

	return (0);
}
