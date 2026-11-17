
#include <sys/sched.h>
#include <sys/signalvar.h>
#include <sys/time.h>

#pragma weak nanosleep
int
nanosleep(const struct timespec *rqtp, struct timespec *rmtp)
{
	struct timespec lim, now;
	int res = 0;

	clock_gettime(CLOCK_MONOTONIC, &now);
	timespecadd(&now, rqtp, &lim);
	do {
		sched_yield();
		if (SIGPENDING(curthread)) {
			errno = EINTR;
			res = -1;
			break;
		}
		clock_gettime(CLOCK_MONOTONIC, &now);
	} while (timespeccmp(&now, &lim, <));

	if (rmtp != NULL)
		*rmtp = *rqtp;

        if (TD_TASK(curthread)->ts_parent == NULL && SIGPENDING(curthread))
                sig_dispatch();
	return (res);
}
