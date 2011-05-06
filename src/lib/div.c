
#include <types.h>
 

static uint32_t
udivmod(uint32_t hi, uint32_t b, int do_mod)
{
	uint32_t a = b << 31;
	uint32_t lo = 0;
	int i;

	for (i = 0; i < 32; i++) {
		lo <<= 1;
		if (a != 0 && hi >= a && b < 2) {
			hi -= a;
			lo |= 1;
		}
		a = (a >> 1) | ((b & 2) << 30);
		b >>= 1;
	}
	if (do_mod)
		return (hi);
	return (lo);
}
 
 
uint32_t
__udivsi3(uint32_t a, uint32_t b)
{

	return (udivmod(a, b, 0));
}
 

int32_t
__divsi3(int32_t a, int32_t b)
{
	int res, neg = 0;

	if(a < 0) {
		a = -a;
		neg = !neg;
	}
	if (b < 0) {
		b = -b;
		neg = !neg;
	}
	res = udivmod(a, b, 0);
	if (neg)
		res = -res;
	return (res);
}
 
 
uint32_t
__umodsi3(uint32_t a, uint32_t b)
{

	return (udivmod(a, b, 1));
}
