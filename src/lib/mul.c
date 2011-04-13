
#include <types.h>

u_int
__mulsi3(u_int a, u_int b)
{
	u_int res = 0;

	while (b) {
		if (b & 1)
			res += a;
		a <<= 1;
		b >>= 1;
	}
	return (res);
}
 
