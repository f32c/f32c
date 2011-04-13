
#include <types.h>
 

static u_int
divmod(u_int a, u_int b, int mod)
{
	u_int hi = a, lo = 0;
	int i;
	a = b << 31;

	for (i = 0; i < 32; ++i) {
		lo = lo << 1;
		if (hi >= a && a && b < 2) {
			hi = hi - a;
			lo |= 1;
		}
		a = ((b & 2) << 30) | (a >> 1);
		b = b >> 1;
	}
	if (!mod)
		return (lo);
	return (hi);
}
 
 
u_int
__udivsi3(u_int a, u_int b)
{

	return (divmod(a, b, 0));
}
 

int
__divsi3(int a, int b)
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
	res = divmod(a, b, 0);
	if (neg)
		res = -res;
	return (res);
}
 
 
u_int
__umodsi3(u_int a, u_int b)
{

	return (divmod(a, b, 1));
}

int
__modsi3(int a, int b)
{

	return (divmod(a, b, 1));
}
