
#include <sys/param.h>
 

//#define	LOOKUP_24_7

#define	UDIVMOD_SIGNED	0x1
#define	UDIVMOD_DO_MOD	0x2


#define	UDIVMOD_BODY()							\
	lo = 0;								\
	uint32_t bit = (b > 0);						\
									\
	while (b < a && (int) b > 0) {					\
		b <<= 1;						\
		bit <<= 1;						\
	}								\
	while (bit != 0) {						\
		if (a >= b) {						\
			a -= b;						\
			lo |= bit;					\
		}							\
		bit >>= 1;						\
		b >>= 1;						\
	}


#ifdef LOOKUP_24_7
static uint32_t div_24_7[126] = {
        0x80000000, 0x55555556, 
        0x40000000, 0x33333334, 0x2aaaaaab, 0x24924925, 
        0x20000000, 0x1c71c71d, 0x1999999a, 0x1745d175, 
        0x15555556, 0x13b13b14, 0x12492493, 0x11111112, 
        0x10000000, 0x0f0f0f10, 0x0e38e38f, 0x0d79435f, 
        0x0ccccccd, 0x0c30c30d, 0x0ba2e8bb, 0x0b21642d, 
        0x0aaaaaab, 0x0a3d70a4, 0x09d89d8a, 0x097b425f, 
        0x0924924a, 0x08d3dcb1, 0x08888889, 0x08421085, 
        0x08000000, 0x07c1f07d, 0x07878788, 0x07507508, 
        0x071c71c8, 0x06eb3e46, 0x06bca1b0, 0x06906907, 
        0x06666667, 0x063e7064, 0x06186187, 0x05f417d1, 
        0x05d1745e, 0x05b05b06, 0x0590b217, 0x0572620b, 
        0x05555556, 0x0539782a, 0x051eb852, 0x05050506, 
        0x04ec4ec5, 0x04d4873f, 0x04bda130, 0x04a7904b, 
        0x04924925, 0x047dc120, 0x0469ee59, 0x0456c798, 
        0x04444445, 0x04325c54, 0x04210843, 0x04104105, 
        0x04000000, 0x03f03f04, 0x03e0f83f, 0x03d22636, 
        0x03c3c3c4, 0x03b5cc0f, 0x03a83a84, 0x039b0ad2, 
        0x038e38e4, 0x0381c0e1, 0x03759f23, 0x0369d037, 
        0x035e50d8, 0x03531ded, 0x03483484, 0x033d91d3, 
        0x03333334, 0x03291620, 0x031f3832, 0x03159722, 
        0x030c30c4, 0x03030304, 0x02fa0be9, 0x02f14991, 
        0x02e8ba2f, 0x02e05c0c, 0x02d82d83, 0x02d02d03, 
        0x02c8590c, 0x02c0b02d, 0x02b93106, 0x02b1da47, 
        0x02aaaaab, 0x02a3a0fe, 0x029cbc15, 0x0295fad5, 
        0x028f5c29, 0x0288df0d, 0x02828283, 0x027c4598, 
        0x02762763, 0x02702703, 0x026a43a0, 0x02647c6a, 
        0x025ed098, 0x02593f6a, 0x0253c826, 0x024e6a18, 
        0x02492493, 0x0243f6f1, 0x023ee090, 0x0239e0d6, 
        0x0234f72d, 0x02302303, 0x022b63cc, 0x0226b903, 
        0x02222223, 0x021d9eae, 0x02192e2a, 0x0214d022, 
        0x02108422, 0x020c49bb, 0x02082083, 0x02040811, 
};
#endif


static uint32_t
__udivmodsi3(uint32_t a, uint32_t b, int flags)
{
#ifndef OPTIMIZED_DIVSI3
	int neg = 0;
#endif
	uint32_t lo;

	if (flags & UDIVMOD_SIGNED) {
		if ((int)b < 0) {
			b = -(int)b;
#ifndef OPTIMIZED_DIVSI3
			neg = 1;
#endif
		}
		if ((int)a < 0) {
			a = -(int)a;
#ifndef OPTIMIZED_DIVSI3
			neg = !neg;
#endif
		}
	}

	UDIVMOD_BODY();

	if (__predict_false(flags & UDIVMOD_DO_MOD))
		return (a);
#ifndef OPTIMIZED_DIVSI3
	if (neg)
		return (-lo);
#endif
	return (lo);
}


int32_t
__divsi3(uint32_t a, uint32_t b)
{
#ifdef LOOKUP_24_7
	uint32_t lo;

	if (b < 128 && b > 1 && (a & 0xff000000) == 0) {
		lo = div_24_7[b - 2];
		__asm volatile (
			".set noreorder\n"
			"multu %1, %2\n"
			"jr $31\n"
			"mfhi $2\n"
			: "=r" (lo)
			: "r" (a), "r" (lo)
		);
	}
	return (__udivmodsi3(a, b, UDIVMOD_SIGNED));
#else
#ifdef OPTIMIZED_DIVSI3
	int neg = 0;
	uint32_t lo;

	if ((int)a < 0) {
		a = -(int)a;
		neg = 1;
	}
	if ((int)b < 0) {
		b = -(int)b;
		neg = !neg;
	}

	UDIVMOD_BODY();

	if (neg)
		return (-lo);
	return (lo);
#else
	return (__udivmodsi3(a, b, UDIVMOD_SIGNED));
#endif /* OPTIMIZED_DIVSI3 */
#endif /* LOOKUP_24_7 */
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
