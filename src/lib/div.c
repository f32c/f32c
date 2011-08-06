
#include <types.h>
 

#define UDIVMOD_SIGNED	0x1
#define UDIVMOD_DO_MOD	0x2

#define	UDIVMOD_BODY()							\
	uint32_t lo = 0;						\
	uint32_t bit = 1;						\
									\
	while (b < a && (b & 0x80000000) == 0 && bit) {			\
		__asm ("addu %0, %1, %1" : "=r" (b) : "r" (b)); 	\
		__asm ("addu %0, %1, %1" : "=r" (bit) : "r" (bit));	\
	}								\
	while (bit) {							\
		if (a >= b) {						\
			lo |= bit;					\
			a -= b;						\
		}							\
		bit >>= 1;						\
		b >>= 1;						\
	}


static uint32_t
__udivmodsi3(uint32_t a, uint32_t b, int flags)
{
	int neg = 0;

	if (flags & UDIVMOD_SIGNED) {
		if ((int)b < 0) {
			b = -(int)b;
			neg = 1;
		}
		if ((int)a < 0) {
			a = -(int)a;
			neg = !neg;
		}
	}

	UDIVMOD_BODY();

	if (flags & UDIVMOD_DO_MOD)
		lo = a;
	if (neg)
		lo = -lo;
	return (lo);
}


int32_t
__divsi3(int32_t a, int32_t b)
{
#ifdef OPTIMIZED_DIVSI3
	int neg = 0;

	if (a < 0) {
		a = -a;
		neg = 1;
	}
	if (b < 0) {
		b = -b;
		neg = !neg;
	}

	UDIVMOD_BODY();

	if (neg)
		lo = -lo;
	return (lo);
#else
	return (__udivmodsi3(a, b, UDIVMOD_SIGNED));
#endif
}
 
 
uint32_t
__modsi3(int32_t a, int32_t b)
{

	return (__udivmodsi3(a, b, UDIVMOD_SIGNED | UDIVMOD_DO_MOD));
}
 
 
uint32_t
__udivsi3(uint32_t a, uint32_t b)
{

	return (__udivmodsi3(a, b, 0));
}
 

uint32_t
__umodsi3(uint32_t a, uint32_t b)
{

	return (__udivmodsi3(a, b, UDIVMOD_DO_MOD));
}
