
#include <sys/time.h>

#pragma weak nanosleep
int
nanosleep(const struct timespec *rqtp, struct timespec *rmtp)
{
	struct timespec lim, now;

	clock_gettime(CLOCK_MONOTONIC, &now);
	timespecadd(&now, rqtp, &lim);
	do {
		clock_gettime(CLOCK_MONOTONIC, &now);
	} while (timespeccmp(&now, &lim, <));

	if (rmtp != NULL)
		*rmtp = *rqtp;

	return (0);
}
