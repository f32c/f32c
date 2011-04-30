
#include <types.h>

uint32_t
__mulsi3(uint32_t a, uint32_t b)
{
	uint32_t res;

	for (res = 0; b != 0; b >>= 1, a <<= 1)
		if (b & 1)
			res += a;
	return (res);
}
 
