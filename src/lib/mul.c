
#include <types.h>

u_int
__mulsi3(u_int a, u_int b)
{
	u_int res;

	for (res = 0; b != 0; b >>= 1, a <<= 1)
		if (b & 1)
			res += a;
	return (res);
}
 
