#include <errno.h>

static int _errno;

int *
__error(void)
{

	return (&_errno);
}
