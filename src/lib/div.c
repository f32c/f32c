
#include <types.h>
 

static uint32_t udivmod(uint32_t, uint32_t, int);


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


int32_t
__divsi3(int32_t a, int32_t b)
{
	int neg = 0;

	if (a < 0) {
		a = -a;
		neg = !neg;
	}
	if (b < 0) {
		b = -b;
		neg = !neg;
	}

#ifdef OPTIMIZED_DIVSI3
	UDIVMOD_BODY();
#else
	int lo = udivmod(a, b, 0);
#endif

	if (neg)
		lo = -lo;
	return (lo);
}
 
 
uint32_t
__modsi3(int32_t a, int32_t b)
{
	int res, neg = 0;

	if (b < 0)
		b = -b;
	if (a < 0) {
		a = -a;
		neg = !neg;
	}

	res = udivmod(a, b, 1);

	if (neg)
		res = -res;
	return (res);
}
 
 
uint32_t
__umodsi3(uint32_t a, uint32_t b)
{

	return (udivmod(a, b, 1));
}


uint32_t
__udivsi3(uint32_t a, uint32_t b)
{

	return (udivmod(a, b, 0));
}
 

static uint32_t
udivmod(uint32_t a, uint32_t b, int do_mod)
{

	UDIVMOD_BODY();

	if (do_mod)
		return (a);
	return (lo);
}
