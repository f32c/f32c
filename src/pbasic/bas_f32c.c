
#include <sys/param.h>

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <fatfs/ff.h>

#include <io.h>

#include "bas.h"


int
bauds(void)
{
	int bauds;

	bauds = evalint();
	check();
	if (bauds < 300 || bauds > 3000000)
                error(33);      /* argument error */
	sio_setbaud(bauds);
        normret;
}


int
bas_sleep(void)
{
	uint64_t start, end, now;
	int c;

	start = tsc_hi;
	start = (start << 32) + tsc_lo;

	evalreal();
	check();
	if (res.f < ZERO)
                error(33);      /* argument error */
	end = start + (uint64_t) (res.f * 1000.0 * freq_khz);

	do {
		now = tsc_hi;
		now = (now << 32) + tsc_lo;
		c = sio_getchar(0);
	} while (c != 3 && now <= end);

	if (c == 3)
		trapped = 1;
        normret;
}
