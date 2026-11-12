
#include <sys/sched.h>
#include <sys/time.h>

#pragma weak nanosleep
int
nanosleep(const struct timespec *rqtp, struct timespec *rmtp)
{
	struct task *task = TD_TASK(curthread);
	struct timespec lim, now;
	int res = 0;

	clock_gettime(CLOCK_MONOTONIC, &now);
	timespecadd(&now, rqtp, &lim);
	do {
		sched_yield();
		if (task->ts_sigf & 2) {
			errno = EINTR;
			task->ts_sigf &= ~2;
			res = -1;
			break;
		}
		clock_gettime(CLOCK_MONOTONIC, &now);
	} while (timespeccmp(&now, &lim, <));

	if (rmtp != NULL)
		*rmtp = *rqtp;

	return (res);
}
